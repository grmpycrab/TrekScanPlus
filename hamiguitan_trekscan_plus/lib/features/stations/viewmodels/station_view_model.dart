import 'package:flutter/foundation.dart';

import '../../../models/station_data.dart';
import '../../../models/climb_session.dart';
import '../../../services/station_service.dart';
import '../../../services/climb_session_service.dart';
import '../../../utils/app_logger.dart';

/// ViewModel for the Stations tab screen.
///
/// Owns station-list reads and climb-session management so the screen
/// contains no service references.
class StationViewModel extends ChangeNotifier {
  bool isLoading = true;

  List<StationData> visitedStations = [];
  List<StationData> unvisitedStations = [];
  List<ClimbSession> allSessions = [];
  ClimbSession? activeSession;

  /// Set when [deleteSession] fails. Screen should show this then call
  /// [clearDeleteError].
  String? deleteError;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  Future<void> initialize() async {
    if (!StationService.instance.isLoaded) {
      await StationService.instance.loadStations();
    }

    if (!ClimbSessionService.isInitialized) {
      AppLogger.w('ClimbSessionService not yet initialized');
    } else {
      try {
        ClimbSessionService.instance.addListener(_onClimbSessionsChanged);
        _updateActiveSession();
      } catch (e) {
        AppLogger.w('Error setting up climb service listener: $e');
      }
    }

    _refreshStations();
    isLoading = false;
    notifyListeners();
  }

  /// Re-run initialization (e.g. retry button after ClimbSessionService was
  /// not ready).
  Future<void> retry() async {
    isLoading = true;
    notifyListeners();
    await initialize();
  }

  @override
  void dispose() {
    if (ClimbSessionService.isInitialized) {
      ClimbSessionService.instance.removeListener(_onClimbSessionsChanged);
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Convenience getters for the screen
  // -------------------------------------------------------------------------

  /// Whether ClimbSessionService is ready. Screen uses this to decide whether
  /// to show the "Initializing…" fallback in the Climbs tab.
  bool get climbServiceReady => ClimbSessionService.isInitialized;

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  /// Delete [sessionId]. Returns `true` on success.
  /// On failure sets [deleteError] and notifies; caller should check it.
  Future<bool> deleteSession(String sessionId, String sessionName) async {
    try {
      await ClimbSessionService.instance.deleteSession(sessionId);
      _updateActiveSession();
      _refreshStations();
      notifyListeners();
      return true;
    } catch (e) {
      deleteError = 'Error deleting climb: $e';
      notifyListeners();
      return false;
    }
  }

  /// Clear [deleteError] after it has been displayed.
  void clearDeleteError() {
    deleteError = null;
  }

  /// Refresh session state after an external edit (e.g. edit dialog closed).
  void refreshAfterEdit() {
    _updateActiveSession();
    _refreshStations();
    notifyListeners();
  }

  /// Relative-time formatter — pure, no service calls.
  String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}';
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  void _onClimbSessionsChanged() {
    _updateActiveSession();
    _refreshStations();
    notifyListeners();
  }

  void _updateActiveSession() {
    try {
      if (ClimbSessionService.isInitialized) {
        activeSession = ClimbSessionService.instance.getActiveSession();
      }
    } catch (e) {
      AppLogger.w('Error updating active session: $e');
      activeSession = null;
    }
  }

  void _refreshStations() {
    visitedStations = StationService.instance.getVisitedStations();
    unvisitedStations = StationService.instance.getUnvisitedStations();
    if (ClimbSessionService.isInitialized) {
      allSessions = ClimbSessionService.instance.getAllSessions();
    }
  }
}
