import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { success, warning, info, alert }

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;
  final String? actionType; // e.g., 'post', 'booking', 'achievement'
  final String? actionData; // e.g., postId, bookingId

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.actionType,
    this.actionData,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    // Handle backward compatibility with old notification format
    String? actionType = map['actionType'] as String?;
    String? actionData = map['actionData'] as String?;

    // Migrate old 'like' and 'comment' notifications to new format
    if (actionType == null && map['postId'] != null) {
      actionType = 'post';
      actionData = map['postId'] as String;
    }

    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: _typeFromString(map['type'] as String? ?? 'info'),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
      actionType: actionType,
      actionData: actionData,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': _typeToString(type),
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      if (actionType != null) 'actionType': actionType,
      if (actionData != null) 'actionData': actionData,
    };
  }

  static NotificationType _typeFromString(String s) {
    switch (s) {
      case 'success':
        return NotificationType.success;
      case 'warning':
        return NotificationType.warning;
      case 'alert':
        return NotificationType.alert;
      case 'info':
      default:
        return NotificationType.info;
    }
  }

  static String _typeToString(NotificationType t) {
    switch (t) {
      case NotificationType.success:
        return 'success';
      case NotificationType.warning:
        return 'warning';
      case NotificationType.alert:
        return 'alert';
      case NotificationType.info:
        return 'info';
    }
  }
}
