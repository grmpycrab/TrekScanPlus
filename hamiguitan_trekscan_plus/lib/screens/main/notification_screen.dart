import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/color.dart';
import '../../models/notification_model.dart';
import '../../services/notification_services.dart';
import '../../services/user_service.dart';
import '../../components/app_dialogue_handler.dart';
import 'main_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _service = NotificationService();
  final UserService _userService = UserService.instance;
  bool _isSelectionMode = false;
  final Set<String> _selectedNotifications = {};

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedNotifications.length} selected'
              : 'Notifications',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _isSelectionMode ? Icons.close : Icons.arrow_back,
            color: Colors.black87,
          ),
          onPressed: () {
            if (_isSelectionMode) {
              setState(() {
                _isSelectionMode = false;
                _selectedNotifications.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: _isSelectionMode
            ? [
                TextButton(
                  onPressed: _selectAll,
                  child: const Text(
                    'Select all',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _selectedNotifications.isEmpty
                      ? null
                      : _deleteSelectedNotifications,
                ),
              ]
            : [
                TextButton(
                  onPressed: () async {
                    if (_userId == null) return;
                    await _service.markAllAsRead(_userId!);
                    setState(() {});
                  },
                  child: const Text(
                    'Mark all as read',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
      ),
      body: _userId == null
          ? _buildEmptyState(message: 'Please sign in to see notifications')
          : StreamBuilder<List<NotificationModel>>(
              stream: _service.notificationsStream(_userId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) return _buildEmptyState();
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final notification = items[index];
                    return _buildNotificationItem(notification, items);
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message ?? 'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : (notification.isRead ? Colors.white : const Color(0xFFF5F9FF)),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isSelectionMode
                ? () => _toggleSelection(notification.id)
                : (notification.showActionButtons
                      ? null
                      : () async {
                          if (_userId != null) {
                            await _service.markAsRead(
                              _userId!,
                              notification.id,
                            );
                          }
                          setState(() {
                            notification.isRead = true;
                          });

                          _handleNotificationNavigation(notification);
                        }),
            onLongPress: () {
              setState(() {
                _isSelectionMode = true;
                _selectedNotifications.add(notification.id);
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNotificationIcon(notification.type),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.message,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatTimestamp(notification.timestamp),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isSelectionMode)
                        Checkbox(
                          value: isSelected,
                          onChanged: (value) =>
                              _toggleSelection(notification.id),
                          activeColor: AppColors.primary,
                        )
                      else if (!notification.isRead &&
                          !notification.showActionButtons)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.notificationDot,
                          ),
                        ),
                    ],
                  ),
                  // Action buttons for follow requests
                  if (notification.showActionButtons &&
                      notification.actionType == 'follow_request' &&
                      notification.followRequestId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _handleRejectFollowRequest(notification),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  _handleAcceptFollowRequest(notification),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
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
    if (_userId == null) return;

    final snapshot = await _service.notificationsStream(_userId!).first;
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

    if (confirmed == true && _userId != null) {
      await _service.deleteNotification(_userId!, notification.id);
      return true;
    }
    return false;
  }

  Future<void> _deleteSelectedNotifications() async {
    if (_userId == null || _selectedNotifications.isEmpty) return;

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
        await _service.deleteNotification(_userId!, notificationId);
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

  Widget _buildNotificationIcon(NotificationType type) {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.success:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case NotificationType.warning:
        icon = Icons.warning_amber_outlined;
        color = Colors.orange;
        break;
      case NotificationType.info:
        icon = Icons.info_outline;
        color = Colors.blue;
        break;
      case NotificationType.alert:
        icon = Icons.notification_important_outlined;
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _handleNotificationNavigation(NotificationModel notification) {
    if (notification.actionType != null && notification.actionData != null) {
      if (notification.actionType == 'post') {
        final postId = notification.actionData!;
        if (mounted) {
          Navigator.pushNamed(context, '/post-detail', arguments: postId);
        }
      } else if (notification.actionType == 'booking') {
        final bookingId = notification.actionData!;
        if (mounted) {
          // Navigate to MainScreen with booking tab selected
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(
                initialTabIndex: 3, // Booking tab
                highlightBookingId: bookingId,
              ),
            ),
            (route) => false,
          );
        }
      }
    } else {
      // Backward compatibility for old notifications
      final bookingTitles = [
        'Booking Approved',
        'Booking Declined',
        'Booking Under Review',
        'Booking Cancelled',
      ];

      if (bookingTitles.any((title) => notification.title.contains(title))) {
        if (mounted) {
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
        }
      }
    }
  }

  Future<void> _handleAcceptFollowRequest(
    NotificationModel notification,
  ) async {
    if (_userId == null || notification.followRequestId == null) return;

    try {
      // Accept the follow request
      await _userService.acceptFollowRequest(
        _userId!,
        notification.followRequestId!,
      );

      // Delete the notification
      await _service.deleteNotification(_userId!, notification.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Follow request accepted'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleRejectFollowRequest(
    NotificationModel notification,
  ) async {
    if (_userId == null || notification.followRequestId == null) return;

    try {
      // Reject the follow request
      await _userService.rejectFollowRequest(
        _userId!,
        notification.followRequestId!,
      );

      // Delete the notification
      await _service.deleteNotification(_userId!, notification.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Follow request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
