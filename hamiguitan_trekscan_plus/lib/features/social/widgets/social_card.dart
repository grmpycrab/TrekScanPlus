// ignore_for_file: use_key_in_widget_constructors, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../models/social_model.dart';
import '../viewmodels/post_view_model.dart';
import '../../../core/services/user_service.dart';
import '../../../theme/app_theme.dart';
import '../../profile/screens/profile_screen.dart';
import 'comments_sheet.dart';
import 'post_options_sheet.dart';
import 'image_viewer.dart';
import '../../../core/widgets/app_dialogue_handler.dart';

// Import new modular components
import 'social_card/social_card_header.dart';
import 'social_card/expandable_caption.dart';
import 'social_card/social_card_media.dart';
import 'social_card/social_card_actions.dart';

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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          SocialCardHeader(
            userId: widget.post.userId,
            displayName: _vm.displayName,
            userPhotoUrl: widget.post.userPhotoUrl,
            createdAt: widget.post.createdAt.toDate(),
            privacy: widget.post.privacy,
            isFollowing: _vm.isFollowing,
            isPending: _vm.isPending,
            isOwnPost: _vm.isOwnPost,
            onFollowTap: _handleFollow,
            onMoreTap: _showOptionsMenu,
            onUserTap: () => _navigateToUserProfile(context),
          ),

          // Caption (Expandable)
          if (widget.post.caption.isNotEmpty)
            ExpandableCaption(
              text: widget.post.caption,
              maxLines: 3,
              style: const TextStyle(fontSize: 14, height: 1.4),
              onExpand: () {
                // Optional: Track expansion analytics
              },
            ),

          // Media
          if (widget.post.imageUrls.isNotEmpty)
            RepaintBoundary(
              child: SocialCardMedia(
                imageUrls: widget.post.imageUrls,
                onImageTap: _openImageViewer,
              ),
            ),

          // Actions with inline stats
          SocialCardActions(
            isLiked: _vm.isLiked,
            isBookmarked: _vm.isBookmarked,
            likesCount: _vm.likesCount,
            commentsCount: _vm.commentsCount,
            sharesCount: _vm.sharesCount,
            onLikeTap: _handleLike,
            onCommentTap: _handleComment,
            onShareTap: _handleShare,
            onBookmarkTap: _handleBookmark,
          ),
        ],
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
}
