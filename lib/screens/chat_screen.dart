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

  /// Navigates back to the Home screen
  void _navigateToHome() {
    // Since we're using a navbar, we don't need to navigate
    // The user can just tap the Home tab
  }

  @override
  Widget build(BuildContext context) {
    final theme = StreamChatTheme.of(context);

    return Scaffold(
      body: _listController == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Custom header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xff242424),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Joined Events",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Didn't join an event yet? Don't miss out",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () {
                                  // For now, show a placeholder
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Event discovery coming soon!'),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.explore),
                                label: const Text("Discover Events"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 15),
      leading: StreamChannelAvatar(channel: channel),
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
              textStyle: theme.channelPreviewTheme.titleStyle!.copyWith(
                color: theme.colorTheme.textHighEmphasis.withOpacity(opacity),
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
              textStyle: theme.channelPreviewTheme.subtitleStyle,
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
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          // Unread count
          Flexible(
            flex: 1,
            child: (channel.state?.unreadCount ?? 0) > 0
                ? CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.red,
                    child: Text(
                      channel.state!.unreadCount.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}
