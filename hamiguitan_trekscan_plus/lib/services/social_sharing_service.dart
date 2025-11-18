import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import '../models/social_model.dart';

class SocialSharingService {
  SocialSharingService._();
  static final instance = SocialSharingService._();

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  /// Generate a new post ID (without creating the post yet)
  String generatePostId() {
    return _firestore.collection('posts').doc().id;
  }

  /// Create a new post
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
    );

    final docRef = await _firestore.collection('posts').add(post.toMap());

    // Update user's post count
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'postsCount': FieldValue.increment(1),
      });
      debugPrint('Post count incremented for ${user.uid}');
    } catch (e) {
      debugPrint('Error updating post count: $e');
    }

    return docRef.id;
  }

  /// Compress image to reduce file size (85% quality)
  Future<File> _compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return imageFile;

      // Compress with 85% quality
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
      debugPrint(
        'Compression: $originalSize → $compressedSize bytes ($reduction% reduction)',
      );

      return compressedFile;
    } catch (e) {
      debugPrint('Compression failed, using original: $e');
      return imageFile;
    }
  }

  /// Upload image to storage and return URL
  Future<String> uploadImage(File imageFile, String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Compress image first
      debugPrint('Compressing image...');
      final compressedFile = await _compressImage(imageFile);
      debugPrint('Compressed file size: ${compressedFile.lengthSync()} bytes');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          '${user.uid}_${timestamp}_${imageFile.path.split('/').last}';
      final path = 'posts/$postId/$fileName';

      final ref = _storage.ref(path);
      debugPrint('Starting upload to: $path');

      // Set metadata for the file upload
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=31536000', // 1 year
      );

      final uploadTask = ref.putFile(compressedFile, metadata);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes * 100)
            .toStringAsFixed(0);
        debugPrint('Upload progress: $progress%');
      });

      // Add timeout of 180 seconds (increased for slower connections)
      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 180),
        onTimeout: () => throw Exception('Upload timeout after 180 seconds'),
      );

      debugPrint('Upload complete. Snapshot path: ${snapshot.ref.fullPath}');
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('Download URL: $downloadUrl');

      // Clean up compressed temp file
      try {
        await compressedFile.delete();
      } catch (e) {
        debugPrint('Failed to delete temp file: $e');
      }

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  /// Stream all public posts
  Stream<List<SocialPost>> streamPublicPosts() {
    return _firestore
        .collection('posts')
        .where('privacy', isEqualTo: PostPrivacy.public.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) => SocialPost.fromDoc(doc)).toList(),
        );
  }

  /// Stream posts for current user (including their own and followers' posts)
  Stream<List<SocialPost>> streamUserFeed(String userId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // Get user's own posts and public posts
    return _firestore
        .collection('posts')
        .where(
          'privacy',
          whereIn: [
            PostPrivacy.public.name,
            if (userId == user.uid) PostPrivacy.private.name,
          ],
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) => SocialPost.fromDoc(doc)).toList(),
        );
  }

  /// Stream user's own posts
  Stream<List<SocialPost>> streamUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) => SocialPost.fromDoc(doc)).toList(),
        );
  }

  /// Toggle like on a post
  Future<void> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(user.uid);
    final likeDoc = await likeRef.get();

    // Get post owner
    final postDoc = await postRef.get();
    final postData = postDoc.data();
    final postOwnerId = postData?['userId'] as String?;

    if (likeDoc.exists) {
      // Unlike
      await likeRef.delete();
      await postRef.update({
        'likesCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Like
      await likeRef.set({
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await postRef.update({
        'likesCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to post owner (only if it's not their own post)
      if (postOwnerId != null && postOwnerId != user.uid) {
        await _sendLikeNotification(
          postOwnerId,
          user.displayName ?? 'Someone',
          postId,
        );
      }
    }
  }

  /// Check if current user liked a post
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

  /// Add a comment to a post
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

    // Update comment count
    final postRef = _firestore.collection('posts').doc(postId);
    await postRef.update({
      'commentsCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Send notification to post owner (only if it's not their own comment)
    final postDoc = await postRef.get();
    final postData = postDoc.data();
    final postOwnerId = postData?['userId'] as String?;

    if (postOwnerId != null && postOwnerId != user.uid) {
      await _sendCommentNotification(
        postOwnerId,
        user.displayName ?? 'Someone',
        postId,
      );
    }

    return commentRef.id;
  }

  /// Stream comments for a post
  Stream<List<Comment>> streamComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Comment.fromDoc(doc)).toList());
  }

  /// Add a reply to a comment
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

    // Update reply count on comment
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({'repliesCount': FieldValue.increment(1)});

    return replyRef.id;
  }

  /// Stream replies for a comment
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

  /// Toggle like on a comment
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
      // Unlike
      await likeRef.delete();
      await commentRef.update({'likesCount': FieldValue.increment(-1)});
    } else {
      // Like
      await likeRef.set({
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await commentRef.update({'likesCount': FieldValue.increment(1)});
    }
  }

  /// Check if current user liked a comment
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

  /// Toggle like on a reply
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
      // Unlike
      await likeRef.delete();
      await replyRef.update({'likesCount': FieldValue.increment(-1)});
    } else {
      // Like
      await likeRef.set({
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await replyRef.update({'likesCount': FieldValue.increment(1)});
    }
  }

  /// Check if current user liked a reply
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

  /// Delete a comment
  Future<void> deleteComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Verify ownership
    final commentDoc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .get();

    if (commentDoc.data()?['userId'] != user.uid) {
      throw Exception('Not authorized to delete this comment');
    }

    // Delete all replies
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

    // Delete likes on comment
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

    // Delete comment
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();

    // Decrement post comment count
    await _firestore.collection('posts').doc(postId).update({
      'commentsCount': FieldValue.increment(-1),
    });
  }

  /// Delete a reply
  Future<void> deleteReply(
    String postId,
    String commentId,
    String replyId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Verify ownership
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

    // Delete likes on reply
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

    // Delete reply
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId)
        .delete();

    // Decrement comment reply count
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({'repliesCount': FieldValue.increment(-1)});
  }

  /// Share a post (increment share count)
  Future<void> sharePost(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'sharesCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Toggle bookmark on a post
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

  /// Check if post is bookmarked by current user
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

  /// Delete a post
  Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final postDoc = await _firestore.collection('posts').doc(postId).get();
    final postUserId = postDoc.data()?['userId'];
    if (postUserId != user.uid) {
      throw Exception('Not authorized to delete this post');
    }

    // Delete images from storage
    final imageUrls = postDoc.data()?['imageUrls'] as List<dynamic>? ?? [];
    for (final url in imageUrls) {
      try {
        final ref = _storage.refFromURL(url.toString());
        await ref.delete();
      } catch (e) {
        print('Error deleting image: $e');
      }
    }

    // Delete post document (subcollections will be deleted via Firestore rules or Cloud Function)
    await _firestore.collection('posts').doc(postId).delete();

    // Decrement user's post count
    try {
      await _firestore.collection('users').doc(postUserId).update({
        'postsCount': FieldValue.increment(-1),
      });
      debugPrint('Post count decremented for $postUserId');
    } catch (e) {
      debugPrint('Error updating post count: $e');
    }
  }

  /// Send notification when someone likes a post
  Future<void> _sendLikeNotification(
    String postOwnerId,
    String likerName,
    String postId,
  ) async {
    try {
      print(
        '📤 Sending like notification to $postOwnerId from $likerName on post $postId',
      );
      final notificationRef = _firestore
          .collection('users')
          .doc(postOwnerId)
          .collection('notifications');

      // Try to find existing like notification for this post
      try {
        final existingNotifications = await notificationRef
            .where('postId', isEqualTo: postId)
            .where('type', isEqualTo: 'like')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (existingNotifications.docs.isNotEmpty) {
          // Update existing notification to stack likes
          final notifDoc = existingNotifications.docs.first;
          final notifData = notifDoc.data();
          final likers = List<String>.from(notifData['likers'] as List? ?? []);

          // Add new liker if not already in list
          if (!likers.contains(likerName)) {
            likers.add(likerName);
          }

          final message = _buildLikeMessage(likers);
          await notifDoc.reference.update({
            'message': message,
            'likers': likers,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
          print(
            '✅ Updated like notification for post $postId with likers: $likers',
          );
          return;
        }
      } catch (e) {
        print('⚠️  Error checking existing notifications: $e');
        // Continue to create new notification
      }

      // Create new notification
      final notifMap = {
        'title': 'New Like',
        'message': '$likerName liked your post',
        'type': 'like',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'postId': postId,
        'likers': [likerName],
      };

      await notificationRef.add(notifMap);
      print('✅ Created new like notification for post $postId from $likerName');
    } catch (e) {
      print('❌ Error sending like notification: $e');
      rethrow;
    }
  }

  /// Send notification when someone comments on a post
  Future<void> _sendCommentNotification(
    String postOwnerId,
    String commenterName,
    String postId,
  ) async {
    try {
      final notifMap = {
        'title': 'New Comment',
        'message': '$commenterName commented on your post',
        'type': 'comment',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'postId': postId,
      };

      await _firestore
          .collection('users')
          .doc(postOwnerId)
          .collection('notifications')
          .add(notifMap);

      debugPrint('Created comment notification for post $postId');
    } catch (e) {
      debugPrint('Error sending comment notification: $e');
      rethrow;
    }
  }

  /// Build stacked like message (e.g., "John, Jane, and 3 others liked your post")
  String _buildLikeMessage(List<String> likers) {
    if (likers.isEmpty) return 'Someone liked your post';
    if (likers.length == 1) return '${likers[0]} liked your post';
    if (likers.length == 2)
      return '${likers[0]} and ${likers[1]} liked your post';

    final others = likers.length - 2;
    return '${likers[0]}, ${likers[1]}, and $others others liked your post';
  }
}
