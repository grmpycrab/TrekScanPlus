// ignore_for_file: use_key_in_widget_constructors, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/social_model.dart';
import '../viewmodels/post_view_model.dart';
import '../../../core/services/user_service.dart';
import '../../../theme/app_theme.dart';
import '../../profile/screens/profile_screen.dart';
import 'comments_sheet.dart';
import 'post_options_sheet.dart';
import 'image_viewer.dart';
import '../../../core/widgets/profile_avatar_with_status.dart';
import '../../../core/widgets/app_dialogue_handler.dart';
import '../../../utils/app_logger.dart';

class SocialCard extends StatefulWidget {
  final SocialPost post;
  final VoidCallback? onCommentTap;
  final VoidCallback? onDelete;

  const SocialCard({
    super.key,
    required this.post,
    this.onCommentTap,
    this.onDelete,
  });

  @override
  State<SocialCard> createState() => _SocialCardState();
}

class _SocialCardState extends State<SocialCard> {
  late final PostViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = PostViewModel(widget.post);
    _vm.addListener(_onVmChanged);
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions delegated to ViewModel (view only handles UI concerns)
  // ---------------------------------------------------------------------------

  Future<void> _handleLike() async {
    try {
      await _vm.handleLike();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to like post: $e')));
      }
    }
  }

  Future<void> _handleShare() async {
    if (widget.post.id == null) return;
    try {
      final deepLink = 'https://trekscanplus.app/posts/${widget.post.id}';
      final shareText =
          '${widget.post.caption}\n\n$deepLink\n\n🏔️ Check out this post on TrekScanPlus!';
      await Share.share(
        shareText,
        subject: 'Amazing Trek Post from TrekScanPlus',
      );
      await _vm.onShareCompleted();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post shared! 🎉')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open share: $e')));
      }
    }
  }

  Future<void> _handleBookmark() async {
    try {
      await _vm.handleBookmark();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _vm.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _vm.isBookmarked
                      ? 'Added to favorites'
                      : 'Removed from favorites',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            backgroundColor: _vm.isBookmarked ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to bookmark: $e',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleFollow() async {
    try {
      await _vm.handleFollow();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow status: $e')),
        );
      }
    }
  }

  void _handleComment() {
    if (widget.post.id == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          CommentsSheet(postId: widget.post.id!, post: widget.post),
    );
  }

  void _showOptionsMenu() {
    PostOptionsSheet.show(
      context: context,
      postUserId: widget.post.userId,
      onEdit: _showEditDialog,
      onDelete: widget.onDelete,
      onReport: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Report submitted')));
      },
    );
  }

  void _showEditDialog() {
    final captionController = TextEditingController(text: widget.post.caption);
    PostPrivacy selectedPrivacy = widget.post.privacy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final colors = context.colors;
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Post',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: captionController,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Caption',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Privacy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PostPrivacy>(
                  value: selectedPrivacy,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: PostPrivacy.public,
                      child: Row(
                        children: [
                          Icon(Icons.public, size: 20),
                          SizedBox(width: 8),
                          Text('Public'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: PostPrivacy.followers,
                      child: Row(
                        children: [
                          Icon(Icons.people, size: 20),
                          SizedBox(width: 8),
                          Text('Followers'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: PostPrivacy.private,
                      child: Row(
                        children: [
                          Icon(Icons.lock, size: 20),
                          SizedBox(width: 8),
                          Text('Private'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedPrivacy = value);
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (widget.post.id == null) return;
                      try {
                        await _vm.updatePost(
                          postId: widget.post.id!,
                          caption: captionController.text.trim(),
                          privacy: selectedPrivacy,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating post: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _navigateToUserProfile(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid == widget.post.userId) return;

    if (currentUser?.uid != null) {
      try {
        final isFollowing = await UserService.instance.isFollowing(
          currentUser!.uid,
          widget.post.userId,
        );

        if (!isFollowing) {
          if (mounted) {
            AppDialogueHandler.showAlert(
              context: context,
              title: 'Profile Access Restricted',
              message:
                  'You and this person don\'t follow each other. You can only view profiles of people you follow.',
              buttonText: 'OK',
            );
          }
          return;
        }

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: widget.post.userId),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          AppDialogueHandler.showAlert(
            context: context,
            title: 'Error',
            message: 'Unable to verify follow status. Please try again.',
            buttonText: 'OK',
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = screenHeight * 0.45;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: SizedBox(
        height: cardHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (widget.post.caption.isNotEmpty) _buildCaption(),
            if (widget.post.imageUrls.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: _buildImages(),
                ),
              ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = context.colors;
    final isOwnPost = _vm.isOwnPost;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _navigateToUserProfile(context),
            child: ProfileAvatarWithStatus(
              userId: widget.post.userId,
              photoUrl: widget.post.userPhotoUrl,
              radius: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToUserProfile(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _vm.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _vm.getTimeAgo(),
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
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                      Icon(
                        _vm.getVisibilityIcon(),
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
              onTap: _handleFollow,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _vm.isFollowing
                      ? colors.background
                      : _vm.isPending
                      ? Colors.orange[50]
                      : colors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _vm.isFollowing
                      ? 'Following'
                      : _vm.isPending
                      ? 'Pending'
                      : 'Follow',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _vm.isFollowing
                        ? colors.textSecondary
                        : _vm.isPending
                        ? Colors.orange[700]
                        : Colors.white,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.more_horiz, size: 22, color: colors.textSecondary),
            onPressed: _showOptionsMenu,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildCaption() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        widget.post.caption,
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
    );
  }

  Widget _buildImages() {
    final images = widget.post.imageUrls;
    if (images.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildImageLayout(images),
      ),
    );
  }

  Widget _buildImageLayout(List<String> images) {
    if (images.length == 1) return _buildSingleImage(images[0]);
    if (images.length == 2) return _buildTwoImages(images);
    if (images.length == 3) return _buildThreeImages(images);
    if (images.length == 4) return _buildFourImages(images);
    return _buildFivePlusImages(images);
  }

  Widget _buildSingleImage(String url) {
    return GestureDetector(
      onTap: () => _openImageViewer(0),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: context.colors.background,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            AppLogger.e('Image load error for $url: $error');
            return Container(
              color: context.colors.borderLight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'Image failed to load',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
          memCacheWidth: 800,
          memCacheHeight: 600,
        ),
      ),
    );
  }

  Widget _buildTwoImages(List<String> urls) {
    final colors = context.colors;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(child: _buildImageTile(urls[0], 0)),
          Container(width: 2, color: colors.background),
          Expanded(child: _buildImageTile(urls[1], 1)),
        ],
      ),
    );
  }

  Widget _buildThreeImages(List<String> urls) {
    final colors = context.colors;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(flex: 2, child: _buildImageTile(urls[0], 0)),
          Container(width: 2, color: colors.background),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildImageTile(urls[1], 1)),
                Container(height: 2, color: colors.background),
                Expanded(child: _buildImageTile(urls[2], 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourImages(List<String> urls) {
    final colors = context.colors;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(flex: 2, child: _buildImageTile(urls[0], 0)),
          Container(width: 2, color: colors.background),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildImageTile(urls[1], 1)),
                Container(height: 2, color: colors.background),
                Expanded(child: _buildImageTile(urls[2], 2)),
                Container(height: 2, color: colors.background),
                Expanded(child: _buildImageTile(urls[3], 3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFivePlusImages(List<String> urls) {
    final colors = context.colors;
    final hasMoreThanFour = urls.length > 4;
    final displayCount = urls.length - 4;
    return AspectRatio(
      aspectRatio: 1,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildImageTile(urls[0], 0)),
                Container(width: 2, color: colors.background),
                Expanded(child: _buildImageTile(urls[1], 1)),
              ],
            ),
          ),
          Container(height: 2, color: colors.background),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildImageTile(urls[2], 2)),
                Container(width: 2, color: colors.background),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImageTile(urls[3], 3),
                      if (hasMoreThanFour)
                        Container(
                          color: Colors.black.withOpacity(0.6),
                          child: Center(
                            child: Text(
                              '+$displayCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTile(String url, int index) {
    return GestureDetector(
      onTap: () => _openImageViewer(index),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: context.colors.background,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          AppLogger.e('Image load error for $url: $error');
          return Container(
            color: context.colors.borderLight,
            child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
          );
        },
        memCacheWidth: 400,
        memCacheHeight: 400,
      ),
    );
  }

  void _openImageViewer(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageViewer(
          imageUrls: widget.post.imageUrls,
          post: widget.post,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _vm.isLiked ? Icons.favorite : Icons.favorite_border,
              color: _vm.isLiked ? Colors.red : colors.textSecondary,
              size: 24,
            ),
            onPressed: _handleLike,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          if (_vm.likesCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              '${_vm.likesCount}',
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _handleComment,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: colors.textSecondary,
                    size: 23,
                  ),
                  if (_vm.commentsCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${_vm.commentsCount}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _handleShare,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(
                    Icons.share_outlined,
                    color: colors.textSecondary,
                    size: 22,
                  ),
                  if (_vm.sharesCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${_vm.sharesCount}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _vm.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _vm.isBookmarked ? colors.primary : colors.textSecondary,
              size: 24,
            ),
            onPressed: _handleBookmark,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }
}
