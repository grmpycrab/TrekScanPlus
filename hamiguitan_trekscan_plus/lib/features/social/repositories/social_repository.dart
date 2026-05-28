import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import '../models/social_model.dart';
import '../../notification/services/notification_manager.dart';
import '../../../utils/app_logger.dart';

/// Pure data-access layer for the social feature.
///
/// All Firestore and Firebase Storage operations for posts, comments, replies,
/// likes, bookmarks, and social notifications live here.
/// ViewModels depend on this class; widgets do NOT call it directly.
class SocialRepository {
  SocialRepository._();
  static final instance = SocialRepository._();

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  // Performance optimization flag
  static const int maxPostsLimit = 50;

  // ---------------------------------------------------------------------------
  // Posts
  // ---------------------------------------------------------------------------

  /// Generate a new post ID (without creating the post yet).
  String generatePostId() {
    return _firestore.collection('posts').doc().id;
  }

  /// Create a new post.
  ///
  /// All new posts start with [PostStatus.pending] and become visible in the
  /// public feed only after an admin approves them.
  Future<String> createPost({
    required String caption,
    required List<String> imageUrls,
    PostPrivacy privacy = PostPrivacy.public,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final post = SocialPost(
      userId: user.uid,
      userName: user.displayName ?? user.email?.split('@').first ?? 'User',
      userPhotoUrl: user.photoURL,
      caption: caption,
      imageUrls: imageUrls,
      privacy: privacy,
      status: PostStatus.pending,
    );

    final docRef = await _firestore.collection('posts').add(post.toMap());
    // postsCount is incremented only when the admin approves — not on submission.

    NotificationManager.showSuccess(
      title: 'Post Submitted ✓',
      message: 'Your post is pending review and will appear once approved.',
    );

    return docRef.id;
  }

  /// Compress image to reduce file size (85% quality).
  Future<File> _compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return imageFile;

      final compressedBytes = img.encodeJpg(image, quality: 85);
      final tempDir = Directory.systemTemp;
      final compressedFile = File(
        '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await compressedFile.writeAsBytes(compressedBytes);

      final originalSize = bytes.length;
      final compressedSize = compressedBytes.length;
      final reduction = ((originalSize - compressedSize) / originalSize * 100)
          .toStringAsFixed(1);
      AppLogger.d(
        'Compression: $originalSize → $compressedSize bytes ($reduction% reduction)',
      );

      return compressedFile;
    } catch (e) {
      AppLogger.w('Compression failed, using original: $e');
      return imageFile;
    }
  }

  /// Upload image to storage and return download URL.
  Future<String> uploadImage(File imageFile, String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      AppLogger.d('Compressing image...');
      final compressedFile = await _compressImage(imageFile);
      AppLogger.d('Compressed file size: ${compressedFile.lengthSync()} bytes');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          '${user.uid}_${timestamp}_${imageFile.path.split('/').last}';
      final path = 'posts/$postId/$fileName';

      final ref = _storage.ref(path);
      AppLogger.i('Starting upload to: $path');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=31536000',
      );

      final uploadTask = ref.putFile(compressedFile, metadata);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes * 100)
            .toStringAsFixed(0);
        AppLogger.d('Upload progress: $progress%');
      });

      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 180),
        onTimeout: () => throw Exception('Upload timeout after 180 seconds'),
      );

      AppLogger.i('Upload complete. Snapshot path: ${snapshot.ref.fullPath}');
      final downloadUrl = await ref.getDownloadURL();
      AppLogger.d('Download URL: $downloadUrl');

      try {
        await compressedFile.delete();
      } catch (e) {
        AppLogger.w('Failed to delete temp file: $e');
      }

      return downloadUrl;
    } catch (e) {
      AppLogger.e('Error uploading image: $e');
      rethrow;
    }
  }

  /// Stream all public and followers-only posts (filtered client-side).
  Stream<List<SocialPost>> streamPublicPosts() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('posts')
        .where(
          'privacy',
          whereIn: [PostPrivacy.public.name, PostPrivacy.followers.name],
        )
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots(includeMetadataChanges: false)
        .asyncMap((snapshot) async {
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(currentUser.uid)
                .get();
            final following =
                (userDoc.data()?['following'] as List<dynamic>?)
                    ?.cast<String>() ??
                [];

            final posts = snapshot.docs
                .map((doc) {
                  try {
                    final post = SocialPost.fromDoc(doc);
                    // Only approved posts appear in the public feed.
                    if (post.status != PostStatus.approved) return null;
                    if (post.privacy == PostPrivacy.public) return post;
                    if (post.privacy == PostPrivacy.followers) {
                      if (post.userId == currentUser.uid ||
                          following.contains(post.userId)) {
                        return post;
                      }
                    }
                    return null;
                  } catch (e) {
                    AppLogger.e('Error parsing post from doc: $e');
                    return null;
                  }
                })
                .whereType<SocialPost>()
                .toList();

            return posts;
          } catch (e) {
            AppLogger.e('Error in streamPublicPosts: $e');
            return <SocialPost>[];
          }
        })
        .handleError((error) {
          AppLogger.e('Stream error in streamPublicPosts: $error');
          return <SocialPost>[];
        })
        .distinct((previous, next) {
          if (previous.length != next.length) return false;
          final prevIds = previous.map((p) => p.id).toSet();
          final nextIds = next.map((p) => p.id).toSet();
          return prevIds.difference(nextIds).isEmpty &&
              nextIds.difference(prevIds).isEmpty;
        });
  }

  /// Stream posts for a specific user (own + following feed).
  Stream<List<SocialPost>> streamUserFeed(String userId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    final isOwnFeed = userId == user.uid;

    return _firestore
        .collection('posts')
        .where(
          'privacy',
          whereIn: [
            PostPrivacy.public.name,
            if (isOwnFeed) PostPrivacy.private.name,
          ],
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) => SocialPost.fromDoc(doc))
              .where((post) {
                // Own feed shows own pending posts so the user can see their
                // submission status. Other users only see approved posts.
                if (isOwnFeed) return true;
                return post.status == PostStatus.approved;
              })
              .toList();
        });
  }

  /// Stream a single user's own posts, respecting privacy for other viewers.
  Stream<List<SocialPost>> streamUserPosts(String userId) async* {
    final currentUser = _auth.currentUser;
    final isOwnProfile = currentUser?.uid == userId;

    if (isOwnProfile) {
      // Profile shows only approved posts — pending/declined are visible
      // exclusively in the Post Status Management screen (/my-posts).
      yield* _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((doc) => SocialPost.fromDoc(doc))
              .where((p) => p.status == PostStatus.approved)
              .toList());
      return;
    }

    yield* _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .where('privacy', whereIn: [PostPrivacy.public.name, PostPrivacy.followers.name])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          final posts = snap.docs
              .map((doc) => SocialPost.fromDoc(doc))
              .toList();

          List<String> following = [];
          if (currentUser != null) {
            final userDoc = await _firestore
                .collection('users')
                .doc(currentUser.uid)
                .get();
            following = List<String>.from(userDoc.data()?['following'] ?? []);
          }

          final filteredPosts = posts.where((post) {
            // Non-owners only see approved posts.
            if (post.status != PostStatus.approved) return false;
            if (post.privacy == PostPrivacy.public) return true;
            if (post.privacy == PostPrivacy.private) return false;
            if (post.privacy == PostPrivacy.followers) {
              return following.contains(userId);
            }
            return true;
          }).toList();

          AppLogger.d(
            'Filtered ${filteredPosts.length}/${posts.length} posts for user $userId',
          );
          return filteredPosts;
        });
  }

  /// Update a post's caption and/or privacy.
  Future<void> updatePost({
    required String postId,
    String? caption,
    PostPrivacy? privacy,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (caption != null) updateData['caption'] = caption;
    if (privacy != null) updateData['privacy'] = privacy.name;

    await _firestore.collection('posts').doc(postId).update(updateData);

    NotificationManager.showSuccess(
      title: 'Post Updated ✓',
      message: 'Your changes have been saved successfully!',
    );
  }

  /// Delete a post and its images from storage.
  Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final postDoc = await _firestore.collection('posts').doc(postId).get();
    final postUserId = postDoc.data()?['userId'];
    if (postUserId != user.uid) {
      throw Exception('Not authorized to delete this post');
    }

    final imageUrls = postDoc.data()?['imageUrls'] as List<dynamic>? ?? [];
    for (final url in imageUrls) {
      try {
        final ref = _storage.refFromURL(url.toString());
        await ref.delete();
      } catch (e) {
        AppLogger.w('Error deleting image: $e');
      }
    }

    await _firestore.collection('posts').doc(postId).delete();

    // Only decrement postsCount if the post was approved — pending/declined were never counted.
    if (postDoc.data()?['status'] == 'approved') {
      try {
        await _firestore.collection('users').doc(postUserId).update({
          'postsCount': FieldValue.increment(-1),
        });
      } catch (e) {
        AppLogger.w('Error updating post count: $e');
      }
    }

    NotificationManager.showInfo(
      title: 'Post Deleted',
      message: 'Your post has been removed successfully.',
    );
  }

  /// Stream all posts created by the currently authenticated user,
  /// regardless of status. Used by the My Posts management screen so
  /// users can see their pending/declined posts and any rejection notes.
  Stream<List<SocialPost>> streamMyPosts() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(maxPostsLimit)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) => SocialPost.fromDoc(doc)).toList(),
        )
        .handleError((error) {
          AppLogger.e('Stream error in streamMyPosts: $error');
          return <SocialPost>[];
        });
  }

  // ---------------------------------------------------------------------------
  // Likes
  // ---------------------------------------------------------------------------

  /// Toggle like on a post.
  Future<void> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(user.uid);
    final likeDoc = await likeRef.get();

    final postDoc = await postRef.get();
    final postOwnerId = postDoc.data()?['userId'] as String?;

    if (likeDoc.exists) {
      await likeRef.delete();
      await postRef.update({
        'likesCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await likeRef.set({
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await postRef.update({
        'likesCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (postOwnerId != null && postOwnerId != user.uid) {
        await _sendLikeNotification(
          postOwnerId,
          user.displayName ?? 'Someone',
          postId,
        );
      }
    }
  }

  /// Check if current user liked a post.
  Future<bool> isLiked(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final likeDoc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid)
        .get();

    return likeDoc.exists;
  }

  // ---------------------------------------------------------------------------
  // Comments
  // ---------------------------------------------------------------------------

  /// Add a comment to a post.
  Future<String> addComment(String postId, String text) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final comment = Comment(
      postId: postId,
      userId: user.uid,
      userName: user.displayName ?? user.email?.split('@').first ?? 'User',
      userPhotoUrl: user.photoURL,
      text: text,
    );

    final commentRef = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add(comment.toMap());

    final postRef = _firestore.collection('posts').doc(postId);
    await postRef.update({
      'commentsCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final postDoc = await postRef.get();
    final postOwnerId = postDoc.data()?['userId'] as String?;
    if (postOwnerId != null && postOwnerId != user.uid) {
      await _sendCommentNotification(
        postOwnerId,
        user.displayName ?? 'Someone',
        postId,
      );
    }

    return commentRef.id;
  }

  /// Stream comments for a post.
  Stream<List<Comment>> streamComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Comment.fromDoc(doc)).toList());
  }

  /// Toggle like on a comment.
  Future<void> toggleCommentLike(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    final likeRef = commentRef.collection('likes').doc(user.uid);
    final likeDoc = await likeRef.get();

    if (likeDoc.exists) {
      await likeRef.delete();
      await commentRef.update({'likesCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await commentRef.update({'likesCount': FieldValue.increment(1)});
    }
  }

  /// Check if current user liked a comment.
  Future<bool> isCommentLiked(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final likeDoc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(user.uid)
        .get();

    return likeDoc.exists;
  }

  /// Delete a comment (and all its replies/likes).
  Future<void> deleteComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final commentDoc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .get();

    if (commentDoc.data()?['userId'] != user.uid) {
      throw Exception('Not authorized to delete this comment');
    }

    final repliesQuery = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .get();
    for (final replyDoc in repliesQuery.docs) {
      await replyDoc.reference.delete();
    }

    final likesQuery = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .get();
    for (final likeDoc in likesQuery.docs) {
      await likeDoc.reference.delete();
    }

    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();

    await _firestore.collection('posts').doc(postId).update({
      'commentsCount': FieldValue.increment(-1),
    });
  }

  // ---------------------------------------------------------------------------
  // Replies
  // ---------------------------------------------------------------------------

  /// Add a reply to a comment.
  Future<String> addReply(String postId, String commentId, String text) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final reply = Reply(
      postId: postId,
      commentId: commentId,
      userId: user.uid,
      userName: user.displayName ?? user.email?.split('@').first ?? 'User',
      userPhotoUrl: user.photoURL,
      text: text,
    );

    final replyRef = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .add(reply.toMap());

    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({'repliesCount': FieldValue.increment(1)});

    return replyRef.id;
  }

  /// Stream replies for a comment.
  Stream<List<Reply>> streamReplies(String postId, String commentId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Reply.fromDoc(doc)).toList());
  }

  /// Toggle like on a reply.
  Future<void> toggleReplyLike(
    String postId,
    String commentId,
    String replyId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final replyRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);
    final likeRef = replyRef.collection('likes').doc(user.uid);
    final likeDoc = await likeRef.get();

    if (likeDoc.exists) {
      await likeRef.delete();
      await replyRef.update({'likesCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await replyRef.update({'likesCount': FieldValue.increment(1)});
    }
  }

  /// Check if current user liked a reply.
  Future<bool> isReplyLiked(
    String postId,
    String commentId,
    String replyId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final likeDoc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId)
        .collection('likes')
        .doc(user.uid)
        .get();

    return likeDoc.exists;
  }

  /// Delete a reply (and its likes).
  Future<void> deleteReply(
    String postId,
    String commentId,
    String replyId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final replyDoc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId)
        .get();

    if (replyDoc.data()?['userId'] != user.uid) {
      throw Exception('Not authorized to delete this reply');
    }

    final likesQuery = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId)
        .collection('likes')
        .get();
    for (final likeDoc in likesQuery.docs) {
      await likeDoc.reference.delete();
    }

    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId)
        .delete();

    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({'repliesCount': FieldValue.increment(-1)});
  }

  // ---------------------------------------------------------------------------
  // Shares & Bookmarks
  // ---------------------------------------------------------------------------

  /// Increment share count for a post.
  Future<void> sharePost(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'sharesCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Toggle bookmark on a post for the current user.
  Future<void> toggleBookmark(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final bookmarkRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookmarks')
        .doc(postId);

    final bookmarkDoc = await bookmarkRef.get();

    if (bookmarkDoc.exists) {
      await bookmarkRef.delete();
    } else {
      await bookmarkRef.set({
        'postId': postId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Check if a post is bookmarked by the current user.
  Future<bool> isBookmarked(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final bookmarkDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookmarks')
        .doc(postId)
        .get();

    return bookmarkDoc.exists;
  }

  /// Stream bookmarked posts for a user.
  Stream<List<SocialPost>> streamBookmarkedPosts(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((bookmarkSnapshot) async {
          final List<SocialPost> bookmarkedPosts = [];

          for (final bookmarkDoc in bookmarkSnapshot.docs) {
            try {
              final postId = bookmarkDoc.id;
              final postDoc = await _firestore
                  .collection('posts')
                  .doc(postId)
                  .get();

              if (postDoc.exists) {
                final post = SocialPost.fromDoc(postDoc);
                bookmarkedPosts.add(
                  SocialPost(
                    id: post.id,
                    userId: post.userId,
                    userName: post.userName,
                    userPhotoUrl: post.userPhotoUrl,
                    caption: post.caption,
                    imageUrls: post.imageUrls,
                    createdAt: post.createdAt,
                    likesCount: post.likesCount,
                    commentsCount: post.commentsCount,
                    sharesCount: post.sharesCount,
                    privacy: post.privacy,
                    status: post.status,
                    moderatorNote: post.moderatorNote,
                    reviewedAt: post.reviewedAt,
                    reviewedBy: post.reviewedBy,
                    isBookmarked: true,
                  ),
                );
              }
            } catch (e) {
              AppLogger.e('Error loading bookmarked post: $e');
              continue;
            }
          }

          return bookmarkedPosts;
        });
  }

  // ---------------------------------------------------------------------------
  // Notifications (private)
  // ---------------------------------------------------------------------------

  Future<void> _sendLikeNotification(
    String postOwnerId,
    String likerName,
    String postId,
  ) async {
    try {
      // Use a deterministic document ID so we can call set(merge:true) without
      // a prior read. A plain query+get requires the caller to have read
      // permission on the target user's notifications, which is denied for
      // cross-user writes. One like-notification per post; subsequent likes
      // from different users append to the likers array in-place.
      final notifDoc = _firestore
          .collection('users')
          .doc(postOwnerId)
          .collection('notifications')
          .doc('like_$postId');

      await notifDoc.set({
        'title': 'New Like',
        'message': '$likerName liked your post',
        'type': 'info',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'actionType': 'post',
        'actionData': postId,
        'likers': FieldValue.arrayUnion([likerName]),
      }, SetOptions(merge: true));

      AppLogger.i(
        '  Like notification updated for post $postId from $likerName',
      );
    } catch (e) {
      AppLogger.e('Error sending like notification: $e');
      rethrow;
    }
  }

  Future<void> _sendCommentNotification(
    String postOwnerId,
    String commenterName,
    String postId,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(postOwnerId)
          .collection('notifications')
          .add({
            'title': 'New Comment',
            'message': '$commenterName commented on your post',
            'type': 'info',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'actionType': 'post',
            'actionData': postId,
          });
      AppLogger.i('Created comment notification for post $postId');
    } catch (e) {
      AppLogger.e('Error sending comment notification: $e');
      rethrow;
    }
  }
}

/// Backward-compatibility alias so existing imports of [SocialSharingService]
/// continue to resolve without changes.
typedef SocialSharingService = SocialRepository;
