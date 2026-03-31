import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../components/bottom_navigation.dart';
import '../../services/achievement_service.dart';
import '../../services/onboarding_service.dart';
import '../../utils/app_logger.dart';
import 'home_screen.dart';
import 'station_screen.dart';
import 'scanner_screen.dart';
import 'settings_screen.dart';
import 'book_a_climb.dart';

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
  final AchievementService _achievementService = AchievementService();
  DateTime? _selectedDateForBooking;
  bool _autoShowBookingForm = false;

  void _navigateToBookingWithDate(DateTime date) {
    setState(() {
      _selectedDateForBooking = date;
      _autoShowBookingForm = true;
      _currentIndex = 3; // Index of BookAClimbScreen
    });
  }

  List<Widget> get _screens => [
    HomeScreen(onNavigateToBooking: _navigateToBookingWithDate),
    const StationScreen(),
    const ScannerScreen(),
    BookAClimbScreen(
      selectedDate: _selectedDateForBooking,
      autoShowBookingForm: _autoShowBookingForm,
      highlightBookingId: widget.highlightBookingId,
    ),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;

    // Initialize non-critical services asynchronously
    _initializeServicesAsync();
  }

  Future<void> _initializeServicesAsync() async {
    // Run achievement initialization in background
    unawaited(
      Future.microtask(() async {
        try {
          await _achievementService.init();
        } catch (e) {
          // Silent fail - non-critical
        }
      }),
    );

    // Check and show onboarding with reduced delay
    unawaited(
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (!mounted) return;

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        try {
          final hasSeenOnboarding = await OnboardingService.hasSeenOnboarding(
            user.uid,
          );

          if (!hasSeenOnboarding && mounted) {
            await OnboardingService.showOnboarding(context, user.uid);
          }
        } catch (e) {
          AppLogger.e('Onboarding check error: $e');
        }
      }),
    );
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
