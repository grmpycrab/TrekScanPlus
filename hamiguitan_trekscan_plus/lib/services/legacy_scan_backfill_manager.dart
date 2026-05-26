// Runs exactly once per user install (guarded by a SharedPreferences flag).
// Subsequent app starts return immediately from the guard check.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'achievement_service.dart';
import 'station_service.dart';
import '../utils/app_logger.dart';

/// Structural data migration that backfills badge achievements for stations
/// the user visited before the badge system was introduced.
///
/// Execution order inside [AchievementService.init]:
///   1. Badge catalog loaded from [BadgeRepository] (local cache).
///   2. User unlock state merged from [LocalAchievementService] + Firestore.
///   3. [LegacyScanBackfillManager.run] fires unawaited in background.
///      a. Guard: returns immediately if already ran for this user.
///      b. Reads visited station IDs from [StationService].
///      c. Fetches original check-in timestamps from Firestore visitedStations.
///      d. Calls [AchievementService.backfillAchievementsFromStations] with
///         {stationId → visitedAt} map so badges are unlocked with accurate
///         historical dates and syncStatus = PENDING_SYNC.
///      e. Marks migration complete in SharedPreferences.
class LegacyScanBackfillManager {
  LegacyScanBackfillManager._();
  static final LegacyScanBackfillManager instance =
      LegacyScanBackfillManager._();

  // Bump the version suffix when the migration logic changes incompatibly
  // so existing users re-run the backfill with the updated rules.
  static const _keyPrefix = 'backfill_scan_v1_';

  /// Entry point — fire unawaited from [AchievementService.init].
  Future<void> run({
    required String userId,
    required AchievementService achievementService,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final guardKey = '$_keyPrefix$userId';

    // Fast-path: migration already completed for this user.
    if (prefs.getBool(guardKey) == true) return;

    try {
      // StationService.init() is idempotent — safe to call even if already
      // initialized elsewhere in the app startup sequence.
      final stationService = await StationService.init(userId: userId);
      await stationService.loadStations();

      // Collect stations marked visited in the local cache.
      // StationService.getVisitedStations() checks the mutable `isVisited`
      // field, which covers both the current 'isVisited' schema and any
      // legacy 'visited' variant that was deserialized as the same field.
      final visitedStations = stationService.getVisitedStations();
      if (visitedStations.isEmpty) {
        await prefs.setBool(guardKey, true);
        return;
      }

      // Try to retrieve authoritative check-in timestamps from Firestore.
      // Falls back gracefully if the device is offline.
      final firestoreTimestamps = await _fetchFirestoreTimestamps(userId);

      // Timestamp resolution priority:
      //   1. Firestore visitedStations.visitedAt  — server-assigned, most accurate
      //   2. station.lastScanned                  — locally recorded scan time
      //   3. null → AchievementService falls back to DateTime.now()
      final stationTimestamps = <String, DateTime?>{
        for (final station in visitedStations)
          station.id: firestoreTimestamps[station.id] ?? station.lastScanned,
      };

      await achievementService.backfillAchievementsFromStations(
        stationTimestamps,
      );

      // Persist the guard only after a successful backfill so a crash or
      // partial run retries cleanly on next startup.
      await prefs.setBool(guardKey, true);

      AppLogger.i(
        '[LegacyScanBackfillManager] completed — '
        '${visitedStations.length} station(s) evaluated for user $userId',
      );
    } catch (e) {
      // Do NOT set the guard flag — allow a retry on the next startup.
      AppLogger.i('[LegacyScanBackfillManager] error (will retry): $e');
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Fetch {stationId → visitedAt} from Firestore for historical timestamp
  /// preservation.  Returns an empty map when offline or unauthenticated.
  Future<Map<String, DateTime?>> _fetchFirestoreTimestamps(
    String userId,
  ) async {
    final result = <String, DateTime?>{};
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('visitedStations')
          .get();

      for (final doc in snap.docs) {
        final raw = doc.data()['visitedAt'];
        // Firestore native Timestamp (server-set via FieldValue.serverTimestamp)
        if (raw is Timestamp) {
          result[doc.id] = raw.toDate();
        } else if (raw is String && raw.isNotEmpty) {
          // ISO-8601 string stored by older app versions
          result[doc.id] = DateTime.tryParse(raw);
        }
      }
    } catch (_) {
      // Offline, auth error, or missing collection — proceed with local timestamps.
    }
    return result;
  }
}
