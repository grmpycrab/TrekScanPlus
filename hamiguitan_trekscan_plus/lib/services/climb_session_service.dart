import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/climb_session.dart';
import '../models/station_data.dart';

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
class ClimbSessionService extends ChangeNotifier {
  static const String CLIMB_SESSIONS_KEY = 'climb_sessions';
  static const String usersCollection = 'users';
  static const String climbsSubcollection = 'climbs';
  static ClimbSessionService? _instance;

  final SharedPreferences prefs;
  final FirebaseFirestore _firestore;

  List<ClimbSession> _climbSessions = [];
  ClimbSession? _activeSession;
  String? _currentUserId;
  bool _isFirebaseEnabled = false;

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

    final prefs = await SharedPreferences.getInstance();
    _instance = ClimbSessionService._(
      prefs,
      userId: userId,
      firestore: FirebaseFirestore.instance,
    );
    await _instance!._loadSessions();
    return _instance!;
  }

  void setCurrentUser(String? userId) {
    _currentUserId = userId;
    _isFirebaseEnabled = userId != null;
    _climbSessions.clear();
    _activeSession = null;
    // Reload sessions for new user
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      // Load from local cache first (instant access)
      final jsonString = prefs.getString(_userClimbSessionsKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        try {
          final List<dynamic> jsonList = json.decode(jsonString);
          _climbSessions = jsonList
              .map((item) => ClimbSession.fromMap(item as Map<String, dynamic>))
              .toList();
        } catch (e) {
          if (kDebugMode) print('Error loading local climb sessions: $e');
        }
      }

      // Sync with Firebase if user is logged in
      if (_isFirebaseEnabled && _userClimbsRef != null) {
        await _syncWithFirebase();
      }

      // Set the most recent ongoing session as active
      _activeSession = _climbSessions
          .where((s) => s.status == 'ongoing')
          .fold<ClimbSession?>(null, (latest, current) {
            if (latest == null) return current;
            return current.createdAt.isAfter(latest.createdAt)
                ? current
                : latest;
          });

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error in _loadSessions: $e');
    }
  }

  /// Sync local sessions with Firebase
  /// Pulls latest from Firebase and merges with local data
  Future<void> _syncWithFirebase() async {
    try {
      if (_userClimbsRef == null) return;

      final snapshot = await _userClimbsRef!.get();
      final firebaseSessions = <ClimbSession>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final session = ClimbSession.fromMap(data);
          firebaseSessions.add(session);
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing climb session from Firebase: $e');
          }
        }
      }

      // Merge: Keep Firebase as source of truth
      // Replace local sessions with Firebase versions
      if (firebaseSessions.isNotEmpty) {
        _climbSessions = firebaseSessions;
        await _saveSessions();
      }

      if (kDebugMode) {
        print(
          '✅ Synced ${firebaseSessions.length} climb sessions from Firebase',
        );
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Error syncing with Firebase: $e');
      // Don't fail - continue with local data
    }
  }

  Future<void> _saveSessions() async {
    try {
      // Save to local cache
      final jsonList = _climbSessions.map((s) => s.toMap()).toList();
      await prefs.setString(_userClimbSessionsKey, json.encode(jsonList));
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error saving sessions locally: $e');
    }
  }

  /// Create a new climb session
  /// Automatically saves to both local storage and Firebase
  Future<ClimbSession> createClimbSession({
    required String name,
    required String description,
    required String trekType,
    DateTime? trekStartDate,
    DateTime? trekEndDate,
  }) async {
    final session = ClimbSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      trekType: trekType,
      createdAt: DateTime.now(),
      trekStartDate: trekStartDate,
      trekEndDate: trekEndDate,
    );

    _climbSessions.add(session);
    _activeSession = session;
    await _saveSessions();

    // Sync to Firebase
    if (_isFirebaseEnabled && _userClimbsRef != null) {
      _syncSessionToFirebase(session, isNew: true);
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

    // Add the station visit
    if (!session.isStationVisited(station.id)) {
      session.addVisitedStation(station);
      await _saveSessions();
    }
  }

  /// Complete an active session
  Future<void> completeSession(ClimbSession session) async {
    session.completeClimb();
    if (session == _activeSession) {
      _activeSession = null;
    }
    await _saveSessions();
  }

  /// Abandon a session and sync to Firebase
  Future<void> abandonSession(ClimbSession session) async {
    session.status = 'abandoned';
    if (session == _activeSession) {
      _activeSession = null;
    }
    await _saveSessions();

    // Sync to Firebase
    if (_isFirebaseEnabled && _userClimbsRef != null) {
      await _syncSessionToFirebase(session, isNew: false);
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
  /// Called automatically after create/update operations
  Future<void> _syncSessionToFirebase(
    ClimbSession session, {
    bool isNew = false,
  }) async {
    try {
      if (!_isFirebaseEnabled || _userClimbsRef == null) {
        if (kDebugMode) {
          print(
            '⚠️ Firebase disabled or no user, skipping sync for ${session.id}',
          );
        }
        return;
      }

      await _userClimbsRef!
          .doc(session.id)
          .set(session.toMap(), SetOptions(merge: true));

      if (kDebugMode) {
        final action = isNew ? 'created' : 'updated';
        print('✅ Climb session ${session.name} $action on Firebase');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error syncing climb session to Firebase: $e');
      }
      // Don't throw - app should work offline
    }
  }

  /// Get real-time stream of climb sessions from Firebase
  /// Useful for cross-device sync and real-time updates
  Stream<List<ClimbSession>> getClimbSessionsStream() {
    if (!_isFirebaseEnabled || _userClimbsRef == null) {
      if (kDebugMode) {
        print('⚠️ Firebase disabled, returning empty stream');
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
            print('Error parsing climb session from stream: $e');
          }
        }
      }
      if (kDebugMode) {
        print('🔄 Climb sessions stream updated: ${sessions.length} sessions');
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
          print('✅ Climb session $sessionId deleted from Firebase');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error deleting climb session from Firebase: $e');
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

      // Sync to Firebase
      if (_isFirebaseEnabled && _userClimbsRef != null) {
        await _syncSessionToFirebase(session, isNew: false);
      }
    }
  }
}
