import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/screens/profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addUidController = TextEditingController();

  Future<void> _addFriendByUid(BuildContext context) async {
    final String uidToAdd = _addUidController.text.trim();
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (uidToAdd.isEmpty || currentUser == null) return;

    if (uidToAdd == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot add yourself as a friend.')),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uidToAdd).get();
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found. Check the UID and try again.')),
        );
        return;
      }

      final currentRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final friendRef = FirebaseFirestore.instance.collection('users').doc(uidToAdd);

      // Add each other to friends lists (mutual)
      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.update(currentRef, {
          'friends': FieldValue.arrayUnion([uidToAdd]),
        });
        tx.update(friendRef, {
          'friends': FieldValue.arrayUnion([currentUser.uid]),
        });
      });

      _addUidController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend added.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add friend: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xff181818),
      body: Column(
        children: [
          // Add by UID row (compact)
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
                        border: Border.all(color: const Color(0xff333333), width: 1),
                      ),
                      child: TextField(
                        controller: _addUidController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add Friend (Enter User ID)',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xff0f0f0f),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onSubmitted: (_) => _addFriendByUid(context),
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
                      onPressed: () => _addFriendByUid(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add',
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
          // Friends list (only user's friends)
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Failed to load friends'));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.data()!;
                final List<dynamic> friendIdsDyn = (data['friends'] ?? []) as List<dynamic>;
                final List<String> friendIds = friendIdsDyn.map((e) => e.toString()).toList();

                if (friendIds.isEmpty) {
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
                            'Add friends using their user ID above',
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
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where(FieldPath.documentId, whereIn: friendIds.length > 10 ? friendIds.sublist(0, 10) : friendIds)
                      .snapshots(),
                  builder: (context, friendsSnap) {
                    if (friendsSnap.hasError) {
                      return const Center(child: Text('Failed to load friends'));
                    }
                    if (!friendsSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = friendsSnap.data!.docs;

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No friends match your search', style: TextStyle(color: Colors.white60)),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final f = doc.data();
                        final name = (f['displayName'] ?? f['email'] ?? 'Unknown') as String;
                        final email = (f['email'] ?? '') as String;
                        final photo = (f['profileImage'] ?? f['photoURL'] ?? '') as String;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xff2a2a2a),
                                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                                child: photo.isEmpty 
                                    ? const Icon(Icons.person, color: Colors.white70, size: 24) 
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
