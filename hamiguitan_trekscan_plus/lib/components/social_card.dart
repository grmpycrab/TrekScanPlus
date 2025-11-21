import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/social_model.dart';
import '../services/social_sharing_service.dart';
import '../services/user_service.dart';
import '../theme/color.dart';
import 'comments_sheet.dart';
import 'post_options_sheet.dart';

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
  final SocialSharingService _socialService = SocialSharingService.instance;
  final UserService _userService = UserService.instance;
  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _isFollowing = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  int _sharesCount = 0;
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post.likesCount;
    _commentsCount = widget.post.commentsCount;
    _sharesCount = widget.post.sharesCount;
    _isBookmarked = widget.post.isBookmarked;
    _displayName = widget.post.userName; // Default to userName
    _checkLikedStatus();
    _checkBookmarkedStatus();
    _checkFollowStatus();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final userData = await _userService.getUserOnce(widget.post.userId);
      if (userData != null && mounted) {
        final firstName = userData['firstName'] as String?;
        final lastName = userData['lastName'] as String?;

        if (firstName != null && lastName != null) {
          setState(() {
            _displayName = '$firstName $lastName';
          });
        } else if (firstName != null) {
          setState(() {
            _displayName = firstName;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user name: $e');
      // Keep the default userName if fetching fails
    }
  }

  Future<void> _checkLikedStatus() async {
    if (widget.post.id != null) {
      final liked = await _socialService.isLiked(widget.post.id!);
      if (mounted) {
        setState(() => _isLiked = liked);
      }
    }
  }

  Future<void> _checkBookmarkedStatus() async {
    if (widget.post.id != null) {
      final bookmarked = await _socialService.isBookmarked(widget.post.id!);
      if (mounted) {
        setState(() => _isBookmarked = bookmarked);
      }
    }
  }

  Future<void> _checkFollowStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == widget.post.userId) {
      // Don't show follow button for own post or if not logged in
      return;
    }

    try {
      final isFollowing = await _userService.isFollowing(
        currentUser.uid,
        widget.post.userId,
      );
      if (mounted) {
        setState(() => _isFollowing = isFollowing);
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }
  }

  Future<void> _handleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isFollowing = !_isFollowing);

    try {
      if (_isFollowing) {
        await _userService.toggleFollow(widget.post.userId, currentUser.uid);
      } else {
        await _userService.unfollow(widget.post.userId, currentUser.uid);
      }
    } catch (e) {
      // Revert on error
      setState(() => _isFollowing = !_isFollowing);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow status: $e')),
        );
      }
    }
  }

  Future<void> _handleLike() async {
    if (widget.post.id == null) return;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      await _socialService.toggleLike(widget.post.id!);
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = !_isLiked;
        _likesCount += _isLiked ? 1 : -1;
      });
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
      await _socialService.sharePost(widget.post.id!);
      setState(() => _sharesCount++);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post shared!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  Future<void> _handleBookmark() async {
    if (widget.post.id == null) return;

    setState(() => _isBookmarked = !_isBookmarked);

    try {
      await _socialService.toggleBookmark(widget.post.id!);
    } catch (e) {
      // Revert on error
      setState(() => _isBookmarked = !_isBookmarked);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to bookmark: $e')));
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

  String _getTimeAgo() {
    final postDate = widget.post.createdAt.toDate();
    final now = DateTime.now();
    final difference = now.difference(postDate);

    if (difference.inDays >= 7) {
      return DateFormat('MMM dd, yyyy').format(postDate);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  IconData _getVisibilityIcon() {
    // For now, default to public icon
    // Can be enhanced when visibility field is added to SocialPost model
    return Icons.public;
  }

  void _showOptionsMenu() {
    PostOptionsSheet.show(
      context: context,
      postUserId: widget.post.userId,
      onDelete: widget.onDelete,
      onReport: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Report submitted')));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          // Caption
          if (widget.post.caption.isNotEmpty) _buildCaption(),
          // Images
          if (widget.post.imageUrls.isNotEmpty) _buildImages(),
          // Footer with actions
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnPost = currentUser?.uid == widget.post.userId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary,
            backgroundImage: widget.post.userPhotoUrl != null
                ? NetworkImage(widget.post.userPhotoUrl!)
                : null,
            child: widget.post.userPhotoUrl == null
                ? const Icon(
                    Icons.person,
                    color: AppColors.iconPrimary,
                    size: 20,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _getTimeAgo(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '•',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                    ),
                    Icon(
                      _getVisibilityIcon(),
                      size: 14,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Follow button (only show if not own post)
          if (!isOwnPost)
            GestureDetector(
              onTap: _handleFollow,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isFollowing ? Colors.grey[100] : AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isFollowing ? Colors.grey[700] : Colors.white,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.more_horiz, size: 22, color: Colors.grey[600]),
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

    if (images.length == 1) {
      return _buildSingleImage(images[0]);
    } else if (images.length == 2) {
      return _buildTwoImages(images);
    } else if (images.length == 3) {
      return _buildThreeImages(images);
    } else {
      return _buildFourImages(images);
    }
  }

  Widget _buildSingleImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoImages(List<String> urls) {
    return Row(
      children: [
        Expanded(child: _buildImageTile(urls[0])),
        const SizedBox(width: 2),
        Expanded(child: _buildImageTile(urls[1])),
      ],
    );
  }

  Widget _buildThreeImages(List<String> urls) {
    return Row(
      children: [
        Expanded(child: _buildImageTile(urls[0])),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _buildImageTile(urls[1])),
              const SizedBox(height: 2),
              Expanded(child: _buildImageTile(urls[2])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFourImages(List<String> urls) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildImageTile(urls[0])),
            const SizedBox(width: 2),
            Expanded(child: _buildImageTile(urls[1])),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(child: _buildImageTile(urls[2])),
            const SizedBox(width: 2),
            Expanded(child: _buildImageTile(urls[3])),
          ],
        ),
      ],
    );
  }

  Widget _buildImageTile(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Like
          IconButton(
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? Colors.red : Colors.grey[600],
              size: 24,
            ),
            onPressed: _handleLike,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          if (_likesCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              '$_likesCount',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(width: 16),
          // Comment
          GestureDetector(
            onTap: _handleComment,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.grey[600],
                    size: 23,
                  ),
                  if (_commentsCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$_commentsCount',
                      style: TextStyle(
                        color: Colors.grey[700],
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
          // Share
          GestureDetector(
            onTap: _handleShare,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(Icons.share_outlined, color: Colors.grey[600], size: 22),
                  if (_sharesCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$_sharesCount',
                      style: TextStyle(
                        color: Colors.grey[700],
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
          // Bookmark
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? AppColors.primary : Colors.grey[600],
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
