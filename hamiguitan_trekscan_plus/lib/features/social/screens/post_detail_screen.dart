import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/social_model.dart';
import '../widgets/social_card.dart';
import '../widgets/comments_sheet.dart';
import '../../../theme/app_theme.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final bool autoShowComments;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.autoShowComments = true,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _isLoading = true;
  SocialPost? _post;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();

      if (!postDoc.exists) {
        setState(() {
          _error = 'Post not found or has been deleted';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _post = SocialPost.fromDoc(postDoc);
        _isLoading = false;
      });

      if (widget.autoShowComments) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _post != null) _showComments();
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading post: $e';
        _isLoading = false;
      });
    }
  }

  void _showComments() {
    if (_post == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(postId: widget.postId, post: _post!),
    );
  }

  Future<void> _handleDelete() async {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
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
            )
          : _post == null
          ? const Center(child: Text('No post data'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  SocialCard(
                    post: _post!,
                    onCommentTap: _showComments,
                    onDelete: () async => _handleDelete(),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showComments,
                        icon: const Icon(Icons.comment),
                        label: Text('View Comments (${_post!.commentsCount})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
