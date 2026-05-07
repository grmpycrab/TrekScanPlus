import '../models/station_data.dart';
import '../utils/app_logger.dart';
import 'climb_session_service.dart';
import 'geofencing_service.dart';

// ─── Result types ─────────────────────────────────────────────────────────────

/// Discriminated result returned by [ClimbSessionGuard.processStationScan].
sealed class ScanGateResult {
  const ScanGateResult();
}

/// Geofence passed, session active, station visit recorded.
/// The screen should navigate to [StationDetailScreen].
final class ScanGateSuccess extends ScanGateResult {
  final StationData station;
  const ScanGateSuccess(this.station);
}

/// Hard-blocked — nothing was written.
/// Show a SnackBar ([message]) and stop. [isWarning] controls the colour.
final class ScanGateBlocked extends ScanGateResult {
  final String message;

  /// `true` → orange (soft warning), `false` → red (hard error).
  final bool isWarning;
  const ScanGateBlocked(this.message, {this.isWarning = false});
}

/// Geofence passed but no active session exists.
/// The screen should show [StartClimbDialog], call
/// [ClimbSessionGuard.createSession], then re-invoke
/// [ClimbSessionGuard.processStationScan] with the same station.
final class ScanGateNeedsSession extends ScanGateResult {
  const ScanGateNeedsSession();
}

// ─── Guard ────────────────────────────────────────────────────────────────────

/// **Single entry point** for all scanner-triggered climb-session and
/// station-visit operations.
///
/// Enforces the mandatory control-flow order:
///
///   1. **Geofence validation** — hard gate; nothing runs until this passes.
///   2. **Active session check** — session must exist before a visit is recorded.
///   3. **Station visit recording** — only reached when both gates pass.
///
/// Neither [ClimbSessionService.createClimbSession] nor
/// [ClimbSessionService.addVisitedStation] may be called from the scanner
/// feature except through this class.
class ClimbSessionGuard {
  ClimbSessionGuard._();

  static final ClimbSessionGuard instance = ClimbSessionGuard._();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Processes a scanned station through the full gate pipeline.
  ///
  /// * [geofencingEnabled] — whether location validation is active.
  /// * [onGeofenceValidating] — called with `true` when the location check
  ///   begins, and `false` when it finishes (whether it passes or fails).
  ///   Use this to drive loading-indicator UI without coupling the guard to
  ///   any particular state-management solution.
  Future<ScanGateResult> processStationScan({
    required StationData station,
    required bool geofencingEnabled,
    void Function(bool validating)? onGeofenceValidating,
  }) async {
    // ── Gate 1: Geofence (non-negotiable, always first) ────────────────────
    if (geofencingEnabled &&
        station.latitude != null &&
        station.longitude != null) {
      onGeofenceValidating?.call(true);
      try {
        final geoResult =
            await GeofencingService.checkGeofence(
              stationLat: station.latitude!,
              stationLng: station.longitude!,
              radiusMeters: GeofencingService.GEOFENCE_RADIUS_METERS,
            ).timeout(
              const Duration(seconds: 15),
              onTimeout: () => GeofenceCheckResult(
                isWithinGeofence: false,
                distanceMeters: null,
                errorMessage:
                    'Could not get your location in time. '
                    'Make sure GPS is enabled and you have a clear sky view.',
              ),
            );

        if (geoResult.errorMessage != null) {
          AppLogger.w('ScanGate — geofence error: ${geoResult.errorMessage}');
          return ScanGateBlocked(
            'Cannot verify location: ${geoResult.errorMessage}',
            isWarning: true,
          );
        }

        if (!geoResult.isWithinGeofence) {
          AppLogger.w(
            'ScanGate — outside geofence '
            '(${geoResult.distanceMeters?.toStringAsFixed(2) ?? "?"} m)',
          );
          return ScanGateBlocked(
            'You are too far from the station '
            '(${geoResult.distanceMeters?.toStringAsFixed(0) ?? "?"} meters away)',
          );
        }

        AppLogger.i(
          'ScanGate — geofence OK '
          '(${geoResult.distanceMeters?.toStringAsFixed(2) ?? "0"} m)',
        );
      } finally {
        // Always release the loading state, even on exception.
        onGeofenceValidating?.call(false);
      }
    }

    // ── Gate 2: Service readiness ───────────────────────────────────────────
    if (!ClimbSessionService.isInitialized) {
      AppLogger.e('ScanGate — ClimbSessionService not initialised');
      return const ScanGateBlocked(
        'Service not initialised. Please restart the app.',
      );
    }

    // ── Gate 3: Active session ──────────────────────────────────────────────
    final active = ClimbSessionService.instance.getActiveSession();
    if (active == null || active.status != 'ongoing') {
      AppLogger.i('ScanGate — no active session; prompting user');
      return const ScanGateNeedsSession();
    }

    // ── Action: record the visit ────────────────────────────────────────────
    AppLogger.i('ScanGate — recording visit for "${station.name}"');
    await ClimbSessionService.instance.addVisitedStation(station, active);

    return ScanGateSuccess(station);
  }

  /// Creates a new climb session from the scanner feature.
  ///
  /// This is the **only** way a session may be created while the scanner is
  /// active. The geofence gate has already passed before this is called.
  ///
  /// Throws [StateError] if another active session already exists (propagated
  /// from [ClimbSessionService.createClimbSession]).
  Future<void> createSession({
    required String name,
    required String trekType,
  }) async {
    AppLogger.i('ScanGate — creating session "$name" ($trekType)');
    await ClimbSessionService.instance.createClimbSession(
      name: name,
      description: 'Started via QR scan',
      trekType: trekType,
    );
  }
}
