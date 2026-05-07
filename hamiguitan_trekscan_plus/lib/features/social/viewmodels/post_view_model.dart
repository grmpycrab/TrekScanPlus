import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/social_model.dart';
import '../repositories/social_repository.dart';
import '../../../core/services/user_service.dart';
import '../../../utils/app_logger.dart';

/// Manages per-post state: like/bookmark/follow status, counts, display name.
///
/// One [PostViewModel] is created per [SocialCard] instance. The widget calls
/// [handleLike], [handleBookmark], [handleFollow], and [onShareCompleted]
/// in response to user interactions; it reads [isLiked], [likesCount], etc.
/// to render the current state.
class PostViewModel extends ChangeNotifier {
  final SocialRepository _repository = SocialRepository.instance;
  final UserService _userService = UserService.instance;

  final SocialPost post;

  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _isFollowing = false;
  bool _isPending = false;
  int _likesCount;
  final int _commentsCount;
  int _sharesCount;
  String _displayName;
  bool _isDisposed = false;

  bool get isLiked => _isLiked;
  bool get isBookmarked => _isBookmarked;
  bool get isFollowing => _isFollowing;
  bool get isPending => _isPending;
  int get likesCount => _likesCount;
  int get commentsCount => _commentsCount;
  int get sharesCount => _sharesCount;
  String get displayName => _displayName;

  PostViewModel(this.post)
    : _likesCount = post.likesCount,
      _commentsCount = post.commentsCount,
      _sharesCount = post.sharesCount,
      _isBookmarked = post.isBookmarked,
      _displayName = post.userName {
    _init();
  }

  void _init() {
    _checkLikedStatus();
    _checkBookmarkedStatus();
    _checkFollowStatus();
    _checkPendingStatus();
    _loadUserName();
  }

  // ---------------------------------------------------------------------------
  // Async initialisation helpers
  // ---------------------------------------------------------------------------

  Future<void> _checkLikedStatus() async {
    if (post.id == null) return;
    try {
      final liked = await _repository.isLiked(post.id!);
      _isLiked = liked;
      _notifyIfAlive();
    } catch (e) {
      AppLogger.e('Error checking liked status: $e');
    }
  }

  Future<void> _checkBookmarkedStatus() async {
    if (post.id == null) return;
    try {
      final bookmarked = await _repository.isBookmarked(post.id!);
      _isBookmarked = bookmarked;
      _notifyIfAlive();
    } catch (e) {
      AppLogger.e('Error checking bookmarked status: $e');
    }
  }

  Future<void> _checkFollowStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == post.userId) return;
    try {
      final isFollowing = await _userService.isFollowing(
        currentUser.uid,
        post.userId,
      );
      _isFollowing = isFollowing;
      _notifyIfAlive();
    } catch (e) {
      AppLogger.e('Error checking follow status: $e');
    }
  }

  Future<void> _checkPendingStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == post.userId) return;
    try {
      final isPending = await _userService.isPendingFollowRequest(
        currentUser.uid,
        post.userId,
      );
      _isPending = isPending;
      _notifyIfAlive();
    } catch (e) {
      AppLogger.e('Error checking pending status: $e');
    }
  }

  Future<void> _loadUserName() async {
    try {
      final userData = await _userService.getUserOnce(post.userId);
      if (userData != null) {
        final firstName = userData['firstName'] as String?;
        final lastName = userData['lastName'] as String?;
        if (firstName != null && lastName != null) {
          _displayName = '$firstName $lastName';
        } else if (firstName != null) {
          _displayName = firstName;
        }
        _notifyIfAlive();
      }
    } catch (e) {
      AppLogger.e('Error loading user name: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Actions — called by the view, throw on error so view can show SnackBar
  // ---------------------------------------------------------------------------

  /// Optimistically toggles like state; reverts and rethrows on failure.
  Future<void> handleLike() async {
    if (post.id == null) return;
    _isLiked = !_isLiked;
    _likesCount += _isLiked ? 1 : -1;
    _notifyIfAlive();
    try {
      await _repository.toggleLike(post.id!);
    } catch (e) {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
      _notifyIfAlive();
      rethrow;
    }
  }

  /// Optimistically toggles bookmark state; reverts and rethrows on failure.
  Future<void> handleBookmark() async {
    if (post.id == null) return;
    _isBookmarked = !_isBookmarked;
    _notifyIfAlive();
    try {
      await _repository.toggleBookmark(post.id!);
    } catch (e) {
      _isBookmarked = !_isBookmarked;
      _notifyIfAlive();
      rethrow;
    }
  }

  /// Increments share counter in Firestore. The view is responsible for
  /// opening the native share sheet before calling this.
  Future<void> onShareCompleted() async {
    if (post.id == null) return;
    _sharesCount++;
    _notifyIfAlive();
    try {
      await _repository.sharePost(post.id!);
    } catch (e) {
      AppLogger.w('Error recording share: $e');
    }
  }

  /// Toggles follow/unfollow/pending-request state; reverts and rethrows
  /// on failure.
  Future<void> handleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      if (_isFollowing) {
        _isFollowing = false;
        _notifyIfAlive();
        await _userService.unfollow(currentUser.uid, post.userId);
      } else if (_isPending) {
        _isPending = false;
        _notifyIfAlive();
        await _userService.cancelFollowRequest(currentUser.uid, post.userId);
      } else {
        _isPending = true;
        _notifyIfAlive();
        await _userService.toggleFollow(post.userId, currentUser.uid);
      }
    } catch (e) {
      // Revert optimistic update
      if (!_isFollowing && !_isPending) {
        _isFollowing = true;
      } else {
        _isPending = false;
      }
      _notifyIfAlive();
      rethrow;
    }
  }

  void _notifyIfAlive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Calls the repository to update the post caption/privacy.
  Future<void> updatePost({
    required String postId,
    String? caption,
    PostPrivacy? privacy,
  }) async {
    await _repository.updatePost(
      postId: postId,
      caption: caption,
      privacy: privacy,
    );
  }

  // ---------------------------------------------------------------------------
  // Computed helpers consumed by the view
  // ---------------------------------------------------------------------------

  String getTimeAgo() {
    final postDate = post.createdAt.toDate();
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

  IconData getVisibilityIcon() {
    switch (post.privacy) {
      case PostPrivacy.public:
        return Icons.public;
      case PostPrivacy.followers:
        return Icons.people;
      case PostPrivacy.private:
        return Icons.lock;
    }
  }

  /// Whether the post belongs to the currently signed-in user.
  bool get isOwnPost {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser?.uid == post.userId;
  }
}
