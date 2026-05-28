import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/app_logger.dart';

/// Handles user-facing data-sovereignty operations:
/// - [exportAndShare] — collects all Firestore documents belonging to the
///   user, serialises them to JSON, and hands the file to [share_plus] so
///   the user can save or send it.
/// - No Hive / local-cache data is stored in this app, so only Firestore
///   collections are included in the export.
class PrivacyDataService {
  PrivacyDataService._();

  static final _db = FirebaseFirestore.instance;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Compiles a complete snapshot of all Firestore data belonging to [userId]
  /// and opens the platform share sheet so the user can export it.
  static Future<void> exportAndShare(String userId) async {
    AppLogger.i('PrivacyDataService: building data export for $userId');

    final payload = await _collectAllUserData(userId);
    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/trekscan_my_data.json');
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'My TrekScan+ Data Export',
      text:
          'Here is a copy of all personal data stored by TrekScan+ for your account.',
    );

    AppLogger.i('PrivacyDataService: export shared successfully');
  }

  // ── Data collection ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _collectAllUserData(
      String userId) async {
    final data = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'userId': userId,
    };

    // 1. Main user document
    data['profile'] = await _fetchDoc('users', userId);

    // 2. Subcollections under users/{userId}
    const subcollections = [
      'achievements',
      'notifications',
      'bookmarks',
      'visitedStations',
      'climbs',
      'certificates',
    ];
    for (final sub in subcollections) {
      data[sub] = await _fetchSubcollection('users', userId, sub);
    }

    // 3. Top-level collections filtered by userId
    data['bookings'] = await _fetchWhere('bookings', 'userId', userId);
    data['posts'] = await _fetchWhere('posts', 'userId', userId);
    data['badgeClaims'] = await _fetchWhere('badge_claims', 'userId', userId);

    return data;
  }

  // ── Firestore helpers ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> _fetchDoc(
      String collection, String docId) async {
    try {
      final snap = await _db.collection(collection).doc(docId).get();
      if (!snap.exists) return null;
      return _sanitise(snap.data() ?? {});
    } catch (e) {
      AppLogger.w('PrivacyDataService: could not fetch $collection/$docId: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchSubcollection(
      String parent, String parentId, String sub) async {
    try {
      final snap = await _db
          .collection(parent)
          .doc(parentId)
          .collection(sub)
          .get();
      return snap.docs
          .map((d) => {'id': d.id, ..._sanitise(d.data())})
          .toList();
    } catch (e) {
      AppLogger.w(
          'PrivacyDataService: could not fetch $parent/$parentId/$sub: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchWhere(
      String collection, String field, String value) async {
    try {
      final snap = await _db
          .collection(collection)
          .where(field, isEqualTo: value)
          .get();
      return snap.docs
          .map((d) => {'id': d.id, ..._sanitise(d.data())})
          .toList();
    } catch (e) {
      AppLogger.w(
          'PrivacyDataService: could not fetch $collection where $field=$value: $e');
      return [];
    }
  }

  /// Converts Firestore-specific types (Timestamp, GeoPoint, DocumentReference)
  /// to JSON-safe primitives so [jsonEncode] never throws.
  static Map<String, dynamic> _sanitise(Map<String, dynamic> raw) {
    return raw.map((key, value) => MapEntry(key, _toJsonSafe(value)));
  }

  static dynamic _toJsonSafe(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }
    if (value is DocumentReference) return value.path;
    if (value is Map<String, dynamic>) return _sanitise(value);
    if (value is List) return value.map(_toJsonSafe).toList();
    return value;
  }
}
