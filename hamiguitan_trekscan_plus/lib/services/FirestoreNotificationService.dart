// ignore_for_file: file_names

import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../utils/app_logger.dart';

class InAppNotificationService {
  final FirebaseFirestore _firestore;

  InAppNotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userNotificationsRef(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications');
  }

  Future<void> sendNotificationForUser(
    String userId,
    NotificationModel notification,
  ) async {
    try {
      final ref = _userNotificationsRef(userId);
      await ref.add(notification.toMap());
    } catch (e) {
      AppLogger.e('Failed to send notification: $e');
      rethrow;
    }
  }

  Stream<List<NotificationModel>> notificationsStream(String userId) {
    try {
      return _userNotificationsRef(userId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((d) {
              return NotificationModel.fromMap(d.id, d.data());
            }).toList();
          })
          .handleError((error) {
            AppLogger.e('Notification stream error for $userId: $error');
            return [];
          });
    } catch (e) {
      AppLogger.e('notificationsStream error: $e');
      return Stream.value([]);
    }
  }

  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    try {
      final snapshot = await _userNotificationsRef(
        userId,
      ).orderBy('timestamp', descending: true).get();
      return snapshot.docs
          .map((d) => NotificationModel.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      AppLogger.e('fetchNotifications error: $e');
      return [];
    }
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _userNotificationsRef(
        userId,
      ).doc(notificationId).update({'isRead': true});
    } catch (e) {
      AppLogger.e('markAsRead error: $e');
      rethrow;
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _userNotificationsRef(
        userId,
      ).where('isRead', isEqualTo: false).get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      AppLogger.e('markAllAsRead error: $e');
    }
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _userNotificationsRef(userId).doc(notificationId).delete();
    } catch (e) {
      AppLogger.e('deleteNotification error: $e');
    }
  }

  Future<void> sendFollowRequest(
    String targetUserId,
    String requesterId,
    String requesterName,
  ) async {
    final notification = NotificationModel(
      id: '',
      title: 'New Follow Request',
      message: '$requesterName wants to follow you',
      type: NotificationType.info,
      timestamp: DateTime.now(),
      actionType: 'follow_request',
      actionData: requesterId,
      showActionButtons: true,
      followRequestId: requesterId,
    );

    await sendNotificationForUser(targetUserId, notification);
  }
}
