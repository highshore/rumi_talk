import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'channel_page.dart';

/// The main screen that displays all channels the user has joined.
/// Tapping the search icon opens [ChatSearchScreen].
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  StreamChannelListController? _listController;
  late Filter _defaultFilter;
  bool _isControllerInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isControllerInitialized) {
      final userId = StreamChat.of(context).currentUser?.id;
      if (userId == null) {
        // Handle the null user scenario appropriately
        print('Error: Current user is null');
        return;
      }

      _defaultFilter = Filter.in_('members', [userId]);

      _listController = StreamChannelListController(
        client: StreamChat.of(context).client,
        filter: _defaultFilter,
        channelStateSort: const [SortOption('last_message_at')],
        limit: 20,
      );
      _isControllerInitialized = true;
    }
  }

  @override
  void dispose() {
    _listController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xff181818),
      body: _listController == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Channel list
                Expanded(
                  child: StreamChannelListView(
                    controller: _listController!,
                    onChannelTap: (channel) {
                      // Navigate to ChannelPage wrapped with StreamChannel
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => StreamChannel(
                                channel: channel,
                                child: const ChannelPage(),
                              ),
                            ),
                          )
                          .then((_) => _listController!.refresh());
                    },
                    emptyBuilder: (context) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xff1a1a1a),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xff2a2a2a), width: 2),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'No chats yet',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add friends and start a conversation',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    itemBuilder: _channelTileBuilder,
                  ),
                ),
              ],
            ),
    );
  }

  /// Builds each Channel tile, including logic for attachments/deleted messages
  Widget _channelTileBuilder(
    BuildContext context,
    List<Channel> channels,
    int index,
    StreamChannelListTile defaultTile,
  ) {
    final theme = StreamChatTheme.of(context);
    final channel = channels[index];

    // Grab the last message including deleted ones
    final lastMessage = channel.state?.messages.reversed.firstWhereOrNull(
      (_) => true,
    );

    // Determine the subtitle for the channel
    String subtitle;
    if (lastMessage == null) {
      subtitle = 'nothing yet';
    } else if (lastMessage.isDeleted) {
      subtitle = 'Message deleted';
    } else {
      // Not deleted
      final userName = lastMessage.user?.name ?? 'Someone';
      final text = lastMessage.text?.trim() ?? '';
      if (text.isEmpty && lastMessage.attachments.isNotEmpty) {
        final attachmentType = lastMessage.attachments.first.type;
        switch (attachmentType) {
          case 'image':
            subtitle = '$userName sent a photo';
            break;
          case 'video':
            subtitle = '$userName sent a video';
            break;
          default:
            subtitle = '$userName sent a file';
        }
      } else {
        subtitle = text.isEmpty ? 'nothing yet' : text;
      }
    }

    // Adjust opacity if no unread messages
    final opacity = (channel.state?.unreadCount ?? 0) > 0 ? 1.0 : 0.5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xff1a1a1a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff2a2a2a), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xff333333), width: 2),
          ),
          child: StreamChannelAvatar(channel: channel),
        ),
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => StreamChannel(
                    channel: channel,
                    child: const ChannelPage(),
                  ),
                ),
              )
              .then((_) => _listController!.refresh());
        },
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Channel Name
            Flexible(
              flex: 3,
              child: StreamChannelName(
                channel: channel,
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Last Message Time
            Flexible(
              flex: 1,
              child: StreamChannelInfo(
                channel: channel,
                showTypingIndicator: false,
                textStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Last message text or "message deleted"
            Flexible(
              flex: 3,
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            // Unread count
            Flexible(
              flex: 1,
              child: (channel.state?.unreadCount ?? 0) > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xff4f46e5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        channel.state!.unreadCount.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
