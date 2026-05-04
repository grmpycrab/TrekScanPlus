import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import '../services/onboarding_service.dart';
import '../services/station_service.dart';
import '../services/booking_service.dart';
import '../services/permission_service.dart';
import '../services/notification_service.dart';
import '../services/climb_session_service.dart';
import '../services/presence_service.dart';
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
/// - [isMounted]  — guards async operations after widget disposal
/// - [getContext] — provides [BuildContext] for permission dialogs
///
/// MVVM role: ViewModel (app-level, not feature-level).
class AppStartupController {
  final bool Function() isMounted;
  final BuildContext Function() getContext;

  bool _servicesInitialized = false;
  bool _permissionsRequested = false;

  AppStartupController({required this.isMounted, required this.getContext});

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

    // Onboarding check — uses getContext() for navigation
    unawaited(
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (!isMounted()) return;
        try {
          final hasSeenOnboarding = await OnboardingService.hasSeenOnboarding(
            userId,
          );
          if (!hasSeenOnboarding && isMounted()) {
            await OnboardingService.showOnboarding(getContext(), userId);
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
  }

  /// Handles app foreground/background transitions for presence tracking.
  void handleLifecycle(AppLifecycleState state) {
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
  void _handleOfflineFallback() {
    if (!ClimbSessionService.isInitialized &&
        FirebaseAuth.instance.currentUser == null) {
      AppLogger.i('Initializing ClimbSessionService in offline mode...');
      initializeUserServices(
        'offline_${DateTime.now().millisecondsSinceEpoch}',
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
    unawaited(DeepLinkHandler.handleInitialLink());
    DeepLinkHandler.startListening();
  }

  Future<void> _requestPermissions() async {
    if (isMounted()) {
      try {
        await PermissionService.instance.requestInitialPermissions(
          getContext(),
        );
      } catch (e) {
        AppLogger.e('Permission request error: $e');
      }
    }
  }
}
