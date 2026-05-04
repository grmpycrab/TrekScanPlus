import 'package:flutter/foundation.dart';
import '../models/social_model.dart';
import '../repositories/social_repository.dart';
import '../../../services/firebase_auth_service.dart';

/// Manages state for the comments bottom sheet.
///
/// Owns: submission loading flag, reply-to context, and the comment/reply
/// submit action. The stream of comments is exposed via [commentsStream] for
/// direct use inside a [StreamBuilder].
class CommentsViewModel extends ChangeNotifier {
  final SocialRepository _repository = SocialRepository.instance;

  bool _isSubmitting = false;
  String? _replyingToCommentId;
  String? _replyingToUserName;

  bool get isSubmitting => _isSubmitting;
  String? get replyingToCommentId => _replyingToCommentId;
  String? get replyingToUserName => _replyingToUserName;

  /// Returns the live comment stream for [postId].
  Stream<List<Comment>> commentsStream(String postId) =>
      _repository.streamComments(postId);

  /// Whether the current user is allowed to comment on [post].
  bool canComment(SocialPost post) {
    final currentUser = FirebaseAuthService.instance.currentUser;
    if (currentUser == null) return false;
    if (post.userId == currentUser.uid) return true;
    return true; // any authenticated user may comment
  }

  void setReplyingTo(String commentId, String userName) {
    _replyingToCommentId = commentId;
    _replyingToUserName = userName;
    notifyListeners();
  }

  void clearReplyingTo() {
    _replyingToCommentId = null;
    _replyingToUserName = null;
    notifyListeners();
  }

  /// Submit a comment or reply. Clears the reply-to context on success.
  /// Throws on failure so the view can display an error message.
  Future<void> submitComment({
    required String postId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    _isSubmitting = true;
    notifyListeners();

    try {
      if (_replyingToCommentId != null) {
        await _repository.addReply(postId, _replyingToCommentId!, text.trim());
      } else {
        await _repository.addComment(postId, text.trim());
      }
      clearReplyingTo();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
