import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Interaction stats: likes, comments, shares counts with divider.
class SocialCardStats extends StatelessWidget {
  final int likesCount;
  final int commentsCount;
  final int sharesCount;

  const SocialCardStats({
    super.key,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (likesCount == 0 && commentsCount == 0 && sharesCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          // Divider
          Container(height: 1, color: colors.borderLight),
          const SizedBox(height: 8),

          // Stats row
          Row(
            children: [
              if (likesCount > 0) ...[
                Icon(Icons.favorite, size: 16, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  '$likesCount',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(width: 12),
              ],
              if (commentsCount > 0) ...[
                Icon(Icons.chat_bubble, size: 16, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '$commentsCount',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(width: 12),
              ],
              if (sharesCount > 0) ...[
                Icon(Icons.share, size: 16, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '$sharesCount',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
