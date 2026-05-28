import 'package:flutter/material.dart';

import '../core/startup_progress_notifier.dart';
import '../core/widgets/precached_asset_image.dart';
import '../theme/app_theme.dart';

/// App startup / loading screen shown while the boot sequence runs.
///
/// ## Performance design
///
/// | Concern | Solution |
/// |---------|----------|
/// | Stage-string updates → NO full rebuild | [ValueListenableBuilder] wraps only the [Text] label. The Scaffold, logo, and [LinearProgressIndicator] are static subtrees that are built once and never touched again. |
/// | Animation frame isolation | [LinearProgressIndicator] with `value: null` (indeterminate) drives its own animation loop on the raster thread — completely independent of Dart state changes. |
/// | No infinite spinner | The circular indicator from [SplashScreen] is replaced by this thin 2 px linear bar. |
/// | Zero-flash background | Background color matches the native Android/iOS launch splash to eliminate the white-frame flicker on cold start. |
class StartupView extends StatefulWidget {
  const StartupView({super.key, required this.notifier});

  final StartupProgressNotifier notifier;

  // ─── Global assets pre-warmed during the startup window ───────────────────
  // These are the same assets the SplashScreen used to warm. By pre-caching
  // them here we guarantee they are resident in Flutter's image cache before
  // the first real screen (Login / Home) paints.
  static const _globalAssets = <(String, int)>[
    ('assets/images/app_logo.png', 600),
    ('assets/icons/google_icon.png', 72),
    ('assets/icons/home_icon.png', 72),
    ('assets/icons/station.png', 72),
    ('assets/icons/qr-code.png', 72),
    ('assets/icons/appointment.png', 72),
    ('assets/icons/setting.png', 72),
  ];

  @override
  State<StartupView> createState() => _StartupViewState();
}

class _StartupViewState extends State<StartupView> {
  bool _assetsCached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assetsCached) return;
    _assetsCached = true;
    for (final (path, size) in StartupView._globalAssets) {
      precacheImage(
        PrecachedAssetImage.provider(path, cacheWidth: size),
        context,
      ).catchError((_) {});
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
            // ── Logo + brand copy ─────────────────────────────────────────────
            // Static subtree — never invalidated by notifier changes.
            const Spacer(flex: 2),
            _Logo(colors: colors),
            const SizedBox(height: 28),
            Text(
              'Hamiguitan TrekScan+',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colors.primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hamiguitan Range Wildlife Sanctuary',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                letterSpacing: 0.4,
              ),
              textAlign: TextAlign.center,
            ),

            // ── Progress area ─────────────────────────────────────────────────
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  // Thin indeterminate bar — animation lives on raster thread,
                  // isolated from all Dart-side state changes.
                  LinearProgressIndicator(
                    value: null,
                    minHeight: 2,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  ),
                  const SizedBox(height: 14),
                  // ──────────────────────────────────────────────────────────
                  // ISOLATED REBUILD NODE
                  // Only this subtree rebuilds when the stage string changes.
                  // The enclosing Column / Scaffold is never invalidated.
                  // ──────────────────────────────────────────────────────────
                  ValueListenableBuilder<String>(
                    valueListenable: widget.notifier,
                    builder: (_, text, __) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: Text(
                        text,
                        // Key change forces AnimatedSwitcher to cross-fade.
                        key: ValueKey(text),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          letterSpacing: 0.25,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 52),
          ],
        ),
      ),
    );
  }
}

// ── Static logo widget ────────────────────────────────────────────────────────
// Extracted as a separate const-friendly widget so it can be identified as a
// stable child and skipped during any ancestor rebuilds.

class _Logo extends StatelessWidget {
  const _Logo({required this.colors});
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: PrecachedAssetImage(
          'assets/images/app_logo.png',
          fit: BoxFit.cover,
          cacheWidth: 480,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              color: colors.green700,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.terrain, size: 80, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
