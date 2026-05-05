import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/station_review.dart';
import '../../../utils/app_logger.dart';

/// Firestore-backed reviews for stations.
class StationReviewService {
  StationReviewService._internal();

  static final StationReviewService instance = StationReviewService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _rootCollection = 'station_reviews';
  static const String _reviewsSubcollection = 'reviews';

  CollectionReference<Map<String, dynamic>> _reviewsRef(String stationId) {
    return _firestore
        .collection(_rootCollection)
        .doc(stationId)
        .collection(_reviewsSubcollection);
  }

  /// Live list of reviews for a station (newest [updatedAt] first).
  /// Sorted client-side to avoid requiring a Firestore composite index.
  Stream<List<StationReview>> watchReviews(String stationId) {
    return _reviewsRef(stationId).snapshots().map((snap) {
      final list = snap.docs.map(StationReview.fromFirestore).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  /// One-time fetch (e.g. offline/error fallback).
  Future<List<StationReview>> fetchReviewsOnce(String stationId) async {
    final snap = await _reviewsRef(stationId).get();
    final list = snap.docs.map(StationReview.fromFirestore).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Create or update the signed-in user's review for this station.
  Future<void> upsertReview({
    required String stationId,
    required int rating,
    String comment = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to post a review.');
    }
    final r = rating.clamp(1, 5);
    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'Hiker');

    final ref = _reviewsRef(stationId).doc(user.uid);
    final existing = await ref.get();
    final now = FieldValue.serverTimestamp();

    await ref.set(<String, dynamic>{
      'userId': user.uid,
      'userDisplayName': name,
      'rating': r,
      'comment': comment.trim(),
      'updatedAt': now,
      if (!existing.exists) 'createdAt': now,
    }, SetOptions(merge: true));

    if (kDebugMode) {
      AppLogger.i('Review saved for station $stationId');
    }
  }

  Future<void> deleteMyReview(String stationId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _reviewsRef(stationId).doc(user.uid).delete();
  }

  String? get currentUserId => _auth.currentUser?.uid;
}
