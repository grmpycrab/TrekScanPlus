import 'package:cloud_firestore/cloud_firestore.dart';

/// A user review for a trail station, stored in Firestore under
/// `station_reviews/{stationId}/reviews/{userId}`.
class StationReview {
  StationReview({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String userDisplayName;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  static double averageRating(List<StationReview> reviews) {
    if (reviews.isEmpty) return 0;
    final sum = reviews.fold<int>(0, (a, r) => a + r.rating);
    return sum / reviews.length;
  }

  factory StationReview.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return StationReview(
      id: doc.id,
      userId: data['userId'] as String? ?? doc.id,
      userDisplayName: data['userDisplayName'] as String? ?? 'Hiker',
      rating: (data['rating'] as num?)?.toInt().clamp(1, 5) ?? 1,
      comment: data['comment'] as String? ?? '',
      createdAt: _readTime(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _readTime(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _readTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
