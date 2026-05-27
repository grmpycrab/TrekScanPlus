import 'package:cloud_firestore/cloud_firestore.dart';

/// A user review for a trail station, stored in Firestore under
/// `station_reviews/{stationId}/reviews/{userId}`.
///
/// [syncAction] and [syncStatus] are local-only tracking fields; they are
/// never written to Firestore. They reflect the pending state of a review
/// that has been mutated on-device but not yet confirmed by the server.
class StationReview {
  const StationReview({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    this.syncAction = 'CREATE',
    this.syncStatus = 'SYNCED',
  });

  final String id;
  final String userId;
  final String userDisplayName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  /// Device-local timestamp of the last edit. Set to [DateTime.now()] when
  /// a mutation is applied locally before the server confirms.
  final DateTime updatedAt;

  /// Strict set: `"CREATE"` | `"UPDATE"` | `"DELETE"`. Defaults to `"CREATE"`.
  final String syncAction;

  /// `"SYNCED"` when the server has confirmed the write; `"PENDING_SYNC"`
  /// while the operation is queued (offline or in-flight).
  final String syncStatus;

  /// Returns a copy with only the supplied fields replaced.
  StationReview copyWith({
    int? rating,
    String? comment,
    DateTime? updatedAt,
    String? syncAction,
    String? syncStatus,
  }) {
    return StationReview(
      id: id,
      userId: userId,
      userDisplayName: userDisplayName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncAction: syncAction ?? this.syncAction,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

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
      createdAt:
          _readTime(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _readTime(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _readTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
