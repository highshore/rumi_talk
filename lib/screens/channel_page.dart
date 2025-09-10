import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:firebase_app/services/ai_service.dart';

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
  final AiService _ai = AiService();
  final GlobalKey<_CustomTranslateInputState> _inputKey =
      GlobalKey<_CustomTranslateInputState>();

  void _showProcessingDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff2c2c2c),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing video...', style: TextStyle(color: Colors.white)),
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

            _messageInputController.addAttachment(attachment);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video ready to send'),
                  backgroundColor: Colors.grey,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

  Future<void> _showAutoTranslateSheet() async {
    final channel = StreamChannel.of(context).channel;
    final currentUserLang =
        StreamChat.of(context).currentUser?.language ?? 'en';
    final enabled =
        (channel.extraData['auto_translation_enabled'] as bool?) ?? false;
    final currentLang =
        (channel.extraData['auto_translation_language'] as String?) ??
        currentUserLang;
    final practiceDialogEnabled =
        (channel.extraData['practice_dialog_enabled'] as bool?) ?? true;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff2c2c2c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool localEnabled = enabled;
        String localLang = currentLang;
        bool saving = false;
        bool localPractice = practiceDialogEnabled;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Auto translation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Enable for this channel',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Switch(
                        value: localEnabled,
                        onChanged: (v) => setModalState(() => localEnabled = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Practice dialog before sending',
                          style: TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Switch(
                        value: localPractice,
                        onChanged: (v) =>
                            setModalState(() => localPractice = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Translate to language',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: localLang,
                    dropdownColor: const Color(0xff2c2c2c),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'es', child: Text('Spanish')),
                      DropdownMenuItem(value: 'ko', child: Text('Korean')),
                      DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                      DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                      DropdownMenuItem(value: 'fr', child: Text('French')),
                      DropdownMenuItem(value: 'de', child: Text('German')),
                      DropdownMenuItem(value: 'it', child: Text('Italian')),
                      DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
                    ],
                    onChanged: (v) =>
                        setModalState(() => localLang = v ?? localLang),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                try {
                                  setModalState(() => saving = true);
                                  await channel.update({
                                    'auto_translation_enabled': localEnabled,
                                    'auto_translation_language': localLang,
                                    'practice_dialog_enabled': localPractice,
                                  });
                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Saved: Auto-translation ${localEnabled ? 'ON' : 'OFF'} (${_mapIsoToName(localLang)}), Practice dialog ${localPractice ? 'ON' : 'OFF'}',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to update: $e'),
                                    ),
                                  );
                                } finally {
                                  if (mounted)
                                    setModalState(() => saving = false);
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _mapIsoToName(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return 'English';
      case 'es':
        return 'Spanish';
      case 'ko':
        return 'Korean';
      case 'ja':
        return 'Japanese';
      case 'zh':
        return 'Chinese';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      default:
        return code;
    }
  }

  @override
  void dispose() {
    _messageInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff181818),
      appBar: StreamChannelHeader(
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
        actions: [
          IconButton(
            tooltip: 'Auto-translate',
            icon: const Icon(Icons.translate_rounded),
            onPressed: _showAutoTranslateSheet,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Expanded(
              child: StreamMessageListView(
                markReadWhenAtTheBottom: true,
                messageBuilder: (context, details, messages, defaultMessage) {
                  // Use the default message but hide the username
                  return StreamMessageWidget(
                    message: details.message,
                    messageTheme: StreamMessageThemeData(
                      messageAuthorStyle: const TextStyle(
                        fontSize: 0,
                        height: 0,
                      ),
                      createdAtStyle: StreamChatTheme.of(
                        context,
                      ).textTheme.footnote.copyWith(color: Colors.white38),
                    ),
                  );
                },
              ),
            ),
            _CustomTranslateInput(
              key: _inputKey,
              controller: _messageInputController,
              onPickAttachment: _showAttachmentPicker,
              ai: _ai,
            ),
          ],
        ),
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
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CustomTranslateInput extends StatefulWidget {
  final StreamMessageInputController controller;
  final VoidCallback onPickAttachment;
  final AiService ai;

  const _CustomTranslateInput({
    super.key,
    required this.controller,
    required this.onPickAttachment,
    required this.ai,
  });

  @override
  State<_CustomTranslateInput> createState() => _CustomTranslateInputState();
}

class _CustomTranslateInputState extends State<_CustomTranslateInput> {
  bool _sending = false;
  String? _targetLang;
  final TextEditingController _textController = TextEditingController();

  void setText(String value) {
    _textController.text = value;
  }

  Future<void> _handleSend() async {
    if (_sending) return;
    final channel = StreamChannel.of(context).channel;
    final text = _textController.text.trim();
    final attachments = widget.controller.attachments;
    if (text.isEmpty && attachments.isEmpty) return;

    // Practice dialog may be disabled per-channel setting
    final practiceEnabled =
        (channel.extraData['practice_dialog_enabled'] as bool?) ?? true;

    // Practice dialog: translate first, then ask user to type the translation
    Map<String, dynamic>? practiceResult;
    if (text.isNotEmpty && practiceEnabled) {
      practiceResult = await _showPracticeDialog(originalText: text);
      if (!mounted || practiceResult == null) return; // cancelled
    }

    setState(() => _sending = true);
    try {
      if (practiceResult != null) {
        final original = (practiceResult['original'] as String).trim();
        final translated = (practiceResult['translated'] as String).trim();
        await channel.sendMessage(
          Message(
            text: translated,
            attachments: attachments,
            extraData: {
              'original_text': original,
              'translated_text': translated,
              'target_lang': _targetLang ?? await _loadTargetLang(),
              'translated': true,
            },
          ),
        );
      } else {
        // No dialog mode: send raw input immediately (no translation)
        await channel.sendMessage(
          Message(text: text, attachments: attachments),
        );
      }
      widget.controller.clear();
      _textController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<Map<String, dynamic>?> _showPracticeDialog({
    required String originalText,
  }) async {
    final iso = await _loadTargetLang();
    final targetName = _mapIsoToName(iso);

    // Gather recent messages and channel meta as context
    final channel = StreamChannel.of(context).channel;
    final state = channel.state;
    final recent = (state?.messages ?? [])
        .where((m) => (m.text ?? '').isNotEmpty)
        .toList()
        .reversed
        .take(10)
        .toList()
        .reversed
        .map((m) => '${m.user?.name ?? m.user?.id ?? 'User'}: ${m.text}')
        .toList();
    final meta = <String, dynamic>{
      'cid': channel.cid,
      'name': channel.name,
      'members': channel.state?.members.map((e) => e.userId).toList() ?? [],
      'extraData': channel.extraData,
    };

    String translated = await widget.ai.translate(
      text: originalText,
      targetLang: targetName,
      history: recent,
      meta: meta,
    );
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String typed = '';
        bool showMore = false;
        bool loading = false;
        return StatefulBuilder(
          builder: (ctx, setState) {
            final canSend = typed.trim() == translated.trim();
            return AlertDialog(
              backgroundColor: const Color(0xff2c2c2c),
              title: const Text(
                'Practice and Send',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Original Message',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xff1f1f1f),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        originalText,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Translated',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xff1f1f1f),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              translated,
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Try writing yourself',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      minLines: 2,
                      maxLines: 5,
                      onChanged: (v) => setState(() => typed = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Enter the translated sentence…',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => showMore = !showMore),
                        child: Text(showMore ? 'Hide options' : 'More options'),
                      ),
                    ),
                    if (showMore)
                      Row(
                        children: [
                          TextButton(
                            onPressed: loading
                                ? null
                                : () => Navigator.of(ctx).pop({
                                    'original': originalText,
                                    'translated': translated,
                                    'action': 'send_anyway',
                                  }),
                            child: const Text('Send Anyway'),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: loading
                                ? null
                                : () async {
                                    setState(() => loading = true);
                                    try {
                                      final newText = await widget.ai.translate(
                                        text: originalText,
                                        targetLang: targetName,
                                        history: recent,
                                        meta: meta,
                                      );
                                      setState(() {
                                        translated = newText;
                                        typed = '';
                                      });
                                    } finally {
                                      setState(() => loading = false);
                                    }
                                  },
                            child: const Text('Translate again'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: canSend
                      ? () => Navigator.of(ctx).pop({
                          'original': originalText,
                          'translated': translated,
                          'action': 'send_verified',
                        })
                      : null,
                  child: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white24, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_rounded, color: Colors.white54),
              onPressed: widget.onPickAttachment,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 6,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Type a message…'),
              ),
            ),
            IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: Color(0xF0F0F0F0)),
              onPressed: _sending ? null : _handleSend,
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _loadTargetLang() async {
    if (_targetLang != null && _targetLang!.isNotEmpty) return _targetLang!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'en';
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final code = (snap.data()?['targetLang'] ?? 'en').toString();
    _targetLang = code;
    return code;
  }

  String _mapIsoToName(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return 'English';
      case 'es':
        return 'Spanish';
      case 'ko':
        return 'Korean';
      case 'ja':
        return 'Japanese';
      case 'zh':
        return 'Chinese';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      default:
        return 'English';
    }
  }
}
