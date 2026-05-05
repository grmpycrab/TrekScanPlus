import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../models/station_data.dart';
import '../../../services/station_service.dart';
import '../../../services/climb_session_service.dart';
import '../../../services/geofencing_service.dart';
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
/// - ClimbSession management (resume or create)
/// - Geofence validation
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

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  final AchievementService _achievementService = AchievementService();

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

  Future<void> _processStation(StationData station) async {
    AppLogger.d('Attempting to mark station as visited...');

    // Fire and forget — non-blocking, so the UI remains responsive offline.
    StationService.instance
        .updateStationVisited(station.id, true)
        .then((_) => AppLogger.i('Station marked as visited'))
        .catchError((e) => AppLogger.w('Error updating station visited: $e'));

    AppLogger.d(
      'ClimbSessionService.isInitialized: ${ClimbSessionService.isInitialized}',
    );

    if (!ClimbSessionService.isInitialized) {
      AppLogger.e('Service NOT initialized');
      pendingError = const ScannerErrorEvent(
        'Service not initialized. Please restart.',
      );
      notifyListeners();
      return;
    }

    final activeSession = ClimbSessionService.instance.getActiveSession();
    AppLogger.d('Active session: ${activeSession?.id ?? "None"}');

    if (activeSession != null && activeSession.status == 'ongoing') {
      AppLogger.i('Using existing active session');
      final alreadyInSession = activeSession.visitedStations.any(
        (visit) => visit.stationId == station.id,
      );
      if (!alreadyInSession) {
        activeSession.addVisitedStation(station);
      }
    } else {
      AppLogger.i('Creating new climb session...');
      final now = DateTime.now();
      final sessionName =
          'Trek - ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final newSession = await ClimbSessionService.instance.createClimbSession(
        name: sessionName,
        description: 'Climbing session starting at ${station.name}',
        trekType: 'regular_trek',
      );
      AppLogger.i('Climb session created: ${newSession.id}');
      newSession.addVisitedStation(station);
    }

    // Geofencing check — if coords are missing or feature is off, skip.
    if (geofencingEnabled &&
        station.latitude != null &&
        station.longitude != null) {
      final passed = await _validateGeofence(station);
      if (!passed) return;
    }

    // Signal screen to navigate to this station.
    stationToNavigate = station;
    notifyListeners();
  }

  /// Runs the geofence check with a 15-second timeout.
  ///
  /// Returns `true` if the user is within the geofence, `false` otherwise.
  /// Sets [pendingError] on failure before returning `false`.
  Future<bool> _validateGeofence(StationData station) async {
    AppLogger.d('Geofencing enabled, verifying location...');
    isValidatingGeofence = true;
    notifyListeners();

    try {
      final geofenceResult =
          await GeofencingService.checkGeofence(
            stationLat: station.latitude!,
            stationLng: station.longitude!,
            radiusMeters: GeofencingService.GEOFENCE_RADIUS_METERS,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              AppLogger.w('Geofence check timed out after 15 seconds');
              return GeofenceCheckResult(
                isWithinGeofence: false,
                distanceMeters: null,
                errorMessage:
                    'Could not get your location in time. Make sure GPS is enabled and you have a clear sky view.',
              );
            },
          );

      isValidatingGeofence = false;

      if (geofenceResult.errorMessage != null) {
        AppLogger.w('Geofence error: ${geofenceResult.errorMessage}');
        pendingError = ScannerErrorEvent(
          'Cannot verify location: ${geofenceResult.errorMessage}',
          isWarning: true,
        );
        notifyListeners();
        return false;
      }

      if (!geofenceResult.isWithinGeofence &&
          geofenceResult.distanceMeters != null) {
        AppLogger.w(
          'NOT within geofence. Distance: '
          '${geofenceResult.distanceMeters?.toStringAsFixed(2) ?? "unknown"} meters',
        );
        pendingError = ScannerErrorEvent(
          'You are too far from the station '
          '(${geofenceResult.distanceMeters?.toStringAsFixed(0) ?? "?"} meters away)',
        );
        notifyListeners();
        return false;
      }

      AppLogger.i(
        'Geofence verified! Distance: '
        '${geofenceResult.distanceMeters?.toStringAsFixed(2) ?? "0"} meters',
      );
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.e('Error during geofence check: $e');
      isValidatingGeofence = false;
      pendingError = ScannerErrorEvent(
        'Could not verify location: $e',
        isWarning: true,
      );
      notifyListeners();
      return false;
    }
  }
}
