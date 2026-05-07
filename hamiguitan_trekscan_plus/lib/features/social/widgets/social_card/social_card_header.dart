import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/social_model.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/widgets/profile_avatar_with_status.dart';

/// Header section: avatar, name, timestamp, follow button, more menu.
class SocialCardHeader extends StatelessWidget {
  final String userId;
  final String displayName;
  final String? userPhotoUrl;
  final DateTime createdAt;
  final PostPrivacy privacy;
  final bool isFollowing;
  final bool isPending;
  final bool isOwnPost;

  final VoidCallback onFollowTap;
  final VoidCallback onMoreTap;
  final VoidCallback onUserTap;

  const SocialCardHeader({
    super.key,
    required this.userId,
    required this.displayName,
    this.userPhotoUrl,
    required this.createdAt,
    required this.privacy,
    required this.isFollowing,
    required this.isPending,
    required this.isOwnPost,
    required this.onFollowTap,
    required this.onMoreTap,
    required this.onUserTap,
  });

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  IconData _getPrivacyIcon(PostPrivacy privacy) {
    switch (privacy) {
      case PostPrivacy.public:
        return Icons.public;
      case PostPrivacy.followers:
        return Icons.people;
      case PostPrivacy.private:
        return Icons.lock;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onUserTap,
            child: ProfileAvatarWithStatus(
              userId: userId,
              photoUrl: userPhotoUrl,
              radius: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onUserTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _getTimeAgo(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      Icon(
                        _getPrivacyIcon(privacy),
                        size: 14,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!isOwnPost)
            GestureDetector(
              onTap: onFollowTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isFollowing
                      ? colors.background
                      : isPending
                      ? colors.surfaceVariant
                      : colors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isFollowing
                      ? 'Following'
                      : isPending
                      ? 'Pending'
                      : 'Follow',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isFollowing
                        ? colors.textSecondary
                        : isPending
                        ? colors.text
                        : Colors.white,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.more_horiz, size: 22, color: colors.textSecondary),
            onPressed: onMoreTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
