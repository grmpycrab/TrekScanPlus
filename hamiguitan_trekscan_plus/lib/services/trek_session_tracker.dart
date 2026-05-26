import 'package:shared_preferences/shared_preferences.dart';

/// Tracks cumulative trek-session data locally in SharedPreferences.
/// Used by [AchievementService.checkSessionMilestones] to evaluate
/// volume-milestone and meta-session badge criteria offline.
class TrekSessionTracker {
  TrekSessionTracker._();
  static final TrekSessionTracker instance = TrekSessionTracker._();

  static const _keyTotalSessions = 'trek_total_completed_sessions';
  static const _keySessionDates  = 'trek_session_dates';
  static const _keySummitCount   = 'trek_summit_visit_count';

  int _totalSessions = 0;
  List<DateTime> _sessionDates = [];
  int _summitVisitCount = 0;

  int get totalCompletedSessions => _totalSessions;
  int get summitVisitCount => _summitVisitCount;
  List<DateTime> get sessionDates => List.unmodifiable(_sessionDates);

  /// Must be called once at app start (or before the first milestone check).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _totalSessions = prefs.getInt(_keyTotalSessions) ?? 0;
    _summitVisitCount = prefs.getInt(_keySummitCount) ?? 0;

    final raw = prefs.getStringList(_keySessionDates) ?? [];
    _sessionDates = raw
        .map((s) => DateTime.tryParse(s))
        .whereType<DateTime>()
        .toList();
  }

  /// Call this at the END of each full completed trek session.
  /// [date] is the date of the completed session (defaults to now).
  /// [visitedSummit] set to true when the summit QR (mr2l529okj) was scanned.
  Future<void> recordCompletedSession({
    DateTime? date,
    bool visitedSummit = false,
  }) async {
    final sessionDate = date ?? DateTime.now();
    _totalSessions += 1;
    _sessionDates.add(sessionDate);
    if (visitedSummit) _summitVisitCount += 1;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalSessions, _totalSessions);
    await prefs.setInt(_keySummitCount, _summitVisitCount);
    await prefs.setStringList(
      _keySessionDates,
      _sessionDates.map((d) => d.toIso8601String()).toList(),
    );
  }

  /// Returns sessions completed within the rolling 30-day window from now.
  List<DateTime> getSessionsInLast30Days() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return _sessionDates.where((d) => d.isAfter(cutoff)).toList();
  }

  /// Returns the number of distinct climatic quarters spanned by all sessions.
  /// Quarter mapping: Q1 = Jan–Mar, Q2 = Apr–Jun, Q3 = Jul–Sep, Q4 = Oct–Dec.
  int getDistinctClimaticQuarters() {
    final quarters = _sessionDates
        .map((d) => '${d.year}-Q${((d.month - 1) ~/ 3) + 1}')
        .toSet();
    return quarters.length;
  }
}
