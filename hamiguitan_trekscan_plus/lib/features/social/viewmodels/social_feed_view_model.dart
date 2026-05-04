import 'package:flutter/foundation.dart';
import '../models/social_model.dart';
import '../repositories/social_repository.dart';

/// Provides the social feed stream and feed-level actions (delete post).
///
/// Consumed by screens that display a list of [SocialPost] items, such as
/// a dedicated feed page or the favorites/bookmarks screen.
class SocialFeedViewModel extends ChangeNotifier {
  final SocialRepository _repository = SocialRepository.instance;

  /// Live stream of public + followers-only posts for the home feed.
  Stream<List<SocialPost>> publicPostsStream() =>
      _repository.streamPublicPosts();

  /// Live stream of a specific user's posts.
  Stream<List<SocialPost>> userPostsStream(String userId) =>
      _repository.streamUserPosts(userId);

  /// Live stream of the current user's bookmarked posts.
  Stream<List<SocialPost>> bookmarkedPostsStream(String userId) =>
      _repository.streamBookmarkedPosts(userId);

  /// Delete a post. Rethrows on failure.
  Future<void> deletePost(String postId) => _repository.deletePost(postId);
}
