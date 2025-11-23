import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_model.dart';
import '../theme/color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class EventCalendar extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime)? onDaySelected;
  final Function(DateTime)? onMonthChanged;
  final List<TrekDay> trekDays;

  EventCalendar({
    super.key,
    DateTime? initialDate,
    this.onDaySelected,
    this.onMonthChanged,
    required this.trekDays,
  }) : initialDate = initialDate ?? DateTime.now();

  @override
  State<EventCalendar> createState() => _EventCalendarState();
}

class _EventCalendarState extends State<EventCalendar> {
  late DateTime _currentMonth;
  late List<String> _weekDays;
  late List<TrekDay> _displayTrekDays;
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    _displayTrekDays = widget.trekDays;
    _subscribeToBookings(_currentMonth);
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToBookings(DateTime month) {
    _bookingsSubscription?.cancel();
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final startTs = Timestamp.fromDate(
      DateTime(firstDay.year, firstDay.month, firstDay.day),
    );
    final endTs = Timestamp.fromDate(lastDay);

    _bookingsSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .where('trekDate', isGreaterThanOrEqualTo: startTs)
        .where('trekDate', isLessThanOrEqualTo: endTs)
        .snapshots()
        .listen((snap) {
          // Only count approved bookings toward the slot limit
          final Map<String, int> slotsPerDay = {};
          for (final doc in snap.docs) {
            final data = doc.data();
            final status = (data['status'] as String?)?.toLowerCase() ?? '';

            // Only count approved bookings - pending bookings don't reserve slots
            if (status != 'approved') continue;

            final Timestamp? t = data['trekDate'] as Timestamp?;
            if (t == null) continue;
            final d = t.toDate();
            final key = '${d.year}-${d.month}-${d.day}';
            final porters = (data['numberOfPorters'] as num?)?.toInt() ?? 0;
            final used = 1 + porters;
            slotsPerDay[key] = (slotsPerDay[key] ?? 0) + used;
          }

          if (!mounted) return;
          setState(() {
            final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
            _displayTrekDays = List.generate(daysInMonth, (index) {
              final date = DateTime(month.year, month.month, index + 1);
              final key = '${date.year}-${date.month}-${date.day}';
              final booked = slotsPerDay[key] ?? 0;
              const maxSlots = 30;
              TrekDayStatus status;
              if (booked >= maxSlots) {
                status = TrekDayStatus.full;
              } else if (booked >= (maxSlots - 5)) {
                status = TrekDayStatus.critical;
              } else {
                status = TrekDayStatus.available;
              }
              final isResearchDay = date.weekday == DateTime.wednesday;
              return TrekDay(
                date: date,
                status: status,
                isResearchDay: isResearchDay,
                bookedSlots: booked,
                maxSlots: maxSlots,
              );
            });
          });
        });
  }

  void _previousMonth() {
    final newMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    setState(() {
      _currentMonth = newMonth;
    });
    _subscribeToBookings(newMonth);
  }

  void _nextMonth() {
    final newMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    setState(() {
      _currentMonth = newMonth;
    });
    _subscribeToBookings(newMonth);
  }

  TrekDay? _getTrekDay(DateTime date) {
    return _displayTrekDays.firstWhere(
      (day) =>
          day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day,
      orElse: () => TrekDay(
        date: date,
        status: TrekDayStatus.closed,
        isResearchDay: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Booking Calendar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Calendar content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildCalendarGrid(),
                    const SizedBox(height: 16),
                    _buildLegend(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _previousMonth,
        ),
        Text(
          DateFormat('MMMM yyyy').format(_currentMonth),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _nextMonth,
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    return SizedBox(
      height:
          380, // Week headers (~20px) + 6 rows × 56px (48px cell + 8px padding)
      child: Column(
        children: [
          _buildWeekdayHeaders(),
          const SizedBox(height: 8),
          ..._buildWeeks(),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _weekDays
          .map(
            (day) => Expanded(
              child: Text(
                day,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          )
          .toList(),
    );
  }

  List<Widget> _buildWeeks() {
    final List<Widget> weeks = [];
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    // Calculate the start of the first week (Sunday)
    var startDate = firstDay.subtract(Duration(days: firstDay.weekday % 7));

    // Calculate weeks
    while (startDate.isBefore(lastDay) || startDate.month == lastDay.month) {
      weeks.add(_buildWeek(startDate));
      startDate = startDate.add(const Duration(days: 7));
    }

    return weeks;
  }

  Widget _buildWeek(DateTime weekStart) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          final date = weekStart.add(Duration(days: index));
          final trekDay = _getTrekDay(date);

          return Expanded(child: Center(child: _buildDayCell(date, trekDay)));
        }),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, TrekDay? trekDay) {
    final actualTrekDay =
        trekDay ??
        TrekDay(date: date, status: TrekDayStatus.closed, isResearchDay: false);
    final isCurrentMonth = date.month == _currentMonth.month;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentDate = DateTime(date.year, date.month, date.day);
    final isToday = currentDate == today;
    final isPastDate = currentDate.isBefore(today);

    Color textColor;
    Color? backgroundColor;
    Color? borderColor;
    Color? badgeColor;
    String? displayText;

    if (!isCurrentMonth) {
      textColor = Colors.grey.shade300;
    } else if (isPastDate) {
      // Gray out past dates
      textColor = Colors.grey.shade400;
      backgroundColor = Colors.grey.withValues(alpha: 0.05);
    } else {
      final bookedSlots = actualTrekDay.bookedSlots;
      final maxSlots = actualTrekDay.maxSlots;
      final remainingSlots = maxSlots - bookedSlots;

      // Default text color for date number
      textColor = Colors.grey.shade700;

      if (bookedSlots >= maxSlots) {
        // Full - show red badge
        badgeColor = Colors.red;
      } else if (remainingSlots <= 10) {
        // Limited slots - show orange badge
        badgeColor = Colors.orange;
      } else if (bookedSlots > 0) {
        // Has bookings - show green badge
        badgeColor = const Color(0xFF06402B);
      }

      // Show booked count if there are bookings
      if (bookedSlots > 0) {
        displayText = bookedSlots.toString();
      }
    }

    if (isToday && !isPastDate) {
      borderColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: isCurrentMonth && !isPastDate && widget.onDaySelected != null
          ? () => widget.onDaySelected!(date)
          : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: borderColor != null
              ? Border.all(color: borderColor, width: 2)
              : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // Day number
            Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            // Booked count badge (if any)
            if (displayText != null)
              Positioned(
                right: 3,
                top: 3,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Center(
                    child: Text(
                      displayText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Available', const Color(0xFF06402B)),
        const SizedBox(width: 12),
        _buildLegendItem('Limited Slots Remaining', Colors.orange),
        const SizedBox(width: 12),
        _buildLegendItem('Full', Colors.red),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 2, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
