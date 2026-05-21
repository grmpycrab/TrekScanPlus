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
  late final List<Widget> _screens;

  void _navigateToBookingWithDate(DateTime _) {
    setState(() => _currentIndex = 3);
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _screens = [
      HomeScreen(onNavigateToBooking: _navigateToBookingWithDate),
      const StationScreen(),
      const ScannerScreen(),
      const MyBookingsScreen(),
      const SettingsScreen(),
    ];
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
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Tabs 0, 1, 3, 4: always in the tree, hidden when inactive.
            // Offstage preserves state + stream connections across tab switches.
            Offstage(offstage: _currentIndex != 0, child: _screens[0]),
            Offstage(offstage: _currentIndex != 1, child: _screens[1]),
            Offstage(offstage: _currentIndex != 3, child: _screens[3]),
            Offstage(offstage: _currentIndex != 4, child: _screens[4]),
            // Tab 2 (Scanner): lazy-mounted so camera permission is only
            // requested when the user actually navigates to the scanner.
            if (_currentIndex == 2) _screens[2],
          ],
        ),
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
