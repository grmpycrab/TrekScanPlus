import 'package:flutter/material.dart';
import '../../components/bottom_navigation.dart';
import 'home_screen.dart';
import 'station_screen.dart';
import 'scanner_screen.dart';
import 'settings_screen.dart';
import '../../features/booking/screens/book_a_climb_screen.dart';

// ignore_for_file: unnecessary_brace_in_string_interps
// ignore_for_file: use_key_in_widget_constructors, deprecated_member_use, use_build_context_synchronously
class MainScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? highlightBookingId;

  const MainScreen({
    super.key,
    this.initialTabIndex = 0,
    this.highlightBookingId,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  DateTime? _selectedDateForBooking;
  bool _autoShowBookingForm = false;
  bool _bookingFormShown = false; // Track if form has been auto-shown

  void _navigateToBookingWithDate(DateTime date) {
    setState(() {
      _selectedDateForBooking = date;
      _autoShowBookingForm = true;
      _bookingFormShown = false; // Reset when new date is selected
      _currentIndex = 3; // Index of BookAClimbScreen
    });
  }

  List<Widget> get _screens => [
    HomeScreen(onNavigateToBooking: _navigateToBookingWithDate),
    const StationScreen(),
    const ScannerScreen(),
    BookAClimbScreenRefactored(
      selectedDate: _selectedDateForBooking,
      autoShowBookingForm: _autoShowBookingForm && !_bookingFormShown,
      highlightBookingId: widget.highlightBookingId,
      onFormShown: () {
        // Called when the booking form is auto-shown
        setState(() {
          _bookingFormShown = true;
          _autoShowBookingForm = false;
        });
      },
    ),
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
            setState(() {
              // Clear booking form state when switching away from booking tab
              if (_currentIndex == 3 && index != 3) {
                _selectedDateForBooking = null;
                _autoShowBookingForm = false;
              }
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
