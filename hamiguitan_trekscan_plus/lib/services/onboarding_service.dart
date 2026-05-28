import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../core/widgets/app_dialogue_handler.dart';

class OnboardingService {
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const String _currentUserOnboardingKey = 'current_user_onboarding';

  static Future<bool> hasSeenOnboarding(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserOnboarding = prefs.getString(_currentUserOnboardingKey);
    if (currentUserOnboarding != userId) return false;
    return prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  static Future<void> markOnboardingCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
    await prefs.setString(_currentUserOnboardingKey, userId);
  }

  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasSeenOnboardingKey);
    await prefs.remove(_currentUserOnboardingKey);
  }

  static Future<void> showOnboarding(BuildContext context, String userId) async {
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
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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
    if (skip == true) _finishOnboarding();
  }

  void _finishOnboarding() async {
    await OnboardingService.markOnboardingCompleted(widget.userId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentPage + 1} / $_totalPages',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Pages ────────────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                children: [
                  _buildWelcomePage(),
                  _buildHomePage(),
                  _buildStationsPage(),
                  _buildBookingPage(),
                  _buildScannerPage(),
                ],
              ),
            ),

            // ── Footer navigation ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back
                  _currentPage > 0
                      ? TextButton.icon(
                          onPressed: _previousPage,
                          icon: Icon(Icons.arrow_back_ios_new,
                              color: colors.primary, size: 14),
                          label: Text(
                            'Back',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        )
                      : const SizedBox(width: 72),

                  // Animated dots
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_totalPages, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPage == index ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? colors.primary
                                : colors.primary.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Next / Start
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _totalPages - 1
                              ? 'Start'
                              : 'Next',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _currentPage == _totalPages - 1
                              ? Icons.done
                              : Icons.arrow_forward_ios,
                          size: 14,
                        ),
                      ],
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

  // ── Page builders ────────────────────────────────────────────────────────

  Widget _buildWelcomePage() => _buildPage(
        assetPath: 'assets/images/app_logo.png',
        title: 'Welcome to\nTrekScan+',
        description:
            'Your ultimate companion for exploring Mt. Hamiguitan Range Wildlife Sanctuary.',
        isLogoPage: true,
      );

  Widget _buildHomePage() => _buildPage(
        assetPath: 'assets/icons/home_icon.png',
        title: 'Your Trek Hub',
        description:
            'See your trek calendar, community posts, and quick access to all the information you need.',
        features: [
          'View available trek dates',
          'Browse community posts and photos',
          'Access trek tips and guidelines',
          'Track your achievements',
        ],
      );

  Widget _buildStationsPage() => _buildPage(
        assetPath: 'assets/icons/station.png',
        title: 'Discover Stations',
        description:
            'Explore checkpoints throughout Mt. Hamiguitan, track your visits, and unlock achievements.',
        features: [
          'View all trek stations on the map',
          'Mark stations as visited on arrival',
          'Unlock badges for visiting stations',
          'Track your exploration progress',
        ],
      );

  Widget _buildBookingPage() => _buildPage(
        assetPath: 'assets/icons/appointment.png',
        title: 'Book Your Trek',
        description:
            'Plan your mountain adventure by booking dates and managing your reservations with ease.',
        features: [
          'Submit trek booking requests',
          'Upload required documents',
          'Add porter requirements',
          'Track booking status and approvals',
        ],
      );

  Widget _buildScannerPage() => _buildPage(
        assetPath: 'assets/icons/qr-code.png',
        title: 'QR Code Scanner',
        description:
            'Scan station QR codes to check in, verify your progress, and access station details.',
        features: [
          'Scan QR codes at trek stations',
          'Automatically mark stations as visited',
          'Unlock station-specific achievements',
          'Access detailed station information',
        ],
      );

  // ── Shared page layout ───────────────────────────────────────────────────

  Widget _buildPage({
    required String assetPath,
    required String title,
    required String description,
    List<String>? features,
    bool isLogoPage = false,
  }) {
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero card
          Container(
            width: double.infinity,
            height: isLogoPage ? 210 : 190,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary.withOpacity(0.13),
                  colors.accent.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: colors.primary.withOpacity(0.12),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.terrain, size: 80, color: colors.primary),
            ),
          ),

          const SizedBox(height: 32),

          // Title
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            description,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 15,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          // Feature list
          if (features != null) ...[
            const SizedBox(height: 28),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: colors.accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
