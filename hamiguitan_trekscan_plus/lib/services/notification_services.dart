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
      return _userNotificationsRef(userId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((d) => NotificationModel.fromMap(d.id, d.data()))
                .toList(),
          );
    } catch (e) {
      // If firestore isn't available, return empty stream
      // ignore: avoid_print
      print('notificationsStream error: $e');
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
      await _userNotificationsRef(
        userId,
      ).doc(notificationId).update({'isRead': true});
    } catch (e) {
      // ignore: avoid_print
      print('markAsRead error: $e');
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
