// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../core/widgets/app_dialogue_handler.dart';

class OnboardingService {
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const String _currentUserOnboardingKey = 'current_user_onboarding';

  /// Check if the current user has seen the onboarding
  static Future<bool> hasSeenOnboarding(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserOnboarding = prefs.getString(_currentUserOnboardingKey);

    // If the stored user ID doesn't match current user, they haven't seen it
    if (currentUserOnboarding != userId) {
      return false;
    }

    return prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  /// Mark onboarding as completed for current user
  static Future<void> markOnboardingCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
    await prefs.setString(_currentUserOnboardingKey, userId);
  }

  /// Reset onboarding (for testing purposes)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasSeenOnboardingKey);
    await prefs.remove(_currentUserOnboardingKey);
  }

  /// Show the onboarding flow
  static Future<void> showOnboarding(
    BuildContext context,
    String userId,
  ) async {
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OnboardingScreen(userId: userId),
        fullscreenDialog: true,
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  final String userId;

  const OnboardingScreen({super.key, required this.userId});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() async {
    final skip = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Skip Tutorial',
      message:
          'Are you sure you want to skip the app tutorial? You can always access help from Settings later.',
      confirmText: 'Skip',
      cancelText: 'Continue Tutorial',
    );

    if (skip == true) {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    await OnboardingService.markOnboardingCompleted(widget.userId);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with skip button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${_currentPage + 1} of $_totalPages',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildWelcomePage(),
                  _buildHomePage(),
                  _buildStationsPage(),
                  _buildBookingPage(),
                  _buildScannerPage(),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  _currentPage > 0
                      ? TextButton.icon(
                          onPressed: _previousPage,
                          icon: Icon(
                            Icons.arrow_back,
                            color: colors.primary,
                          ),
                          label: Text(
                            'Back',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox(width: 80),

                  // Page indicators
                  Row(
                    children: List.generate(_totalPages, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? colors.primary
                              : colors.primary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Next/Done button
                  ElevatedButton.icon(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: SharedColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: Icon(
                      _currentPage == _totalPages - 1
                          ? Icons.check_circle
                          : Icons.arrow_forward_ios,
                    ),
                    label: Text(
                      _currentPage == _totalPages - 1 ? 'Get Started' : 'Next',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return _buildOnboardingPage(
      icon: Icons.landscape,
      title: 'Welcome to\nTrekScan+!',
      description:
          'Your ultimate companion for exploring Mt. Hamiguitan. Track your journey, discover stations, and connect with fellow trekkers.',
      image: 'assets/images/app_logo.png',
    );
  }

  Widget _buildHomePage() {
    return _buildOnboardingPage(
      icon: Icons.dashboard_outlined,
      title: 'Your Trek Hub',
      description:
          'The Home screen shows your trek calendar, recent posts from the community, and quick access to important information and tips.',
      features: [
        'View available trek dates',
        'See community posts and photos',
        'Access trek tips and guidelines',
        'Track your achievements',
      ],
    );
  }

  Widget _buildStationsPage() {
    return _buildOnboardingPage(
      icon: Icons.explore_outlined,
      title: 'Discover Stations',
      description:
          'Explore the various checkpoints and points of interest throughout Mt. Hamiguitan. Track your visits and unlock achievements.',
      features: [
        'View all trek stations on the map',
        'Mark stations as visited when you arrive',
        'Unlock badges for visiting stations',
        'Track your exploration progress',
      ],
    );
  }

  Widget _buildBookingPage() {
    return _buildOnboardingPage(
      icon: Icons.event_available_outlined,
      title: 'Book Your Trek',
      description:
          'Plan your mountain adventure by booking trek dates, managing your reservations, and tracking approval status.',
      features: [
        'Submit trek booking requests',
        'Upload required documents',
        'Add porter requirements',
        'Track booking status and approvals',
      ],
    );
  }

  Widget _buildScannerPage() {
    return _buildOnboardingPage(
      icon: Icons.qr_code_scanner_outlined,
      title: 'QR Code Scanner',
      description:
          'Use the built-in scanner to check into stations, verify your trek progress, and access station-specific information.',
      features: [
        'Scan QR codes at trek stations',
        'Automatically mark stations as visited',
        'Unlock station-specific achievements',
        'Access detailed station information',
      ],
    );
  }

  Widget _buildOnboardingPage({
    required IconData icon,
    required String title,
    required String description,
    String? image,
    List<String>? features,
  }) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon or Image
          if (image != null)
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(75),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: Image.asset(
                  image,
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(icon, size: 80, color: colors.primary),
                ),
              ),
            )
          else
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Icon(icon, size: 60, color: colors.primary),
            ),

          const SizedBox(height: 40),

          // Title
          Text(
            title,
            style: TextStyle(
              color: colors.primary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            description,
            style: TextStyle(
              color: colors.primary,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          // Features list
          if (features != null) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: features
                    .map(
                      (feature) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Text(
                              feature.split(' ')[0], // The emoji
                              style: TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature.substring(feature.indexOf(' ') + 1),
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
