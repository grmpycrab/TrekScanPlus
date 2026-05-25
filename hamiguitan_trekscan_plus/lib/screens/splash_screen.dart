import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/widgets/precached_asset_image.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _assetsCached = false;

  // Assets that must be warm before the first real screen paints.
  // Keyed by logical display size so ResizeImage uses the right cache slot.
  static const _globalAssets = <(String, int)>[
    // Brand — shown on splash, login, signup, onboarding
    ('assets/images/app_logo.png', 600),
    // Auth — shown on login + signup
    ('assets/icons/google_icon.png', 72),
    // Bottom navigation — shown on every tab switch
    ('assets/icons/home_icon.png', 72),
    ('assets/icons/station.png', 72),
    ('assets/icons/qr-code.png', 72),
    ('assets/icons/appointment.png', 72),
    ('assets/icons/setting.png', 72),
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assetsCached) return;
    _assetsCached = true;
    // Fire-and-forget: the 1 200 ms splash window is enough time for these
    // small assets. We use the same ResizeImage provider that each consuming
    // widget will request, so they share the exact same cache entry.
    for (final (path, size) in _globalAssets) {
      precacheImage(
        PrecachedAssetImage.provider(path, cacheWidth: size),
        context,
      ).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background, // Using your app's primary color
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadowDark,
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: PrecachedAssetImage(
                          'assets/images/app_logo.png',
                          fit: BoxFit.cover,
                          cacheWidth: 600,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: colors.green700,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.terrain,
                                size: 100,
                                color: SharedColors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // App Name
                    Text(
                      'Hamiguitan TrekScan+',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Tagline
                    Text(
                      'Hamiguitan Range Wildlife Sanctuary',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 50),
                    // Loading indicator
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          SharedColors.white,
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
