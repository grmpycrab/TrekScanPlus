import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/fcm_service.dart';
import '../services/notification_manager.dart';
import '../components/notification_banner.dart';
import '../utils/app_logger.dart';
import '../config/app_router.dart';

/// Handles FCM initialisation, foreground banner display, and
/// notification-driven navigation.
///
/// MVVM role: ViewModel / Handler
/// - No UI widgets owned here.
/// - Navigation uses [navigatorKey] (not a BuildContext) to stay UI-free.
/// - The View counterpart is [NotificationBannerOverlay] in components/.
///
/// Extraction reason: FCM setup, notification-type mapping, and navigation
/// were all mixed inside `_MyAppState._initializeFCM`. This class isolates
/// the push notification responsibility so `_MyAppState` only needs one line:
/// `unawaited(NotificationHandler.initialize())`.
class NotificationHandler {
  /// Initialises FCM and registers foreground + opened-notification callbacks.
  ///
  /// Call once per authenticated session from [_initializeVerifiedUserServices].
  static Future<void> initialize() async {
    try {
      await FCMService().initialize(
        onMessageReceived: _onForegroundMessage,
        onMessageOpened: _onNotificationOpened,
      );
      AppLogger.i('FCM initialized successfully');
    } catch (e) {
      AppLogger.e('FCM initialization error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private callbacks
  // ---------------------------------------------------------------------------

  static void _onForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';
    final actionType = message.data['actionType'] as String?;

    final type = _getNotificationType(actionType);

    if (type == NotificationBannerType.success) {
      NotificationManager.showSuccess(title: title, message: body);
    } else if (type == NotificationBannerType.warning) {
      NotificationManager.showWarning(title: title, message: body);
    } else if (type == NotificationBannerType.error) {
      NotificationManager.showError(title: title, message: body);
    } else {
      NotificationManager.showInfo(title: title, message: body);
    }
  }

  static void _onNotificationOpened(RemoteMessage message) {
    AppLogger.d('Notification opened: ${message.data}');
    _handleNotificationNavigation(message);
  }

  /// Maps FCM actionType strings to banner severity levels.
  static NotificationBannerType _getNotificationType(String? actionType) {
    return switch (actionType) {
      'booking_approved' => NotificationBannerType.success,
      'booking_rejected' => NotificationBannerType.error,
      'booking_pending' => NotificationBannerType.warning,
      'follow_request' => NotificationBannerType.info,
      'post_liked' => NotificationBannerType.success,
      'post_commented' => NotificationBannerType.info,
      _ => NotificationBannerType.info,
    };
  }

  /// Navigates to the appropriate screen when a notification is tapped.
  ///
  /// Uses [navigatorKey] so this method has no BuildContext dependency.
  static void _handleNotificationNavigation(RemoteMessage message) {
    final actionType = message.data['actionType'] as String?;
    final actionData = message.data['actionData'] as String?;

    AppLogger.d('ActionType: $actionType, ActionData: $actionData');

    if (actionType == 'post' && actionData != null) {
      navigatorKey.currentState?.pushNamed(
        '/post-detail',
        arguments: actionData,
      );
    } else if (actionType == 'booking' && actionData != null) {
      navigatorKey.currentState?.pushNamed(
        '/book-climb',
        arguments: actionData,
      );
    } else if (actionType?.startsWith('booking_') == true) {
      navigatorKey.currentState?.pushReplacementNamed('/main');
    }
  }
}
