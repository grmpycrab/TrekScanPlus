import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../models/station_data.dart';
import '../../../services/station_service.dart';
import '../../../services/climb_session_guard.dart';
import '../../../services/achievement_service.dart';
import '../../../utils/app_logger.dart';

/// Carries a message to show in a SnackBar together with its severity colour.
class ScannerErrorEvent {
  final String message;

  /// true → orange (warning), false → red (error)
  final bool isWarning;

  const ScannerErrorEvent(this.message, {this.isWarning = false});
}

/// ViewModel for the QR scanner feature.
///
/// Responsibilities:
/// - Camera permission request
/// - Service initialisation (StationService, AchievementService)
/// - QR barcode processing
/// - Delegating ALL session and geofence logic to [ClimbSessionGuard]
///
/// The screen is responsible for:
/// - Owning the [MobileScannerController] (tied to MobileScanner widget lifecycle)
/// - Showing / dismissing dialogs
/// - Showing SnackBars
/// - Navigating to [StationDetailScreen]
///
/// Communication contract (screen listens via addListener):
/// - [isLoading]             → show loading spinner
/// - [permissionDenied]      → show permission-denied UI
/// - [isValidatingGeofence]  → show/dismiss geofence dialog
/// - [pendingError]          → read once, show SnackBar, call [clearError]
/// - [stationToNavigate]     → read once, navigate, call [clearNavigationRequest]
/// - [isProcessing]          → scanner lock (prevent duplicate detections)
/// - [requiresActiveSession] → show StartClimbDialog; call [retryPendingStation] after session created
class ScannerViewModel extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// True while permission request / service init is in progress.
  bool isLoading = true;

  /// True when camera permission was denied.
  bool permissionDenied = false;

  /// True while a QR barcode is being processed — prevents duplicate scans.
  bool isProcessing = false;

  /// True while the geofence check is running.
  bool isValidatingGeofence = false;

  /// Whether location-based validation is enabled.
  bool geofencingEnabled = true;

  /// Non-null when the screen should navigate to a station detail.
  /// Read once, then call [clearNavigationRequest].
  StationData? stationToNavigate;

  /// Non-null when the screen should show a SnackBar.
  /// Read once, then call [clearError].
  ScannerErrorEvent? pendingError;

  /// True when a station was scanned but no active session exists.
  /// The screen must show a "Start Climb" dialog, create a session via
  /// [ClimbSessionService], then call [retryPendingStation].
  bool requiresActiveSession = false;

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  final AchievementService _achievementService = AchievementService();

  /// Station held while the user is prompted to start a session.
  StationData? _pendingStation;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Request camera permission and initialise services.
  ///
  /// Safe to call multiple times (e.g. on app resume). Service calls are
  /// idempotent — [AchievementService.init] and [StationService.loadStations]
  /// both guard against redundant work.
  Future<void> initialize() async {
    final status = await Permission.camera.request();

    if (!status.isGranted) {
      permissionDenied = true;
      isLoading = false;
      notifyListeners();
      return;
    }

    permissionDenied = false;

    if (!StationService.instance.isLoaded) {
      await StationService.instance.loadStations();
    }

    await _achievementService.init();

    isLoading = false;
    notifyListeners();
  }

  /// Toggle geofencing on/off.
  void toggleGeofencing() {
    geofencingEnabled = !geofencingEnabled;
    notifyListeners();
  }

  /// Call after the screen has consumed [stationToNavigate].
  void clearNavigationRequest() {
    stationToNavigate = null;
  }

  /// Call after the screen has consumed [pendingError].
  void clearError() {
    pendingError = null;
  }

  /// Called by the screen after the user has successfully created or selected
  /// an active session via the StartClimbDialog.
  ///
  /// Re-processes the held [_pendingStation] so the scan can continue.
  Future<void> retryPendingStation() async {
    final station = _pendingStation;
    if (station == null) return;
    requiresActiveSession = false;
    _pendingStation = null;
    await _processStation(station);
  }

  /// Entry point for [MobileScanner.onDetect].
  ///
  /// Guards against concurrent processing with [isProcessing].
  Future<void> onDetect(BarcodeCapture capture) async {
    if (isProcessing) {
      AppLogger.d('Already processing QR, skipping...');
      return;
    }

    isProcessing = true;

    try {
      final barcodes = capture.barcodes;
      AppLogger.d(
        'QR Detection triggered: ${barcodes.length} barcode(s) detected',
      );

      for (final barcode in barcodes) {
        final rawValue = barcode.rawValue;
        AppLogger.d(
          'Barcode detected - Type: ${barcode.format}, Value: $rawValue',
        );

        if (rawValue == null || rawValue.isEmpty) {
          AppLogger.w('Empty barcode value, skipping');
          continue;
        }

        final station = StationService.instance.getStationById(rawValue);

        if (station != null) {
          AppLogger.i('Station found: ${station.name} (ID: ${station.id})');
          await _processStation(station);
          return;
        } else {
          AppLogger.e('Station NOT found for QR value: $rawValue');
        }
      }
    } catch (e) {
      AppLogger.e('CRITICAL ERROR in QR detection: $e');
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Processes a detected station through [ClimbSessionGuard].
  ///
  /// [ClimbSessionGuard] enforces the strict order:
  ///   1. Geofence validation (hard gate)
  ///   2. Active session check
  ///   3. Station visit recording
  ///
  /// This method only translates [ScanGateResult] values into ViewModel state;
  /// it contains no session or geofence logic of its own.
  Future<void> _processStation(StationData station) async {
    // Mark visited locally + sync to Firestore — non-blocking so the UI
    // stays responsive even on slow networks.
    StationService.instance
        .updateStationVisited(station.id, true)
        .then((_) => AppLogger.i('Station marked as visited in local cache'))
        .catchError((e) => AppLogger.w('Error updating station visited: $e'));

    // Check and unlock badges for this scan.  updateStationVisited updates
    // the in-memory list synchronously before its first await, so
    // getVisitedStations() already reflects the new scan when we read it here.
    // _syncSingleAchievementToFirebase inside checkAndUnlockAchievements writes
    // newly unlocked badges to Firestore, making them visible on other devices.
    unawaited(
      Future.microtask(() async {
        try {
          final visited = StationService.instance.getVisitedStations();
          await _achievementService.checkAndUnlockAchievements(
            visited.length,
            visited.map((s) => s.id).toList(),
            currentStationId: station.id,
            currentStationIndex: visited.length,
          );
        } catch (e) {
          AppLogger.w('Achievement check: $e');
        }
      }),
    );

    final result = await ClimbSessionGuard.instance.processStationScan(
      station: station,
      geofencingEnabled: geofencingEnabled,
      onGeofenceValidating: (validating) {
        isValidatingGeofence = validating;
        notifyListeners();
      },
    );

    switch (result) {
      case ScanGateSuccess(:final station):
        stationToNavigate = station;
        notifyListeners();

      case ScanGateNeedsSession():
        _pendingStation = station;
        requiresActiveSession = true;
        notifyListeners();

      case ScanGateBlocked(:final message, :final isWarning):
        pendingError = ScannerErrorEvent(message, isWarning: isWarning);
        notifyListeners();
    }
  }
}
