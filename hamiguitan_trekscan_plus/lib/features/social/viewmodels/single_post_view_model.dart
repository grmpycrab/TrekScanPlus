import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/social_model.dart';
import '../repositories/social_repository.dart';
import '../../../core/services/user_service.dart';
import '../../../utils/app_logger.dart';

class SinglePostViewModel extends ChangeNotifier {
  final _repo = SocialRepository.instance;
  final _userService = UserService.instance;
  bool _disposed = false;

  // ── Post ────────────────────────────────────────────────────────────────────
  SocialPost? _post;
  bool _isLoadingPost = false;
  String? _postError;

  SocialPost? get post => _post;
  bool get isLoadingPost => _isLoadingPost;
  String? get postError => _postError;

  // ── Interactions ────────────────────────────────────────────────────────────
  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _isFollowing = false;
  bool _isPending = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  int _sharesCount = 0;
  String _displayName = '';

  bool get isLiked => _isLiked;
  bool get isBookmarked => _isBookmarked;
  bool get isFollowing => _isFollowing;
  bool get isPending => _isPending;
  int get likesCount => _likesCount;
  int get commentsCount => _commentsCount;
  int get sharesCount => _sharesCount;
  String get displayName => _displayName;
  bool get isOwnPost =>
      FirebaseAuth.instance.currentUser?.uid == _post?.userId;

  // ── Optimistic comments ─────────────────────────────────────────────────────
  final List<Comment> _pendingComments = [];
  bool _isSubmittingComment = false;
  String? _replyingToCommentId;
  String? _replyingToUserName;

  bool get isSubmittingComment => _isSubmittingComment;
  String? get replyingToCommentId => _replyingToCommentId;
  String? get replyingToUserName => _replyingToUserName;

  // ── Init ────────────────────────────────────────────────────────────────────

  /// [initialPostData] short-circuits the loading spinner: the post is rendered
  /// immediately while a background fetch silently refreshes live counts.
  void initialize({required String postId, SocialPost? initialPostData}) {
    if (initialPostData != null) {
      _hydrate(initialPostData);
      _initInteractions(postId);
      _loadDisplayName(initialPostData.userId);
      _refreshSilently(postId);
    } else {
      _fetchPost(postId);
    }
  }

  void _hydrate(SocialPost p) {
    _post = p;
    _displayName = p.userName;
    _likesCount = p.likesCount;
    _commentsCount = p.commentsCount;
    _sharesCount = p.sharesCount;
    _notifyIfAlive();
  }

  Future<void> _fetchPost(String postId) async {
    _isLoadingPost = true;
    _notifyIfAlive();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      if (!doc.exists) {
        _postError = 'Post not found or has been deleted.';
      } else {
        _hydrate(SocialPost.fromDoc(doc));
        _initInteractions(postId);
        _loadDisplayName(_post!.userId);
      }
    } catch (e) {
      _postError = 'Failed to load post.';
      AppLogger.e('[SinglePostVM] _fetchPost: $e');
    } finally {
      _isLoadingPost = false;
      _notifyIfAlive();
    }
  }

  // Silently refresh counts after instant hydration — no spinner shown.
  Future<void> _refreshSilently(String postId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      if (!doc.exists) return;
      final fresh = SocialPost.fromDoc(doc);
      _post = fresh;
      _likesCount = fresh.likesCount;
      _commentsCount = fresh.commentsCount;
      _sharesCount = fresh.sharesCount;
      _notifyIfAlive();
    } catch (_) {}
  }

  void _initInteractions(String postId) {
    _checkLiked(postId);
    _checkBookmarked(postId);
    _checkFollow();
    _checkPending();
  }

  Future<void> _checkLiked(String postId) async {
    try {
      _isLiked = await _repo.isLiked(postId);
      _notifyIfAlive();
    } catch (_) {}
  }

  Future<void> _checkBookmarked(String postId) async {
    try {
      _isBookmarked = await _repo.isBookmarked(postId);
      _notifyIfAlive();
    } catch (_) {}
  }

  Future<void> _checkFollow() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final targetId = _post?.userId;
    if (uid == null || targetId == null || uid == targetId) return;
    try {
      _isFollowing = await _userService.isFollowing(uid, targetId);
      _notifyIfAlive();
    } catch (_) {}
  }

  Future<void> _checkPending() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final targetId = _post?.userId;
    if (uid == null || targetId == null || uid == targetId) return;
    try {
      _isPending = await _userService.isPendingFollowRequest(uid, targetId);
      _notifyIfAlive();
    } catch (_) {}
  }

  Future<void> _loadDisplayName(String userId) async {
    try {
      final data = await _userService.getUserOnce(userId);
      if (data == null) return;
      final first = (data['firstName'] as String?) ?? '';
      final last = (data['lastName'] as String?) ?? '';
      final full = '$first $last'.trim();
      if (full.isNotEmpty) {
        _displayName = full;
        _notifyIfAlive();
      }
    } catch (_) {}
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> handleLike() async {
    final postId = _post?.id;
    if (postId == null) return;
    final prev = _isLiked;
    _isLiked = !_isLiked;
    _likesCount += _isLiked ? 1 : -1;
    _notifyIfAlive();
    try {
      await _repo.toggleLike(postId);
    } catch (e) {
      _isLiked = prev;
      _likesCount += prev ? 1 : -1;
      _notifyIfAlive();
      rethrow;
    }
  }

  Future<void> handleBookmark() async {
    final postId = _post?.id;
    if (postId == null) return;
    _isBookmarked = !_isBookmarked;
    _notifyIfAlive();
    try {
      await _repo.toggleBookmark(postId);
    } catch (e) {
      _isBookmarked = !_isBookmarked;
      _notifyIfAlive();
      rethrow;
    }
  }

  Future<void> handleShare() async {
    final postId = _post?.id;
    if (postId == null) return;
    _sharesCount++;
    _notifyIfAlive();
    try {
      await _repo.sharePost(postId);
    } catch (_) {}
  }

  Future<void> handleFollow() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final targetId = _post?.userId;
    if (uid == null || targetId == null) return;
    try {
      if (_isFollowing) {
        _isFollowing = false;
        _notifyIfAlive();
        await _userService.unfollow(uid, targetId);
      } else if (_isPending) {
        _isPending = false;
        _notifyIfAlive();
        await _userService.cancelFollowRequest(uid, targetId);
      } else {
        _isPending = true;
        _notifyIfAlive();
        await _userService.toggleFollow(targetId, uid);
      }
    } catch (e) {
      if (!_isFollowing && !_isPending) {
        _isFollowing = true;
      } else {
        _isPending = false;
      }
      _notifyIfAlive();
      rethrow;
    }
  }

  // ── Comment stream + optimistic merge ───────────────────────────────────────

  Stream<List<Comment>> commentsStream(String postId) =>
      _repo.streamComments(postId);

  /// Returns stream comments with any not-yet-confirmed optimistic items appended.
  List<Comment> mergeComments(List<Comment> streamComments) {
    final arrived = streamComments.map((c) => c.id).toSet();
    final pending =
        _pendingComments.where((c) => !arrived.contains(c.id)).toList();
    return [...streamComments, ...pending];
  }

  void setReplyingTo(String commentId, String userName) {
    _replyingToCommentId = commentId;
    _replyingToUserName = userName;
    _notifyIfAlive();
  }

  void clearReplyingTo() {
    _replyingToCommentId = null;
    _replyingToUserName = null;
    _notifyIfAlive();
  }

  Future<void> submitComment({
    required String postId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isReply = _replyingToCommentId != null;
    Comment? optimistic;

    if (!isReply) {
      optimistic = Comment(
        id: '_opt_${DateTime.now().millisecondsSinceEpoch}',
        postId: postId,
        userId: user.uid,
        userName: user.displayName ?? user.email?.split('@').first ?? 'You',
        userPhotoUrl: user.photoURL,
        text: text.trim(),
        createdAt: Timestamp.now(),
      );
      _pendingComments.add(optimistic);
      _commentsCount++;
      _notifyIfAlive();
    }

    _isSubmittingComment = true;
    _notifyIfAlive();

    try {
      if (isReply) {
        await _repo.addReply(postId, _replyingToCommentId!, text.trim());
      } else {
        await _repo.addComment(postId, text.trim());
      }
      clearReplyingTo();
    } catch (e) {
      if (optimistic != null) {
        _pendingComments.remove(optimistic);
        if (_commentsCount > 0) _commentsCount--;
        _notifyIfAlive();
      }
      rethrow;
    } finally {
      _isSubmittingComment = false;
      _notifyIfAlive();
    }
  }

  void _notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
