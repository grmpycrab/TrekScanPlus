// ignore_for_file: use_build_context_synchronously
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/social_model.dart';
import '../viewmodels/single_post_view_model.dart';
import '../widgets/comment_thread.dart';
import '../widgets/image_viewer.dart';
import '../widgets/post_options_sheet.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../core/services/user_service.dart';
import '../../../core/widgets/app_dialogue_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────

class SinglePostViewer extends StatefulWidget {
  final String postId;

  /// When supplied (e.g. navigating from the feed), post text and media render
  /// instantly without a loading spinner. A silent background fetch still
  /// refreshes live counts.
  final SocialPost? initialPostData;

  const SinglePostViewer({
    super.key,
    required this.postId,
    this.initialPostData,
  });

  @override
  State<SinglePostViewer> createState() => _SinglePostViewerState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class _SinglePostViewerState extends State<SinglePostViewer> {
  late final SinglePostViewModel _vm;
  late final TextEditingController _inputController;
  late final FocusNode _inputFocus;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _vm = SinglePostViewModel()
      ..addListener(_onVmChanged)
      ..initialize(
        postId: widget.postId,
        initialPostData: widget.initialPostData,
      );
    _inputController = TextEditingController();
    _inputFocus = FocusNode();
    _scrollController = ScrollController();
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm
      ..removeListener(_onVmChanged)
      ..dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _openImageViewer(int index) {
    final urls = _vm.post?.imageUrls ?? [];
    if (urls.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewer(
          imageUrls: urls,
          post: _vm.post!,
          initialIndex: index,
        ),
      ),
    );
  }

  Future<void> _navigateToAuthorProfile() async {
    final post = _vm.post;
    if (post == null) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid == post.userId) return;
    if (currentUser == null) return;

    try {
      final following = await UserService.instance.isFollowing(
        currentUser.uid,
        post.userId,
      );
      if (!following) {
        AppDialogueHandler.showAlert(
          context: context,
          title: 'Profile Access Restricted',
          message:
              'You and this person don\'t follow each other. '
              'You can only view profiles of people you follow.',
          buttonText: 'OK',
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: post.userId),
        ),
      );
    } catch (_) {}
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _handleLike() async {
    try {
      await _vm.handleLike();
    } catch (e) {
      _showSnack('Failed to like post: $e');
    }
  }

  Future<void> _handleBookmark() async {
    try {
      await _vm.handleBookmark();
      _showSnack(
        _vm.isBookmarked ? 'Added to favorites' : 'Removed from favorites',
      );
    } catch (e) {
      _showSnack('Failed to bookmark: $e');
    }
  }

  Future<void> _handleShare() async {
    final post = _vm.post;
    if (post?.id == null) return;
    try {
      final link = 'https://trekscanplus.app/posts/${post!.id}';
      await Share.share(
        '${post.caption}\n\n$link\n\n🏔️ Check out this post on TrekScanPlus!',
        subject: 'TrekScanPlus Post',
      );
      await _vm.handleShare();
    } catch (e) {
      _showSnack('Failed to share: $e');
    }
  }

  Future<void> _handleFollow() async {
    try {
      await _vm.handleFollow();
    } catch (e) {
      _showSnack('Failed to update follow: $e');
    }
  }

  Future<void> _submitComment() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    try {
      await _vm.submitComment(postId: widget.postId, text: text);
    } catch (e) {
      _showSnack('Failed to post comment: $e');
    }
  }

  void _focusCommentInput() => _inputFocus.requestFocus();

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showOptions() {
    final post = _vm.post;
    if (post == null) return;
    PostOptionsSheet.show(
      context: context,
      postUserId: post.userId,
      onEdit: () {/* edit handled via SocialCard in feed; no-op here */},
      onDelete: () => Navigator.of(context).pop(),
      onReport: () => _showSnack('Report submitted'),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // ── Error / not-found state ─────────────────────────────────────────────
    if (_vm.postError != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Post'),
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _vm.postError!,
                style: TextStyle(fontSize: 16, color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(child: _buildScrollView(colors)),
          // Input bar isolated in its own RepaintBoundary — changes here
          // never trigger repaints in the comment SliverList above.
          RepaintBoundary(child: _CommentInputBar(
            controller: _inputController,
            focusNode: _inputFocus,
            isSubmitting: _vm.isSubmittingComment,
            replyingToUserName: _vm.replyingToUserName,
            onClearReply: _vm.clearReplyingTo,
            onSubmit: _submitComment,
          )),
        ],
      ),
    );
  }

  Widget _buildScrollView(AppTheme colors) {
    final post = _vm.post;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        // ── App bar ─────────────────────────────────────────────────────────
        SliverAppBar(
          pinned: true,
          backgroundColor: colors.surface,
          foregroundColor: colors.text,
          elevation: 0.5,
          title: Text(
            'Post',
            style: TextStyle(
              color: colors.text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: colors.text, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (post != null)
              IconButton(
                icon: Icon(Icons.more_horiz, color: colors.text),
                onPressed: _showOptions,
              ),
          ],
        ),

        // ── Post content (header + caption + media) ──────────────────────────
        SliverToBoxAdapter(
          child: post == null
              ? _vm.isLoadingPost
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink()
              : _PostContent(
                  post: post,
                  displayName: _vm.displayName,
                  isFollowing: _vm.isFollowing,
                  isPending: _vm.isPending,
                  isOwnPost: _vm.isOwnPost,
                  onFollowTap: _handleFollow,
                  onAuthorTap: _navigateToAuthorProfile,
                  onImageTap: _openImageViewer,
                ),
        ),

        // ── Pinned reaction bar ──────────────────────────────────────────────
        if (post != null)
          SliverPersistentHeader(
            pinned: true,
            delegate: _ReactionBarDelegate(
              isLiked: _vm.isLiked,
              isBookmarked: _vm.isBookmarked,
              likesCount: _vm.likesCount,
              commentsCount: _vm.commentsCount,
              sharesCount: _vm.sharesCount,
              surfaceColor: colors.surface,
              borderColor: colors.borderLight,
              textSecondaryColor: colors.textSecondary,
              primaryColor: colors.primary,
              onLike: _handleLike,
              onComment: _focusCommentInput,
              onShare: _handleShare,
              onBookmark: _handleBookmark,
            ),
          ),

        // ── Comments header ──────────────────────────────────────────────────
        if (post != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                'Comments',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ),
          ),

        // ── Infinite comment stream ──────────────────────────────────────────
        if (post != null)
          StreamBuilder<List<Comment>>(
            stream: _vm.commentsStream(widget.postId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  _vm.commentsStream(widget.postId).isBroadcast == false) {
                // Only show a single spinner tile while cold-starting
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (snap.hasError) {
                AppLogger.e('[SinglePostViewer] comment stream: ${snap.error}');
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load comments.',
                      style: TextStyle(color: colors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final merged = _vm.mergeComments(snap.data ?? []);

              if (merged.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No comments yet.\nBe the first to comment!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final comment = merged[index];
                    // Optimistic items have no persistent id; mark them visually.
                    final isOptimistic =
                        comment.id?.startsWith('_opt_') == true;
                    return Opacity(
                      opacity: isOptimistic ? 0.6 : 1.0,
                      child: CommentThread(
                        key: ValueKey(comment.id ?? 'comment_$index'),
                        postId: widget.postId,
                        comment: comment,
                        onReplyTap: (commentId, userName) {
                          _vm.setReplyingTo(commentId, userName);
                          _focusCommentInput();
                        },
                      ),
                    );
                  },
                  childCount: merged.length,
                  // Widgets outside the viewport are recycled immediately —
                  // no implicit KeepAlive wrappers needed for a comment list.
                  addAutomaticKeepAlives: false,
                ),
              );
            },
          ),

        // Bottom breathing room
        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post content (inside SliverToBoxAdapter)
// ─────────────────────────────────────────────────────────────────────────────

class _PostContent extends StatelessWidget {
  final SocialPost post;
  final String displayName;
  final bool isFollowing;
  final bool isPending;
  final bool isOwnPost;
  final VoidCallback onFollowTap;
  final VoidCallback onAuthorTap;
  final void Function(int index) onImageTap;

  const _PostContent({
    required this.post,
    required this.displayName,
    required this.isFollowing,
    required this.isPending,
    required this.isOwnPost,
    required this.onFollowTap,
    required this.onAuthorTap,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PostHeader(
          post: post,
          displayName: displayName,
          isFollowing: isFollowing,
          isPending: isPending,
          isOwnPost: isOwnPost,
          onFollowTap: onFollowTap,
          onAuthorTap: onAuthorTap,
          colors: colors,
        ),
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              post.caption,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colors.text,
              ),
            ),
          ),
        if (post.imageUrls.isNotEmpty)
          _PostMediaGrid(
            imageUrls: post.imageUrls,
            onImageTap: onImageTap,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post header row (avatar + meta + follow chip)
// ─────────────────────────────────────────────────────────────────────────────

class _PostHeader extends StatelessWidget {
  final SocialPost post;
  final String displayName;
  final bool isFollowing;
  final bool isPending;
  final bool isOwnPost;
  final VoidCallback onFollowTap;
  final VoidCallback onAuthorTap;
  final AppTheme colors;

  const _PostHeader({
    required this.post,
    required this.displayName,
    required this.isFollowing,
    required this.isPending,
    required this.isOwnPost,
    required this.onFollowTap,
    required this.onAuthorTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel = _timeAgo(post.createdAt.toDate());
    final privacyIcon = _privacyIcon(post.privacy);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar — memCacheWidth: 250 caps GPU texture upload size.
          GestureDetector(
            onTap: onAuthorTap,
            child: ClipOval(
              child: post.userPhotoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: post.userPhotoUrl!,
                      width: 42,
                      height: 42,
                      memCacheWidth: 250,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _avatarFallback(),
                      errorWidget: (_, __, ___) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
          const SizedBox(width: 12),
          // Name + timestamp row
          Expanded(
            child: GestureDetector(
              onTap: onAuthorTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Text('·',
                            style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary)),
                      ),
                      Icon(privacyIcon,
                          size: 13, color: colors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Follow chip — hidden for own posts
          if (!isOwnPost)
            GestureDetector(
              onTap: onFollowTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isFollowing
                      ? colors.background
                      : isPending
                          ? colors.surfaceVariant
                          : colors.primary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isFollowing
                        ? colors.border
                        : isPending
                            ? colors.border
                            : colors.primary,
                    width: 1,
                  ),
                ),
                child: Text(
                  isFollowing
                      ? 'Following'
                      : isPending
                          ? 'Pending'
                          : 'Follow',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isFollowing || isPending
                        ? colors.textSecondary
                        : Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Container(
        width: 42,
        height: 42,
        color: Colors.grey.shade300,
        child: const Icon(Icons.person, size: 24, color: Colors.white),
      );

  IconData _privacyIcon(PostPrivacy p) {
    switch (p) {
      case PostPrivacy.public:
        return Icons.public;
      case PostPrivacy.followers:
        return Icons.people;
      case PostPrivacy.private:
        return Icons.lock;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Media grid — memCacheHeight: 800 limits GPU texture bloat for tall images
// ─────────────────────────────────────────────────────────────────────────────

class _PostMediaGrid extends StatelessWidget {
  final List<String> imageUrls;
  final void Function(int index) onImageTap;

  const _PostMediaGrid({
    required this.imageUrls,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = imageUrls.length.clamp(1, 4);
    if (count == 1) return _single();
    if (count == 2) return _double();
    if (count == 3) return _triple();
    return _quad();
  }

  Widget _tile(int index, {BoxFit fit = BoxFit.cover}) {
    return GestureDetector(
      onTap: () => onImageTap(index),
      child: CachedNetworkImage(
        imageUrl: imageUrls[index],
        fit: fit,
        memCacheHeight: 800,
        placeholder: (_, __) =>
            Container(color: Colors.grey.shade200),
        errorWidget: (_, __, ___) =>
            Container(color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image)),
      ),
    );
  }

  Widget _single() => AspectRatio(
        aspectRatio: 4 / 3,
        child: _tile(0),
      );

  Widget _double() => SizedBox(
        height: 220,
        child: Row(
          children: [
            Expanded(child: _tile(0)),
            const SizedBox(width: 2),
            Expanded(child: _tile(1)),
          ],
        ),
      );

  Widget _triple() => SizedBox(
        height: 280,
        child: Column(
          children: [
            Expanded(child: _tile(0)),
            const SizedBox(height: 2),
            SizedBox(
              height: 130,
              child: Row(
                children: [
                  Expanded(child: _tile(1)),
                  const SizedBox(width: 2),
                  Expanded(child: _tile(2)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _quad() => SizedBox(
        height: 280,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(0)),
                  const SizedBox(width: 2),
                  Expanded(child: _tile(1)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(2)),
                  const SizedBox(width: 2),
                  Expanded(child: _tile(3)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned reactions bar — SliverPersistentHeaderDelegate
// ─────────────────────────────────────────────────────────────────────────────

class _ReactionBarDelegate extends SliverPersistentHeaderDelegate {
  final bool isLiked;
  final bool isBookmarked;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final Color surfaceColor;
  final Color borderColor;
  final Color textSecondaryColor;
  final Color primaryColor;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  const _ReactionBarDelegate({
    required this.isLiked,
    required this.isBookmarked,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.surfaceColor,
    required this.borderColor,
    required this.textSecondaryColor,
    required this.primaryColor,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onBookmark,
  });

  static const double _height = 52.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_ReactionBarDelegate old) =>
      old.isLiked != isLiked ||
      old.isBookmarked != isBookmarked ||
      old.likesCount != likesCount ||
      old.commentsCount != commentsCount ||
      old.sharesCount != sharesCount ||
      old.surfaceColor != surfaceColor;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: _height,
      color: surfaceColor,
      foregroundDecoration: overlapsContent
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 0.8),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _ReactionBtn(
              icon: isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : textSecondaryColor,
              count: likesCount,
              onTap: onLike,
              textColor: textSecondaryColor,
            ),
            _ReactionBtn(
              icon: Icons.chat_bubble_outline_rounded,
              color: textSecondaryColor,
              count: commentsCount,
              onTap: onComment,
              textColor: textSecondaryColor,
            ),
            _ReactionBtn(
              icon: Icons.share_outlined,
              color: textSecondaryColor,
              count: sharesCount,
              onTap: onShare,
              textColor: textSecondaryColor,
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: isBookmarked ? primaryColor : textSecondaryColor,
                size: 22,
              ),
              onPressed: onBookmark,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _ReactionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;
  final Color textColor;

  const _ReactionBtn({
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comment input bar — isolated in RepaintBoundary by the parent
// ─────────────────────────────────────────────────────────────────────────────

class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final String? replyingToUserName;
  final VoidCallback onClearReply;
  final VoidCallback onSubmit;

  const _CommentInputBar({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.replyingToUserName,
    required this.onClearReply,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderLight, width: 0.8)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reply-to context chip
          if (replyingToUserName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 13, color: colors.primary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Replying to $replyingToUserName',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: onClearReply,
                    child: Icon(Icons.close, size: 15,
                        color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          // Text field + send button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !isSubmitting,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(fontSize: 14, color: colors.text),
                  decoration: InputDecoration(
                    hintText: replyingToUserName != null
                        ? 'Write a reply...'
                        : 'Write a comment...',
                    hintStyle:
                        TextStyle(fontSize: 14, color: colors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          BorderSide(color: colors.primary, width: 1.5),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: colors.inputFill,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                child: isSubmitting
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                        onPressed: onSubmit,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
