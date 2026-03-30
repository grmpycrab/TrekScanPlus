import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/social_model.dart';

/// Manages paginated feed loading with in-memory caching
class FeedPaginationService {
  FeedPaginationService._();
  static final instance = FeedPaginationService._();

  final _firestore = FirebaseFirestore.instance;

  // In-memory cache for loaded posts (prevents re-fetching)
  final Map<String, SocialPost> _postCache = {};

  // Track the last document for pagination
  DocumentSnapshot? _lastPublicPostDocument;

  // Pagination config
  static const int postsPerPage = 10;

  /// Load first page of public posts (10 posts)
  /// Returns: List of posts and a boolean indicating if more posts exist
  Future<(List<SocialPost>, bool)> loadPublicPostsFirstPage() async {
    try {
      debugPrint('📄 Loading first page of public posts...');

      final query = _firestore
          .collection('posts')
          .where('privacy', whereIn: ['public', 'followers'])
          .orderBy('createdAt', descending: true)
          .limit(postsPerPage + 1); // +1 to check if more posts exist

      final snapshot = await query.get();

      // Clear previous pagination state
      _lastPublicPostDocument = null;
      _postCache.clear();

      final posts = <SocialPost>[];
      for (int i = 0; i < snapshot.docs.length && i < postsPerPage; i++) {
        try {
          final post = SocialPost.fromDoc(snapshot.docs[i]);
          posts.add(post);
          _postCache[post.id ?? ''] = post;
        } catch (e) {
          debugPrint('⚠️ Error parsing post: $e');
        }
      }

      // Store last document for next page (if it exists)
      if (snapshot.docs.isNotEmpty) {
        _lastPublicPostDocument = snapshot.docs[snapshot.docs.length - 1];
      }

      // Check if more posts exist
      final hasMore = snapshot.docs.length > postsPerPage;

      debugPrint('✅ Loaded ${posts.length} posts (more available: $hasMore)');
      return (posts, hasMore);
    } catch (e) {
      debugPrint('❌ Error loading public posts: $e');
      return (<SocialPost>[], false);
    }
  }

  /// Load next page of public posts (pagination)
  /// Returns: List of new posts and a boolean indicating if more posts exist
  Future<(List<SocialPost>, bool)> loadPublicPostsNextPage() async {
    if (_lastPublicPostDocument == null) {
      debugPrint('⚠️ No more posts to load');
      return (<SocialPost>[], false);
    }

    try {
      debugPrint('📄 Loading next page of public posts...');

      final query = _firestore
          .collection('posts')
          .where('privacy', whereIn: ['public', 'followers'])
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastPublicPostDocument!)
          .limit(postsPerPage + 1); // +1 to check if more posts exist

      final snapshot = await query.get();

      final posts = <SocialPost>[];
      for (int i = 0; i < snapshot.docs.length && i < postsPerPage; i++) {
        try {
          final post = SocialPost.fromDoc(snapshot.docs[i]);
          // Only add if not already cached
          if (!_postCache.containsKey(post.id)) {
            posts.add(post);
            _postCache[post.id ?? ''] = post;
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing post: $e');
        }
      }

      // Store last document for next page
      if (snapshot.docs.isNotEmpty) {
        _lastPublicPostDocument = snapshot.docs[snapshot.docs.length - 1];
      } else {
        _lastPublicPostDocument = null;
      }

      final hasMore = snapshot.docs.length > postsPerPage;

      debugPrint(
        '✅ Loaded ${posts.length} more posts (more available: $hasMore)',
      );
      return (posts, hasMore);
    } catch (e) {
      debugPrint('❌ Error loading next page of public posts: $e');
      return (<SocialPost>[], false);
    }
  }

  /// Get cached post by ID
  SocialPost? getCachedPost(String postId) {
    return _postCache[postId];
  }

  /// Update cached post (when likes, comments count change)
  void updateCachedPost(SocialPost post) {
    _postCache[post.id ?? ''] = post;
    debugPrint('🔄 Updated cached post: ${post.id}');
  }

  /// Clear all cache (when needed for refresh)
  void clearCache() {
    _postCache.clear();
    _lastPublicPostDocument = null;
    debugPrint('🗑️ Cache cleared');
  }

  /// Get cache size for debugging
  int getCacheSize() => _postCache.length;
}
