import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'config/app_init.dart';
import 'core/app_startup_controller.dart';
import 'core/providers/app_providers.dart';
import 'core/startup_progress_notifier.dart';
import 'core/widgets/auth_gate.dart';
import 'core/services/presence_service.dart';
import 'screens/startup_view.dart';
import 'services/achievement_service.dart';
import 'services/badge_sync_engine.dart';
import 'services/station_service.dart';
import 'utils/app_logger.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Phase 1 — fast pre-runApp setup (theme, dotenv, logging, connectivity).
    // Firebase is intentionally excluded here so runApp returns immediately
    // and the StartupView renders its first frame before the SDK initialises.
    await AppInit.preRunAppInit();

    runApp(AppProviders(child: const MyApp()));
  }, (error, stack) {
    // Firestore streams emit permission-denied when the auth token is
    // revoked on sign-out. This is expected — swallow it silently.
    final msg = error.toString();
    if (msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED')) {
      AppLogger.w('Firestore stream closed on sign-out (expected): $error');
      return;
    }
    AppLogger.e('Unhandled error: $error\n$stack');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppStartupController _controller;

  /// Updated through the 4 boot stages; only the [ValueListenableBuilder]
  /// inside [StartupView] listens to this — no Scaffold-wide rebuild occurs.
  final _progressNotifier = StartupProgressNotifier();

  /// Flips to true exactly once, causing a single [setState] that swaps
  /// [StartupView] for [AuthGate].  All per-stage text updates go through
  /// [_progressNotifier] instead and never touch this flag.
  bool _startupComplete = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = AppStartupController(isMounted: () => mounted);

    // Defer until after the first frame so [StartupView] is visible before
    // any async work begins — the user sees the loading bar immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupSequence());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PresenceService.instance.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _controller.handleLifecycle(state);
  }

  // ---------------------------------------------------------------------------
  // Startup sequence — four ordered, non-blocking async stages
  // ---------------------------------------------------------------------------

  /// Executes the four-stage boot pipeline, updating [_progressNotifier] at
  /// each milestone so only the text label widget rebuilds.
  ///
  /// Each [await] yields to the event loop, keeping the UI thread free to
  /// service the [LinearProgressIndicator] animation frame callbacks.
  ///
  /// [_startupComplete] is flipped to [true] exactly once at the end,
  /// causing the single [setState] that replaces [StartupView] with [AuthGate].
  Future<void> _runStartupSequence() async {
    try {
      // ── Stage 1: Firebase + App Check ──────────────────────────────────────
      // All Firebase SDK calls are async I/O — the UI thread is never blocked.
      _progressNotifier.value = StartupProgressNotifier.stage1;
      await AppInit.initializeFirebase();

      // BadgeSyncEngine must start after Firebase is ready.
      BadgeSyncEngine.instance.start();

      // ── Stage 2: Station JSON (15 stations from bundled asset) ────────────
      // rootBundle.loadString is non-blocking; json.decode on 15 records is
      // negligible (< 1 ms) — no isolate spawning needed.
      _progressNotifier.value = StartupProgressNotifier.stage2;
      await StationService.init();
      await StationService.instance.loadStations();

      // ── Stage 3 & 4: User-scoped data (only if a session already exists) ──
      // FirebaseAuth persists the last signed-in user across cold starts.
      // If currentUser is non-null the device has a valid cached token and
      // we can pre-warm the user's progress data before AuthGate validates.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Stage 3 — visited stations cross-device sync
        _progressNotifier.value = StartupProgressNotifier.stage3;
        StationService.instance.setCurrentUser(user.uid);
        await StationService.instance
            .syncFromFirebase(user.uid)
            .catchError((e) => AppLogger.w('Station sync skipped: $e'));

        // Stage 4 — achievement / badge cache hydration
        _progressNotifier.value = StartupProgressNotifier.stage4;
        await AchievementService()
            .init(userId: user.uid)
            .catchError((e) => AppLogger.w('AchievementService skipped: $e'));
      }

      // ── Hand off to AppStartupController background tasks ─────────────────
      // start() launches notification, deep-link, and presence services in
      // the background. Station loading inside it is guarded by _isLoaded so
      // it becomes a no-op for what we have already fetched above.
      _controller.start();

      if (mounted) setState(() => _startupComplete = true);
    } catch (e, stack) {
      AppLogger.e('Startup sequence failed: $e\n$stack');
      _progressNotifier.value = StartupProgressNotifier.stageError;

      // Brief pause so the error message is readable, then proceed anyway
      // so the app does not brick on a transient init failure.
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _startupComplete = true);
    }
  }

  // ---------------------------------------------------------------------------
  // Build — two mutually exclusive subtrees
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // StartupView: rendered while the boot pipeline runs.
    // _progressNotifier updates only the text label inside it — this build
    // method is NOT called again for stage changes.
    if (!_startupComplete) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: StartupView(notifier: _progressNotifier),
      );
    }

    // AuthGate: rendered exactly once after startup completes.
    return AuthGate(
      onServicesInitNeeded: _controller.initializeUserServices,
      onLogout: _controller.resetForLogout,
    );
  }
}
