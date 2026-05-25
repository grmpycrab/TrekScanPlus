import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Staged (offline) claim ────────────────────────────────────────────────────

class StagedBadgeClaim {
  final String badgeId;
  final String badgeName;
  final String userId;
  final String localImagePath;
  final DateTime stagedAt;

  const StagedBadgeClaim({
    required this.badgeId,
    required this.badgeName,
    required this.userId,
    required this.localImagePath,
    required this.stagedAt,
  });

  Map<String, dynamic> toJson() => {
    'badgeId': badgeId,
    'badgeName': badgeName,
    'userId': userId,
    'localImagePath': localImagePath,
    'stagedAt': stagedAt.toIso8601String(),
  };

  factory StagedBadgeClaim.fromJson(Map<String, dynamic> j) => StagedBadgeClaim(
    badgeId: j['badgeId'] as String,
    badgeName: j['badgeName'] as String,
    userId: j['userId'] as String,
    localImagePath: j['localImagePath'] as String,
    stagedAt: DateTime.parse(j['stagedAt'] as String),
  );
}

// ── Online claim (Firestore) ──────────────────────────────────────────────────

class BadgeClaim {
  final String id;
  final String userId;
  final String badgeId;
  final String status; // PENDING | APPROVED | REJECTED | PENDING_SYNC
  final String imageUrl;
  final DateTime submittedAt;
  final String? rejectionNote;

  const BadgeClaim({
    required this.id,
    required this.userId,
    required this.badgeId,
    required this.status,
    required this.imageUrl,
    required this.submittedAt,
    this.rejectionNote,
  });

  factory BadgeClaim.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return BadgeClaim(
      id: doc.id,
      userId: d['userId'] as String,
      badgeId: d['badgeId'] as String,
      status: d['status'] as String,
      imageUrl: d['imageUrl'] as String,
      submittedAt: (d['submittedAt'] as Timestamp).toDate(),
      rejectionNote: d['reviewNote'] as String?,
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class BadgeClaimService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;
  static final _auth = FirebaseAuth.instance;
  static const _stagedClaimsKey = 'staged_badge_claims';

  // ── Online query ──────────────────────────────────────────────────────────

  // Requires a composite Firestore index on badge_claims: (userId ASC, badgeId ASC, submittedAt DESC)
  static Future<BadgeClaim?> getLatestClaim(String badgeId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final snap = await _firestore
          .collection('badge_claims')
          .where('userId', isEqualTo: uid)
          .where('badgeId', isEqualTo: badgeId)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return BadgeClaim.fromDoc(snap.docs.first);
    } catch (_) {
      return null;
    }
  }

  // ── File picker ───────────────────────────────────────────────────────────

  static Future<PlatformFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    return result?.files.single;
  }

  // ── Online submit ─────────────────────────────────────────────────────────

  static Future<void> submitClaim({
    required String badgeId,
    required String badgeName,
    required PlatformFile file,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storageRef = _storage
        .ref()
        .child('badge_claims/${user.uid}/$badgeId/$timestamp.jpg');

    UploadTask task;
    if (file.path != null) {
      task = storageRef.putFile(File(file.path!));
    } else if (file.bytes != null) {
      task = storageRef.putData(file.bytes!);
    } else {
      throw Exception('No file data available');
    }

    final snapshot = await task;
    final imageUrl = await snapshot.ref.getDownloadURL();

    await _firestore.collection('badge_claims').add({
      'userId': user.uid,
      'badgeId': badgeId,
      'badgeName': badgeName,
      'userName': user.displayName ?? 'Trekker',
      'userPhotoUrl': user.photoURL ?? '',
      'imageUrl': imageUrl,
      'status': 'PENDING',
      'submittedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewNote': null,
    });
  }

  // ── Offline staging ───────────────────────────────────────────────────────

  static Future<bool> hasStagedClaim(String badgeId) async {
    final claims = await getStagedClaims();
    return claims.any((c) => c.badgeId == badgeId);
  }

  static Future<List<StagedBadgeClaim>> getStagedClaims() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stagedClaimsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => StagedBadgeClaim.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> submitClaimOffline({
    required String badgeId,
    required String badgeName,
    required PlatformFile file,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Stage image to the app's documents directory
    final docsDir = await getApplicationDocumentsDirectory();
    final stagedDir = Directory('${docsDir.path}/staged_badge_claims');
    if (!await stagedDir.exists()) {
      await stagedDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final localPath = '${stagedDir.path}/${user.uid}_${badgeId}_$timestamp.jpg';

    if (file.path != null) {
      await File(file.path!).copy(localPath);
    } else if (file.bytes != null) {
      await File(localPath).writeAsBytes(file.bytes!);
    } else {
      throw Exception('No file data available');
    }

    // Replace any existing staged claim for this badge (only one pending at a time)
    final existing = await getStagedClaims();
    final filtered = existing.where((c) => c.badgeId != badgeId).toList();
    filtered.add(StagedBadgeClaim(
      badgeId: badgeId,
      badgeName: badgeName,
      userId: user.uid,
      localImagePath: localPath,
      stagedAt: DateTime.now(),
    ));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _stagedClaimsKey,
      jsonEncode(filtered.map((c) => c.toJson()).toList()),
    );
  }

  // ── Background sync — upload all staged claims ────────────────────────────

  static Future<void> uploadStagedClaims() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final claims = await getStagedClaims();
    if (claims.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final remaining = <StagedBadgeClaim>[];

    for (final claim in claims) {
      try {
        final file = File(claim.localImagePath);
        if (!await file.exists()) continue;

        final storageRef = _storage
            .ref()
            .child('badge_claims/${claim.userId}/${claim.badgeId}/${claim.stagedAt.millisecondsSinceEpoch}.jpg');

        final snapshot = await storageRef.putFile(file);
        final imageUrl = await snapshot.ref.getDownloadURL();

        await _firestore.collection('badge_claims').add({
          'userId': claim.userId,
          'badgeId': claim.badgeId,
          'badgeName': claim.badgeName,
          'userName': user.displayName ?? 'Trekker',
          'userPhotoUrl': user.photoURL ?? '',
          'imageUrl': imageUrl,
          'status': 'PENDING',
          'submittedAt': FieldValue.serverTimestamp(),
          'reviewedAt': null,
          'reviewNote': null,
        });

        await file.delete();
      } catch (_) {
        remaining.add(claim);
      }
    }

    await prefs.setString(
      _stagedClaimsKey,
      jsonEncode(remaining.map((c) => c.toJson()).toList()),
    );
  }
}
