import 'package:cloud_firestore/cloud_firestore.dart';

enum PostPrivacy { public, followers, private }

/// Moderation lifecycle for a social post.
/// - pending  : default on creation, not visible in public feed
/// - approved : visible in public feed (set by admin)
/// - declined : rejected by moderator, never visible in public feed
enum PostStatus { pending, approved, declined }

class SocialPost {
  String? id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String? userRole;
  final String caption;
  final List<String> imageUrls; // Max 4 images
  final PostPrivacy privacy;
  final PostStatus status;
  final String? moderatorNote; // populated when status == declined
  final Timestamp? reviewedAt;
  final String? reviewedBy; // admin UID who reviewed
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isBookmarked;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  SocialPost({
    this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.userRole,
    required this.caption,
    required this.imageUrls,
    this.privacy = PostPrivacy.public,
    this.status = PostStatus.pending,
    this.moderatorNote,
    this.reviewedAt,
    this.reviewedBy,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isBookmarked = false,
    Timestamp? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'userRole': userRole,
      'caption': caption,
      'imageUrls': imageUrls,
      'privacy': privacy.name,
      'status': status.name,
      if (moderatorNote != null) 'moderatorNote': moderatorNote,
      if (reviewedAt != null) 'reviewedAt': reviewedAt,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'isBookmarked': isBookmarked,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory SocialPost.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SocialPost(
      id: doc.id,
      userId: data['userId'] as String,
      userName: data['userName'] as String? ?? 'Unknown',
      userPhotoUrl: data['userPhotoUrl'] as String?,
      userRole: data['userRole'] as String?,
      caption: data['caption'] as String? ?? '',
      imageUrls:
          (data['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      privacy: PostPrivacy.values.firstWhere(
        (p) => p.name == (data['privacy'] as String? ?? 'public'),
        orElse: () => PostPrivacy.public,
      ),
      // Existing posts without a status field default to approved for
      // backward compatibility — only new posts start as pending.
      status: PostStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String? ?? 'approved'),
        orElse: () => PostStatus.approved,
      ),
      moderatorNote: data['moderatorNote'] as String?,
      reviewedAt: data['reviewedAt'] as Timestamp?,
      reviewedBy: data['reviewedBy'] as String?,
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      sharesCount: (data['sharesCount'] as num?)?.toInt() ?? 0,
      isBookmarked: data['isBookmarked'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }
}

class Comment {
  String? id;
  final String postId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String text;
  final int likesCount;
  final int repliesCount;
  final Timestamp createdAt;

  Comment({
    this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.text,
    this.likesCount = 0,
    this.repliesCount = 0,
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'likesCount': likesCount,
      'repliesCount': repliesCount,
      'createdAt': createdAt,
    };
  }

  factory Comment.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      postId: data['postId'] as String,
      userId: data['userId'] as String,
      userName: data['userName'] as String? ?? 'Unknown',
      userPhotoUrl: data['userPhotoUrl'] as String?,
      text: data['text'] as String? ?? '',
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      repliesCount: (data['repliesCount'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}

class Reply {
  String? id;
  final String postId;
  final String commentId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String text;
  final int likesCount;
  final Timestamp createdAt;

  Reply({
    this.id,
    required this.postId,
    required this.commentId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.text,
    this.likesCount = 0,
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'postId': postId,
      'commentId': commentId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'likesCount': likesCount,
      'createdAt': createdAt,
    };
  }

  factory Reply.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reply(
      id: doc.id,
      postId: data['postId'] as String,
      commentId: data['commentId'] as String,
      userId: data['userId'] as String,
      userName: data['userName'] as String? ?? 'Unknown',
      userPhotoUrl: data['userPhotoUrl'] as String?,
      text: data['text'] as String? ?? '',
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}

