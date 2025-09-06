import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream_chat;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class StreamService {
  final stream_chat.StreamChatClient client;
  final firebase_auth.FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  StreamService({
    required this.client,
    required this.auth,
    required this.firestore,
    required this.functions,
  });

  Future<void> connectStreamUser() async {
    try {
      final firebaseUser = auth.currentUser;
      print('Current Firebase user: ${firebaseUser?.uid}');
      if (firebaseUser == null) throw Exception('No Firebase user found');

      // Check if user is already connected
      if (client.state.currentUser?.id == firebaseUser.uid) {
        print('User already connected to Stream');
        return;
      }

      // Fetch user data from Firestore
      String? displayNameFromDb;
      String? imageFromDb;
      try {
        final userDoc =
            await firestore.collection('users').doc(firebaseUser.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          print('User data from Firestore: $userData');
          displayNameFromDb = userData['displayName'] as String?;
          imageFromDb = (userData['profileImage'] ?? userData['avatarUrl']) as String?;
        } else {
          // ignore: avoid_print
          print('No user document found in Firestore, using Firebase profile');
        }
      } catch (e) {
        // ignore: avoid_print
        print('Skipping Firestore user read due to error: $e');
      }

      // For development, use dev token. In production, use cloud function
      String streamToken;
      try {
        print('Calling generateStreamToken function...');
        final callable = functions.httpsCallable('generateStreamToken');
        final result = await callable.call({
          'userId': firebaseUser.uid,
        });
        print('Stream token response: ${result.data}');
        streamToken = result.data['token'] as String;
      } catch (e) {
        print('Cloud function failed, using dev token: $e');
        // Fallback to dev token for development
        streamToken = client.devToken(firebaseUser.uid).rawValue;
      }

      print('Stream token: $streamToken');

      // Create a Stream User object from Firebase user data
      final streamUser = stream_chat.User(
        id: firebaseUser.uid,
        name: displayNameFromDb ?? firebaseUser.displayName,
        image: imageFromDb ?? firebaseUser.photoURL,
        extraData: {
          'email': firebaseUser.email,
        },
      );

      await client.disconnectUser(); // Disconnect any existing connection
      await client.connectUser(
        streamUser,
        streamToken,
      );
      print('Successfully connected to Stream');
    } catch (e, stackTrace) {
      print('Error connecting Stream user: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Updates the Stream Chat user's name and image.
  Future<void> updateStreamUser({String? name, String? image}) async {
    final user = auth.currentUser;
    if (user == null) return;

    await client.updateUser(
      stream_chat.User(
        id: user.uid,
        name: name,
        image: image,
      ),
    );
  }

  Future<void> deleteUser() async {
    final user = auth.currentUser;
    if (user == null) return;

    try {
      // Get all channels where the user is a member
      final filter = stream_chat.Filter.in_('members', [user.uid]);
      final channels = await client.queryChannels(filter: filter).first;

      // Remove user from all channels
      for (final channel in channels) {
        try {
          await channel.removeMembers([user.uid]);
        } catch (e) {
          print('Error removing user from channel: $e');
        }
      }

      // Disconnect the user
      await client.disconnectUser();
    } catch (e) {
      print('Error during user deletion from Stream Chat: $e');
    }
  }

  /// Static methods for backwards compatibility and easier access
  static const String _defaultApiKey = 'YOUR_STREAM_API_KEY'; // Replace in dev or pass via --dart-define
  static stream_chat.StreamChatClient? _client;

  static stream_chat.StreamChatClient get staticClient {
    if (_client == null) {
      throw Exception('Stream client not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Initialize the Stream client
  static Future<void> initialize() async {
    if (_client != null) return; // Already initialized
    final apiKey = _resolveApiKey();
    if (apiKey == _defaultApiKey) {
      // ignore: avoid_print
      print('StreamService: Missing STREAM_API_KEY. Provide with --dart-define=STREAM_API_KEY=YOUR_KEY');
    }
    _client = stream_chat.StreamChatClient(
      apiKey,
      logLevel: stream_chat.Level.INFO,
    );
  }

  static String _resolveApiKey() {
    const String keyFromEnv = String.fromEnvironment('STREAM_API_KEY', defaultValue: '');
    if (keyFromEnv.isNotEmpty) return keyFromEnv;
    return _defaultApiKey;
  }

  /// Disconnect the current user from Stream
  static Future<void> disconnectUser() async {
    if (_client != null) {
      await _client!.disconnectUser();
      print('Stream user disconnected');
    }
  }

  /// Dispose the Stream client
  static Future<void> dispose() async {
    if (_client != null) {
      await _client!.dispose();
      _client = null;
      print('Stream client disposed');
    }
  }
}
