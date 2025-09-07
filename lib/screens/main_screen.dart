import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app/screens/friends_screen.dart';
import 'package:firebase_app/screens/chat_screen.dart';
import 'package:firebase_app/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  /// Handles tab selection in the BottomNavigationBar.
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // List of screens for the simplified navbar
    final List<Widget> screens = [
      const FriendsScreen(), // index 0 (Friends page)
      const ChatScreen(), // index 1
      ProfileScreen(userId: _auth.currentUser!.uid), // index 2
    ];

    // List of BottomNavigationBarItems for the simplified navbar
    final List<BottomNavigationBarItem> bottomNavItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.people_alt_rounded),
        label: 'Friends',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat_bubble_rounded),
        label: 'Chat',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    // Ensure current index is within valid range
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    final titles = <String>['Friends', 'Chats', 'Profile'];

    return Scaffold(
      backgroundColor: const Color(0xff181818),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: screens[_currentIndex], // Display the selected screen
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, // Highlight the selected tab
        onTap: _onTabTapped, // Handle tab selection
        items: bottomNavItems,
        backgroundColor: const Color(0xff181818),
        selectedItemColor: Colors.white, // Color for selected tab
        unselectedItemColor: Colors.grey[600], // Color for unselected tabs
        type: BottomNavigationBarType.fixed, // Fixes layout
      ),
    );
  }
}
