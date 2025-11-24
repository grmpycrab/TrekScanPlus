import 'package:cloud_firestore/cloud_firestore.dart';
//import '../models/calendar_model.dart';

/// Service for managing centralized calendar configuration in Firestore
///
/// Collections:
/// - `system_settings/calendar` - Global calendar defaults (default max slots, etc.)
/// - `calendar_config/{dateKey}` - Date-specific overrides (closed dates, custom limits)
class CalendarConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for system settings to reduce Firestore reads
  Map<String, dynamic>? _systemSettingsCache;
  DateTime? _cacheTimestamp;
  static const _cacheValidityDuration = Duration(minutes: 5);

  /// Get system-wide calendar settings (default max slots, etc.)
  Future<Map<String, dynamic>> getSystemSettings() async {
    // Return cached settings if still valid
    if (_systemSettingsCache != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheValidityDuration) {
      return _systemSettingsCache!;
    }

    try {
      final doc = await _firestore
          .collection('system_settings')
          .doc('calendar')
          .get();

      if (doc.exists && doc.data() != null) {
        _systemSettingsCache = doc.data()!;
        _cacheTimestamp = DateTime.now();
        return _systemSettingsCache!;
      }

      // Return defaults if document doesn't exist
      final defaults = {
        'defaultMaxSlots': 30,
        'criticalThreshold': 5, // Show warning when <= 5 slots left
        'allowWeekendBookings': true,
        'advanceBookingDays': 90, // How far in advance users can book
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Create the document with defaults
      await _firestore
          .collection('system_settings')
          .doc('calendar')
          .set(defaults);

      _systemSettingsCache = defaults;
      _cacheTimestamp = DateTime.now();
      return defaults;
    } catch (e) {
      print('Error getting system settings: $e');
      // Return hardcoded defaults on error
      return {
        'defaultMaxSlots': 30,
        'criticalThreshold': 5,
        'allowWeekendBookings': true,
        'advanceBookingDays': 90,
      };
    }
  }

  /// Get configuration for a specific date
  /// Returns merged config (date-specific overrides + system defaults)
  Future<DateConfig> getDateConfig(DateTime date) async {
    final dateKey = _formatDateKey(date);
    final systemSettings = await getSystemSettings();
    final defaultMaxSlots = systemSettings['defaultMaxSlots'] as int? ?? 30;

    try {
      final doc = await _firestore
          .collection('calendar_config')
          .doc(dateKey)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return DateConfig.fromFirestore(data, defaultMaxSlots);
      }

      // No date-specific config, return defaults
      return DateConfig(
        date: date,
        isClosed: false,
        maxSlots: defaultMaxSlots,
        reason: null,
        customNote: null,
      );
    } catch (e) {
      print('Error getting date config for $dateKey: $e');
      // Return defaults on error
      return DateConfig(
        date: date,
        isClosed: false,
        maxSlots: defaultMaxSlots,
        reason: null,
        customNote: null,
      );
    }
  }

  /// Get configurations for a date range (for calendar display)
  Future<Map<String, DateConfig>> getDateRangeConfig(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final systemSettings = await getSystemSettings();
    final defaultMaxSlots = systemSettings['defaultMaxSlots'] as int? ?? 30;

    try {
      // Query date-specific configs in range
      final startKey = _formatDateKey(startDate);
      final endKey = _formatDateKey(endDate);

      final snapshot = await _firestore
          .collection('calendar_config')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
          .get();

      final Map<String, DateConfig> configs = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dateKey = doc.id;
        configs[dateKey] = DateConfig.fromFirestore(data, defaultMaxSlots);
      }

      return configs;
    } catch (e) {
      print('Error getting date range config: $e');
      return {};
    }
  }

  /// Close a specific date (admin only)
  Future<void> closeDate(
    DateTime date, {
    String? reason,
    String? customNote,
  }) async {
    final dateKey = _formatDateKey(date);

    await _firestore.collection('calendar_config').doc(dateKey).set({
      'date': Timestamp.fromDate(date),
      'isClosed': true,
      'reason': reason ?? 'Closed by admin',
      'customNote': customNote,
      'maxSlots': 0, // No bookings allowed
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Open a previously closed date (admin only)
  Future<void> openDate(DateTime date, {int? maxSlots}) async {
    final dateKey = _formatDateKey(date);
    final systemSettings = await getSystemSettings();
    final defaultMaxSlots = systemSettings['defaultMaxSlots'] as int? ?? 30;

    await _firestore.collection('calendar_config').doc(dateKey).set({
      'date': Timestamp.fromDate(date),
      'isClosed': false,
      'reason': null,
      'customNote': null,
      'maxSlots': maxSlots ?? defaultMaxSlots,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Set custom slot limit for a specific date (admin only)
  Future<void> setDateMaxSlots(DateTime date, int maxSlots) async {
    final dateKey = _formatDateKey(date);

    await _firestore.collection('calendar_config').doc(dateKey).set({
      'date': Timestamp.fromDate(date),
      'maxSlots': maxSlots,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Delete date-specific configuration (revert to defaults)
  Future<void> deleteeDateConfig(DateTime date) async {
    final dateKey = _formatDateKey(date);
    await _firestore.collection('calendar_config').doc(dateKey).delete();
  }

  /// Update system-wide settings (admin only)
  Future<void> updateSystemSettings({
    int? defaultMaxSlots,
    int? criticalThreshold,
    bool? allowWeekendBookings,
    int? advanceBookingDays,
  }) async {
    final updates = <String, dynamic>{
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    if (defaultMaxSlots != null) updates['defaultMaxSlots'] = defaultMaxSlots;
    if (criticalThreshold != null)
      updates['criticalThreshold'] = criticalThreshold;
    if (allowWeekendBookings != null)
      updates['allowWeekendBookings'] = allowWeekendBookings;
    if (advanceBookingDays != null)
      updates['advanceBookingDays'] = advanceBookingDays;

    await _firestore
        .collection('system_settings')
        .doc('calendar')
        .set(updates, SetOptions(merge: true));

    // Invalidate cache
    _systemSettingsCache = null;
    _cacheTimestamp = null;
  }

  /// Stream of system settings changes (for real-time updates)
  Stream<Map<String, dynamic>> watchSystemSettings() {
    return _firestore
        .collection('system_settings')
        .doc('calendar')
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return doc.data()!;
          }
          return {
            'defaultMaxSlots': 30,
            'criticalThreshold': 5,
            'allowWeekendBookings': true,
            'advanceBookingDays': 90,
          };
        });
  }

  /// Stream of date-specific config changes
  Stream<DateConfig> watchDateConfig(DateTime date) {
    final dateKey = _formatDateKey(date);

    return _firestore
        .collection('calendar_config')
        .doc(dateKey)
        .snapshots()
        .asyncMap((doc) async {
          final systemSettings = await getSystemSettings();
          final defaultMaxSlots =
              systemSettings['defaultMaxSlots'] as int? ?? 30;

          if (doc.exists && doc.data() != null) {
            return DateConfig.fromFirestore(doc.data()!, defaultMaxSlots);
          }

          return DateConfig(
            date: date,
            isClosed: false,
            maxSlots: defaultMaxSlots,
            reason: null,
            customNote: null,
          );
        });
  }

  /// Format date as Firestore document key (YYYY-MM-DD)
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Parse date from Firestore document key
  DateTime parseDateKey(String dateKey) {
    final parts = dateKey.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}

/// Date-specific configuration model
class DateConfig {
  final DateTime date;
  final bool isClosed;
  final int maxSlots;
  final String? reason; // Reason for closure or special config
  final String? customNote; // Admin notes

  DateConfig({
    required this.date,
    required this.isClosed,
    required this.maxSlots,
    this.reason,
    this.customNote,
  });

  factory DateConfig.fromFirestore(
    Map<String, dynamic> data,
    int defaultMaxSlots,
  ) {
    final timestamp = data['date'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();

    return DateConfig(
      date: date,
      isClosed: data['isClosed'] as bool? ?? false,
      maxSlots: data['maxSlots'] as int? ?? defaultMaxSlots,
      reason: data['reason'] as String?,
      customNote: data['customNote'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'isClosed': isClosed,
      'maxSlots': maxSlots,
      'reason': reason,
      'customNote': customNote,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}
