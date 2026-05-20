import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../services/date_validation_service.dart';

/// Trek date picker widget with availability checking
/// Integrates with DateValidationService to show real-time slot availability,
/// buffer days, and closure information
class TrekDatePicker extends StatefulWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final int totalMembers;

  const TrekDatePicker({
    super.key,
    this.selectedDate,
    required this.onDateSelected,
    this.totalMembers = 1,
  });

  @override
  State<TrekDatePicker> createState() => _TrekDatePickerState();
}

class _TrekDatePickerState extends State<TrekDatePicker> {
  late DateValidationService _dateValidationService;
  DateTime? _selectedDate;
  Map<String, dynamic>? _availabilityInfo;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _dateValidationService = DateValidationService();
    _selectedDate = widget.selectedDate;
    if (_selectedDate != null) {
      _checkDateAvailability(_selectedDate!);
    }
  }

  /// Check availability for selected date
  Future<void> _checkDateAvailability(DateTime date) async {
    setState(() => _isChecking = true);
    try {
      final availability = await _dateValidationService.checkDateAvailability(
        date,
        widget.totalMembers,
      );
      setState(() {
        _availabilityInfo = availability;
        _isChecking = false;
      });
    } catch (e) {
      setState(() => _isChecking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking availability: $e')),
        );
      }
    }
  }

  /// Open date picker
  Future<void> _openDatePicker() async {
    final colors = context.colors;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: colors.primary,
              onPrimary: SharedColors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _checkDateAvailability(picked);
      widget.onDateSelected(picked);
    }
  }

  /// Get availability status widget
  Widget _buildAvailabilityStatus() {
    final colors = context.colors;
    if (_availabilityInfo == null) {
      return const SizedBox.shrink();
    }

    final available = _availabilityInfo!['available'] as bool? ?? false;
    final isClosed = _availabilityInfo!['isClosed'] as bool? ?? false;
    final isBufferDay = _availabilityInfo!['isBufferDay'] as bool? ?? false;
    final bookedTrekkers = _availabilityInfo!['bookedTrekkers'] as int? ?? 0;
    final allocatedPorters = _availabilityInfo!['allocatedPorters'] as int? ?? 0;
    final slotsUsed = _availabilityInfo!['slotsUsed'] as int? ?? 0;
    final maxSlots = _availabilityInfo!['maxSlots'] as int? ?? 30;
    final remaining = _availabilityInfo!['remainingTrekkerSlots'] as int? ??
        _availabilityInfo!['remaining'] as int? ?? 0;
    final closureReason = _availabilityInfo!['closureReason'] as String?;
    final conflictDate = _availabilityInfo!['conflictDate'] as String?;

    // Closed date
    if (isClosed) {
      return Container(
        decoration: BoxDecoration(
          color: colors.statusRejectedLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel, color: colors.statusRejectedDark, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Date Unavailable',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.statusRejectedDark,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              closureReason ?? 'This date is closed for bookings',
              style: TextStyle(color: colors.statusRejectedDark, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Buffer day (trek down day)
    if (isBufferDay) {
      return Container(
        decoration: BoxDecoration(
          color: colors.statusPendingLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.statusPendingBorder),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: colors.statusPendingDark, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Buffer Day - Trek Down',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.statusPendingDark,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Trekkers from trek on $conflictDate are coming down. No new bookings allowed.',
              style: TextStyle(color: colors.statusPendingDark, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Available with slots info
    if (available) {
      final isCritical = remaining <= 5;
      return Container(
        decoration: BoxDecoration(
          color: isCritical ? colors.warningLight : colors.green50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCritical ? colors.warningBorder : colors.green200,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCritical ? Icons.info : Icons.check_circle,
                  color: isCritical ? colors.warning : colors.green700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isCritical ? 'Limited Slots Available' : 'Date Available',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCritical ? colors.warning : colors.green700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Site Capacity Used',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      '$slotsUsed / $maxSlots',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$bookedTrekkers trekker${bookedTrekkers != 1 ? 's' : ''}'
                      ' + $allocatedPorters porter${allocatedPorters != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 11, color: colors.textTertiary),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Trekker Slots Left',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      '$remaining',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isCritical ? colors.warning : colors.green700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Not available
    return Container(
      decoration: BoxDecoration(
        color: colors.statusRejectedLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.cancel, color: colors.statusRejectedDark, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No slots available for this date',
              style: TextStyle(
                color: colors.statusRejectedDark,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dateFormatter = DateFormat('MMMM dd, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trek Date',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 8),
        // Date selector button
        GestureDetector(
          onTap: _openDatePicker,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedDate != null && _availabilityInfo != null
                    ? ((_availabilityInfo!['available'] as bool?) ?? false)
                          ? colors.green200
                          : Colors.red.shade200
                    : Colors.black12,
              ),
              boxShadow: [
                BoxShadow(
                  color: SharedColors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'When do you want to climb?',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedDate != null
                          ? dateFormatter.format(_selectedDate!)
                          : 'Select a date',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.calendar_today, color: colors.primary, size: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Availability status
        if (_isChecking)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Checking availability...',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ),
          )
        else if (_selectedDate != null)
          _buildAvailabilityStatus(),
      ],
    );
  }
}
