import 'package:flutter/material.dart';
import '../../components/bottom_navigation.dart';
import 'home_screen.dart';
import 'station_screen.dart';
import 'scanner_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const StationScreen(),
    const ScannerScreen(),
    const Placeholder(), // Book screen placeholder
    const Placeholder(), // Settings screen placeholder
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
