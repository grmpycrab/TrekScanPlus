import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/calendar_config_service.dart';
import '../../../utils/app_logger.dart';

/// Service for validating trek dates and checking availability
/// Handles buffer periods, closures, and slot availability
class DateValidationService {
  static final DateValidationService _instance =
      DateValidationService._internal();

  factory DateValidationService() {
    return _instance;
  }

  DateValidationService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _calendarService = CalendarConfigService();

  /// Check if a date falls in buffer period (trek down day)
  /// Returns the conflicting booking date if found, null otherwise
  Future<DateTime?> checkBufferPeriod(DateTime date) async {
    try {
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

      return snapshot.docs.isNotEmpty ? dayBefore : null;
    } catch (e) {
      AppLogger.e('Error checking buffer period: $e');
      return null;
    }
  }

  /// Check if selected date has available slots
  /// Returns map with availability details (available, slotsUsed, slotsNeeded, etc.)
  Future<Map<String, dynamic>> checkDateAvailability(
    DateTime date,
    int totalMembers,
  ) async {
    try {
      // Get calendar config for this date
      final dateConfig = await _calendarService.getDateConfig(date);

      // Check if date is closed
      if (dateConfig.isClosed) {
        return {
          'available': false,
          'slotsUsed': 0,
          'slotsNeeded': 1,
          'maxSlots': dateConfig.maxSlots,
          'remaining': 0,
          'isClosed': true,
          'closureReason': dateConfig.reason,
        };
      }

      // Check for buffer period (trek down day)
      final conflictDate = await checkBufferPeriod(date);
      if (conflictDate != null) {
        final conflictDateStr =
            '${conflictDate.year}-${conflictDate.month.toString().padLeft(2, '0')}-${conflictDate.day.toString().padLeft(2, '0')}';
        return {
          'available': false,
          'slotsUsed': 0,
          'slotsNeeded': 1,
          'maxSlots': dateConfig.maxSlots,
          'remaining': 0,
          'isClosed': false,
          'isBufferDay': true,
          'conflictDate': conflictDateStr,
        };
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

      return {
        'available': available,
        'slotsUsed': slotsUsed,
        'slotsNeeded': slotsNeeded,
        'maxSlots': maxSlots,
        'remaining': remaining,
        'isClosed': false,
      };
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
