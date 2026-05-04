import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../components/profile_avatar_with_status.dart';
import '../../../services/presence_service.dart';
import '../../../services/user_service.dart';
import '../../../theme/color.dart';
import '../../../screens/main/notification_screen.dart';

/// Top app-bar row: greeting / avatar, search field, notifications bell.
///
/// Stateless data inputs; state (expanded search, query text) is owned by
/// the parent via [isSearchExpanded], [searchController], [searchFocusNode]
/// and [searchQuery].
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.userId,
    required this.userPhotoUrl,
    required this.isSearchExpanded,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchQuery,
    required this.onToggleSearch,
    required this.onProfileTap,
  });

  final String? userId;
  final String? userPhotoUrl;
  final bool isSearchExpanded;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final String searchQuery;
  final VoidCallback onToggleSearch;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isSearchExpanded) _buildGreeting(context),
          if (isSearchExpanded)
            Expanded(
              child: TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search posts and users...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    if (userId == null) {
      return Expanded(
        child: GestureDetector(
          onTap: onProfileTap,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome,',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Traveler!',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: onProfileTap,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: UserService.instance.streamUser(userId!),
          builder: (context, snapshot) {
            String firstName = '';
            String lastName = '';

            if (snapshot.hasData && snapshot.data != null) {
              final userData = snapshot.data!.data() ?? {};
              firstName = userData['firstName'] ?? '';
              lastName = userData['lastName'] ?? '';
            }

            if (firstName.isEmpty && lastName.isEmpty) {
              firstName = 'Traveler';
            }

            return Row(
              children: [
                ProfileAvatarWithStatus(
                  userId: userId!,
                  photoUrl: userPhotoUrl,
                  radius: 20,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome,',
                        style: TextStyle(
                          color: AppColors.textSecondary,
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
                        builder: (context, snapshot) {
                          final isOnline = snapshot.data ?? false;
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
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        // Search toggle
        IconButton(
          icon: isSearchExpanded
              ? Icon(Icons.close, size: 20, color: AppColors.primary)
              : Image.asset(
                  'assets/icons/search.png',
                  width: 20,
                  height: 20,
                  color: searchQuery.isNotEmpty
                      ? AppColors.primary
                      : Colors.black,
                ),
          tooltip: isSearchExpanded ? 'Close search' : 'Search posts',
          onPressed: onToggleSearch,
        ),
        // Notifications bell (hidden during search)
        if (!isSearchExpanded) _buildNotificationBell(context),
      ],
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: Image.asset(
            'assets/icons/bell.png',
            width: 20,
            height: 20,
            color: Colors.black,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationScreen()),
          ),
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
              return hasUnread
                  ? const Positioned(
                      right: 12,
                      top: 12,
                      child: SizedBox(
                        width: 8,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.notificationDot,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
      ],
    );
  }
}
