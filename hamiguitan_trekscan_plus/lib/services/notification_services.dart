import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore;

  NotificationService({FirebaseFirestore? firestore})
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
      // fallback or log
      // ignore: avoid_print
      print('Failed to send notification: $e');
      rethrow;
    }
  }

  Stream<List<NotificationModel>> notificationsStream(String userId) {
    try {
      print('🔔 Subscribing to notification stream for user: $userId');
      return _userNotificationsRef(userId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            print(
              '🔔 Notifications snapshot received: ${snapshot.docs.length} notifications for $userId',
            );
            for (final d in snapshot.docs) {
              print('🔔 Notification data: ${d.data()}');
            }
            return snapshot.docs.map((d) {
              return NotificationModel.fromMap(d.id, d.data());
            }).toList();
          })
          .handleError((error) {
            print('❌ Notification stream error for $userId: $error');
            return [];
          });
    } catch (e) {
      // If firestore isn't available, return empty stream
      print('❌ notificationsStream error: $e');
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
      // ignore: avoid_print
      print('fetchNotifications error: $e');
      return [];
    }
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      print('Marking notification $notificationId as read');
      await _userNotificationsRef(
        userId,
      ).doc(notificationId).update({'isRead': true});
      print('Successfully marked notification as read');
    } catch (e) {
      print('markAsRead error: $e');
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
      // ignore: avoid_print
      print('markAllAsRead error: $e');
    }
  }
}
