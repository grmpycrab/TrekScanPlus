import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/color.dart';
import '../../services/permission_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Notification preferences
  bool _pushNotificationsEnabled = true;
  bool _bookingNotifications = true;
  bool _socialNotifications = true;
  bool _followRequestNotifications = true;
  bool _achievementNotifications = true;
  bool _certificateNotifications = true;
  bool _systemNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _systemPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkSystemPermission();
  }

  Future<void> _checkSystemPermission() async {
    final status = await Permission.notification.status;
    setState(() {
      _systemPermissionGranted = status.isGranted;
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotificationsEnabled =
          prefs.getBool('push_notifications_enabled') ?? true;
      _bookingNotifications = prefs.getBool('booking_notifications') ?? true;
      _socialNotifications = prefs.getBool('social_notifications') ?? true;
      _followRequestNotifications =
          prefs.getBool('follow_request_notifications') ?? true;
      _achievementNotifications =
          prefs.getBool('achievement_notifications') ?? true;
      _certificateNotifications =
          prefs.getBool('certificate_notifications') ?? true;
      _systemNotifications = prefs.getBool('system_notifications') ?? true;
      _soundEnabled = prefs.getBool('notification_sound') ?? true;
      _vibrationEnabled = prefs.getBool('notification_vibration') ?? true;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.notificationToggle,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // System permission warning (if not granted)
          if (!_systemPermissionGranted) _buildPermissionWarning(),
          if (!_systemPermissionGranted) const SizedBox(height: 16),

          // Master toggle
          _buildMasterToggle(),
          const SizedBox(height: 24),

          // Notification Types Section
          _buildSectionHeader('Notification Types'),
          const SizedBox(height: 12),
          _buildNotificationCard(
            icon: Icons.calendar_today,
            iconColor: AppColors.notificationToggle,
            title: 'Booking Notifications',
            subtitle: 'Booking approvals, declines, and updates',
            value: _bookingNotifications,
            enabled: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() => _bookingNotifications = value);
              _savePreference('booking_notifications', value);
            },
          ),
          _buildNotificationCard(
            icon: Icons.people,
            iconColor: AppColors.notificationToggle,
            title: 'Social Notifications',
            subtitle: 'Likes, comments, and mentions',
            value: _socialNotifications,
            enabled: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() => _socialNotifications = value);
              _savePreference('social_notifications', value);
            },
          ),
          _buildNotificationCard(
            icon: Icons.person_add,
            iconColor: AppColors.notificationToggle,
            title: 'Follow Requests',
            subtitle: 'New follow requests and acceptances',
            value: _followRequestNotifications,
            enabled: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() => _followRequestNotifications = value);
              _savePreference('follow_request_notifications', value);
            },
          ),
          _buildNotificationCard(
            icon: Icons.emoji_events,
            iconColor: AppColors.notificationToggle,
            title: 'Achievement Notifications',
            subtitle: 'New achievements and milestones',
            value: _achievementNotifications,
            enabled: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() => _achievementNotifications = value);
              _savePreference('achievement_notifications', value);
            },
          ),
          _buildNotificationCard(
            icon: Icons.card_membership,
            iconColor: AppColors.notificationToggle,
            title: 'Certificate Notifications',
            subtitle: 'E-certificates and trek completions',
            value: _certificateNotifications,
            enabled: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() => _certificateNotifications = value);
              _savePreference('certificate_notifications', value);
            },
          ),
          _buildNotificationCard(
            icon: Icons.settings,
            iconColor: AppColors.notificationToggle,
            title: 'System Notifications',
            subtitle: 'App updates and important announcements',
            value: _systemNotifications,
            enabled: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() => _systemNotifications = value);
              _savePreference('system_notifications', value);
            },
          ),

          const SizedBox(height: 24),

          // Alert Preferences Section
          _buildSectionHeader('Alert Preferences'),
          const SizedBox(height: 12),
          _buildNotificationCard(
            icon: Icons.volume_up,
            iconColor: AppColors.primary,
            title: 'Sound',
            subtitle: 'Play sound for notifications',
            value: _soundEnabled,
            enabled: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() => _soundEnabled = value);
              _savePreference('notification_sound', value);
            },
          ),
          _buildNotificationCard(
            icon: Icons.vibration,
            iconColor: AppColors.primary,
            title: 'Vibration',
            subtitle: 'Vibrate for notifications',
            value: _vibrationEnabled,
            enabled: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() => _vibrationEnabled = value);
              _savePreference('notification_vibration', value);
            },
          ),

          const SizedBox(height: 24),

          // Info card
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildMasterToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _pushNotificationsEnabled
              ? [AppColors.notificationBooking, AppColors.primary]
              : [Colors.grey.shade300, Colors.grey.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _pushNotificationsEnabled
                ? AppColors.notificationBooking.withValues(alpha: 0.3)
                : AppColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _pushNotificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: AppColors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Push Notifications',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pushNotificationsEnabled
                      ? 'Notifications are enabled'
                      : 'Notifications are disabled',
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _pushNotificationsEnabled,
            onChanged: (value) async {
              // If enabling notifications, check system permission first
              if (value && !_systemPermissionGranted) {
                final granted = await PermissionService.instance
                    .requestNotificationPermission(context);
                if (granted) {
                  setState(() {
                    _systemPermissionGranted = true;
                    _pushNotificationsEnabled = value;
                  });
                  _savePreference('push_notifications_enabled', value);
                }
              } else {
                setState(() => _pushNotificationsEnabled = value);
                _savePreference('push_notifications_enabled', value);
              }
            },
            activeColor: AppColors.white,
            activeTrackColor: AppColors.white.withValues(alpha: 0.5),
            inactiveThumbColor: AppColors.white.withValues(alpha: 0.7),
            inactiveTrackColor: AppColors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: enabled ? AppColors.textTertiary : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeColor: iconColor,
        ),
      ),
    );
  }

  Widget _buildPermissionWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Permission Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable notification permission in system settings to receive alerts.',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              // Recheck permission when returning
              await Future.delayed(const Duration(milliseconds: 500));
              await _checkSystemPermission();
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Open Settings', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.notificationBooking.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.notificationBooking.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: AppColors.notificationBooking,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.notificationBooking.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You can customize which notifications you receive. Turn off push notifications to disable all alerts.',
                  style: TextStyle(
                    color: AppColors.notificationBooking.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
