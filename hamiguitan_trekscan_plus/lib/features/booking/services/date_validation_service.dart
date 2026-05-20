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

      // Get max slots for this date (total site capacity: trekkers + porters)
      final maxSlots = dateConfig.maxSlots;

      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      final tsStart = Timestamp.fromDate(startOfDay);
      final tsEnd = Timestamp.fromDate(endOfDay);

      // Count approved individual bookings
      final indivSnap = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'approved')
          .where('trekDate', isGreaterThanOrEqualTo: tsStart)
          .where('trekDate', isLessThanOrEqualTo: tsEnd)
          .get();
      final indivTrekkers = indivSnap.docs.length;

      // Count trekkers from active group bookings (open / pending_review / approved / full)
      final groupSnap = await _firestore
          .collection('groupBookings')
          .where('trekDate', isGreaterThanOrEqualTo: tsStart)
          .where('trekDate', isLessThanOrEqualTo: tsEnd)
          .get();
      final groupTrekkers = groupSnap.docs
          .where((d) {
            final s = d['status'] as String? ?? '';
            return s != 'cancelled' && s != 'declined';
          })
          .fold<int>(
              0, (acc, d) => acc + ((d['currentSlots'] as num?)?.toInt() ?? 0));

      // Total trekkers on site for this date
      final bookedTrekkers = indivTrekkers + groupTrekkers;

      // Porter ratio: 1 porter per every 5 trekkers (floor division).
      // Porter positions count toward total site capacity.
      final allocatedPorters = bookedTrekkers ~/ 5;
      final slotsUsed = bookedTrekkers + allocatedPorters;

      // How many porters the incoming party will require
      final incomingPorters = totalMembers ~/ 5;
      final slotsNeeded = totalMembers + incomingPorters;

      final available = (slotsUsed + slotsNeeded) <= maxSlots;
      final remaining = maxSlots - slotsUsed;
      // Express remaining in trekker-equivalent slots (5 trekkers use 6 site slots)
      final remainingTrekkerSlots = (remaining * 5) ~/ 6;

      final result = {
        'available': available,
        'slotsUsed': slotsUsed,
        'bookedTrekkers': bookedTrekkers,
        'allocatedPorters': allocatedPorters,
        'slotsNeeded': slotsNeeded,
        'maxSlots': maxSlots,
        'remaining': remaining,
        'remainingTrekkerSlots': remainingTrekkerSlots,
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
        'bookedTrekkers': 0,
        'allocatedPorters': 0,
        'slotsNeeded': totalMembers,
        'maxSlots': 30,
        'remaining': 30,
        'remainingTrekkerSlots': 25,
        'isClosed': false,
      };
    }
  }

  /// Format date for display (YYYY-MM-DD)
  String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
