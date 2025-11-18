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
    await _firestore.collection('posts').doc(postId).update({
      'commentsCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

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
}
