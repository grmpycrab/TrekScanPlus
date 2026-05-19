import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/social_model.dart';
import '../repositories/social_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/status_helpers.dart';
import '../../../utils/app_logger.dart';

/// Displays all posts created by the current user with their moderation
/// status (Pending / Approved / Declined) and, for declined posts, the
/// moderator rejection note. Reachable via the '/my-posts' route.
class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = SocialRepository.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          indicatorColor: colors.primary,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Declined'),
          ],
        ),
      ),
      body: StreamBuilder<List<SocialPost>>(
        stream: _repo.streamMyPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            AppLogger.e('MyPostsScreen error: ${snapshot.error}');
            return const Center(child: Text('Failed to load posts.'));
          }

          final all = snapshot.data ?? [];
          final pending =
              all.where((p) => p.status == PostStatus.pending).toList();
          final approved =
              all.where((p) => p.status == PostStatus.approved).toList();
          final declined =
              all.where((p) => p.status == PostStatus.declined).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _PostList(posts: pending, emptyMessage: 'No posts pending review.'),
              _PostList(posts: approved, emptyMessage: 'No approved posts yet.'),
              _PostList(
                posts: declined,
                emptyMessage: 'No declined posts.',
                showModeratorNote: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PostList extends StatelessWidget {
  const _PostList({
    required this.posts,
    required this.emptyMessage,
    this.showModeratorNote = false,
  });

  final List<SocialPost> posts;
  final String emptyMessage;
  final bool showModeratorNote;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _PostCard(
        post: posts[index],
        showModeratorNote: showModeratorNote,
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, this.showModeratorNote = false});

  final SocialPost post;
  final bool showModeratorNote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = PostStatusHelper.color(post.status.name);
    final statusIcon = PostStatusHelper.icon(post.status.name);
    final statusLabel = PostStatusHelper.label(post.status.name);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status chip row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(post.createdAt.toDate()),
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Caption
            Text(
              post.caption,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),

            // Thumbnail strip
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.imageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrls[i],
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey.shade200,
                        width: 70,
                        height: 70,
                      ),
                      errorWidget: (_, __, ___) =>
                          Container(color: Colors.grey.shade300, width: 70),
                    ),
                  ),
                ),
              ),
            ],

            // Moderator note for declined posts
            if (showModeratorNote && post.moderatorNote != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment_outlined,
                            size: 14, color: Colors.red.shade700),
                        const SizedBox(width: 5),
                        Text(
                          'Moderator Note',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.moderatorNote!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
