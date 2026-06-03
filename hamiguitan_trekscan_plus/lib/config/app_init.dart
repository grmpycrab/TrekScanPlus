import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import '../utils/app_logger.dart';
import '../services/connectivity_service.dart';
import '../services/theme_service.dart';

/// Handles app pre-initialisation in two distinct phases.
///
/// ## Phase 1 — [preRunAppInit] (before [runApp])
/// Fast, synchronous-equivalent tasks that produce no observable latency:
/// theme prefs, logging config, connectivity monitor.
/// Firebase is deliberately excluded so [runApp] returns as early as possible
/// and the [StartupView] can render its first frame before Firebase completes.
///
/// ## Phase 2 — [initializeFirebase] (inside the startup screen)
/// Firebase, App Check, and Firestore persistence settings.
/// Called from [_MyAppState._runStartupSequence] so the loading UI can reflect
/// Stage 1 progress text while these heavier operations resolve.
class AppInit {
  // ---------------------------------------------------------------------------
  // Phase 1 — pre-runApp (fast, no Firebase)
  // ---------------------------------------------------------------------------

  /// Performs the minimal setup that must complete before [runApp] is called.
  ///
  /// Neither Firebase nor any Firestore/Auth call is made here, so this
  /// completes in < 50 ms on most devices.
  static Future<void> preRunAppInit() async {
    await ThemeService().initialize();

    _configureLogging();

    // ConnectivityService.start() is non-blocking; it launches a stream
    // internally and returns immediately.
    ConnectivityService.instance.start();
  }

  // ---------------------------------------------------------------------------
  // Phase 2 — inside the startup screen (Firebase)
  // ---------------------------------------------------------------------------

  /// Initialises Firebase, activates App Check, and configures Firestore
  /// offline persistence.
  ///
  /// Called once from [_MyAppState._runStartupSequence] after the first frame
  /// of [StartupView] has been committed to screen.  This ensures the loading
  /// bar is already visible before the heavier Firebase SDK initialisation
  /// blocks the isolate.
  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.i('  Firebase initialized successfully');

    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
    AppLogger.i('  App Check activated');

    _configureFirestore();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static void _configureLogging() {
    AppLogger.setLogLevel(LogLevel.info);
    AppLogger.suppressTag('GoogleApiManager');
    AppLogger.suppressTag('FlagStore');
    AppLogger.suppressTag('FlagRegistrar');
  }

  static void _configureFirestore() {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 104857600, // 100 MB
      );
      AppLogger.d('  Firestore offline persistence and caching enabled');
    } catch (e) {
      AppLogger.w('Could not configure Firestore caching: $e');
    }
  }
}
