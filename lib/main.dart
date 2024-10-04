import 'package:flutter/material.dart';

import 'Screens/HomeScreen.dart';
import 'Screens/NotificationsScreen.dart';
import 'Screens/OrderTracking.dart';
import 'Screens/ProfileScreen.dart';
import 'Screens/ScheduleScreen.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Managing the current screen index
  int _currentIndex = 0;

  // List of screens to navigate
  final List<Widget> _screens = [
    HomeScreen(),
    ScheduleScreen(),
    OrderTrackingScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  // Function to handle bottom navigation bar tap
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Bottom Navigation Bar items
  final List<BottomNavigationBarItem> _bottomNavItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.schedule),
      label: 'Schedule',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.shopping_cart),
      label: 'Orders',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.notifications),
      label: 'Notifications',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: _screens[_currentIndex], // Displaying the selected screen
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: _bottomNavItems,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
