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
  String _searchQuery = '';
  bool _showUnreadOnly = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listController == null) {
      final userId = StreamChat.of(context).currentUser?.id;
      if (userId == null) {
        // Will try again on next dependency change/build
        return;
      }
      _defaultFilter = Filter.in_('members', [userId]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _listController != null) return;
        setState(() {
          _listController = StreamChannelListController(
            client: StreamChat.of(context).client,
            filter: _defaultFilter,
            channelStateSort: const [SortOption('last_message_at')],
            limit: 20,
          );
        });
      });
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
                // Header like Kakao/WhatsApp
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      children: [
                        // Search bar
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xff1f1f1f),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xff2a2a2a),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            onChanged: (v) =>
                                setState(() => _searchQuery = v.trim()),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Search',
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Filter chips
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('All'),
                              selected: !_showUnreadOnly,
                              onSelected: (val) =>
                                  setState(() => _showUnreadOnly = false),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Unread'),
                              selected: _showUnreadOnly,
                              onSelected: (val) =>
                                  setState(() => _showUnreadOnly = true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Channel list
                Expanded(
                  child: StreamChannelListView(
                    controller: _listController!,
                    onChannelTap: (channel) {
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
                                  border: Border.all(
                                    color: const Color(0xff2a2a2a),
                                    width: 2,
                                  ),
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
    StreamChatTheme.of(context);
    final channel = channels[index];

    // Optional filters (search / unread) applied client-side
    final channelName = channel.name?.toLowerCase() ?? '';
    final members =
        channel.state?.members
            .map((m) => m.user?.name ?? m.userId)
            .join(', ')
            .toLowerCase() ??
        '';
    final lastMessage = channel.state?.messages.reversed.firstWhereOrNull(
      (_) => true,
    );
    final lastText = lastMessage?.text?.toLowerCase() ?? '';
    final matchesSearch = _searchQuery.isEmpty
        ? true
        : (channelName.contains(_searchQuery.toLowerCase()) ||
              members.contains(_searchQuery.toLowerCase()) ||
              lastText.contains(_searchQuery.toLowerCase()));
    final unread = channel.state?.unreadCount ?? 0;
    if (!matchesSearch || (_showUnreadOnly && unread == 0)) {
      return const SizedBox.shrink();
    }

    // Determine the subtitle for the channel (typing indicator, attachments, last text)
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

    // Format time like WhatsApp/Kakao
    String timeLabel = '';
    final lmAt = lastMessage?.createdAt;
    if (lmAt != null) {
      final now = DateTime.now();
      final local = lmAt.toLocal();
      final isSameDay =
          now.year == local.year &&
          now.month == local.month &&
          now.day == local.day;
      if (isSameDay) {
        final hh = local.hour % 12 == 0 ? 12 : local.hour % 12;
        final mm = local.minute.toString().padLeft(2, '0');
        final ampm = local.hour >= 12 ? 'PM' : 'AM';
        timeLabel = '$hh:$mm $ampm';
      } else {
        timeLabel = '${local.month}/${local.day}/${local.year % 100}';
      }
    }

    // Adjust opacity if no unread messages

    final isUnread = unread > 0;
    return InkWell(
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) =>
                    StreamChannel(channel: channel, child: const ChannelPage()),
              ),
            )
            .then((_) => _listController!.refresh());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Row(
          children: [
            // Avatar (use Stream default sizing/behavior for best fit)
            StreamChannelAvatar(channel: channel),
            const SizedBox(width: 12),
            // Middle: name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StreamChannelName(
                          channel: channel,
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUnread ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Unread badge
            if (isUnread)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff4f46e5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
