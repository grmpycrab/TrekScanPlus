import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/social_model.dart';
import '../services/social_sharing_service.dart';
import '../services/firebase_auth_service.dart';
import '../theme/color.dart';

class CommentThread extends StatefulWidget {
  final String postId;
  final Comment comment;
  final VoidCallback? onDelete;
  final Function(String commentId, String userName)? onReplyTap;

  const CommentThread({
    super.key,
    required this.postId,
    required this.comment,
    this.onDelete,
    this.onReplyTap,
  });

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  final _replyController = TextEditingController();
  bool _showReplies = false;
  bool _isLiked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.comment.likesCount;
    _checkLikedStatus();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _checkLikedStatus() async {
    if (widget.comment.id != null) {
      final liked = await SocialSharingService.instance.isCommentLiked(
        widget.postId,
        widget.comment.id!,
      );
      if (mounted) {
        setState(() => _isLiked = liked);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (widget.comment.id == null) return;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      await SocialSharingService.instance.toggleCommentLike(
        widget.postId,
        widget.comment.id!,
      );
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likesCount += _isLiked ? 1 : -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to like comment: $e')));
      }
    }
  }

  Future<void> _deleteComment() async {
    if (widget.comment.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SocialSharingService.instance.deleteComment(
        widget.postId,
        widget.comment.id!,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comment deleted')));
        widget.onDelete?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete comment: $e')));
      }
    }
  }

  void _showOptionsMenu() {
    final currentUser = FirebaseAuthService.instance.currentUser;
    final isOwner = currentUser?.uid == widget.comment.userId;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Comment'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment();
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = _getTimeAgo(widget.comment.createdAt.toDate());
    final currentUser = FirebaseAuthService.instance.currentUser;
    final isOwner = currentUser?.uid == widget.comment.userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main comment
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.comment.userPhotoUrl != null
                    ? NetworkImage(widget.comment.userPhotoUrl!)
                    : null,
                child: widget.comment.userPhotoUrl == null
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and time
                    Row(
                      children: [
                        Text(
                          widget.comment.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showOptionsMenu,
                            child: Icon(
                              Icons.more_horiz,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Comment text
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.comment.text,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Like and reply buttons
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleLike,
                          child: Row(
                            children: [
                              Icon(
                                _isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 14,
                                color: _isLiked ? Colors.red : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _likesCount > 0 ? '$_likesCount' : '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            widget.onReplyTap?.call(
                              widget.comment.id ?? '',
                              widget.comment.userName,
                            );
                          },
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (widget.comment.repliesCount > 0) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              setState(() => _showReplies = !_showReplies);
                            },
                            child: Text(
                              _showReplies
                                  ? 'Hide ${widget.comment.repliesCount} replies'
                                  : 'View ${widget.comment.repliesCount} ${widget.comment.repliesCount == 1 ? 'reply' : 'replies'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Replies
        if (_showReplies && widget.comment.id != null)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 8),
            child: StreamBuilder<List<Reply>>(
              stream: SocialSharingService.instance.streamReplies(
                widget.postId,
                widget.comment.id!,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: ${snapshot.error}'),
                    ),
                  );
                }

                final replies = snapshot.data ?? [];

                if (replies.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  children: List.generate(
                    replies.length,
                    (index) => ReplyTile(
                      postId: widget.postId,
                      commentId: widget.comment.id!,
                      reply: replies[index],
                    ),
                  ),
                );
              },
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}

class ReplyTile extends StatefulWidget {
  final String postId;
  final String commentId;
  final Reply reply;

  const ReplyTile({
    super.key,
    required this.postId,
    required this.commentId,
    required this.reply,
  });

  @override
  State<ReplyTile> createState() => _ReplyTileState();
}

class _ReplyTileState extends State<ReplyTile> {
  bool _isLiked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.reply.likesCount;
    _checkLikedStatus();
  }

  Future<void> _checkLikedStatus() async {
    if (widget.reply.id != null) {
      final liked = await SocialSharingService.instance.isReplyLiked(
        widget.postId,
        widget.commentId,
        widget.reply.id!,
      );
      if (mounted) {
        setState(() => _isLiked = liked);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (widget.reply.id == null) return;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      await SocialSharingService.instance.toggleReplyLike(
        widget.postId,
        widget.commentId,
        widget.reply.id!,
      );
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likesCount += _isLiked ? 1 : -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to like reply: $e')));
      }
    }
  }

  Future<void> _deleteReply() async {
    if (widget.reply.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reply'),
        content: const Text('Are you sure you want to delete this reply?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SocialSharingService.instance.deleteReply(
        widget.postId,
        widget.commentId,
        widget.reply.id!,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reply deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete reply: $e')));
      }
    }
  }

  void _showOptionsMenu() {
    final currentUser = FirebaseAuthService.instance.currentUser;
    final isOwner = currentUser?.uid == widget.reply.userId;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Reply'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteReply();
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = _getTimeAgo(widget.reply.createdAt.toDate());
    final currentUser = FirebaseAuthService.instance.currentUser;
    final isOwner = currentUser?.uid == widget.reply.userId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: widget.reply.userPhotoUrl != null
                ? NetworkImage(widget.reply.userPhotoUrl!)
                : null,
            child: widget.reply.userPhotoUrl == null
                ? const Icon(Icons.person, size: 16)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and time
                Row(
                  children: [
                    Text(
                      widget.reply.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showOptionsMenu,
                        child: Icon(
                          Icons.more_horiz,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Reply text
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.reply.text,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 6),
                // Like button
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 13,
                        color: _isLiked ? Colors.red : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _likesCount > 0 ? '$_likesCount' : '',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}
