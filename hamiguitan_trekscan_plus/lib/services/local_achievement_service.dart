// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../../utils/app_logger.dart';

/// Service for local/offline achievement storage and management
/// Handles caching, syncing flags, and persistence using SharedPreferences
class LocalAchievementService {
  static const String ACHIEVEMENTS_KEY = 'local_achievements';
  static const String SYNC_QUEUE_KEY = 'achievement_sync_queue';
  static const String PENDING_NOTIFICATIONS_KEY =
      'achievement_pending_notifications';

  final SharedPreferences prefs;
  String? _currentUserId;

  LocalAchievementService._(this.prefs, {String? userId})
    : _currentUserId = userId;

  /// Get key for achievements scoped to current user
  String get _userAchievementsKey {
    if (_currentUserId == null) return ACHIEVEMENTS_KEY;
    return '${ACHIEVEMENTS_KEY}_$_currentUserId';
  }

  /// Get key for sync queue scoped to current user
  String get _userSyncQueueKey {
    if (_currentUserId == null) return SYNC_QUEUE_KEY;
    return '${SYNC_QUEUE_KEY}_$_currentUserId';
  }

  /// Get key for pending notifications scoped to current user
  String get _userPendingNotificationsKey {
    if (_currentUserId == null) return PENDING_NOTIFICATIONS_KEY;
    return '${PENDING_NOTIFICATIONS_KEY}_$_currentUserId';
  }

  static Future<LocalAchievementService> init({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    return LocalAchievementService._(prefs, userId: userId);
  }

  /// Update the current user ID (call this when user changes)
  void setCurrentUser(String? userId) {
    _currentUserId = userId;
  }

  /// Save achievement locally with unlock status
  Future<void> saveAchievement(Achievement achievement) async {
    try {
      final achievements = await getAchievements();
      final index = achievements.indexWhere((a) => a.id == achievement.id);

      if (index != -1) {
        achievements[index] = achievement;
      } else {
        achievements.add(achievement);
      }

      final jsonList = achievements.map((a) => a.toJson()).toList();
      await prefs.setString(_userAchievementsKey, jsonEncode(jsonList));
    } catch (e) {
      AppLogger.i('Error saving achievement locally: $e');
      rethrow;
    }
  }

  /// Bulk save achievements
  Future<void> saveAchievements(List<Achievement> achievements) async {
    try {
      final jsonList = achievements.map((a) => a.toJson()).toList();
      await prefs.setString(_userAchievementsKey, jsonEncode(jsonList));
    } catch (e) {
      AppLogger.i('Error saving achievements locally: $e');
      rethrow;
    }
  }

  /// Get all locally stored achievements
  Future<List<Achievement>> getAchievements() async {
    try {
      final jsonString = prefs.getString(_userAchievementsKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Achievement.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.i('Error retrieving achievements locally: $e');
      return [];
    }
  }

  /// Get a specific achievement by ID
  Future<Achievement?> getAchievementById(String id) async {
    final achievements = await getAchievements();
    try {
      return achievements.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Mark achievement as unlocked and add to sync queue
  Future<void> unlockAchievement(Achievement achievement) async {
    try {
      final unlockedAchievement = achievement.copyWith(
        isUnlocked: true,
        unlockedAt: DateTime.now(),
        isNotificationShown: false, // Mark notification as not shown yet
      );

      await saveAchievement(unlockedAchievement);
      await addToSyncQueue(unlockedAchievement.id);
      await addToPendingNotifications(unlockedAchievement.id);
    } catch (e) {
      AppLogger.i('Error unlocking achievement: $e');
      rethrow;
    }
  }

  /// Add achievement ID to sync queue (for offline syncing to Firebase)
  Future<void> addToSyncQueue(String achievementId) async {
    try {
      final queue = await getSyncQueue();
      if (!queue.contains(achievementId)) {
        queue.add(achievementId);
        await prefs.setStringList(_userSyncQueueKey, queue);
      }
    } catch (e) {
      AppLogger.i('Error adding to sync queue: $e');
      rethrow;
    }
  }

  /// Get achievements pending sync to Firebase
  Future<List<String>> getSyncQueue() async {
    return prefs.getStringList(_userSyncQueueKey) ?? [];
  }

  /// Remove achievement from sync queue after successful Firebase sync
  Future<void> removeFromSyncQueue(String achievementId) async {
    try {
      final queue = await getSyncQueue();
      queue.remove(achievementId);
      await prefs.setStringList(_userSyncQueueKey, queue);
    } catch (e) {
      AppLogger.i('Error removing from sync queue: $e');
      rethrow;
    }
  }

  /// Add achievement ID to pending notifications queue
  Future<void> addToPendingNotifications(String achievementId) async {
    try {
      final notifications = await getPendingNotifications();
      if (!notifications.contains(achievementId)) {
        notifications.add(achievementId);
        await prefs.setStringList(_userPendingNotificationsKey, notifications);
      }
    } catch (e) {
      AppLogger.i('Error adding to pending notifications: $e');
      rethrow;
    }
  }

  /// Get achievements with pending notifications
  Future<List<String>> getPendingNotifications() async {
    return prefs.getStringList(_userPendingNotificationsKey) ?? [];
  }

  /// Remove achievement from pending notifications after showing to user
  Future<void> removeFromPendingNotifications(String achievementId) async {
    try {
      final notifications = await getPendingNotifications();
      notifications.remove(achievementId);
      await prefs.setStringList(_userPendingNotificationsKey, notifications);

      // Also mark notification as shown in the achievement
      final achievement = await getAchievementById(achievementId);
      if (achievement != null) {
        final updated = achievement.copyWith(isNotificationShown: true);
        await saveAchievement(updated);
      }
    } catch (e) {
      AppLogger.i('Error removing from pending notifications: $e');
      rethrow;
    }
  }

  /// Check if achievement is already unlocked locally
  Future<bool> isAchievementUnlocked(String achievementId) async {
    final achievement = await getAchievementById(achievementId);
    return achievement?.isUnlocked ?? false;
  }

  /// Get count of unlocked achievements
  Future<int> getUnlockedCount() async {
    final achievements = await getAchievements();
    return achievements.where((a) => a.isUnlocked).length;
  }

  /// Clear all local achievements for current user
  Future<void> clearAll() async {
    try {
      await prefs.remove(_userAchievementsKey);
      await prefs.remove(_userSyncQueueKey);
      await prefs.remove(_userPendingNotificationsKey);
    } catch (e) {
      AppLogger.i('Error clearing achievements: $e');
      rethrow;
    }
  }

  /// Get achievements that need to be synced to Firebase
  Future<List<Achievement>> getAchievementsToSync() async {
    try {
      final syncQueue = await getSyncQueue();
      final achievements = await getAchievements();
      return achievements.where((a) => syncQueue.contains(a.id)).toList();
    } catch (e) {
      AppLogger.i('Error getting achievements to sync: $e');
      return [];
    }
  }
}
