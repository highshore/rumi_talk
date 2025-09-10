import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/services/friend_service.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final _auth = FirebaseAuth.instance;
  final FriendService _friendService = FriendService();

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xff181818),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Friend Requests',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: uid == null
          ? const Center(
              child: Text(
                'Not signed in',
                style: TextStyle(color: Colors.white),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('friendships')
                  .where('participants', arrayContains: uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error loading requests: ${snap.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;

                final List<String> receivedIds = [];
                final List<String> sentIds = [];
                for (final d in docs) {
                  final data = d.data();
                  final String requester = (data['requester'] ?? '') as String;
                  final String recipient = (data['recipient'] ?? '') as String;
                  if (recipient == uid) {
                    receivedIds.add(requester);
                  }
                  if (requester == uid) {
                    sentIds.add(recipient);
                  }
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Received',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (receivedIds.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xff1a1a1a),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xff2a2a2a)),
                        ),
                        child: const Text(
                          'No incoming requests',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else
                      _UsersList(
                        userIds: receivedIds,
                        trailingBuilder: (context, uid) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () async {
                                try {
                                  await _friendService.acceptFriendRequest(
                                    fromUid: uid,
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed: $e')),
                                    );
                                  }
                                }
                              },
                              child: const Text('Accept'),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await _friendService.declineFriendRequest(
                                    fromUid: uid,
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed: $e')),
                                    );
                                  }
                                }
                              },
                              child: const Text(
                                'Decline',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),
                    const Text(
                      'Sent',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (sentIds.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xff1a1a1a),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xff2a2a2a)),
                        ),
                        child: const Text(
                          'No sent requests',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else
                      _UsersList(
                        userIds: sentIds,
                        trailingBuilder: (context, uid) => TextButton(
                          onPressed: () async {
                            try {
                              await _friendService.cancelFriendRequest(
                                toUid: uid,
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                              }
                            }
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.orangeAccent),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _UsersList extends StatelessWidget {
  final List<String> userIds;
  final Widget Function(BuildContext, String) trailingBuilder;

  const _UsersList({required this.userIds, required this.trailingBuilder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where(
            FieldPath.documentId,
            whereIn: userIds.length > 10 ? userIds.sublist(0, 10) : userIds,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Failed to load users',
            style: TextStyle(color: Colors.white),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snapshot.data!.docs;
        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final name =
                (data['displayName'] ?? data['email'] ?? 'Unknown') as String;
            final photo =
                (data['profileImage'] ?? data['photoURL'] ?? '') as String;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xff1a1a1a),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xff2a2a2a), width: 1),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xff2a2a2a),
                  backgroundImage: photo.isNotEmpty
                      ? NetworkImage(photo)
                      : null,
                  child: photo.isEmpty
                      ? const Icon(Icons.person, color: Colors.white70)
                      : null,
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  doc.id,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                trailing: trailingBuilder(context, doc.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
