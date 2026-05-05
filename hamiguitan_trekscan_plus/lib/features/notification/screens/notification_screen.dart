import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../screens/main/main_screen.dart';
import '../../../core/widgets/app_dialogue_handler.dart';
import '../models/notification_model.dart';
import '../viewmodels/notification_view_model.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final NotificationViewModel _vm;
  bool _isSelectionMode = false;
  final Set<String> _selectedNotifications = {};

  @override
  void initState() {
    super.initState();
    _vm = NotificationViewModel();
    _vm.addListener(_onVmChanged);
  }

  void _onVmChanged() {
    if (!mounted) return;
    if (_vm.deleteError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_vm.deleteError!), backgroundColor: Colors.red),
      );
      _vm.clearDeleteError();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final userId = _vm.currentUserId;

    return Scaffold(
      backgroundColor: colors.background,
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
                  child: Text(
                    'Select all',
                    style: TextStyle(
                      color: colors.primary,
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
                    if (userId == null) return;
                    await _vm.markAllAsRead(userId);
                    setState(() {});
                  },
                  child: Text(
                    'Mark all as read',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
      ),
      body: userId == null
          ? _buildEmptyState(message: 'Please sign in to see notifications')
          : StreamBuilder<List<NotificationModel>>(
              stream: _vm.notificationsStream(userId),
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
    final colors = context.colors;
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
              color: colors.textSecondary,
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
    final colors = context.colors;
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
              ? colors.primary.withValues(alpha: 0.1)
              : (notification.isRead ? Colors.white : const Color(0xFFF5F9FF)),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: colors.primary, width: 2)
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
                          final uid = _vm.currentUserId;
                          if (uid != null) {
                            await _vm.markAsRead(uid, notification.id);
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
                                color: colors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _vm.formatTimestamp(notification.timestamp),
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
                          activeColor: colors.primary,
                        )
                      else if (!notification.isRead &&
                          !notification.showActionButtons)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
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
                                backgroundColor: colors.primary,
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
    final uid = _vm.currentUserId;
    if (uid == null) return;
    final snapshot = await _vm.notificationsStream(uid).first;
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
    final uid = _vm.currentUserId;
    if (confirmed == true && uid != null) {
      await _vm.deleteNotification(uid, notification.id);
      return true;
    }
    return false;
  }

  Future<void> _deleteSelectedNotifications() async {
    final uid = _vm.currentUserId;
    if (uid == null || _selectedNotifications.isEmpty) return;

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
      await _vm.deleteSelected(uid, Set.from(_selectedNotifications));
      if (mounted && _vm.deleteError == null) {
        setState(() {
          _selectedNotifications.clear();
          _isSelectionMode = false;
        });
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
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MainScreen(initialTabIndex: 3, highlightBookingId: bookingId),
            ),
            (route) => false,
          );
        }
      }
    } else {
      final bookingTitles = [
        'Booking Approved',
        'Booking Declined',
        'Booking Under Review',
        'Booking Cancelled',
      ];

      if (bookingTitles.any((title) => notification.title.contains(title))) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const MainScreen(initialTabIndex: 3),
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
    final uid = _vm.currentUserId;
    if (uid == null || notification.followRequestId == null) return;

    try {
      await _vm.acceptFollowRequest(
        uid,
        notification.followRequestId!,
        notification.id,
      );
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
    final uid = _vm.currentUserId;
    if (uid == null || notification.followRequestId == null) return;

    try {
      await _vm.rejectFollowRequest(
        uid,
        notification.followRequestId!,
        notification.id,
      );
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
