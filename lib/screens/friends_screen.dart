import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/screens/profile_screen.dart';
import 'package:firebase_app/services/friend_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _addUidController = TextEditingController();
  final FriendService _friendService = FriendService();

  Future<void> _sendFriendRequest(BuildContext context) async {
    final String input = _addUidController.text.trim();
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (input.isEmpty || currentUser == null) return;

    final bool isEmail = input.contains('@');
    if ((isEmail &&
            input.toLowerCase() == (currentUser.email ?? '').toLowerCase()) ||
        (!isEmail && input == currentUser.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot send a request to yourself.')),
      );
      return;
    }

    try {
      final res = await _friendService.sendFriendRequest(
        targetUid: isEmail ? null : input,
        targetEmail: isEmail ? input : null,
      );
      _addUidController.clear();
      if (!mounted) return;
      final status = (res['status'] ?? 'sent').toString();
      final msg = switch (status) {
        'already_friends' => 'You are already friends.',
        'already_sent' => 'Request already sent.',
        'accepted' => 'Request matched and accepted. You are now friends.',
        _ => 'Friend request sent.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send request: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xff181818),
      body: Column(
        children: [
          // Add by ID or Email (single input)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xff333333),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _addUidController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add Friend (ID or Email)',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xff0f0f0f),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) => _sendFriendRequest(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xff4f46e5), Color(0xff7c3aed)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _sendFriendRequest(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Friends list via friendships
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('friendships')
                  .where('participants', arrayContains: currentUser!.uid)
                  .where('status', isEqualTo: 'accepted')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Failed to load friends'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final friendshipDocs = snapshot.data!.docs;
                if (friendshipDocs.isEmpty) {
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
                              Icons.people_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No friends yet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add friends using their ID or email above',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final myUid = currentUser.uid;
                final friendIds = friendshipDocs.map((d) {
                  final p = d.data()['participants'] as List<dynamic>;
                  final a = p[0].toString();
                  final b = p[1].toString();
                  return a == myUid ? b : a;
                }).toList();

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where(
                        FieldPath.documentId,
                        whereIn: friendIds.length > 10
                            ? friendIds.sublist(0, 10)
                            : friendIds,
                      )
                      .snapshots(),
                  builder: (context, usersSnap) {
                    if (usersSnap.hasError) {
                      return const Center(
                        child: Text('Failed to load friends'),
                      );
                    }
                    if (!usersSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = usersSnap.data!.docs;
                    return ListView.builder(
                      itemCount: docs.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final f = doc.data();
                        final name =
                            (f['displayName'] ?? f['email'] ?? 'Unknown')
                                as String;
                        final email = (f['email'] ?? '') as String;
                        final photo =
                            (f['profileImage'] ?? f['photoURL'] ?? '')
                                as String;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xff1a1a1a),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xff2a2a2a),
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xff333333),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xff2a2a2a),
                                backgroundImage: photo.isNotEmpty
                                    ? NetworkImage(photo)
                                    : null,
                                child: photo.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.white70,
                                        size: 24,
                                      )
                                    : null,
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: email.isNotEmpty
                                ? Text(
                                    email,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xff2a2a2a),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white70,
                                size: 16,
                              ),
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(userId: doc.id),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
