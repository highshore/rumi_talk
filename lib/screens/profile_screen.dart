import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app/screens/profile_detail_screen.dart';
import 'package:firebase_app/services/stream_service.dart';
import 'package:firebase_app/services/friend_service.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app/widgets/tag.dart';
import 'package:firebase_app/utils/interests.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream_chat;
import 'package:firebase_app/screens/channel_page.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum StatType { interested, joined, ledHost }

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  bool _openingDm = false;

  Widget _buildAuthButtons(bool isCurrentUser, {String? otherUserId}) {
    if (!isCurrentUser) {
      return Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xff4f46e5), Color(0xff7c3aed)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: () =>
                    _startDirectMessageWith(otherUserId ?? widget.userId),
                icon: const Icon(Icons.message),
                label: const Text('Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    // Current user: no auth buttons here anymore; they live in ProfileDetailScreen
    return const SizedBox.shrink();
  }

  Future<void> _startDirectMessageWith(String otherUserId) async {
    if (_openingDm) return;
    setState(() => _openingDm = true);
    try {
      // Allow messaging only if friends
      final friendService = FriendService();
      final isFriend = await friendService.isFriendWith(otherUserId);
      if (!isFriend) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You can only message friends. Send a request first.',
              ),
            ),
          );
        }
        return;
      }
      final client = StreamService.staticClient;
      final currentUserId = _auth.currentUser!.uid;
      final channel = client.channel(
        'messaging',
        extraData: {
          'members': [currentUserId, otherUserId],
          'isDirectMessage': true,
          'distinct': true,
        },
      );
      // watch will create the channel if it doesn't exist and return state
      await channel.watch();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => stream_chat.StreamChannel(
            channel: channel,
            child: const ChannelPage(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
    } finally {
      if (mounted) setState(() => _openingDm = false);
    }
  }

  void _navigateToProfileDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(userId: widget.userId),
      ),
    );
  }

  // Delete/Sign out actions moved to ProfileDetailScreen for current user

  @override
  Widget build(BuildContext context) {
    final String currentUid = _auth.currentUser?.uid ?? '';
    final bool isCurrentUser = (currentUid == widget.userId);

    return Scaffold(
      backgroundColor: const Color(0xff181818),
      appBar: Navigator.canPop(context)
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Error: ${userSnapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    _buildAuthButtons(
                      isCurrentUser,
                      otherUserId: widget.userId,
                    ),
                  ],
                ),
              ),
            );
          }
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading profile...',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    _buildAuthButtons(isCurrentUser),
                  ],
                ),
              ),
            );
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'User not found or no data available',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    _buildAuthButtons(isCurrentUser),
                  ],
                ),
              ),
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final displayName =
              (userData['displayName'] ?? _auth.currentUser?.displayName)
                  as String?;
          final profileImage =
              userData['profileImage'] ?? userData['photoURL'] ?? '';
          final email = userData['email'] ?? '';
          final List<String> interests =
              ((userData['interests'] ?? []) as List<dynamic>)
                  .map((e) => e.toString())
                  .toList();

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GestureDetector(
                          onTap: isCurrentUser
                              ? () => _navigateToProfileDetail(context)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(20.0),
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: const Color(0xff1a1a1a),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xff2a2a2a),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xff333333),
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 45,
                                    backgroundColor: const Color(0xff2a2a2a),
                                    backgroundImage:
                                        (profileImage is String &&
                                            profileImage.isNotEmpty)
                                        ? NetworkImage(profileImage)
                                        : null,
                                    child:
                                        (profileImage is! String ||
                                            profileImage.isEmpty)
                                        ? const Icon(
                                            Icons.person,
                                            size: 48,
                                            color: Colors.white70,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName ?? 'Unknown User',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        email,
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'ID: ${widget.userId}',
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.copy,
                                              color: Colors.white54,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              Clipboard.setData(
                                                ClipboardData(
                                                  text: widget.userId,
                                                ),
                                              );
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'User ID copied',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      if (interests.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: interests.map((interest) {
                                            final emoji = getEmojiForInterest(
                                              interest,
                                            );
                                            final color = getColorForInterest(
                                              interest,
                                            );
                                            return Tag(
                                              label: interest,
                                              emoji: emoji,
                                              color: color,
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SafeArea(
                  top: false,
                  child: _buildAuthButtons(isCurrentUser),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
