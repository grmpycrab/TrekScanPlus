import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/achievement.dart';
import 'local_achievement_service.dart';

/// Achievement service that handles logic, Firebase sync, and offline support
class AchievementService {
  static final AchievementService _instance = AchievementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late LocalAchievementService _localService;

  List<Achievement> _allAchievements = [];
  bool _isInitialized = false;

  AchievementService._internal();

  factory AchievementService() {
    return _instance;
  }

  /// Initialize the service - load achievements from JSON and local cache
  /// Pass userId to scope local storage to current user
  Future<void> init({String? userId}) async {
    if (_isInitialized) return;

    try {
      // Use current user ID if not provided
      final currentUserId = userId ?? _auth.currentUser?.uid;

      // Initialize local service with user ID
      _localService = await LocalAchievementService.init(userId: currentUserId);

      // Load achievements from JSON file
      await _loadAchievementsFromJson();

      // Merge with local achievements (keeping unlock status)
      await _mergeWithLocalAchievements();

      // Then, if user is authenticated, load achievements from Firebase and merge
      if (currentUserId != null) {
        await _mergeWithFirebaseAchievements(currentUserId);
      }

      // Sync any pending achievements to Firebase if online
      await _syncPendingToFirebase();

      _isInitialized = true;
    } catch (e) {
      print('Error initializing AchievementService: $e');
      rethrow;
    }
  }

  /// Reset initialization so next init() call will reinitialize
  /// Call this when user changes
  void resetInitialization() {
    _isInitialized = false;
    _allAchievements = [];
  }

  /// Load achievements from badge.json file
  Future<void> _loadAchievementsFromJson() async {
    try {
      String jsonString = await rootBundle.loadString('assets/data/badge.json');
      Map<String, dynamic> jsonData = json.decode(jsonString);
      List<dynamic> badgesList = jsonData['badges'] ?? [];

      _allAchievements = badgesList
          .map((badge) => Achievement.fromJson(badge as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading achievements from JSON: $e');
      _allAchievements = [];
    }
  }

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
      print('Error merging with local achievements: $e');
    }
  }

  /// Merge achievements from Firebase into the list
  /// Updates local unlock status from Firebase data
  Future<void> _mergeWithFirebaseAchievements(String userId) async {
    try {
      final firebaseAchievements = await fetchFromFirebase();

      if (firebaseAchievements.isEmpty) return;

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

          // Also save to local storage to keep them in sync
          await _localService.saveAchievement(_allAchievements[i]);
        }
      }
    } catch (e) {
      print('Error merging with Firebase achievements: $e');
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
          // Location-based achievements - match current location
          if (currentStationId != null && value is String) {
            return currentStationId.toLowerCase() ==
                value.toString().toLowerCase();
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
      print('Error checking achievement criteria: $e');
      return false;
    }
  }

  /// Unlock achievement locally
  Future<void> _unlockAchievementLocally(Achievement achievement) async {
    try {
      await _localService.unlockAchievement(achievement);

      // Update in-memory list
      final index = _allAchievements.indexWhere((a) => a.id == achievement.id);
      if (index != -1) {
        _allAchievements[index] = achievement.copyWith(
          isUnlocked: true,
          unlockedAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('Error unlocking achievement locally: $e');
    }
  }

  /// Sync pending achievements to Firebase
  Future<void> _syncPendingToFirebase() async {
    try {
      final isConnected = await _isOnline();
      if (!isConnected) return;

      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final syncQueue = await _localService.getSyncQueue();
      if (syncQueue.isEmpty) return;

      for (final achievementId in syncQueue) {
        try {
          final achievement = await _localService.getAchievementById(
            achievementId,
          );
          if (achievement != null) {
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
                  'unlockedAt': achievement.unlockedAt?.toIso8601String(),
                  'syncedAt': FieldValue.serverTimestamp(),
                });

            // Also update user's badges array
            await _firestore.collection('users').doc(userId).update({
              'badges': FieldValue.arrayUnion([achievement.id]),
            });

            // Remove from sync queue
            await _localService.removeFromSyncQueue(achievementId);
          }
        } catch (e) {
          // Continue with next achievement if one fails
          continue;
        }
      }
    } catch (e) {
      print('Error syncing achievements to Firebase: $e');
    }
  }

  /// Public method to manually trigger Firebase sync (can be called periodically)
  Future<void> syncToFirebase() async {
    await _syncPendingToFirebase();
  }

  /// Check if device is online
  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
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
  Future<List<Achievement>> fetchFromFirebase() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .get();

      final firebaseAchievements = querySnapshot.docs
          .map((doc) => Achievement.fromJson(doc.data()))
          .toList();

      return firebaseAchievements;
    } catch (e) {
      print('Error fetching achievements from Firebase: $e');
      return [];
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
      print('Error resetting achievements: $e');
    }
  }
}
