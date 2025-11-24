import 'package:flutter/material.dart';
import '../../components/bottom_navigation.dart';
import '../../services/achievement_service.dart';
import 'home_screen.dart';
import 'station_screen.dart';
import 'scanner_screen.dart';
import 'settings_screen.dart';
import 'book_a_climb.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final AchievementService _achievementService = AchievementService();
  DateTime? _selectedDateForBooking;

  void _navigateToBookingWithDate(DateTime date) {
    setState(() {
      _selectedDateForBooking = date;
      _currentIndex = 3; // Index of BookAClimbScreen
    });
  }

  List<Widget> get _screens => [
    HomeScreen(onNavigateToBooking: _navigateToBookingWithDate),
    const StationScreen(),
    const ScannerScreen(),
    BookAClimbScreen(selectedDate: _selectedDateForBooking),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAchievements();
  }

  Future<void> _initializeAchievements() async {
    try {
      await _achievementService.init();
    } catch (e) {
      // Silent fail - non-critical
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigation(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
