import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../firebase_options.dart';
import '../utils/app_logger.dart';
import '../services/connectivity_service.dart';
import '../services/theme_service.dart';

/// Handles all pre-runApp initialisation in the correct, deterministic order.
///
/// Call exactly once at the top of [main] before [runApp].
///
/// Extraction reason: `main()` had 40+ lines of initialisation mixed with
/// error handling, logging, and Firebase config. This class owns that
/// responsibility so `main()` remains a thin entry point.
class AppInit {
  /// Runs the full initialisation sequence.
  ///
  /// Order is preserved from the original main():
  /// 1. Parallel: ThemeService + dotenv
  /// 2. Logger configuration
  /// 3. Connectivity monitor
  /// 4. Firebase + App Check + Firestore settings
  static Future<void> initialize() async {
    // Parallel: neither depends on the other
    await Future.wait([
      ThemeService().initialize(),
      dotenv.load(fileName: '.env'),
    ]);

    _configureLogging();

    ConnectivityService.instance.start();

    // Firebase must complete before runApp — it is critical for auth
    await _initializeFirebase();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static void _configureLogging() {
    AppLogger.setLogLevel(LogLevel.info); // suppress DEBUG/VERBOSE
    AppLogger.suppressTag('GoogleApiManager');
    AppLogger.suppressTag('FlagStore');
    AppLogger.suppressTag('FlagRegistrar');
  }

  static Future<void> _initializeFirebase() async {
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
