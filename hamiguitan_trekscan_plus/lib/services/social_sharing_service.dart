import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/social_model.dart';

class SocialSharingService {
  SocialSharingService._();
  static final instance = SocialSharingService._();

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

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
    return docRef.id;
  }

  /// Upload image to storage and return URL
  Future<String> uploadImage(File imageFile, String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName =
        '${user.uid}_${timestamp}_${imageFile.path.split('/').last}';
    final path = 'posts/$postId/$fileName';

    final ref = _storage.ref(path);
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
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
    if (postDoc.data()?['userId'] != user.uid) {
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
  }
}
