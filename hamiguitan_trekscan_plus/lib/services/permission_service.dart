import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/new_color.dart';

/// Service to handle app permissions (notifications, storage, etc.)
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  static PermissionService get instance => _instance;

  PermissionService._internal();

  static const String _notificationPermissionKey =
      'notification_permission_requested';
  static const String _storagePermissionKey = 'storage_permission_requested';

  /// Check if notification permission has been requested before
  Future<bool> hasRequestedNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationPermissionKey) ?? false;
  }

  /// Check if storage permission has been requested before
  Future<bool> hasRequestedStoragePermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_storagePermissionKey) ?? false;
  }

  /// Mark notification permission as requested
  Future<void> markNotificationPermissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationPermissionKey, true);
  }

  /// Mark storage permission as requested
  Future<void> markStoragePermissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storagePermissionKey, true);
  }

  /// Request notification permission with explanation dialog
  Future<bool> requestNotificationPermission(
    BuildContext context, {
    bool showExplanation = false,
  }) async {
    // Check current permission status
    final status = await Permission.notification.status;

    // If already granted, return true
    if (status.isGranted) return true;

    // Check if already requested before
    final hasRequested = await hasRequestedNotificationPermission();

    // If showing explanation or already requested once before, show dialog
    if (showExplanation || (hasRequested && status.isDenied)) {
      final shouldRequest = await _showPermissionDialog(
        context: context,
        title: 'Enable Notifications',
        message:
            'TrekScan+ would like to send you notifications about:\n\n'
            '• Booking status updates\n'
            '• Social interactions (likes, comments)\n'
            '• Follow requests\n'
            '• Achievement unlocks\n'
            '• Certificate availability\n'
            '• Important system updates\n\n'
            'You can customize notification types in settings.',
        icon: Icons.notifications_active,
        iconColor: Colors.blue,
      );

      if (!shouldRequest) {
        await markNotificationPermissionRequested();
        return false;
      }
    }

    // Request the system permission directly
    await markNotificationPermissionRequested();
    final result = await Permission.notification.request();

    if (result.isGranted) {
      // Enable push notifications in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('push_notifications_enabled', true);
      return true;
    } else if (result.isPermanentlyDenied) {
      if (context.mounted) {
        _showOpenSettingsDialog(context, 'notification');
      }
    }

    return false;
  }

  /// Request storage permission with explanation dialog
  Future<bool> requestStoragePermission(
    BuildContext context, {
    bool showExplanation = false,
  }) async {
    // For Android 13+ (API 33+), use photos permission
    // For Android 10-12, use storage permission
    // Check photos permission first (for Android 13+)
    var photosStatus = await Permission.photos.status;

    // If photos permission is granted, we're good
    if (photosStatus.isGranted) return true;

    // Check storage permission (for Android < 13)
    var storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;

    // Check if already requested before
    final hasRequested = await hasRequestedStoragePermission();

    // If showing explanation or already requested once before, show dialog
    if (showExplanation ||
        (hasRequested && !photosStatus.isGranted && !storageStatus.isGranted)) {
      final shouldRequest = await _showPermissionDialog(
        context: context,
        title: 'Storage Permission',
        message:
            'TrekScan+ needs storage access to:\n\n'
            '• Save certificates to your device\n'
            '• Store trek photos and memories\n'
            '• Cache station information offline\n'
            '• Save achievement badges\n\n'
            'Your privacy is important. We only access files you explicitly save.',
        icon: Icons.folder_outlined,
        iconColor: Colors.orange,
      );

      if (!shouldRequest) {
        await markStoragePermissionRequested();
        return false;
      }
    }

    // Mark as requested
    await markStoragePermissionRequested();

    // Try photos permission first (Android 13+)
    if (!photosStatus.isPermanentlyDenied) {
      final result = await Permission.photos.request();
      if (result.isGranted) return true;
    }

    // Try storage permission (Android < 13)
    if (!storageStatus.isPermanentlyDenied) {
      final result = await Permission.storage.request();
      if (result.isGranted) return true;
    }

    // Try manageExternalStorage for Android 11+
    final manageStatus = await Permission.manageExternalStorage.status;
    if (!manageStatus.isPermanentlyDenied && !manageStatus.isGranted) {
      final result = await Permission.manageExternalStorage.request();
      if (result.isGranted) return true;
    }

    // Check if any permission was permanently denied
    photosStatus = await Permission.photos.status;
    storageStatus = await Permission.storage.status;

    if (photosStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
      if (context.mounted) {
        _showOpenSettingsDialog(context, 'storage');
      }
    }

    return false;
  }

  /// Request camera permission (already implemented in scanner_screen)
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Show permission explanation dialog
  Future<bool> _showPermissionDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Not Now',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Allow'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Show dialog to open app settings
  Future<void> _showOpenSettingsDialog(
    BuildContext context,
    String permissionType,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Permission Required',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Please enable $permissionType permission in app settings to use this feature.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Request all initial permissions at app start
  Future<void> requestInitialPermissions(BuildContext context) async {
    // Request notification permission first
    await requestNotificationPermission(context);

    // Small delay between permission requests for better UX
    await Future.delayed(const Duration(milliseconds: 500));

    // Request storage permission
    await requestStoragePermission(context);
  }

  /// Check if all critical permissions are granted
  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'notifications': await Permission.notification.isGranted,
      'storage':
          await Permission.storage.isGranted ||
          await Permission.photos.isGranted,
      'camera': await Permission.camera.isGranted,
      'location': await Permission.location.isGranted,
    };
  }
}
