// All Firestore reads here use get() — a single-shot promise.
// onSnapshot() is intentionally NOT used to prevent listener accumulation.

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/badge.dart';
import '../utils/app_logger.dart';

/// Hybrid badge catalog repository.
///
/// Read priority (highest → lowest):
///   1. In-memory cache (_catalog) — always consulted first
///   2. SharedPreferences key [_catalogKey] — loaded once on [init]
///   3. Bundled asset (assets/data/badge.json) — seed on first launch only
///
/// Remote hydration runs asynchronously via [hydrateFromFirestore], which
/// upserts admin-created badge_definitions from Firestore into the local
/// cache so they appear in the gallery even without restarting the app.
class BadgeRepository {
  BadgeRepository._();
  static final BadgeRepository instance = BadgeRepository._();

  // Bump the version suffix when the stored schema changes incompatibly.
  static const _catalogKey = 'badge_catalog_v1';

  bool _initialized = false;
  List<UserBadge> _catalog = [];
  SharedPreferences? _prefs;

  /// Current in-memory catalog — the source of truth for the UI.
  List<UserBadge> get all => List.unmodifiable(_catalog);

  // ── Initialization ───────────────────────────────────────────────────────────

  /// Load the local catalog. On first launch the bundled asset seeds the
  /// cache; subsequent launches read the persisted cache directly.
  /// Idempotent — safe to call multiple times across the app lifecycle.
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs!.getString(_catalogKey);
    if (stored == null) {
      await _seedFromAsset();
    } else {
      final decoded = _decodeList(stored);
      // Fall back to asset seed if the stored data is corrupt/empty.
      if (decoded.isEmpty) {
        await _seedFromAsset();
      } else {
        _catalog = decoded;
      }
    }
    _initialized = true;
  }

  // ── Remote hydration ─────────────────────────────────────────────────────────

  /// Fetch all active admin-created badge definitions from Firestore and
  /// upsert them into the local catalog.  Designed to run fire-and-forget
  /// immediately after [init]; silently skips when the device is offline.
  Future<void> hydrateFromFirestore() async {
    try {
      if (!await _isOnline()) return;

      final snap = await FirebaseFirestore.instance
          .collection('badge_definitions')
          .where('isActive', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) return;

      bool changed = false;
      for (final doc in snap.docs) {
        final incoming = _fromFirestoreDoc(doc);
        final idx = _catalog.indexWhere((b) => b.id == doc.id);
        if (idx == -1) {
          _catalog.add(incoming);
          changed = true;
        } else {
          // Always upsert so admin edits (points, title, tier) propagate.
          _catalog[idx] = incoming;
          changed = true;
        }
      }

      if (changed) await _persist();
    } catch (e) {
      AppLogger.i('[BadgeRepository] hydrateFromFirestore error: $e');
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<void> _seedFromAsset() async {
    final jsonString = await rootBundle.loadString('assets/data/badge.json');
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final list =
        (data['badges'] as List<dynamic>).cast<Map<String, dynamic>>();
    _catalog = list.map(UserBadge.fromJson).toList();
    await _persist();
  }

  List<UserBadge> _decodeList(String stored) {
    try {
      final list =
          (jsonDecode(stored) as List<dynamic>).cast<Map<String, dynamic>>();
      return list.map(UserBadge.fromJson).toList();
    } catch (e) {
      AppLogger.i('[BadgeRepository] corrupt cache — will reseed: $e');
      return [];
    }
  }

  Future<void> _persist() async {
    final list = _catalog.map((b) => b.toJson()).toList();
    await _prefs!.setString(_catalogKey, jsonEncode(list));
  }

  /// Convert a Firestore badge_definitions document to a [UserBadge].
  ///
  /// Admin-created badges omit fields that only exist in the bundled asset
  /// (category, icon, requirement, rarity, difficulty); sensible defaults
  /// are applied so the gallery renders them cleanly.
  UserBadge _fromFirestoreDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    final vtRaw = (d['verificationType'] as String? ?? 'SCAN').toUpperCase();
    final vt = vtRaw == 'MANUAL_IMAGE_REVIEW'
        ? VerificationType.manualImageReview
        : vtRaw == 'SESSION'
            ? VerificationType.session
            : VerificationType.scan;

    return UserBadge(
      id: doc.id,
      name: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      category: 'admin_created',
      icon: 'trophy',
      requirement: {
        'type': vt == VerificationType.manualImageReview
            ? 'manual_image_review'
            : 'reach_location',
        'value': '',
      },
      rarity: 'rare',
      difficulty: 'medium',
      tier: d['tier'] as String? ?? 'bronze',
      verificationType: vt,
      triggerStationId: null,
      points: (d['points'] as num?)?.toInt() ?? 0,
      isLimitedEdition: d['isLimitedEdition'] as bool? ?? false,
      startDate: _parseDate(d['startDate']),
      endDate: _parseDate(d['endDate']),
      visibilityRule: d['visibilityRule'] as String? ?? 'ALWAYS_VISIBLE',
      tracking: d['tracking'] as Map<String, dynamic>?,
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  Future<bool> _isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
}
