class TrekDay {
  final DateTime date;
  final TrekDayStatus status;
  final bool isResearchDay;
  final int maxSlots;
  final int bookedSlots;

  const TrekDay({
    required this.date,
    required this.status,
    this.isResearchDay = false,
    this.maxSlots = 20, // Default max slots per day
    this.bookedSlots = 0,
  });

  bool get isFull => bookedSlots >= maxSlots;
  bool get isWeekend =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  bool get isAvailable =>
      status == TrekDayStatus.available &&
      (isResearchDay || isWeekend) &&
      !isFull;
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
