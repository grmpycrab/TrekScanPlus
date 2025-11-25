import 'package:flutter/material.dart';
import '../components/notification_banner.dart';

/// Service to manage in-app notifications globally
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();

  factory NotificationManager() {
    return _instance;
  }

  NotificationManager._internal();

  /// Show an in-app notification banner
  static void showSuccess({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    _showNotification(
      title: title,
      message: message,
      type: NotificationBannerType.success,
      duration: duration,
      onTap: onTap,
    );
  }

  static void showInfo({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    _showNotification(
      title: title,
      message: message,
      type: NotificationBannerType.info,
      duration: duration,
      onTap: onTap,
    );
  }

  static void showWarning({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onTap,
  }) {
    _showNotification(
      title: title,
      message: message,
      type: NotificationBannerType.warning,
      duration: duration,
      onTap: onTap,
    );
  }

  static void showError({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onTap,
  }) {
    _showNotification(
      title: title,
      message: message,
      type: NotificationBannerType.error,
      duration: duration,
      onTap: onTap,
    );
  }

  static void _showNotification({
    required String title,
    required String message,
    required NotificationBannerType type,
    required Duration duration,
    VoidCallback? onTap,
  }) {
    // This will be called by NavigatorObserver with BuildContext
    // For now, we store the data and show it through the overlay
    print(
      '📢 [NotificationManager] _showNotification called: $title, type: $type',
    );
    print('📢 [NotificationManager] GlobalKey: $_globalNotificationKey');
    print(
      '📢 [NotificationManager] currentState: ${_globalNotificationKey.currentState}',
    );

    final data = NotificationBannerData(
      title: title,
      message: message,
      type: type,
      duration: duration,
      onTap: onTap,
    );

    if (_globalNotificationKey.currentState == null) {
      print(
        '❌ [NotificationManager] ERROR: currentState is null! Overlay not initialized.',
      );
      return;
    }

    // Access the global context through the observer if available
    // Otherwise, this will be called from a BuildContext directly
    _globalNotificationKey.currentState?.showNotification(data);
  }

  // Global key for accessing the overlay state
  static final _globalNotificationKey =
      GlobalKey<NotificationBannerOverlayState>();

  static GlobalKey<NotificationBannerOverlayState> get overlayKey =>
      _globalNotificationKey;
}

/// Extension to show notifications from any BuildContext
extension NotificationContext on BuildContext {
  void showSuccessNotification({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    NotificationManager.showSuccess(
      title: title,
      message: message,
      duration: duration,
      onTap: onTap,
    );
  }

  void showInfoNotification({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    NotificationManager.showInfo(
      title: title,
      message: message,
      duration: duration,
      onTap: onTap,
    );
  }

  void showWarningNotification({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onTap,
  }) {
    NotificationManager.showWarning(
      title: title,
      message: message,
      duration: duration,
      onTap: onTap,
    );
  }

  void showErrorNotification({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onTap,
  }) {
    NotificationManager.showError(
      title: title,
      message: message,
      duration: duration,
      onTap: onTap,
    );
  }
}
