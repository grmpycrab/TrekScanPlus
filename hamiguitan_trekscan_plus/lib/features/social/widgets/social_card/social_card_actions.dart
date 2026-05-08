import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Action buttons with inline stats: like, comment, share, bookmark.
class SocialCardActions extends StatelessWidget {
  final bool isLiked;
  final bool isBookmarked;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onBookmarkTap;

  const SocialCardActions({
    super.key,
    required this.isLiked,
    required this.isBookmarked,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onBookmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          // Divider above actions
          Container(
            height: 1.5,
            color: colors.borderLight.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),

          // Action buttons with inline counts
          Row(
            children: [
              // Like button with count
              _ActionButtonWithCount(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : colors.textSecondary,
                count: likesCount,
                onTap: onLikeTap,
              ),
              const SizedBox(width: 16),
              //this is a test for clockify if it really tracks the visual studio app.

              // Comment button with count
              _ActionButtonWithCount(
                icon: Icons.chat_bubble_outline_rounded,
                color: colors.textSecondary,
                count: commentsCount,
                onTap: onCommentTap,
              ),
              const SizedBox(width: 16),

              // Share button with count
              _ActionButtonWithCount(
                icon: Icons.share_outlined,
                color: colors.textSecondary,
                count: sharesCount,
                onTap: onShareTap,
              ),

              const Spacer(),

              // Bookmark button (no count)
              _ActionButton(
                icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: isBookmarked ? colors.primary : colors.textSecondary,
                onTap: onBookmarkTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Action button with inline count display.
class _ActionButtonWithCount extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _ActionButtonWithCount({
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          IconButton(
            icon: Icon(icon, color: color, size: 24),
            onPressed: onTap,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Individual action button (no count).
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: 24),
      onPressed: onTap,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(8),
    );
  }
}
