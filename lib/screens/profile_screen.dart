import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app/services/auth_service.dart';
import 'package:firebase_app/screens/profile_detail_screen.dart';
import 'package:firebase_app/services/stream_service.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app/widgets/tag.dart';
import 'package:firebase_app/utils/interests.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream_chat;
import 'package:firebase_app/screens/channel_page.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum StatType { interested, joined, ledHost }

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  StatType _activeStat = StatType.joined;

  Stream<QuerySnapshot> _getEventsForActiveStat(String uid) {
    switch (_activeStat) {
      case StatType.interested:
        return FirebaseFirestore.instance
            .collection('events')
            .where('interested', arrayContains: uid)
            .snapshots();
      case StatType.joined:
        return FirebaseFirestore.instance
            .collection('events')
            .where('participants', arrayContains: uid)
            .snapshots();
      case StatType.ledHost:
        return FirebaseFirestore.instance
            .collection('events')
            .where('leaders', arrayContains: uid)
            .snapshots();
    }
  }

  Stream<int> _countInterested(String uid) {
    return FirebaseFirestore.instance
        .collection('events')
        .where('interested', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Widget _buildAuthButtons(bool isCurrentUser, {String? otherUserId}) {
    if (isCurrentUser) {
      return Column(
        children: [
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xffdc2626), Color(0xffb91c1c)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: () async {
                await _authService.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _confirmDeleteAccount,
              child: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
            ),
          ),
        ],
      );
    } else {
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
                onPressed: () => _startDirectMessageWith(otherUserId ?? widget.userId),
                icon: const Icon(Icons.message),
                label: const Text('Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Future<void> _startDirectMessageWith(String otherUserId) async {
    try {
      final client = StreamService.staticClient;
      final currentUserId = _auth.currentUser!.uid;
      final channel = client.channel('messaging', extraData: {
        'members': [currentUserId, otherUserId],
        'isDirectMessage': true,
      });
      await channel.create();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: $e')),
      );
    }
  }

  Stream<int> _countJoined(String uid) {
    return FirebaseFirestore.instance
        .collection('events')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _countLed(String uid) {
    return FirebaseFirestore.instance
        .collection('events')
        .where('leaders', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  void _handleStatTap(StatType statType) {
    setState(() => _activeStat = statType);
  }

  void _navigateToProfileDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(userId: widget.userId),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xff242424),
          title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
          content: const Text(
            'This will permanently delete your account and data. Continue?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.blueAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    try {
      final streamService = StreamService(
        client: StreamService.staticClient,
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
        functions: FirebaseFunctions.instance,
      );
      await streamService.deleteUser();
      await _authService.deleteAccount();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e')),
        );
      }
    }
  }

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
                    Text('Error: ${userSnapshot.error}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 24),
                    _buildAuthButtons(isCurrentUser, otherUserId: widget.userId),
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
                    const Text('Loading profile...', style: TextStyle(color: Colors.white70)),
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
                    const Text('User not found or no data available', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 24),
                    _buildAuthButtons(isCurrentUser),
                  ],
                ),
              ),
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final displayName = (userData['displayName'] ?? _auth.currentUser?.displayName) as String?;
          final memberStatus = userData['memberStatus'] ?? '';
          final profileImage = userData['profileImage'] ?? userData['photoURL'] ?? '';
          final email = userData['email'] ?? '';
          final List<String> interests = ((userData['interests'] ?? []) as List<dynamic>)
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
                          onTap: isCurrentUser ? () => _navigateToProfileDetail(context) : null,
                        child: Container(
                          padding: const EdgeInsets.all(20.0),
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            color: const Color(0xff1a1a1a),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xff2a2a2a), width: 1),
                          ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xff333333), width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 45,
                                  backgroundColor: const Color(0xff2a2a2a),
                                  backgroundImage: (profileImage is String && profileImage.isNotEmpty)
                                      ? NetworkImage(profileImage)
                                      : null,
                                  child: (profileImage is! String || profileImage.isEmpty)
                                      ? const Icon(Icons.person, size: 48, color: Colors.white70)
                                      : null,
                                ),
                              ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                        style: const TextStyle(color: Colors.white60, fontSize: 12),
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
                                            icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: widget.userId));
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('User ID copied')),
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
                                            final emoji = getEmojiForInterest(interest);
                                            final color = getColorForInterest(interest);
                                            return Tag(label: interest, emoji: emoji, color: color);
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

class _StatCard extends StatelessWidget {
  final String number;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _StatCard({
    required this.number,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? const Color(0xff212121) : const Color(0xff181818),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
