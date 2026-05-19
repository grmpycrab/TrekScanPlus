import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/social_model.dart';
import '../repositories/social_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/status_helpers.dart';
import '../../../utils/app_logger.dart';

/// Centralized Post Status Management screen.
/// Shows the current user's posts grouped by moderation status.
/// Accessible via the '/my-posts' route.
class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final _repo = SocialRepository.instance;
  PostStatus _selected = PostStatus.pending;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colors),
            Expanded(
              child: StreamBuilder<List<SocialPost>>(
                stream: _repo.streamMyPosts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    );
                  }
                  if (snapshot.hasError) {
                    AppLogger.e('MyPostsScreen error: ${snapshot.error}');
                    return Center(
                      child: Text(
                        'Failed to load posts.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    );
                  }

                  final all = snapshot.data ?? [];
                  final pending =
                      all.where((p) => p.status == PostStatus.pending).toList();
                  final approved =
                      all.where((p) => p.status == PostStatus.approved).toList();
                  final declined =
                      all.where((p) => p.status == PostStatus.declined).toList();

                  final counts = {
                    PostStatus.pending: pending.length,
                    PostStatus.approved: approved.length,
                    PostStatus.declined: declined.length,
                  };

                  final current = switch (_selected) {
                    PostStatus.pending => pending,
                    PostStatus.approved => approved,
                    PostStatus.declined => declined,
                  };

                  return Column(
                    children: [
                      _buildFilterRow(counts, colors),
                      Expanded(
                        child: _PostList(
                          key: ValueKey(_selected),
                          posts: current,
                          status: _selected,
                          onDelete: (post) => _confirmDelete(post),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppTheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border, width: 0.8)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
            color: colors.text,
          ),
          Expanded(
            child: Text(
              'Post Status',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildFilterRow(Map<PostStatus, int> counts, AppTheme colors) {
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: PostStatus.values.map((status) {
          final isActive = _selected == status;
          final color = PostStatusHelper.color(status.name);
          final label = PostStatusHelper.label(status.name);
          final count = counts[status] ?? 0;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selected = status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? color.withAlpha(25) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? color : colors.border,
                    width: isActive ? 1.5 : 0.8,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isActive ? color : colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isActive ? color : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _confirmDelete(SocialPost post) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Post', style: TextStyle(color: colors.text)),
        content: Text(
          'This post will be permanently removed.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.deletePost(post.id!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------

class _PostList extends StatelessWidget {
  const _PostList({
    super.key,
    required this.posts,
    required this.status,
    required this.onDelete,
  });

  final List<SocialPost> posts;
  final PostStatus status;
  final ValueChanged<SocialPost> onDelete;

  String get _emptyMessage => switch (status) {
    PostStatus.pending => 'No posts pending review.',
    PostStatus.approved => 'No approved posts yet.',
    PostStatus.declined => 'No declined posts.',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              switch (status) {
                PostStatus.pending => Icons.hourglass_empty_rounded,
                PostStatus.approved => Icons.check_circle_outline_rounded,
                PostStatus.declined => Icons.cancel_outlined,
              },
              size: 48,
              color: colors.textSecondary.withAlpha(80),
            ),
            const SizedBox(height: 12),
            Text(
              _emptyMessage,
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _PostCard(
        post: posts[i],
        onDelete: () => onDelete(posts[i]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PostCard extends StatefulWidget {
  const _PostCard({required this.post, required this.onDelete});

  final SocialPost post;
  final VoidCallback onDelete;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _noteExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final post = widget.post;
    final statusColor = PostStatusHelper.color(post.status.name);
    final statusIcon = PostStatusHelper.icon(post.status.name);
    final statusLabel = PostStatusHelper.label(post.status.name);
    final isDeclined = post.status == PostStatus.declined;
    final hasNote = isDeclined && post.moderatorNote != null;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withAlpha(70)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(post.createdAt.toDate()),
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
          ),

          // ── Caption ───────────────────────────────────────────────────
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(
                post.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: colors.text, height: 1.4),
              ),
            ),

          // ── Image thumbnails ──────────────────────────────────────────
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: post.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrls[i],
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: colors.border, width: 72, height: 72),
                    errorWidget: (_, __, ___) =>
                        Container(color: colors.border, width: 72, height: 72),
                  ),
                ),
              ),
            ),
          ],

          // ── Moderator note (declined) ─────────────────────────────────
          if (hasNote) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _noteExpanded = !_noteExpanded),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Moderator Note',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _noteExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Colors.red.shade400,
                          ),
                        ],
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: _noteExpanded
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                              child: Text(
                                post.moderatorNote!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red.shade900,
                                  height: 1.45,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Footer: delete action ─────────────────────────────────────
          if (post.status != PostStatus.approved) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 15, color: Colors.red.shade400),
                        const SizedBox(width: 4),
                        Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
