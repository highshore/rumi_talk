import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/auth_service.dart';
import 'services/stream_service.dart';
import 'services/friend_service.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up Firebase Messaging background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Stream Chat
  await StreamService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    final notoText = GoogleFonts.notoSansTextTheme(base.textTheme);
    return MaterialApp(
      title: 'RumiTalk',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xff181818),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xff4f46e5),
          secondary: Color(0xff7c3aed),
          surface: Color(0xff1a1a1a),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.notoSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
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
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textTheme: notoText.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      builder: (context, child) => StreamChat(
        client: StreamService.staticClient,
        streamChatThemeData: StreamChatThemeData.fromTheme(Theme.of(context)),
        child: child!,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isConnectingStream = false;
  bool _didConnectStream = false;
  bool _didMigrateFriendships = false;

  Future<void> _connectStreamUser() async {
    if (_isConnectingStream) return;

    setState(() {
      _isConnectingStream = true;
    });

    try {
      // Create StreamService instance with required dependencies
      final streamService = StreamService(
        client: StreamService.staticClient,
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
        functions: FirebaseFunctions.instance,
      );

      await streamService.connectStreamUser();

      // Set up push notifications after Stream connection
      await _setupPushNotifications();
    } catch (e) {
      print('Failed to connect Stream user: $e');
    } finally {
      setState(() {
        _isConnectingStream = false;
      });
    }
  }

  Future<void> _setupPushNotifications() async {
    try {
      // Request permission for iOS
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission for push notifications');

        // Get FCM token
        final token = await messaging.getToken();
        if (token != null) {
          print('FCM Token: $token');

          // Add device to Stream Chat for push notifications
          await StreamService.staticClient.addDevice(
            token,
            PushProvider.firebase,
          );
          print('Device registered with Stream Chat for push notifications');
        }

        // Listen to token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          print('FCM token refreshed: $newToken');
          await StreamService.staticClient.addDevice(
            newToken,
            PushProvider.firebase,
          );
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('Got a message whilst in the foreground!');
          print('Message data: ${message.data}');

          if (message.notification != null) {
            print(
              'Message also contained a notification: ${message.notification}',
            );
          }
        });
      } else {
        print(
          'User declined or has not accepted permission for push notifications',
        );
      }
    } catch (e) {
      print('Error setting up push notifications: $e');
    }
  }

  Future<void> _disconnectStreamUser() async {
    try {
      await StreamService.disconnectUser();
    } catch (e) {
      print('Failed to disconnect Stream user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_auth.User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isConnectingStream) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connecting to RumiTalk...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          // User is signed in - connect to Stream once per session/user
          final currentStreamUser =
              StreamService.staticClient.state.currentUser;
          if (!_didConnectStream ||
              currentStreamUser?.id != snapshot.data!.uid) {
            _didConnectStream = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _connectStreamUser();
            });
          }

          // Trigger one-time friendships migration per session
          if (!_didMigrateFriendships) {
            _didMigrateFriendships = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                await FriendService().migrateLegacyFriendData();
              } catch (e) {
                // best-effort; ignore errors
              }
            });
          }
          return const MainScreen();
        } else {
          // User is not signed in - disconnect from Stream
          if (_didConnectStream) {
            _didConnectStream = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _disconnectStreamUser();
            });
          }
          return const LoginScreen();
        }
      },
    );
  }
}
