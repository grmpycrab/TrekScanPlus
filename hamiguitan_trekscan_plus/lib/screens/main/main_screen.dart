import 'package:flutter/material.dart';
import '../../components/bottom_navigation.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/stations/screens/station_screen.dart';
import '../../features/scanner/screens/scanner_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/booking/screens/my_bookings_screen.dart';

// ignore_for_file: unnecessary_brace_in_string_interps
// ignore_for_file: use_key_in_widget_constructors, deprecated_member_use, use_build_context_synchronously
class MainScreen extends StatefulWidget {
  final int initialTabIndex;

  const MainScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  void _navigateToBookingWithDate(DateTime _) {
    setState(() => _currentIndex = 3);
  }

  List<Widget> get _screens => [
    HomeScreen(onNavigateToBooking: _navigateToBookingWithDate),
    const StationScreen(),
    const ScannerScreen(),
    const MyBookingsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
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
            setState(() => _currentIndex = index);
          },
        ),
      ),
    );
  }
}
