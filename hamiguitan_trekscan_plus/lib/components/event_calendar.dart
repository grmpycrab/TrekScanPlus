import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_model.dart';
import '../theme/color.dart';

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

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _weekDays = ['mo', 'tu', 'wed', 'th', 'fri', 'sat', 'sun'];
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    if (widget.onMonthChanged != null) widget.onMonthChanged!(_currentMonth);
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    if (widget.onMonthChanged != null) widget.onMonthChanged!(_currentMonth);
  }

  TrekDay? _getTrekDay(DateTime date) {
    return widget.trekDays.firstWhere(
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
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        _buildCalendarGrid(),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
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
    return Column(
      children: [
        _buildWeekdayHeaders(),
        const SizedBox(height: 8),
        ..._buildWeeks(),
      ],
    );
  }

  Widget _buildWeekdayHeaders() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _weekDays
          .map(
            (day) => SizedBox(
              width: 40,
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

    // Calculate the start of the first week (Monday)
    var startDate = firstDay.subtract(Duration(days: firstDay.weekday - 1));

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

          return _buildDayCell(date, trekDay);
        }),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, TrekDay? trekDay) {
    final actualTrekDay =
        trekDay ??
        TrekDay(date: date, status: TrekDayStatus.closed, isResearchDay: false);
    final isCurrentMonth = date.month == _currentMonth.month;
    final isToday = date.difference(DateTime.now()).inDays == 0;

    Color textColor;
    Color? backgroundColor;
    Color? borderColor;

    if (!isCurrentMonth) {
      textColor = Colors.grey.shade300;
    } else if (actualTrekDay.isAvailable) {
      textColor = Colors.green;
      backgroundColor = Colors.green.withOpacity(0.1);
      borderColor = Colors.green;
    } else if (actualTrekDay.status == TrekDayStatus.critical) {
      textColor = Colors.orange;
      backgroundColor = Colors.orange.withOpacity(0.1);
      borderColor = Colors.orange;
    } else if (actualTrekDay.status == TrekDayStatus.full) {
      textColor = Colors.red;
      backgroundColor = Colors.red.withOpacity(0.1);
      borderColor = Colors.red;
    } else {
      textColor = Colors.grey;
    }

    if (isToday) {
      borderColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: isCurrentMonth && widget.onDaySelected != null
          ? () => widget.onDaySelected!(date)
          : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1)
              : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: textColor,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Available', Colors.green),
        const SizedBox(width: 16),
        _buildLegendItem('Limited Slots Remaining', Colors.orange),
        const SizedBox(width: 16),
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
