import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  FriendService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : auth = auth ?? FirebaseAuth.instance,
      firestore = firestore ?? FirebaseFirestore.instance;

  String _pairId(String a, String b) =>
      (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';

  Future<Map<String, dynamic>> sendFriendRequest({
    String? targetUid,
    String? targetEmail,
  }) async {
    final current = auth.currentUser;
    if (current == null) {
      throw 'not_authenticated';
    }

    String? toUid = targetUid;

    if ((toUid == null || toUid.isEmpty) &&
        targetEmail != null &&
        targetEmail.isNotEmpty) {
      // Lookup user by email
      final q = await firestore
          .collection('users')
          .where('email', isEqualTo: targetEmail)
          .limit(1)
          .get();
      if (q.docs.isEmpty) {
        throw 'user_not_found';
      }
      toUid = q.docs.first.id;
    }

    if (toUid == null || toUid.isEmpty) {
      throw 'invalid_target';
    }
    if (toUid == current.uid) {
      throw 'cannot_self_request';
    }

    final id = _pairId(current.uid, toUid);
    final ref = firestore.collection('friendships').doc(id);

    return await firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final String status = (data['status'] ?? 'pending') as String;
        final String requester = (data['requester'] ?? '') as String;
        final String recipient = (data['recipient'] ?? '') as String;
        if (status == 'accepted') {
          return {'status': 'already_friends'};
        }
        if (status == 'pending') {
          if (requester == current.uid) {
            return {'status': 'already_sent'};
          }
          if (recipient == current.uid) {
            // Auto-accept on reciprocal request
            tx.update(ref, {
              'status': 'accepted',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return {'status': 'accepted'};
          }
        }
        return {'status': 'already_sent'};
      } else {
        tx.set(ref, {
          'participants': [current.uid, toUid],
          'requester': current.uid,
          'recipient': toUid,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return {'status': 'sent'};
      }
    });
  }

  Future<void> acceptFriendRequest({required String fromUid}) async {
    final current = auth.currentUser;
    if (current == null) {
      throw 'not_authenticated';
    }
    final id = _pairId(current.uid, fromUid);
    final ref = firestore.collection('friendships').doc(id);
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw 'request_not_found';
      }
      final data = snap.data() as Map<String, dynamic>;
      if (data['status'] == 'accepted') return;
      if (data['recipient'] != current.uid) {
        throw 'not_recipient';
      }
      tx.update(ref, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> declineFriendRequest({required String fromUid}) async {
    final current = auth.currentUser;
    if (current == null) {
      throw 'not_authenticated';
    }
    final id = _pairId(current.uid, fromUid);
    final ref = firestore.collection('friendships').doc(id);
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      if (data['status'] != 'pending') return;
      if (data['recipient'] != current.uid) {
        throw 'not_recipient';
      }
      tx.delete(ref);
    });
  }

  Future<void> cancelFriendRequest({required String toUid}) async {
    final current = auth.currentUser;
    if (current == null) {
      throw 'not_authenticated';
    }
    final id = _pairId(current.uid, toUid);
    final ref = firestore.collection('friendships').doc(id);
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      if (data['status'] != 'pending') return;
      if (data['requester'] != current.uid) {
        throw 'not_requester';
      }
      tx.delete(ref);
    });
  }

  Future<bool> isFriendWith(String otherUid) async {
    final current = auth.currentUser;
    if (current == null) return false;
    final id = _pairId(current.uid, otherUid);
    final doc = await firestore.collection('friendships').doc(id).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>;
    return (data['status'] == 'accepted');
  }

  Future<void> migrateLegacyFriendData() async {
    final current = auth.currentUser;
    if (current == null) return;
    final userRef = firestore.collection('users').doc(current.uid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) return;
    final userData = userSnap.data() as Map<String, dynamic>;
    if ((userData['friendshipsMigrated'] ?? false) == true) {
      return;
    }

    final List<String> friends = ((userData['friends'] ?? []) as List<dynamic>)
        .map((e) => e.toString())
        .toList();
    final List<String> sent =
        ((userData['friend_requests_sent'] ?? []) as List<dynamic>)
            .map((e) => e.toString())
            .toList();
    final List<String> received =
        ((userData['friend_requests_received'] ?? []) as List<dynamic>)
            .map((e) => e.toString())
            .toList();

    // Accepted friendships
    for (final other in friends.toSet()) {
      if (other == current.uid) continue;
      final id = _pairId(current.uid, other);
      final ref = firestore.collection('friendships').doc(id);
      await firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          tx.set(ref, {
            'participants': [current.uid, other],
            'requester': other,
            'recipient': current.uid,
            'status': 'accepted',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final data = snap.data() as Map<String, dynamic>;
          if ((data['status'] ?? 'pending') != 'accepted') {
            tx.update(ref, {
              'status': 'accepted',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
    }

    // Sent pending
    for (final other in sent.toSet()) {
      if (other == current.uid) continue;
      final id = _pairId(current.uid, other);
      final ref = firestore.collection('friendships').doc(id);
      await firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          tx.set(ref, {
            'participants': [current.uid, other],
            'requester': current.uid,
            'recipient': other,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          final data = snap.data() as Map<String, dynamic>;
          if (data['status'] == 'pending' &&
              data['recipient'] == current.uid &&
              data['requester'] == other) {
            tx.update(ref, {
              'status': 'accepted',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
    }

    // Received pending
    for (final other in received.toSet()) {
      if (other == current.uid) continue;
      final id = _pairId(current.uid, other);
      final ref = firestore.collection('friendships').doc(id);
      await firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          tx.set(ref, {
            'participants': [current.uid, other],
            'requester': other,
            'recipient': current.uid,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    }

    await userRef.set({
      'friendshipsMigrated': true,
      'friends': [],
      'friend_requests_sent': [],
      'friend_requests_received': [],
      'friend_count': friends.length,
    }, SetOptions(merge: true));
  }
}
