import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../services/firestore_notification_service.dart';
import '../../../core/services/user_service.dart';
import '../../../utils/app_logger.dart';

class NotificationViewModel extends ChangeNotifier {
  final InAppNotificationService _notifService = InAppNotificationService();
  final UserService _userService = UserService.instance;

  bool isDeleting = false;
  String? deleteError;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<NotificationModel>> notificationsStream(String userId) =>
      _notifService.notificationsStream(userId);

  Future<void> markAllAsRead(String userId) =>
      _notifService.markAllAsRead(userId);

  Future<void> markAsRead(String userId, String notificationId) =>
      _notifService.markAsRead(userId, notificationId);

  Future<void> deleteNotification(String userId, String notificationId) =>
      _notifService.deleteNotification(userId, notificationId);

  /// Bulk delete — sets [isDeleting] while running. Sets [deleteError] on
  /// failure. Call [clearDeleteError] after displaying the error.
  Future<void> deleteSelected(String userId, Set<String> ids) async {
    isDeleting = true;
    deleteError = null;
    notifyListeners();
    try {
      for (final id in ids) {
        await _notifService.deleteNotification(userId, id);
      }
    } catch (e) {
      deleteError = e.toString();
      AppLogger.e('Error deleting notifications: $e');
    } finally {
      isDeleting = false;
      notifyListeners();
    }
  }

  Future<void> acceptFollowRequest(
    String userId,
    String requestId,
    String notificationId,
  ) async {
    await _userService.acceptFollowRequest(userId, requestId);
    await _notifService.deleteNotification(userId, notificationId);
  }

  Future<void> rejectFollowRequest(
    String userId,
    String requestId,
    String notificationId,
  ) async {
    await _userService.rejectFollowRequest(userId, requestId);
    await _notifService.deleteNotification(userId, notificationId);
  }

  String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  void clearDeleteError() {
    deleteError = null;
    notifyListeners();
  }
}
