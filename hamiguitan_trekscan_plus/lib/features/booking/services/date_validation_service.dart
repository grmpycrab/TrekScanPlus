import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/calendar_config_service.dart';
import '../../../utils/app_logger.dart';

/// Service for validating trek dates and checking availability
/// Handles buffer periods, closures, and slot availability with caching
class DateValidationService {
  static final DateValidationService _instance =
      DateValidationService._internal();

  factory DateValidationService() {
    return _instance;
  }

  DateValidationService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _calendarService = CalendarConfigService();

  // Cache for date availability queries (key: YYYY-MM-DD, value: result map)
  final Map<String, Map<String, dynamic>> _availabilityCache = {};
  // Cache for buffer period checks (key: YYYY-MM-DD, value: conflict date or null)
  final Map<String, DateTime?> _bufferCache = {};

  /// Clear all caches (useful for testing or manual refresh)
  void clearCache() {
    _availabilityCache.clear();
    _bufferCache.clear();
  }

  /// Clear cache for a specific date
  void clearCacheForDate(DateTime date) {
    final dateStr = formatDate(date);
    _availabilityCache.remove(dateStr);
    _bufferCache.remove(dateStr);
  }

  /// Check if a date falls in buffer period (trek down day)
  /// Returns the conflicting booking date if found, null otherwise
  /// Results are cached to prevent repeated Firestore queries
  Future<DateTime?> checkBufferPeriod(DateTime date) async {
    try {
      final dateStr = formatDate(date);

      // Return cached result if available
      if (_bufferCache.containsKey(dateStr)) {
        return _bufferCache[dateStr];
      }

      final dayBefore = date.subtract(const Duration(days: 1));
      final dayBeforeStart = DateTime(
        dayBefore.year,
        dayBefore.month,
        dayBefore.day,
        0,
        0,
        0,
      );
      final dayBeforeEnd = DateTime(
        dayBefore.year,
        dayBefore.month,
        dayBefore.day,
        23,
        59,
        59,
      );

      final snapshot = await _firestore
          .collection('bookings')
          .where(
            'trekDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayBeforeStart),
          )
          .where(
            'trekDate',
            isLessThanOrEqualTo: Timestamp.fromDate(dayBeforeEnd),
          )
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      final result = snapshot.docs.isNotEmpty ? dayBefore : null;
      _bufferCache[dateStr] = result; // Cache the result
      return result;
    } catch (e) {
      AppLogger.e('Error checking buffer period: $e');
      return null;
    }
  }

  /// Check if selected date has available slots
  /// Returns map with availability details (available, slotsUsed, slotsNeeded, etc.)
  /// Results are cached to prevent repeated Firestore queries
  Future<Map<String, dynamic>> checkDateAvailability(
    DateTime date,
    int totalMembers,
  ) async {
    try {
      final dateStr = formatDate(date);

      // Return cached result if available
      if (_availabilityCache.containsKey(dateStr)) {
        return _availabilityCache[dateStr]!;
      }

      // Get calendar config for this date
      final dateConfig = await _calendarService.getDateConfig(date);

      // Check if date is closed
      if (dateConfig.isClosed) {
        final result = {
          'available': false,
          'slotsUsed': 0,
          'slotsNeeded': 1,
          'maxSlots': dateConfig.maxSlots,
          'remaining': 0,
          'isClosed': true,
          'closureReason': dateConfig.reason,
        };
        _availabilityCache[dateStr] = result;
        return result;
      }

      // Check for buffer period (trek down day)
      final conflictDate = await checkBufferPeriod(date);
      if (conflictDate != null) {
        final conflictDateStr =
            '${conflictDate.year}-${conflictDate.month.toString().padLeft(2, '0')}-${conflictDate.day.toString().padLeft(2, '0')}';
        final result = {
          'available': false,
          'slotsUsed': 0,
          'slotsNeeded': 1,
          'maxSlots': dateConfig.maxSlots,
          'remaining': 0,
          'isClosed': false,
          'isBufferDay': true,
          'conflictDate': conflictDateStr,
        };
        _availabilityCache[dateStr] = result;
        return result;
      }

      // Get max slots for this date
      final maxSlots = dateConfig.maxSlots;

      // Query approved bookings for this date
      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'approved')
          .where(
            'trekDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('trekDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      // Count approved bookings (all docs in snapshot are already approved due to filter)
      int slotsUsed = snapshot.docs.length;

      final slotsNeeded = 1; // Only count primary trekker
      final available = (slotsUsed + slotsNeeded) <= maxSlots;
      final remaining = maxSlots - slotsUsed;

      final result = {
        'available': available,
        'slotsUsed': slotsUsed,
        'slotsNeeded': slotsNeeded,
        'maxSlots': maxSlots,
        'remaining': remaining,
        'isClosed': false,
      };
      _availabilityCache[dateStr] = result;
      return result;
    } catch (e) {
      AppLogger.e('Error checking date availability: $e');
      // Fail open - allow booking on error
      return {
        'available': true,
        'slotsUsed': 0,
        'slotsNeeded': 1,
        'maxSlots': 30,
        'remaining': 30,
        'isClosed': false,
      };
    }
  }

  /// Format date for display (YYYY-MM-DD)
  String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
