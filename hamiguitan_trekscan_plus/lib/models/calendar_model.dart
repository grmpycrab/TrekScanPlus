class TrekDay {
  final DateTime date;
  final TrekDayStatus status;
  final bool isResearchDay;
  final int maxSlots;
  final int bookedSlots;
  final bool isClosed;
  final String? closureReason;

  const TrekDay({
    required this.date,
    required this.status,
    this.isResearchDay = false,
    this.maxSlots = 30,
    this.bookedSlots = 0,
    this.isClosed = false,
    this.closureReason,
  });

  bool get isFull => bookedSlots >= maxSlots;
  bool get isWeekend =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  bool get isAvailable =>
      status == TrekDayStatus.available && !isFull && !isClosed;

  /// Create a TrekDay from booked slot count and calendar configuration
  factory TrekDay.fromBookingData({
    required DateTime date,
    required int bookedSlots,
    required int maxSlots,
    required int criticalThreshold,
    bool isClosed = false,
    String? closureReason,
    bool isResearchDay = false,
  }) {
    TrekDayStatus status;

    if (isClosed) {
      status = TrekDayStatus.closed;
    } else if (bookedSlots >= maxSlots) {
      status = TrekDayStatus.full;
    } else if (maxSlots - bookedSlots <= criticalThreshold) {
      status = TrekDayStatus.critical;
    } else {
      status = TrekDayStatus.available;
    }

    return TrekDay(
      date: date,
      status: status,
      maxSlots: maxSlots,
      bookedSlots: bookedSlots,
      isClosed: isClosed,
      closureReason: closureReason,
      isResearchDay: isResearchDay,
    );
  }

  TrekDay copyWith({
    DateTime? date,
    TrekDayStatus? status,
    bool? isResearchDay,
    int? maxSlots,
    int? bookedSlots,
    bool? isClosed,
    String? closureReason,
  }) {
    return TrekDay(
      date: date ?? this.date,
      status: status ?? this.status,
      isResearchDay: isResearchDay ?? this.isResearchDay,
      maxSlots: maxSlots ?? this.maxSlots,
      bookedSlots: bookedSlots ?? this.bookedSlots,
      isClosed: isClosed ?? this.isClosed,
      closureReason: closureReason ?? this.closureReason,
    );
  }
}

enum TrekDayStatus {
  available,
  critical, // Few slots left
  full,
  closed, // Maintenance or special events
}

extension TrekDayStatusColor on TrekDayStatus {
  String toColorString() {
    switch (this) {
      case TrekDayStatus.available:
        return '#4CAF50'; // Green
      case TrekDayStatus.critical:
        return '#FFA000'; // Orange
      case TrekDayStatus.full:
        return '#F44336'; // Red
      case TrekDayStatus.closed:
        return '#9E9E9E'; // Grey
    }
  }
}
