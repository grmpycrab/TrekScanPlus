import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// Service to handle Firebase Cloud Messaging (FCM) for push notifications
class FCMService {
  static final FCMService _instance = FCMService._internal();

  factory FCMService() {
    return _instance;
  }

  FCMService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Callbacks for when messages are received
  Function(RemoteMessage)? _onMessageReceivedCallback;
  Function(RemoteMessage)? _onMessageOpenedCallback;

  /// Initialize FCM
  Future<void> initialize({
    required Function(RemoteMessage) onMessageReceived,
    required Function(RemoteMessage) onMessageOpened,
  }) async {
    _onMessageReceivedCallback = onMessageReceived;
    _onMessageOpenedCallback = onMessageOpened;

    try {
      // Request permission for notifications
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      AppLogger.i(
        'User notification permission: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        AppLogger.w('Notification permission denied');
        return;
      }

      // Get FCM token
      final token = await _messaging.getToken();
      if (kDebugMode) {
        AppLogger.d('🗞️ FCM Token obtained');
      }

      // Save token to Firestore
      if (_auth.currentUser != null && token != null) {
        await _saveFCMToken(token);
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        AppLogger.i(
          'Message received in foreground: ${message.notification?.title}',
        );
        _onMessageReceivedCallback?.call(message);
      });

      // Handle background message (when app is in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLogger.i(
          'Message opened from background: ${message.notification?.title}',
        );
        _onMessageOpenedCallback?.call(message);
      });

      // Handle terminated message (when app is closed)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.i(
          'App launched from terminated state with message: ${initialMessage.notification?.title}',
        );
        _onMessageOpenedCallback?.call(initialMessage);
      }

      // Token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          AppLogger.d('🗞️ FCM Token refreshed');
        }
        if (_auth.currentUser != null) {
          _saveFCMToken(newToken);
        }
      });
    } catch (e) {
      AppLogger.e('FCM Initialization Error: $e');
    }
  }

  /// Save FCM token to Firestore for this user
  Future<void> _saveFCMToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final deviceId = _getDeviceIdentifier();

      await _firestore.collection('users').doc(userId).set({
        'fcmTokens': {
          deviceId: {
            'token': token,
            'platform': Platform.isIOS ? 'ios' : 'android',
            'timestamp': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));

      AppLogger.i('FCM Token saved to Firestore');
    } catch (e) {
      AppLogger.e('Error saving FCM token: $e');
    }
  }

  /// Get unique device identifier
  String _getDeviceIdentifier() {
    // In production, you'd use package_info_plus or device_info_plus
    // For now, use a simple identifier
    return '${Platform.isIOS ? 'ios' : 'android'}_device';
  }

  /// Send a notification to a specific user
  Future<void> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String message,
    required String
    actionType, // 'post', 'booking', 'follow', 'like', 'comment'
    required String actionData, // postId, bookingId, userId, etc.
    Map<String, String>? customData,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': targetUserId,
        'title': title,
        'message': message,
        'actionType': actionType,
        'actionData': actionData,
        'customData': customData ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      AppLogger.i('Notification sent to user: $targetUserId');
    } catch (e) {
      AppLogger.e('Error sending notification: $e');
    }
  }

  /// Subscribe to a topic for broadcast notifications
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      AppLogger.i('Subscribed to topic: $topic');
    } catch (e) {
      AppLogger.e('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      AppLogger.i('Unsubscribed from topic: $topic');
    } catch (e) {
      AppLogger.e('Error unsubscribing from topic: $e');
    }
  }
}

/// Background message handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.i('Handling background message: ${message.notification?.title}');
  // Handle background messages here
}
