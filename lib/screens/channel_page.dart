import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_compress/video_compress.dart';

class PollOption {
  final String text;
  final String id;

  PollOption({required this.text, required this.id});
}

class ChannelPage extends StatefulWidget {
  const ChannelPage({super.key});

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  final StreamMessageInputController _messageInputController =
      StreamMessageInputController();
  final bool _isProcessing = false;
  late final String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = StreamChat.of(context).currentUser?.id;
  }

  void _showProcessingDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff2c2c2c),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Processing video...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _hideProcessingDialog() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty && mounted) {
      for (final file in result.files) {
        if (file.path != null) {
          if (file.size > 100 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video file size must be less than 100MB'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            continue;
          }

          try {
            _showProcessingDialog();

            // Compress video
            final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
              file.path!,
              quality: VideoQuality.MediumQuality,
              includeAudio: true,
              frameRate: 24,
            );

            if (mediaInfo?.file == null) {
              throw Exception('Video compression failed');
            }

            final compressedFile = mediaInfo!.file!;
            final compressedSize = await compressedFile.length();
            final duration = mediaInfo.duration?.toInt() ?? 60000;

            // Create attachment
            final attachment = Attachment(
              type: 'video',
              file: AttachmentFile(
                size: compressedSize,
                path: compressedFile.path,
                name: file.name,
              ),
              extraData: {
                'mime_type': 'video/${file.extension?.toLowerCase() ?? 'mp4'}',
                'file_size': compressedSize,
                'duration': duration,
              },
            );

            _hideProcessingDialog();

            // Add the attachment to the message input
            _messageInputController.addAttachment(attachment);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video ready to send'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            _hideProcessingDialog();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error processing video: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    }
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty && mounted) {
      for (final file in result.files) {
        if (file.path != null) {
          final attachment = Attachment(
            type: 'image',
            file: AttachmentFile(
              size: file.size,
              path: file.path,
              name: file.name,
            ),
            uploadState: const UploadState.preparing(),
            extraData: {
              'mime_type': 'image/${file.extension?.toLowerCase() ?? 'jpeg'}',
              'file_size': file.size,
            },
          );
          _messageInputController.addAttachment(attachment);
        }
      }
    }
  }

  Future<void> _showAttachmentPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff2c2c2c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'Add to your message',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentButton(
                  icon: Icons.image_rounded,
                  label: 'Photos',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImages();
                  },
                ),
                _AttachmentButton(
                  icon: Icons.video_library_rounded,
                  label: 'Video',
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo();
                  },
                ),
                _AttachmentButton(
                  icon: Icons.poll_rounded,
                  label: 'Poll',
                  onTap: () async {
                    final parentContext = context;
                    Navigator.pop(context);
                    await Future.delayed(const Duration(milliseconds: 200));

                    if (!parentContext.mounted) return;

                    // For now, show a placeholder for poll functionality
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(
                        content: Text('Poll feature coming soon!'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StreamChannelHeader(
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          const Expanded(
            child: StreamMessageListView(),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
            child: StreamMessageInput(
              messageInputController: _messageInputController,
              actionsLocation: ActionsLocation.left,
              disableAttachments: false,
              showCommandsButton: false,
              attachmentButtonBuilder: (context, defaultButton) {
                return IconButton(
                  icon: const Icon(
                    Icons.add_circle_rounded,
                    color: Colors.white54,
                    size: 24,
                  ),
                  onPressed: _showAttachmentPicker,
                );
              },
              idleSendButton: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white54,
                ),
              ),
              activeSendButton: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(
                  Icons.send_rounded,
                  color: Color(0xFF90EE90), // Light green color
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
