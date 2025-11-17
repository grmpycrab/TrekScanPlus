import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/climb.dart';
import '../models/booking_model.dart';
import 'booking_details_modal.dart';

typedef ClimbCallback = void Function(Climb);

class ClimbCard extends StatelessWidget {
  final Climb climb;
  final VoidCallback? onTap;
  final ClimbCallback? onCancel;
  final BookingModel? booking;

  const ClimbCard({
    super.key,
    required this.climb,
    this.onTap,
    this.onCancel,
    this.booking,
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
    final statusColor = _getStatusColor(status);
    final statusTextColor = _getStatusTextColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: const DecorationImage(
            image: AssetImage('assets/images/mountain_with_background.png'),
            fit: BoxFit.cover,
            opacity: 0.25,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with name and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        climb.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            climb.type,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Date information
            _buildDateRow('Date Booked:', _formatDate(climb.dateBooked)),
            const SizedBox(height: 8),
            _buildDateRow('Target Date:', _formatDate(climb.targetDate)),
            const SizedBox(height: 8),
            if (status != 'Pending')
              _buildDateRow('Date Approved:', _formatDate(climb.dateApproved)),
            if (status != 'Pending') const SizedBox(height: 8),
            const SizedBox(height: 8),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (status != 'Cancelled' && status != 'Expired')
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => onCancel?.call(climb),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                if (status != 'Cancelled' && status != 'Expired')
                  const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showBookingDetails(context),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('View Details'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueGrey[700],
                      padding: const EdgeInsets.symmetric(vertical: 8),
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

  Widget _buildDateRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green[100]!;
      case 'Cancelled':
        return Colors.grey[200]!;
      case 'Expired':
        return Colors.red[100]!;
      default:
        return Colors.orange[100]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green[800]!;
      case 'Cancelled':
        return Colors.grey[700]!;
      case 'Expired':
        return Colors.red[800]!;
      default:
        return Colors.orange[800]!;
    }
  }

  void _showBookingDetails(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => BookingDetailsModal(
        climb: climb,
        booking: booking,
        onClose: () => Navigator.pop(context),
      ),
    );
  }
}
