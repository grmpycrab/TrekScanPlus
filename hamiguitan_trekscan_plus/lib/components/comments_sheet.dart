import 'package:flutter/material.dart';
import '../models/social_model.dart';
import '../services/social_sharing_service.dart';
import '../services/firebase_auth_service.dart';
import '../theme/color.dart';
import 'comment_thread.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final SocialPost post;

  const CommentsSheet({super.key, required this.postId, required this.post});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  /// Check if current user can comment on this post
  bool _canComment() {
    final currentUser = FirebaseAuthService.instance.currentUser;
    if (currentUser == null) return false;

    // Post owner can always comment
    if (widget.post.userId == currentUser.uid) return true;

    // For now, anyone authenticated can comment
    // In future, add follower check for "followers only" posts
    return true;
  }

  Future<void> _submitComment() async {
    if (commentController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await SocialSharingService.instance.addComment(
        widget.postId,
        commentController.text.trim(),
      );
      commentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comment added!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add comment: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canComment = _canComment();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Comments list
            Expanded(
              child: StreamBuilder<List<Comment>>(
                stream: SocialSharingService.instance.streamComments(
                  widget.postId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final comments = snapshot.data ?? [];

                  if (comments.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet.\nBe the first to comment!',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];

                      return CommentThread(
                        postId: widget.postId,
                        comment: comment,
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Comment input
            if (canComment)
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        enabled: !_isSubmitting,
                        maxLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Write a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: _isSubmitting ? null : _submitComment,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'You cannot comment on this post',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
