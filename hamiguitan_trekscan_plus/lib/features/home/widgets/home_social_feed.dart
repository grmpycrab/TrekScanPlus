import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'package:hamiguitan_trekscan_plus/features/social/models/social_model.dart';
import 'package:hamiguitan_trekscan_plus/features/social/widgets/social_card.dart';
import 'package:hamiguitan_trekscan_plus/features/social/widgets/social_card_skeleton.dart';
import 'package:hamiguitan_trekscan_plus/core/widgets/skeleton_placeholder.dart';
import '../viewmodels/home_view_model.dart';

/// Paginated social feed list. Owns the scroll controller and delegates
/// scroll events and "load next page" calls to [viewModel].
class HomeSocialFeed extends StatefulWidget {
  const HomeSocialFeed({
    super.key,
    required this.viewModel,
    required this.searchQuery,
    required this.onShowComments,
    required this.onDeletePost,
  });

  final HomeViewModel viewModel;
  final String searchQuery;
  final void Function(SocialPost) onShowComments;
  final void Function(SocialPost) onDeletePost;

  @override
  State<HomeSocialFeed> createState() => _HomeSocialFeedState();
}

class _HomeSocialFeedState extends State<HomeSocialFeed> {
  static const _greyAnim = AlwaysStoppedAnimation<Color>(Colors.grey);

  late final ScrollController _scrollController;

  List<SocialPost> _filteredPosts = const [];
  List<SocialPost>? _lastLoadedPosts;
  String? _lastQuery;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _recomputeFilteredPosts();
  }

  @override
  void didUpdateWidget(HomeSocialFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recomputeFilteredPosts();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() => widget.viewModel.onFeedScroll(_scrollController);

  void _recomputeFilteredPosts() {
    final posts = widget.viewModel.loadedPosts;
    final q = widget.searchQuery;
    if (identical(posts, _lastLoadedPosts) && q == _lastQuery) return;
    _lastLoadedPosts = posts;
    _lastQuery = q;
    _filteredPosts = q.isEmpty
        ? posts
        : posts
              .where(
                (p) =>
                    p.caption.toLowerCase().contains(q) ||
                    p.userName.toLowerCase().contains(q),
              )
              .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = widget.viewModel;

    // ── Not signed in ────────────────────────────────────────────────────────
    if (vm.firebaseUser == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Sign in to view posts')),
      );
    }

    // ── Initial loading ──────────────────────────────────────────────────────
    if (vm.loadedPosts.isEmpty && vm.isLoadingMore) {
      return SkeletonShimmer(
        child: ListView(
          padding: const EdgeInsets.only(top: 4),
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            SocialCardSkeleton(),
            SocialCardSkeleton(),
            SocialCardSkeleton(),
          ],
        ),
      );
    }

    // ── Empty state (first page returned 0 posts) ────────────────────────────
    if (vm.loadedPosts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            widget.searchQuery.isNotEmpty
                ? 'No posts found for "${widget.searchQuery}"'
                : 'No posts yet. Be the first to share your experience!',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    final posts = _filteredPosts;
    // itemCount layout:
    //  0 → "Community Feed" header
    //  1 … posts.length → post cards (or "no results" if posts is empty)
    //  posts.length + 1 → load-more / end-of-feed footer
    final itemCount = 1 + (posts.isEmpty ? 1 : posts.length) + 1;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 4, bottom: 30),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // ── Header ──────────────────────────────────────────────────────────
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: [
                const Text(
                  'Community Feed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (vm.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: _greyAnim,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        // ── No search results ────────────────────────────────────────────────
        if (posts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'No posts found for "${widget.searchQuery}"',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          );
        }

        // ── Footer ───────────────────────────────────────────────────────────
        if (index == posts.length + 1) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: vm.isLoadingMore
                  ? const CircularProgressIndicator()
                  : vm.hasMorePosts
                  ? ElevatedButton(
                      onPressed: () => vm.loadNextPage(),
                      child: const Text('Load More Posts'),
                    )
                  : _EndOfFeedCard(),
            ),
          );
        }

        // ── Post card ────────────────────────────────────────────────────────
        final post = posts[index - 1];
        return SocialCard(
          key: ValueKey(post.id ?? index),
          post: post,
          onCommentTap: () => widget.onShowComments(post),
          onDelete: () => widget.onDeletePost(post),
        );
      },
    );
  }
}

class _EndOfFeedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sentiment_satisfied_alt,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            "You've reached the end!",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Share your Hamiguitan adventure to inspire others',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
