import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../config/app_router.dart';
import '../services/achievement_service.dart';
import '../services/onboarding_service.dart';
import '../services/station_service.dart';
import '../services/booking_service.dart';
import '../services/permission_service.dart';
import '../features/notification/services/notification_service.dart';
import '../services/climb_session_service.dart';
import 'services/presence_service.dart';
import 'notification_handler.dart';
import 'deep_link_handler.dart';
import '../utils/app_logger.dart';

/// Coordinates all app-level service startup and lifecycle transitions.
///
/// Extraction reason: five service-init methods were embedded in
/// [_MyAppState], mixing widget lifecycle with infrastructure concerns.
/// This class owns that responsibility so [_MyAppState] becomes a thin
/// widget that only manages Flutter lifecycle hooks.
///
/// Dependencies on widget context are injected via callbacks:
/// - [isMounted] — guards async operations after widget disposal
///
/// Navigation uses [navigatorKey] directly instead of a BuildContext callback.
///
/// MVVM role: ViewModel (app-level, not feature-level).
class AppStartupController {
  final bool Function() isMounted;

  bool _servicesInitialized = false;
  bool _permissionsRequested = false;

  // Completed once NotificationService + PresenceService are ready so that
  // the deep-link handler does not route before those services exist.
  final Completer<void> _criticalServicesReady = Completer<void>();

  AppStartupController({required this.isMounted});

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Kick off the full startup sequence.
  ///
  /// Call once from the first post-frame callback in [_MyAppState.initState].
  void start() {
    _handleOfflineFallback();
    _initializeCriticalServices();
    _deferredInitializeStations();
    _deferredHandleDeepLinks();
  }

  /// Responds to auth state changes that result in a verified user session.
  ///
  /// Safe to call multiple times — guarded by [_servicesInitialized].
  Future<void> initializeUserServices(String userId) async {
    if (_servicesInitialized) return;

    AppLogger.i('Initializing services for verified user: $userId');

    try {
      await ClimbSessionService.init(userId: userId);
      AppLogger.i('  ClimbSessionService initialized (offline-first)');
    } catch (e) {
      AppLogger.w('ClimbSessionService: $e (offline mode available)');
    }

    // Scope the station service to this user and pull their visited stations
    // from Firestore.  This is the primary cross-device sync path: when the
    // user logs in on Device B the in-memory station list is refreshed with
    // whatever they scanned on Device A.
    StationService.instance.setCurrentUser(userId);
    unawaited(
      Future.microtask(() async {
        try {
          await StationService.instance.syncFromFirebase(userId);
          AppLogger.i('  Stations synced from Firebase');
        } catch (e) {
          AppLogger.w('Station sync: $e');
        }
      }),
    );

    unawaited(
      Future.delayed(const Duration(milliseconds: 300), () async {
        try {
          BookingService.instance.startBookingStatusListener(userId);
        } catch (e) {
          AppLogger.w('Booking service: $e');
        }
      }),
    );

    unawaited(NotificationHandler.initialize());
    unawaited(
      Future.microtask(() => NotificationService().listenToBookingUpdates()),
    );
    unawaited(
      Future.microtask(
        () => NotificationService().listenToPostModerationNotifications(),
      ),
    );

    // Achievement init — no context needed, silent fail on error
    unawaited(
      Future.microtask(() async {
        try {
          await AchievementService().init(userId: userId);
          AppLogger.i('  AchievementService initialized');
        } catch (e) {
          AppLogger.w('AchievementService: $e');
        }
      }),
    );

    // Onboarding check — uses navigatorKey for navigation
    unawaited(
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (!isMounted()) return;
        final ctx = navigatorKey.currentContext;
        try {
          final hasSeenOnboarding = await OnboardingService.hasSeenOnboarding(
            userId,
          );
          if (!hasSeenOnboarding && isMounted() && ctx != null) {
            unawaited(
              OnboardingService.showOnboarding(ctx, userId),
            ); // ignore: use_build_context_synchronously
          }
        } catch (e) {
          AppLogger.e('Onboarding check error: $e');
        }
      }),
    );

    if (!_permissionsRequested) {
      _permissionsRequested = true;
      unawaited(
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (isMounted()) _requestPermissions();
        }),
      );
    }

    _servicesInitialized = true;
  }

  /// Resets service-init flags when the user signs out.
  ///
  /// Called by [AuthGate] when [AuthStatus.unauthenticated] is observed,
  /// so the next login triggers a fresh [initializeUserServices] call.
  void resetForLogout() {
    _servicesInitialized = false;
    _permissionsRequested = false;
    // Stop Firestore listeners before auth is revoked to prevent
    // permission-denied errors from streams that are still open.
    NotificationService().stopListeners();
    BookingService.instance.cancelBookingStatusListener();
    // Clear visited state so a different user logging in does not briefly see
    // the previous user's scanned stations before their own sync completes.
    StationService.instance.clearUserData();
    AchievementService().resetInitialization();
  }

  /// Handles app foreground/background transitions for presence tracking.
  void handleLifecycle(AppLifecycleState state) {
    if (Firebase.apps.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // pausePresence cancels the timer AND marks offline, preventing the
      // timer from firing within the next 30 s and re-marking the user online.
      unawaited(PresenceService.instance.pausePresence(user.uid));
    } else if (state == AppLifecycleState.resumed) {
      PresenceService.instance.initialize();
    }
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  /// Ensures ClimbSessionService starts even when there is no network user.
  ///
  /// Previously this called [initializeUserServices] with a garbage offline
  /// userId which set [_servicesInitialized] = true and blocked the real
  /// per-user init from running after login.  Now we only init the one
  /// service that genuinely needs an offline-first cold start.
  void _handleOfflineFallback() {
    if (!ClimbSessionService.isInitialized &&
        FirebaseAuth.instance.currentUser == null) {
      AppLogger.i('Initializing ClimbSessionService in offline mode...');
      unawaited(
        Future(() async {
          try {
            await ClimbSessionService.init(
              userId: 'offline_${DateTime.now().millisecondsSinceEpoch}',
            );
          } catch (e) {
            AppLogger.w('ClimbSessionService offline: $e');
          }
        }),
      );
    }
  }

  Future<void> _initializeCriticalServices() async {
    unawaited(
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          await NotificationService().initialize();
          PresenceService.instance.initialize();
        } catch (e) {
          AppLogger.w('Non-critical service initialization: $e (offline mode)');
        } finally {
          if (!_criticalServicesReady.isCompleted) {
            _criticalServicesReady.complete();
          }
        }
      }),
    );
  }

  void _deferredInitializeStations() {
    unawaited(
      Future.microtask(() async {
        try {
          AppLogger.d('Loading stations in background...');
          final stationService = await StationService.init();
          await stationService.loadStations();
          AppLogger.i('Stations loaded successfully');
        } catch (error) {
          AppLogger.e('Failed to load stations: $error');
        }
      }),
    );
  }

  void _deferredHandleDeepLinks() {
    unawaited(
      _criticalServicesReady.future.then((_) {
        DeepLinkHandler.handleInitialLink();
        DeepLinkHandler.startListening();
      }),
    );
  }

  Future<void> _requestPermissions() async {
    final ctx = navigatorKey.currentContext;
    if (isMounted() && ctx != null) {
      try {
        // ignore: use_build_context_synchronously — navigatorKey context is global, not widget-scoped
        await PermissionService.instance.requestInitialPermissions(ctx);
      } catch (e) {
        AppLogger.e('Permission request error: $e');
      }
    }
  }
}
