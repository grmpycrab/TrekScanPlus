import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/social_model.dart';
import '../services/social_sharing_service.dart';
import '../theme/color.dart';
import 'comments_sheet.dart';

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
  bool _isLiked = false;
  bool _isBookmarked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  int _sharesCount = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post.likesCount;
    _commentsCount = widget.post.commentsCount;
    _sharesCount = widget.post.sharesCount;
    _isBookmarked = widget.post.isBookmarked;
    _checkLikedStatus();
    _checkBookmarkedStatus();
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

  void _showOptionsMenu() {
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = user?.uid == widget.post.userId;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDelete?.call();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text('Report Post'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            backgroundImage: widget.post.userPhotoUrl != null
                ? NetworkImage(widget.post.userPhotoUrl!)
                : null,
            child: widget.post.userPhotoUrl == null
                ? const Icon(Icons.person, color: AppColors.iconPrimary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (widget.post.userRole != null)
                  Text(
                    widget.post.userRole!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: _showOptionsMenu,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCaption() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(widget.post.caption, style: const TextStyle(fontSize: 14)),
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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Like
              IconButton(
                icon: Icon(
                  Icons.favorite,
                  color: _isLiked ? Colors.red : Colors.grey[400],
                ),
                onPressed: _handleLike,
                constraints: const BoxConstraints(),
              ),
              Text(
                '$_likesCount',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 16),
              // Comment
              GestureDetector(
                onTap: _handleComment,
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.grey[600],
                      size: 22,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_commentsCount',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Share
              GestureDetector(
                onTap: _handleShare,
                child: Icon(Icons.send, color: Colors.grey[600], size: 22),
              ),
              const SizedBox(width: 4),
              Text(
                '$_sharesCount',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              // Bookmark
              IconButton(
                icon: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: _isBookmarked ? AppColors.primary : Colors.grey[400],
                ),
                onPressed: _handleBookmark,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM dd, yyyy').format(widget.post.createdAt.toDate()),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
