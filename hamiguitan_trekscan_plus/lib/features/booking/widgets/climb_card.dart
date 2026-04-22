import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/climb.dart';
import '../../../models/booking_model.dart';
import 'booking_details_modal.dart';
import '../../../theme/color.dart';
import '../../../utils/status_helpers.dart';

typedef ClimbCallback = void Function(Climb);

class ClimbCard extends StatelessWidget {
  final Climb climb;
  final VoidCallback? onTap;
  final ClimbCallback? onCancel;
  final BookingModel? booking;
  final void Function(BookingModel booking)? onEditBooking;
  final void Function(BookingModel booking)? onSubmitBooking;

  const ClimbCard({
    super.key,
    required this.climb,
    this.onTap,
    this.onCancel,
    this.booking,
    this.onEditBooking,
    this.onSubmitBooking,
  });

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '--- --, ----';
    }
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final status = climb.computedStatus();
    final statusColor = BookingStatusHelper.color(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        color: SharedColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name and Status badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        climb.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        climb.type,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Compact dates row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booked',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(climb.dateBooked),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(climb.targetDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status != 'Pending')
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Approved',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(climb.dateApproved),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Draft status and action buttons
            Row(
              children: [
                if (booking != null && booking!.isDraft)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusPendingLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Draft',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusPendingDark,
                      ),
                    ),
                  )
                else if (booking != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.green50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Submitted',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.green700,
                      ),
                    ),
                  ),
                const Spacer(),
                // Action buttons
                if (status != 'Cancelled' &&
                    status != 'Completed' &&
                    status != 'Declined' &&
                    status != 'Rejected')
                  SizedBox(
                    height: 36,
                    child: TextButton(
                      onPressed: () => onCancel?.call(climb),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: FilledButton(
                    onPressed: () => _showBookingDetails(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.shadowOverlay,
      builder: (context) => BookingDetailsModal(
        climb: climb,
        booking: booking,
        onClose: () => Navigator.pop(context),
        onEdit: booking != null && onEditBooking != null
            ? () {
                Navigator.pop(context);
                onEditBooking!(booking!);
              }
            : null,
        onSubmit: booking != null && onSubmitBooking != null
            ? () {
                Navigator.pop(context);
                onSubmitBooking!(booking!);
              }
            : null,
      ),
    );
  }
}
