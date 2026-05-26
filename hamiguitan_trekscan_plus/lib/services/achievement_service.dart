import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/achievement.dart';
import '../models/badge.dart';
import 'badge_repository.dart';
import 'legacy_scan_backfill_manager.dart';
import 'local_achievement_service.dart';
import 'trek_session_tracker.dart';
import '../core/achievement_overlay_manager.dart';
import '../utils/app_logger.dart';

/// Achievement service that handles logic, Firebase sync, and offline support
class AchievementService {
  static final AchievementService _instance = AchievementService._internal();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  late LocalAchievementService _localService;

  List<Achievement> _allAchievements = [];
  bool _isInitialized = false;
  String? _currentUserId;

  bool get isInitialized => _isInitialized;

  /// Completes when the background Firestore badge hydration finishes.
  /// Callers (e.g. BadgesScreen) can chain .then() on this to refresh the UI.
  Future<void> get hydrationFuture => _hydrationFuture ?? Future.value();
  Future<void>? _hydrationFuture;

  AchievementService._internal()
    : _firestore = FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance;

  /// Factory constructor - creates singleton for default use
  factory AchievementService() {
    return _instance;
  }

  /// Create a new instance for specific user (used in profile views)
  AchievementService.forUser()
    : _firestore = FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance;

  /// Initialize the service - load achievements from JSON and local cache
  /// Pass userId to scope local storage to current user
  Future<void> init({String? userId}) async {
    final targetUserId = userId ?? _auth.currentUser?.uid;

    // If already initialized for this user, return
    if (_isInitialized && _currentUserId == targetUserId) return;

    // If initializing for a different user, reset first
    if (_currentUserId != targetUserId) {
      resetInitialization();
    }

    try {
      // Use current user ID if not provided
      final currentUserId = targetUserId;
      final isOwnProfile = currentUserId == _auth.currentUser?.uid;
      _currentUserId = currentUserId;

      // Initialize local service with user ID
      _localService = await LocalAchievementService.init(userId: currentUserId);

      // Load badge catalog from the local repository (SharedPreferences cache,
      // seeded from bundled JSON on first launch).
      await _loadFromRepository();

      // Only merge with local achievements if viewing own profile
      if (isOwnProfile) {
        await _mergeWithLocalAchievements();
      }

      // Load achievements from Firebase and merge
      if (currentUserId != null) {
        await _mergeWithFirebaseAchievements(
          currentUserId,
          saveToLocal: isOwnProfile,
        );
      }

      // Only sync to Firebase if viewing own profile
      if (isOwnProfile) {
        await _syncPendingToFirebase();
      }

      // Fire background Firestore hydration for the badge catalog.
      // Callers can await hydrationFuture to react when it completes.
      _hydrationFuture = BadgeRepository.instance
          .hydrateFromFirestore()
          .then((_) => _mergeNewBadgesFromRepository());

      // Run legacy scan backfill exactly once per user install (fire-and-forget).
      // Unlocks badges for pre-existing visited stations using their original
      // check-in timestamps so historical records remain accurate.
      if (targetUserId != null && isOwnProfile) {
        unawaited(LegacyScanBackfillManager.instance.run(
          userId: targetUserId,
          achievementService: this,
        ));
      }

      _isInitialized = true;
    } catch (e) {
      AppLogger.e('AchievementService init error: $e');
      rethrow;
    }
  }

  /// Reset initialization so next init() call will reinitialize
  /// Call this when user changes
  void resetInitialization() {
    _isInitialized = false;
    _allAchievements = [];
    _currentUserId = null;
  }

  /// Force refresh from Firebase (useful for profile screen)
  Future<void> refreshFromFirebase() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _mergeWithFirebaseAchievements(userId);
    } catch (e) {
      AppLogger.e('Error refreshing from Firebase: $e');
    }
  }

  /// Load the badge catalog from [BadgeRepository] (SharedPreferences cache,
  /// seeded from the bundled asset on first launch).
  Future<void> _loadFromRepository() async {
    try {
      await BadgeRepository.instance.init();
      _allAchievements = BadgeRepository.instance.all
          .map(_achievementFromBadge)
          .toList();
    } catch (e) {
      AppLogger.i('Error loading achievements from repository: $e');
      _allAchievements = [];
    }
  }

  /// Append any badges the background hydration added to the repository that
  /// are not yet in the in-memory achievement list. Also refreshes fields on
  /// admin-created badges (points, name, etc.) in case they were updated.
  void _mergeNewBadgesFromRepository() {
    final repoBadges = BadgeRepository.instance.all;
    for (final badge in repoBadges) {
      final idx = _allAchievements.indexWhere((a) => a.id == badge.id);
      if (idx == -1) {
        // Newly hydrated badge — add with default unlock state.
        _allAchievements.add(_achievementFromBadge(badge));
      } else if (_allAchievements[idx].category == 'admin_created') {
        // Preserve unlock state but refresh mutable admin fields.
        final existing = _allAchievements[idx];
        _allAchievements[idx] = existing.copyWith(
          name: badge.name,
          description: badge.description,
          points: badge.points,
          tier: badge.tier,
          isLimitedEdition: badge.isLimitedEdition,
          startDate: badge.startDate,
          endDate: badge.endDate,
          visibilityRule: badge.visibilityRule,
        );
      }
    }
  }

  /// Convert a catalog [UserBadge] to an [Achievement] with default unlock state.
  Achievement _achievementFromBadge(UserBadge b) => Achievement(
        id: b.id,
        name: b.name,
        description: b.description,
        category: b.category,
        icon: b.icon,
        requirement: b.requirement,
        rarity: b.rarity,
        difficulty: b.difficulty,
        tier: b.tier,
        verificationType: b.verificationType,
        triggerStationId: b.triggerStationId,
        points: b.points,
        isLimitedEdition: b.isLimitedEdition,
        startDate: b.startDate,
        endDate: b.endDate,
        visibilityRule: b.visibilityRule,
        tracking: b.tracking,
      );

  /// Merge achievements with local stored data to preserve unlock status
  Future<void> _mergeWithLocalAchievements() async {
    try {
      final localAchievements = await _localService.getAchievements();

      for (int i = 0; i < _allAchievements.length; i++) {
        final achievement = _allAchievements[i];
        Achievement? localAchievement;
        try {
          localAchievement = localAchievements.firstWhere(
            (a) => a.id == achievement.id,
          );
        } catch (e) {
          localAchievement = null;
        }

        if (localAchievement != null && localAchievement.isUnlocked) {
          _allAchievements[i] = achievement.copyWith(
            isUnlocked: true,
            unlockedAt: localAchievement.unlockedAt,
            isNotificationShown: localAchievement.isNotificationShown,
          );
        }
      }

      // Save merged list locally
      await _localService.saveAchievements(_allAchievements);
    } catch (e) {
      AppLogger.e('Error merging local achievements: $e');
    }
  }

  /// Merge achievements from Firebase into the list
  /// Updates local unlock status from Firebase data
  Future<void> _mergeWithFirebaseAchievements(
    String userId, {
    bool saveToLocal = true,
  }) async {
    try {
      AppLogger.i(
        'AchievementService: Fetching achievements from Firebase for userId: $userId',
      );
      final firebaseAchievements = await fetchFromFirebase(userId: userId);
      if (firebaseAchievements.isEmpty) {
        AppLogger.i(
          'AchievementService: No achievements found in Firebase for userId: $userId',
        );
        return;
      }

      AppLogger.i(
        'AchievementService: Found ${firebaseAchievements.length} achievements in Firebase',
      );

      for (int i = 0; i < _allAchievements.length; i++) {
        final achievement = _allAchievements[i];
        Achievement? firebaseAchievement;

        try {
          firebaseAchievement = firebaseAchievements.firstWhere(
            (a) => a.id == achievement.id,
          );
        } catch (e) {
          firebaseAchievement = null;
        }

        if (firebaseAchievement != null && firebaseAchievement.isUnlocked) {
          // Update with Firebase data (which is the source of truth)
          _allAchievements[i] = achievement.copyWith(
            isUnlocked: true,
            unlockedAt: firebaseAchievement.unlockedAt,
            isNotificationShown:
                true, // Don't show notification for existing achievements
          );

          // Only save to local storage if viewing own profile
          if (saveToLocal) {
            await _localService.saveAchievement(_allAchievements[i]);
          }
        }
      }
    } catch (e) {
      AppLogger.i('Error merging with Firebase achievements: $e');
    }
  }

  /// Check and unlock achievements based on criteria
  /// Accepts the current station being visited for station-specific achievements
  Future<Achievement?> checkAndUnlockAchievements(
    int stationsVisited,
    List<String> completedStationIds, {
    String? currentStationId,
    int? currentStationIndex,
  }) async {
    Achievement? newlyUnlocked;

    for (final achievement in _allAchievements) {
      // Skip if already unlocked
      if (achievement.isUnlocked) continue;

      // SESSION badges are evaluated by checkSessionMilestones, not QR scans
      if (achievement.verificationType == VerificationType.session) continue;

      // Check if achievement criteria is met
      if (_checkAchievementCriteria(
        achievement,
        stationsVisited,
        currentStationId: currentStationId,
        currentStationIndex: currentStationIndex,
      )) {
        // Unlock the achievement
        newlyUnlocked = achievement;
        await _unlockAchievementLocally(achievement);
        break; // Only unlock one per scan for better UX
      }
    }

    return newlyUnlocked;
  }

  /// Check if achievement criteria is met
  bool _checkAchievementCriteria(
    Achievement achievement,
    int stationsVisited, {
    String? currentStationId,
    int? currentStationIndex,
  }) {
    final requirement = achievement.requirement;
    final type = requirement['type'] as String?;
    final value = requirement['value'];

    if (type == null || value == null) return false;

    try {
      switch (type) {
        case 'reach_station':
          // Unlock when user reaches specific station number
          final stationValue = value is int
              ? value
              : int.tryParse(value.toString());
          if (stationValue == null) return false;

          // Check if this is the station we're currently visiting
          // This ensures Station 1 achievement unlocks at Station 1, Station 2 at Station 2, etc.
          if (currentStationIndex != null) {
            return currentStationIndex == stationValue;
          }
          // Fallback: unlock if reached that many stations
          return stationsVisited >= stationValue;
        case 'stations_reached':
          // Unlock when user reaches specific number of stations (cumulative)
          final stationCount = value is int
              ? value
              : int.tryParse(value.toString());
          if (stationCount == null) return false;
          return stationsVisited >= stationCount;
        case 'reach_location':
          // Match the scanned station ID against the badge's triggerStationId.
          // Falls back to the legacy requirement value string for older records.
          if (currentStationId != null) {
            if (achievement.triggerStationId != null) {
              return currentStationId == achievement.triggerStationId;
            }
            if (value is String) {
              return currentStationId.toLowerCase() == value.toLowerCase();
            }
          }
          return false;
        case 'trail_completed':
          // Trail completion achievements
          return value == true || value == 'true';
        case 'trails_completed':
          // Multiple trails completed
          final trailCount = value is int
              ? value
              : int.tryParse(value.toString());
          if (trailCount == null) return false;
          return stationsVisited >= trailCount;
        case 'qr_scanned':
          // QR code scanned achievements
          return value is int || value is String;
        case 'qr_scanned_count':
          // Multiple QR codes scanned
          final qrCount = value is int ? value : int.tryParse(value.toString());
          if (qrCount == null) return false;
          return stationsVisited >= qrCount; // Simplified mapping
        case 'no_violation':
          // Conservation achievements
          return value == true || value == 'true';
        case 'gps_track_compliant':
          // GPS compliance
          return value == true || value == 'true';
        case 'total_distance_km':
          // Distance-based achievements
          final distance = value is int
              ? value
              : int.tryParse(value.toString());
          if (distance == null) return false;
          return stationsVisited >= distance; // Simplified mapping
        case 'total_elevation_m':
          // Elevation-based achievements
          final elevation = value is int
              ? value
              : int.tryParse(value.toString());
          if (elevation == null) return false;
          return stationsVisited >= elevation; // Simplified mapping
        case 'trail_duration_hours':
          // Duration-based achievements
          final duration = value is int
              ? value
              : int.tryParse(value.toString());
          if (duration == null) return false;
          return stationsVisited >= duration; // Simplified mapping
        default:
          return false;
      }
    } catch (e) {
      AppLogger.i('Error checking achievement criteria: $e');
      return false;
    }
  }

  /// Unlock achievement locally.
  ///
  /// [silent] = true suppresses the overlay banner (used for retroactive
  /// backfill so the user isn't spammed on login).
  /// [unlockedAt] preserves the original check-in timestamp for legacy
  /// backfill; falls back to [DateTime.now] when null.
  Future<void> _unlockAchievementLocally(
    Achievement achievement, {
    bool silent = false,
    DateTime? unlockedAt,
  }) async {
    try {
      final unlocked = achievement.copyWith(
        isUnlocked: true,
        unlockedAt: unlockedAt ?? DateTime.now(),
        syncStatus: 'PENDING_SYNC',
      );
      await _localService.unlockAchievement(unlocked);

      // Update in-memory list
      final index = _allAchievements.indexWhere((a) => a.id == achievement.id);
      if (index != -1) {
        _allAchievements[index] = unlocked;
      }

      // Show the animated top-banner immediately — fires even when offline
      if (!silent) {
        AchievementOverlayManager.instance.show(unlocked);
      }

      // Immediately try to sync to Firebase
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _syncSingleAchievementToFirebase(unlocked, userId);
      }
    } catch (e) {
      AppLogger.i('Error unlocking achievement locally: $e');
    }
  }

  /// Backfill achievements for stations the user has already visited but whose
  /// badge was never awarded (e.g. because the feature was added after the trek).
  Future<void> retroactivelyUnlockFromVisitedStations(
    List<String> visitedStationIds,
  ) async {
    if (!_isInitialized) return;
    final visitedSet = visitedStationIds.toSet();
    for (final achievement in List.of(_allAchievements)) {
      if (achievement.isUnlocked) continue;
      if (achievement.verificationType != VerificationType.scan) continue;
      if (achievement.triggerStationId == null) continue;
      if (visitedSet.contains(achievement.triggerStationId)) {
        await _unlockAchievementLocally(achievement, silent: true);
      }
    }
  }

  /// Sync a single achievement to Firebase immediately
  Future<void> _syncSingleAchievementToFirebase(
    Achievement achievement,
    String userId,
  ) async {
    try {
      final isConnected = await _isOnline();
      if (!isConnected) {
        // Add to sync queue if offline
        await _localService.addToSyncQueue(achievement.id);
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .doc(achievement.id)
          .set({
            'id': achievement.id,
            'name': achievement.name,
            'description': achievement.description,
            'category': achievement.category,
            'icon': achievement.icon,
            'rarity': achievement.rarity,
            'difficulty': achievement.difficulty,
            'tier': achievement.tier,
            'requirement': achievement.requirement,
            'triggerStationId': achievement.triggerStationId,
            'unlockedAt': achievement.unlockedAt?.toIso8601String(),
            'syncedAt': FieldValue.serverTimestamp(),
            'syncStatus': 'SYNCED',
          });

      // Also update user's badges array
      await _firestore.collection('users').doc(userId).update({
        'badges': FieldValue.arrayUnion([achievement.id]),
      });

      // Mark as synced in local storage and in-memory list
      await _localService.removeFromSyncQueue(achievement.id);
      final synced = achievement.copyWith(syncStatus: 'SYNCED');
      await _localService.saveAchievement(synced);
      final idx = _allAchievements.indexWhere((a) => a.id == achievement.id);
      if (idx != -1) _allAchievements[idx] = synced;
    } catch (e) {
      AppLogger.i('Error syncing achievement to Firebase: $e');
      await _localService.addToSyncQueue(achievement.id);
    }
  }

  /// Sync pending achievements to Firebase
  Future<void> _syncPendingToFirebase() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final syncQueue = await _localService.getSyncQueue();
      if (syncQueue.isEmpty) return;

      // Resolve all achievement objects locally (SharedPreferences, no network).
      final toSync = <Achievement>[];
      for (final id in syncQueue) {
        final a = await _localService.getAchievementById(id);
        if (a != null) toSync.add(a);
      }
      if (toSync.isEmpty) return;

      // One batched Firestore round-trip instead of N×2 serial awaits.
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(userId);

      for (final achievement in toSync) {
        batch.set(
          userRef.collection('achievements').doc(achievement.id),
          {
            'id': achievement.id,
            'name': achievement.name,
            'description': achievement.description,
            'category': achievement.category,
            'icon': achievement.icon,
            'rarity': achievement.rarity,
            'difficulty': achievement.difficulty,
            'tier': achievement.tier,
            'requirement': achievement.requirement,
            'unlockedAt': achievement.unlockedAt?.toIso8601String(),
            'syncedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      // Merge so the user doc is created if it doesn't exist yet.
      batch.set(
        userRef,
        {'badges': FieldValue.arrayUnion(toSync.map((a) => a.id).toList())},
        SetOptions(merge: true),
      );

      await batch.commit();

      for (final a in toSync) {
        await _localService.removeFromSyncQueue(a.id);
      }
    } catch (e) {
      AppLogger.i('Error syncing achievements to Firebase: $e');
    }
  }

  /// Public method to manually trigger Firebase sync (can be called periodically)
  Future<void> syncToFirebase() async {
    if (!_isInitialized) return;
    await _syncPendingToFirebase();
  }

  /// Check if device is online
  Future<bool> _isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Get all achievements
  List<Achievement> getAllAchievements() {
    return List.unmodifiable(_allAchievements);
  }

  /// Get unlocked achievements
  List<Achievement> getUnlockedAchievements() {
    return _allAchievements.where((a) => a.isUnlocked).toList();
  }

  /// Get locked achievements
  List<Achievement> getLockedAchievements() {
    return _allAchievements.where((a) => !a.isUnlocked).toList();
  }

  /// Get achievement by ID
  Achievement? getAchievementById(String id) {
    try {
      return _allAchievements.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get pending notifications
  Future<List<Achievement>> getPendingNotifications() async {
    final pendingIds = await _localService.getPendingNotifications();
    return _allAchievements.where((a) => pendingIds.contains(a.id)).toList();
  }

  /// Mark notification as shown
  Future<void> markNotificationAsShown(String achievementId) async {
    await _localService.removeFromPendingNotifications(achievementId);
  }

  /// Get count of unlocked achievements
  int getUnlockedCount() {
    return _allAchievements.where((a) => a.isUnlocked).length;
  }

  /// Get count of total achievements
  int getTotalCount() {
    return _allAchievements.length;
  }

  /// Fetch achievements from Firebase for current user
  Future<List<Achievement>> fetchFromFirebase({String? userId}) async {
    try {
      final targetUserId = userId ?? _auth.currentUser?.uid;
      if (targetUserId == null) return [];

      final querySnapshot = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('achievements')
          .get();

      final firebaseAchievements = <Achievement>[];

      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          try {
            final data = doc.data();

            // Handle unlockedAt which can be either Timestamp, DateTime, or String
            DateTime? unlockedAt;
            if (data['unlockedAt'] != null) {
              final unlockedAtValue = data['unlockedAt'];
              if (unlockedAtValue is Timestamp) {
                unlockedAt = unlockedAtValue.toDate();
              } else if (unlockedAtValue is DateTime) {
                unlockedAt = unlockedAtValue;
              } else if (unlockedAtValue is String) {
                unlockedAt = DateTime.parse(unlockedAtValue);
              }
            }

            final achievementData = {
              'id': data['id'] ?? doc.id,
              'name': data['name'] ?? '',
              'description': data['description'] ?? '',
              'category': data['category'] ?? 'general',
              'icon': data['icon'] ?? '🏆',
              'rarity': data['rarity'] ?? 'common',
              'difficulty': data['difficulty'] ?? 'easy',
              'tier': data['tier'] as String? ?? 'bronze',
              'requirement': data['requirement'] ?? <String, dynamic>{},
              'isUnlocked': true,
              'unlockedAt': unlockedAt?.toIso8601String(),
            };

            firebaseAchievements.add(Achievement.fromJson(achievementData));
          } catch (e) {
            AppLogger.i('Error parsing achievement ${doc.id}: $e');
            continue;
          }
        }
      } else {
        // Fallback: Check badges array in user document
        final userDoc = await _firestore.collection('users').doc(userId).get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          final badges = userData?['badges'] as List<dynamic>?;

          if (badges != null && badges.isNotEmpty) {
            for (var badgeId in badges) {
              if (badgeId is String) {
                Achievement? jsonAchievement;
                try {
                  jsonAchievement = _allAchievements.firstWhere(
                    (a) => a.id == badgeId,
                  );
                } catch (e) {
                  jsonAchievement = null;
                }

                if (jsonAchievement != null) {
                  firebaseAchievements.add(
                    jsonAchievement.copyWith(
                      isUnlocked: true,
                      unlockedAt: DateTime.now(),
                    ),
                  );
                }
              }
            }
          }
        }
      }

      return firebaseAchievements;
    } catch (e) {
      AppLogger.i('Error fetching achievements from Firebase: $e');
      return [];
    }
  }

  /// Unlock SCAN-type badges for stations the user already visited before the
  /// badge system was introduced.  Called once per user install by
  /// [LegacyScanBackfillManager]; never call this from the QR scan path.
  ///
  /// [stationTimestamps] maps each visited station ID to its original check-in
  /// timestamp (null falls back to [DateTime.now] inside the unlock helper).
  Future<void> backfillAchievementsFromStations(
    Map<String, DateTime?> stationTimestamps,
  ) async {
    if (!_isInitialized) return;

    for (final achievement in List.of(_allAchievements)) {
      if (achievement.isUnlocked) continue;
      if (achievement.verificationType != VerificationType.scan) continue;
      final stationId = achievement.triggerStationId;
      if (stationId == null) continue;
      if (!stationTimestamps.containsKey(stationId)) continue;

      await _unlockAchievementLocally(
        achievement,
        silent: true,
        unlockedAt: stationTimestamps[stationId],
      );
    }
  }

  /// Evaluate all SESSION-type badges against the current [TrekSessionTracker]
  /// state and unlock any whose criteria are now satisfied.
  /// Call this at the end of each completed trek session after recording it.
  Future<void> checkSessionMilestones(TrekSessionTracker tracker) async {
    if (!_isInitialized) return;

    for (final achievement in List.of(_allAchievements)) {
      if (achievement.isUnlocked) continue;
      if (achievement.verificationType != VerificationType.session) continue;

      if (_checkSessionCriteria(achievement, tracker)) {
        await _unlockAchievementLocally(achievement);
      }
    }
  }

  /// Returns true when [achievement]'s session-based requirement is satisfied.
  bool _checkSessionCriteria(
    Achievement achievement,
    TrekSessionTracker tracker,
  ) {
    final type = achievement.requirement['type'] as String?;
    final value = achievement.requirement['value'];
    if (type == null || value == null) return false;

    final threshold = value is int ? value : int.tryParse(value.toString());
    if (threshold == null) return false;

    try {
      switch (type) {
        case 'total_completed_sessions':
          return tracker.totalCompletedSessions >= threshold;
        case 'rolling_30_day_sessions':
          return tracker.getSessionsInLast30Days().length >= threshold;
        case 'climatic_quarters':
          return tracker.getDistinctClimaticQuarters() >= threshold;
        case 'summit_across_sessions':
          return tracker.summitVisitCount >= threshold;
        default:
          return false;
      }
    } catch (e) {
      AppLogger.i('Error checking session criteria for ${achievement.id}: $e');
      return false;
    }
  }

  /// Reset all achievements (for testing/development)
  Future<void> resetAll() async {
    try {
      for (var achievement in _allAchievements) {
        if (achievement.isUnlocked) {
          _allAchievements[_allAchievements.indexWhere(
            (a) => a.id == achievement.id,
          )] = achievement.copyWith(
            isUnlocked: false,
            unlockedAt: null,
          );
        }
      }
      await _localService.clearAll();
    } catch (e) {
      AppLogger.i('Error resetting achievements: $e');
    }
  }
}
