import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/auth_service.dart';
import 'services/stream_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Stream Chat
  await StreamService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RumiTalk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      builder: (context, child) => StreamChat(
        client: StreamService.staticClient,
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
    } catch (e) {
      print('Failed to connect Stream user: $e');
    } finally {
      setState(() {
        _isConnectingStream = false;
      });
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
        if (snapshot.connectionState == ConnectionState.waiting || _isConnectingStream) {
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
          final currentStreamUser = StreamService.staticClient.state.currentUser;
          if (!_didConnectStream || currentStreamUser?.id != snapshot.data!.uid) {
            _didConnectStream = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _connectStreamUser();
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

