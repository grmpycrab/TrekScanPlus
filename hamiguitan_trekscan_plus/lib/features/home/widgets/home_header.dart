import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/profile_avatar_with_status.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/services/user_service.dart';
import '../../../theme/app_theme.dart';

/// Top app-bar row: greeting/avatar on the left, hamburger menu on the right.
///
/// Tapping the avatar/greeting navigates to the profile screen via [onProfileTap].
/// Tapping the hamburger opens the end drawer via [onMenuTap].
/// An unread-notification dot appears on the hamburger when there are unread items.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.userId,
    required this.userPhotoUrl,
    required this.onProfileTap,
    required this.onMenuTap,
  });

  final String? userId;
  final String? userPhotoUrl;
  final VoidCallback onProfileTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colors.surface,
      child: Row(
        children: [
          Expanded(child: _buildGreeting(context)),
          _buildMenuButton(context),
        ],
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final colors = context.colors;

    if (userId == null) {
      return GestureDetector(
        onTap: onProfileTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colors.primary,
              child: const Icon(Icons.person, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome,',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const Text(
                  'Traveler!',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onProfileTap,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: UserService.instance.streamUser(userId!),
        builder: (context, snapshot) {
          String firstName = '';
          String lastName = '';
          if (snapshot.hasData && snapshot.data != null) {
            final data = snapshot.data!.data() ?? {};
            firstName = data['firstName'] ?? '';
            lastName = data['lastName'] ?? '';
          }
          if (firstName.isEmpty && lastName.isEmpty) firstName = 'Traveler';

          return Row(
            children: [
              ProfileAvatarWithStatus(
                userId: userId!,
                photoUrl: userPhotoUrl,
                radius: 20,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome,',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      firstName.isNotEmpty
                          ? '$firstName ${lastName.isNotEmpty ? lastName : ''}'
                                .trim()
                          : 'Traveler!',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    StreamBuilder<bool>(
                      stream: PresenceService.instance.userOnlineStatus(
                        userId!,
                      ),
                      builder: (context, snap) {
                        final isOnline = snap.data ?? false;
                        return Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: isOnline ? Colors.green : Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.menu, color: colors.text, size: 26),
          onPressed: onMenuTap,
          tooltip: 'Open menu',
        ),
        if (userId != null)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('notifications')
                .where('isRead', isEqualTo: false)
                .limit(1)
                .snapshots(),
            builder: (context, snapshot) {
              final hasUnread =
                  snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              if (!hasUnread) return const SizedBox.shrink();
              return Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
