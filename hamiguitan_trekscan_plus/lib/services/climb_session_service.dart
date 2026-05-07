// ignore_for_file: constant_identifier_names, avoid_types_as_parameter_names

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:convert';
import '../models/climb_session.dart';
import '../models/station_data.dart';
import '../features/notification/services/notification_service.dart';
import '../utils/app_logger.dart';

/// Service for managing climb/trek sessions
///
/// Uses hybrid approach:
/// - SharedPreferences: Local cache for instant access and offline support
/// - Firebase Firestore: Cloud persistence for cross-device sync
///
/// Firebase Integration:
/// Path: /users/{userId}/climbs/{climbId}
/// - Create: POST operation (auto-synced)
/// - Read: GET + real-time listeners
/// - Update: PUT operation (auto-synced)
/// - Delete: DELETE operation (auto-synced)
///
/// Business rules enforced here (not in ViewModel):
/// - Only ONE active (ongoing) session allowed at a time
/// - Sessions inactive for 72+ hours are auto-completed
/// - Firebase sync never silently overwrites locally-pending sessions
class ClimbSessionService extends ChangeNotifier {
  static const String CLIMB_SESSIONS_KEY = 'climb_sessions';
  static const String usersCollection = 'users';
  static const String climbsSubcollection = 'climbs';

  /// Sessions inactive longer than this are auto-completed.
  static const Duration _inactivityThreshold = Duration(hours: 72);

  /// Fire a reminder notification after this much inactivity.
  static const Duration _reminderThreshold = Duration(hours: 2);

  static const _uuid = Uuid();

  static ClimbSessionService? _instance;

  final SharedPreferences prefs;
  final FirebaseFirestore _firestore;

  List<ClimbSession> _climbSessions = [];
  ClimbSession? _activeSession;
  String? _currentUserId;
  bool _isFirebaseEnabled = false;

  /// Periodic timer that checks for inactivity while the app is running.
  Timer? _inactivityTimer;

  /// Tracks which session IDs have already received a reminder in this app run,
  /// so we don't spam the user every 30 minutes.
  final Set<String> _remindedSessionIds = {};

  ClimbSessionService._(
    this.prefs, {
    String? userId,
    required FirebaseFirestore firestore,
  }) : _firestore = firestore,
       _currentUserId = userId {
    _isFirebaseEnabled = _currentUserId != null;
  }

  static ClimbSessionService get instance {
    if (_instance == null) {
      throw StateError(
        'ClimbSessionService not initialized. Call init() first.',
      );
    }
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  String get _userClimbSessionsKey {
    if (_currentUserId == null) return CLIMB_SESSIONS_KEY;
    return '${CLIMB_SESSIONS_KEY}_$_currentUserId';
  }

  /// Get reference to current user's climbs collection
  CollectionReference<Map<String, dynamic>>? get _userClimbsRef {
    final userId = _currentUserId;
    if (userId == null) return null;
    return _firestore
        .collection(usersCollection)
        .doc(userId)
        .collection(climbsSubcollection);
  }

  static Future<ClimbSessionService> init({String? userId}) async {
    if (_instance != null) {
      if (userId != null) {
        _instance!.setCurrentUser(userId);
      }
      return _instance!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _instance = ClimbSessionService._(
        prefs,
        userId: userId,
        firestore: FirebaseFirestore.instance,
      );
      AppLogger.i(
        'ClimbSessionService: Initializing for userId: $userId (offline-first)',
      );

      // Load from local cache immediately (synchronous, non-blocking)
      try {
        _instance!._loadLocalSessions();
        AppLogger.i(
          'ClimbSessionService: Local sessions loaded (${_instance!._climbSessions.length} sessions)',
        );
      } catch (loadError) {
        AppLogger.w('Error loading local sessions: $loadError');
        _instance!._climbSessions = [];
        _instance!._activeSession = null;
      }

      // Check for inactivity on startup (handles 72h rule after app restart).
      _instance!._checkInactivityTimeout();

      // Start periodic inactivity check (every 30 minutes while app is open).
      _instance!._startInactivityTimer();

      // Sync with Firebase in background (fire-and-forget, non-blocking)
      if (_instance!._isFirebaseEnabled) {
        AppLogger.d(
          'ClimbSessionService: Starting background Firebase sync (non-blocking)',
        );
        _instance!._syncWithFirebaseBackground();
      } else {
        AppLogger.i('🔌 ClimbSessionService: Offline mode (no userId)');
      }

      return _instance!;
    } catch (e) {
      AppLogger.e('ClimbSessionService init error: $e');
      rethrow;
    }
  }

  void setCurrentUser(String? userId) {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _remindedSessionIds.clear();
    _currentUserId = userId;
    _isFirebaseEnabled = userId != null;
    _climbSessions.clear();
    _activeSession = null;
    // Reload sessions for new user
    _loadLocalSessions();
    if (_isFirebaseEnabled) {
      _syncWithFirebaseBackground();
      _checkInactivityTimeout();
      _startInactivityTimer();
    }
  }

  /// Load sessions from local cache (synchronous, fast)
  void _loadLocalSessions() {
    try {
      final jsonString = prefs.getString(_userClimbSessionsKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _climbSessions = jsonList
            .map((item) => ClimbSession.fromMap(item as Map<String, dynamic>))
            .toList();
      } else {
        _climbSessions = [];
      }

      _refreshActiveSession();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) AppLogger.e('Error in _loadLocalSessions: $e');
    }
  }

  /// Sync with Firebase in background without blocking initialization
  void _syncWithFirebaseBackground() {
    // Fire and forget - don't await
    _syncWithFirebase()
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            AppLogger.w('Firebase sync timeout');
          },
        )
        .catchError(
          (e) => AppLogger.w('Background Firebase sync error: $e'),
          test: (_) => true,
        );
  }

  /// Sync local sessions with Firebase using a safe merge strategy.
  ///
  /// Rules:
  /// - If local session has [syncPending] = true → push local to Firebase (local wins).
  /// - If Firebase has a newer [lastActivityAt] → take Firebase version.
  /// - Sessions on Firebase but missing locally → add locally.
  /// - Sessions only in local with [syncPending] → push to Firebase.
  Future<void> _syncWithFirebase() async {
    try {
      if (_userClimbsRef == null) return;

      final snapshot = await _userClimbsRef!.get();
      final firebaseSessions = <ClimbSession>[];

      for (var doc in snapshot.docs) {
        try {
          firebaseSessions.add(ClimbSession.fromMap(doc.data()));
        } catch (e) {
          if (kDebugMode) {
            AppLogger.e('Error parsing climb session from Firebase: $e');
          }
        }
      }

      // --- Merge ---
      for (final remote in firebaseSessions) {
        final localIndex = _climbSessions.indexWhere((s) => s.id == remote.id);
        if (localIndex == -1) {
          // New from Firebase — add locally.
          _climbSessions.add(remote);
        } else {
          final local = _climbSessions[localIndex];
          if (local.syncPending) {
            // Local has unconfirmed changes → push local to Firebase, keep local.
            unawaited(_syncSessionToFirebase(local, isNew: false));
          } else {
            // Compare by lastActivityAt (later wins); server wins on tie.
            final remoteActivity = remote.lastActivityAt ?? remote.createdAt;
            final localActivity = local.lastActivityAt ?? local.createdAt;
            if (remoteActivity.isAfter(localActivity)) {
              _climbSessions[localIndex] = remote;
            }
          }
        }
      }

      // Push any local-only pending sessions that Firebase doesn't know about.
      for (final local in _climbSessions.where((s) => s.syncPending)) {
        if (!firebaseSessions.any((r) => r.id == local.id)) {
          unawaited(_syncSessionToFirebase(local, isNew: true));
        }
      }

      // Refresh active session pointer after merge.
      _refreshActiveSession();
      await _saveSessions();

      if (kDebugMode) {
        AppLogger.i(
          'Merged ${firebaseSessions.length} Firebase sessions with '
          '${_climbSessions.length} local sessions',
        );
      }
    } catch (e) {
      if (kDebugMode) AppLogger.w('Error syncing with Firebase: $e');
      // Don't fail — continue with local data.
    }
  }

  /// Pick the most-recent ongoing session as the active session.
  void _refreshActiveSession() {
    _activeSession = _climbSessions
        .where((s) => s.status == 'ongoing')
        .fold<ClimbSession?>(null, (latest, current) {
          if (latest == null) return current;
          return current.createdAt.isAfter(latest.createdAt) ? current : latest;
        });
  }

  // ---------------------------------------------------------------------------
  // Inactivity auto-complete
  // ---------------------------------------------------------------------------

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _checkInactivityTimeout(),
    );
  }

  /// Checks inactivity for the active session.
  ///
  /// - At [_reminderThreshold] (2h): fires a local notification reminder once.
  /// - At [_inactivityThreshold] (72h): auto-completes the session.
  void _checkInactivityTimeout() {
    final session = _activeSession;
    if (session == null || session.status != 'ongoing') return;

    final anchor =
        session.lastActivityAt ?? session.startedAt ?? session.createdAt;
    final inactiveFor = DateTime.now().difference(anchor);

    // Auto-complete threshold — highest priority check.
    if (inactiveFor >= _inactivityThreshold) {
      AppLogger.i(
        'Session "${session.name}" auto-completing after '
        '${inactiveFor.inHours}h of inactivity',
      );
      _autoCompleteSession(session);
      return;
    }

    // Reminder threshold — fire once per session per app run.
    if (inactiveFor >= _reminderThreshold &&
        !_remindedSessionIds.contains(session.id)) {
      _remindedSessionIds.add(session.id);
      AppLogger.i(
        'Sending inactivity reminder for session "${session.name}" '
        '(inactive ${inactiveFor.inHours}h ${inactiveFor.inMinutes % 60}m)',
      );
      _sendReminderNotification(session, inactiveFor);
    }
  }

  void _sendReminderNotification(ClimbSession session, Duration inactiveFor) {
    final stats = session.liveStats;
    final autoCompleteIn = _inactivityThreshold - inactiveFor;

    unawaited(
      NotificationService().showTrekSessionReminder(
        sessionName: session.name,
        inactiveFor: inactiveFor,
        stationsVisited: stats.stationCount,
        distanceKm: stats.distanceKm,
        elapsed: stats.elapsed ?? Duration.zero,
        autoCompleteIn: autoCompleteIn,
      ),
    );
  }

  void _autoCompleteSession(ClimbSession session) {
    // completedAt = the last actual activity, not an artificial future timestamp.
    // This way totalDuration reflects real trekking time, not idle wait time.
    final lastActivity =
        session.lastActivityAt ?? session.startedAt ?? session.createdAt;
    session.completedAt = lastActivity;
    session.status = 'auto_completed';

    // Stamp duration for the final station (from last scan to auto-complete).
    if (session.visitedStations.isNotEmpty) {
      final last = session.visitedStations.last;
      last.durationAtStation ??= lastActivity.difference(last.scannedAt);
    }

    // totalDuration = actual time trekking (start → last activity), excluding idle.
    if (session.startedAt != null) {
      session.totalDuration = lastActivity.difference(session.startedAt!);
    }

    // totalDistance = sum of per-station distances recorded during the trek.
    session.totalDistance = session.visitedStations.fold<double>(
      0.0,
      (sum, v) => sum + (v.distanceFromPrevious ?? 0.0),
    );

    session.syncPending = true;
    if (session == _activeSession) _activeSession = null;

    // Notify the user that their session was auto-completed.
    final stats = session.liveStats;
    unawaited(
      NotificationService().showAutoCompletedNotification(
        sessionName: session.name,
        stationsVisited: stats.stationCount,
        distanceKm: stats.distanceKm,
        elapsed: stats.elapsed ?? Duration.zero,
      ),
    );

    _saveSessions();
    if (_isFirebaseEnabled && _userClimbsRef != null) {
      unawaited(_syncSessionToFirebase(session, isNew: false));
    }
    notifyListeners();
  }

  Future<void> _saveSessions() async {
    try {
      // Save to local cache
      final jsonList = _climbSessions.map((s) => s.toMap()).toList();
      await prefs.setString(_userClimbSessionsKey, json.encode(jsonList));
      notifyListeners();
    } catch (e) {
      if (kDebugMode) AppLogger.e('Error saving sessions locally: $e');
    }
  }

  /// Create a new climb session.
  ///
  /// Throws [StateError] if the user already has an active (ongoing) session.
  /// Callers (ViewModel, not Scanner) must check [getActiveSession()] first
  /// and prompt the user to complete or abandon the existing session.
  Future<ClimbSession> createClimbSession({
    required String name,
    required String description,
    required String trekType,
    DateTime? trekStartDate,
    DateTime? trekEndDate,
  }) async {
    // --- Single-session enforcement ---
    if (_activeSession != null && _activeSession!.status == 'ongoing') {
      throw StateError(
        'Cannot create a new session: "${_activeSession!.name}" is still active. '
        'Please complete or abandon it first.',
      );
    }

    final isOffline = !_isFirebaseEnabled;
    final session = ClimbSession(
      id: _uuid.v4(),
      name: name,
      description: description,
      trekType: trekType,
      createdAt: DateTime.now(),
      trekStartDate: trekStartDate,
      trekEndDate: trekEndDate,
      syncPending: true,
      createdOffline: isOffline,
    );

    _climbSessions.add(session);
    _activeSession = session;
    await _saveSessions();

    // Sync to Firebase in background (fire-and-forget, non-blocking).
    if (_isFirebaseEnabled && _userClimbsRef != null) {
      unawaited(_syncSessionToFirebase(session, isNew: true));
    }

    return session;
  }

  /// Get all climb sessions
  List<ClimbSession> getAllSessions() => List.unmodifiable(_climbSessions);

  /// Get only completed sessions
  List<ClimbSession> getCompletedSessions() =>
      _climbSessions.where((s) => s.status == 'completed').toList();

  /// Get only ongoing sessions
  List<ClimbSession> getOngoingSessions() =>
      _climbSessions.where((s) => s.status == 'ongoing').toList();

  /// Get the active session
  ClimbSession? getActiveSession() => _activeSession;

  /// Set active session
  void setActiveSession(ClimbSession? session) {
    _activeSession = session;
    notifyListeners();
  }

  /// Add a visited station to active session
  Future<void> addVisitedStation(
    StationData station,
    ClimbSession session,
  ) async {
    // Start the climb if not started
    if (session.startedAt == null) {
      session.startClimb();
    }

    // Add the station visit (also updates lastActivityAt + syncPending)
    if (!session.isStationVisited(station.id)) {
      session.addVisitedStation(station);

      // User resumed activity — clear reminder flag so it can fire again
      // if they go idle again after this scan.
      _remindedSessionIds.remove(session.id);
      await _saveSessions();

      if (_isFirebaseEnabled && _userClimbsRef != null) {
        unawaited(
          _syncSessionToFirebase(session, isNew: false)
              .then((_) {
                session.syncPending = false;
                _saveSessions();
              })
              .catchError((e) {
                AppLogger.w('Deferred Firebase sync error (station visit): $e');
              }),
        );
      }
    }
  }

  /// Complete an active session
  Future<void> completeSession(ClimbSession session) async {
    session.completeClimb();
    session.syncPending = true;
    if (session == _activeSession) {
      _activeSession = null;
    }
    await _saveSessions();

    if (_isFirebaseEnabled && _userClimbsRef != null) {
      unawaited(
        _syncSessionToFirebase(session, isNew: false)
            .then((_) {
              session.syncPending = false;
              _saveSessions();
            })
            .catchError((e) {
              AppLogger.w('Deferred Firebase sync error (complete): $e');
            }),
      );
    }
  }

  /// Abandon a session and sync to Firebase
  Future<void> abandonSession(ClimbSession session) async {
    session.status = 'abandoned';
    session.syncPending = true;
    if (session == _activeSession) {
      _activeSession = null;
    }
    await _saveSessions();

    if (_isFirebaseEnabled && _userClimbsRef != null) {
      unawaited(
        _syncSessionToFirebase(session, isNew: false)
            .then((_) {
              session.syncPending = false;
              _saveSessions();
            })
            .catchError((e) {
              AppLogger.w('Deferred Firebase sync error (abandon): $e');
            }),
      );
    }
  }

  /// Get session by ID
  ClimbSession? getSessionById(String id) {
    try {
      return _climbSessions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Calculate statistics for a session
  Map<String, dynamic> getSessionStats(ClimbSession session) {
    return {
      'totalStations': session.visitedStations.length,
      'totalDuration': session.getElapsedDuration(),
      'totalDistance': session.totalDistance ?? 0.0,
      'avgElevationGain': session.visitedStations.isNotEmpty
          ? session.visitedStations.fold<int>(
                  0,
                  (sum, v) => sum + v.elevation,
                ) /
                session.visitedStations.length
          : 0.0,
      'progress': session.getProgressPercentage(session.visitedStations.length),
    };
  }

  /// ========== Firebase Sync Methods ==========

  /// Sync a single session to Firebase
  Future<void> _syncSessionToFirebase(
    ClimbSession session, {
    bool isNew = false,
  }) async {
    try {
      if (!_isFirebaseEnabled || _userClimbsRef == null) return;

      await _userClimbsRef!
          .doc(session.id)
          .set(session.toMap(), SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              if (kDebugMode) {
                AppLogger.w('Firebase sync timeout for session ${session.id}');
              }
              throw TimeoutException('Firebase sync timed out');
            },
          );

      if (kDebugMode) {
        final action = isNew ? 'created' : 'updated';
        AppLogger.i('Climb session "${session.name}" $action on Firebase');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('Error syncing climb session to Firebase: $e');
      }
      // Don't throw — app should work offline.
      rethrow;
    }
  }

  /// Get real-time stream of climb sessions from Firebase
  /// Useful for cross-device sync and real-time updates
  Stream<List<ClimbSession>> getClimbSessionsStream() {
    if (!_isFirebaseEnabled || _userClimbsRef == null) {
      if (kDebugMode) {
        AppLogger.w('Firebase disabled, returning empty stream');
      }
      return const Stream.empty();
    }

    return _userClimbsRef!.snapshots().map((snapshot) {
      final sessions = <ClimbSession>[];
      for (var doc in snapshot.docs) {
        try {
          final session = ClimbSession.fromMap(doc.data());
          sessions.add(session);
        } catch (e) {
          if (kDebugMode) {
            AppLogger.e('Error parsing climb session from stream: $e');
          }
        }
      }
      if (kDebugMode) {
        AppLogger.i(
          'Climb sessions stream updated: ${sessions.length} sessions',
        );
      }
      return sessions;
    });
  }

  /// Delete a session and sync to Firebase
  Future<void> deleteSession(String sessionId) async {
    _climbSessions.removeWhere((s) => s.id == sessionId);
    if (_activeSession?.id == sessionId) {
      _activeSession = null;
    }
    await _saveSessions();

    // Sync deletion to Firebase
    if (_isFirebaseEnabled && _userClimbsRef != null) {
      try {
        await _userClimbsRef!.doc(sessionId).delete();
        if (kDebugMode) {
          AppLogger.i('Climb session $sessionId deleted from Firebase');
        }
      } catch (e) {
        if (kDebugMode) {
          AppLogger.e('Error deleting climb session from Firebase: $e');
        }
      }
    }

    notifyListeners();
  }

  /// Update session and sync to Firebase
  Future<void> updateSession(ClimbSession session) async {
    final index = _climbSessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _climbSessions[index] = session;
      await _saveSessions();

      // Sync to Firebase in background (fire-and-forget, non-blocking)
      if (_isFirebaseEnabled && _userClimbsRef != null) {
        unawaited(_syncSessionToFirebase(session, isNew: false));
      }
    }
  }
}
