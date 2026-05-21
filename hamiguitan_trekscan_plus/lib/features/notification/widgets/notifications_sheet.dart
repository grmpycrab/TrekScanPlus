import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../services/firestore_notification_service.dart';
import '../../../screens/main/main_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../core/widgets/app_dialogue_handler.dart';
import '../../../utils/app_logger.dart';

class NotificationsSheet extends StatefulWidget {
  final String userId;

  const NotificationsSheet({super.key, required this.userId});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  final _notificationService = InAppNotificationService();
  bool _isSelectionMode = false;
  final Set<String> _selectedNotifications = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isSelectionMode
                      ? '${_selectedNotifications.length} selected'
                      : 'Notifications',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (_isSelectionMode) ...[
                      TextButton(
                        onPressed: _selectAll,
                        child: const Text('Select all'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _selectedNotifications.isEmpty
                            ? null
                            : _deleteSelectedNotifications,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedNotifications.clear();
                          });
                        },
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: () async {
                          await _notificationService.markAllAsRead(
                            widget.userId,
                          );
                        },
                        child: const Text('Mark all as read'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Notifications list
          Expanded(
            child: StreamBuilder<List<NotificationModel>>(
              stream: _notificationService.notificationsStream(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final notifications = snapshot.data ?? [];

                if (notifications.isEmpty) {
                  return const Center(child: Text('No notifications yet'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationTile(notification, notifications);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(
    NotificationModel notification,
    List<NotificationModel> allNotifications,
  ) {
    final isSelected = _selectedNotifications.contains(notification.id);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _confirmDelete(notification);
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      child: _NotificationTile(
        notification: notification,
        isSelectionMode: _isSelectionMode,
        isSelected: isSelected,
        onTap: () async {
          if (_isSelectionMode) {
            _toggleSelection(notification.id);
            return;
          }

          AppLogger.i('🔔 Notification tapped: ${notification.title}');
          AppLogger.i('🔔 ActionType: ${notification.actionType}');
          AppLogger.i('🔔 ActionData: ${notification.actionData}');

          // Handle navigation first BEFORE marking as read
          if (notification.actionType != null &&
              notification.actionData != null) {
            AppLogger.i('🔔 Starting navigation...');

            // Close the notifications sheet immediately
            AppLogger.i('🔔 Closing notification sheet...');
            Navigator.pop(context);

            // Mark as read asynchronously (don't wait)
            _notificationService.markAsRead(widget.userId, notification.id);

            // Navigate based on type
            if (notification.actionType == 'post') {
              final postId = notification.actionData!;
              AppLogger.i('🔔 Navigating to post: $postId');
              Navigator.pushNamed(context, '/post-detail', arguments: postId);
            } else if (notification.actionType == 'booking') {
              final bookingId = notification.actionData!;
              AppLogger.i('🔔 Navigating to booking: $bookingId');
              // Navigate to MainScreen with booking tab selected
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const MainScreen(
                    initialTabIndex: 3,
                  ),
                ),
                (route) => false,
              );
            }
          } else {
            // Backward compatibility for old notifications
            AppLogger.i(
              '🔔 No actionType/actionData - checking for old format',
            );

            // Detect old booking notifications by title
            final bookingTitles = [
              'Booking Approved',
              'Booking Declined',
              'Booking Under Review',
              'Booking Cancelled',
            ];

            if (bookingTitles.any(
              (title) => notification.title.contains(title),
            )) {
              AppLogger.i(
                '🔔 Old booking notification - navigating to book-climb',
              );
              // Navigate to MainScreen with booking tab selected
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const MainScreen(
                    initialTabIndex: 3, // Booking tab
                  ),
                ),
                (route) => false,
              );
            } else {
              AppLogger.i('🔔 No navigation available');
            }

            // Mark as read
            await _notificationService.markAsRead(
              widget.userId,
              notification.id,
            );
          }
        },
        onLongPress: () {
          setState(() {
            _isSelectionMode = true;
            _selectedNotifications.add(notification.id);
          });
        },
        onSelectionChanged: (selected) {
          _toggleSelection(notification.id);
        },
      ),
    );
  }

  void _toggleSelection(String notificationId) {
    setState(() {
      if (_selectedNotifications.contains(notificationId)) {
        _selectedNotifications.remove(notificationId);
        if (_selectedNotifications.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedNotifications.add(notificationId);
      }
    });
  }

  Future<void> _selectAll() async {
    final snapshot = await _notificationService
        .notificationsStream(widget.userId)
        .first;
    setState(() {
      _selectedNotifications.clear();
      _selectedNotifications.addAll(snapshot.map((n) => n.id));
    });
  }

  Future<bool> _confirmDelete(NotificationModel notification) async {
    final confirmed = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Delete Notification',
      message: 'Are you sure you want to delete this notification?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirmed == true) {
      await _notificationService.deleteNotification(
        widget.userId,
        notification.id,
      );
      return true;
    }
    return false;
  }

  Future<void> _deleteSelectedNotifications() async {
    if (_selectedNotifications.isEmpty) return;

    final confirmed = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Delete Notifications',
      message:
          'Are you sure you want to delete ${_selectedNotifications.length} notification${_selectedNotifications.length > 1 ? 's' : ''}?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirmed == true) {
      // Delete all selected notifications
      for (final notificationId in _selectedNotifications) {
        await _notificationService.deleteNotification(
          widget.userId,
          notificationId,
        );
      }

      setState(() {
        _selectedNotifications.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(bool?)? onSelectionChanged;
  final bool isSelectionMode;
  final bool isSelected;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    this.onLongPress,
    this.onSelectionChanged,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  Color _getBackgroundColor(AppTheme colors) {
    if (isSelected) {
      return colors.primary.withValues(alpha: 0.1);
    }
    return switch (notification.type) {
      NotificationType.success => Colors.green.withValues(alpha: 0.1),
      NotificationType.warning => Colors.orange.withValues(alpha: 0.1),
      NotificationType.alert => Colors.red.withValues(alpha: 0.1),
      NotificationType.info => Colors.blue.withValues(alpha: 0.1),
    };
  }

  Color _getIconColor(AppTheme colors) {
    return switch (notification.type) {
      NotificationType.success => Colors.green,
      NotificationType.warning => Colors.orange,
      NotificationType.alert => Colors.red,
      NotificationType.info => colors.primary,
    };
  }

  IconData _getIcon() {
    return switch (notification.type) {
      NotificationType.success => Icons.check_circle,
      NotificationType.warning => Icons.warning,
      NotificationType.alert => Icons.error,
      NotificationType.info => Icons.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final timeAgo = _getTimeAgo(notification.timestamp);

    return GestureDetector(
      onTap: () {
        AppLogger.i('🔴🔴🔴 GESTURE DETECTOR TAPPED!!! 🔴🔴🔴');
        onTap();
      },
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: notification.isRead && !isSelected
              ? Colors.transparent
              : _getBackgroundColor(colors),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : (notification.isRead ? colors.border : _getIconColor(colors)),
            width: isSelected ? 2 : (notification.isRead ? 0.5 : 1.5),
          ),
        ),
        child: ListTile(
          onTap: () {
            AppLogger.i('🔴 ListTile tapped!');
            onTap();
          },
          leading: isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: onSelectionChanged,
                  activeColor: colors.primary,
                )
              : Icon(_getIcon(), color: _getIconColor(colors)),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: notification.isRead
                  ? FontWeight.normal
                  : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                timeAgo,
                style: TextStyle(fontSize: 11, color: colors.textSecondary),
              ),
            ],
          ),
          isThreeLine: true,
          trailing: !isSelectionMode && notification.isRead
              ? null
              : (!isSelectionMode
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}
