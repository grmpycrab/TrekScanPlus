import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/climb.dart';
import '../models/booking_model.dart';
import '../theme/color.dart';

class BookingDetailsModal extends StatelessWidget {
  final Climb climb;
  final BookingModel? booking;
  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onSubmit;

  const BookingDetailsModal({
    super.key,
    required this.climb,
    this.booking,
    required this.onClose,
    this.onEdit,
    this.onSubmit,
  });

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not available';
    }
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: SharedColors.black.withValues(alpha: 0.5),
        child: GestureDetector(
          onTap: () {},
          child: Center(
            child: Material(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                ),
                decoration: BoxDecoration(
                  color: SharedColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: SharedColors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with close button
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Booking Details',
                                  style: const TextStyle(
                                    color: SharedColors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  climb.name,
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: SharedColors.white,
                            ),
                            onPressed: onClose,
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status section
                            _buildStatusSection(),
                            const SizedBox(height: 24),
                            // Booking dates section
                            _buildSectionTitle('Booking Dates'),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Date Booked:',
                              _formatDate(climb.dateBooked),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              'Target Trek Date:',
                              _formatDate(climb.targetDate),
                            ),
                            const SizedBox(height: 8),
                            if (climb.computedStatus() != 'Pending')
                              _buildDetailRow(
                                'Date Approved:',
                                _formatDate(climb.dateApproved),
                              ),
                            if (climb.computedStatus() != 'Pending')
                              const SizedBox(height: 8),
                            const SizedBox(height: 24),
                            // Trek information section
                            _buildSectionTitle('Trek Information'),
                            const SizedBox(height: 12),
                            _buildDetailRow('Trek Type:', climb.type),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              'Total Participants:',
                              booking != null
                                  ? '${booking!.members.length}'
                                  : 'N/A',
                            ),
                            const SizedBox(height: 12),
                            if (booking != null && booking!.members.isNotEmpty)
                              _buildMembersSection(),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Affiliation:',
                              booking?.affiliation ?? 'Not provided',
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              'Contact Number:',
                              booking?.phoneNumber ?? 'Not provided',
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              'Hometown:',
                              booking?.hometown ?? 'Not provided',
                            ),
                            const SizedBox(height: 12),
                            // Attachments section
                            if (booking != null &&
                                booking!.attachments.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('Attachments'),
                                  const SizedBox(height: 12),
                                  ..._buildAttachmentsList(),
                                  const SizedBox(height: 12),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Actions row
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          if (onEdit != null) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    (climb.computedStatus() == 'Cancelled' ||
                                        climb.computedStatus() == 'Approved')
                                    ? null
                                    : onEdit,
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit Details'),
                                style: OutlinedButton.styleFrom(
                                  disabledForegroundColor: Colors.grey.shade400,
                                  disabledBackgroundColor: AppColors.background,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          // Submit button for draft bookings, Close for others
                          if (booking != null &&
                              booking!.isDraft &&
                              onSubmit != null)
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: onSubmit,
                                child: const Text('Submit'),
                              ),
                            )
                          else
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: onClose,
                                child: const Text('Close'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    final status = climb.computedStatus();
    final statusColor = _getStatusColor(status);
    final statusTextColor = _getStatusTextColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusTextColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(status), color: statusTextColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Booking Status',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _hasAdminNotes() ? _getAdminNotes() : 'No notes to be shown',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: statusTextColor.withValues(alpha: 0.85),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Colors.blueGrey[700]),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection() {
    if (booking == null || booking!.members.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Group Members'),
        const SizedBox(height: 12),
        ...booking!.members.asMap().entries.map((entry) {
          final member = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: member.isPrimaryContact
                  ? Colors.blue[50]
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: member.isPrimaryContact ? Colors.blue : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      member.fullName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: member.isPrimaryContact
                            ? Colors.blue[800]
                            : Colors.black87,
                      ),
                    ),
                    if (member.isPrimaryContact)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Primary',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Gender:', member.gender),
                const SizedBox(height: 4),
                _buildDetailRow('Birth Date:', member.birthDate),
                const SizedBox(height: 4),
                _buildDetailRow('Contact:', member.contactNumber),
                const SizedBox(height: 4),
                _buildDetailRow('Nationality:', member.nationality),
                const SizedBox(height: 4),
                _buildDetailRow('Address:', member.homeAddress),
                const SizedBox(height: 4),
                _buildDetailRow('Category:', member.categoryDisplayName),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  List<Widget> _buildAttachmentsList() {
    if (booking == null || booking!.attachments.isEmpty) {
      return [];
    }

    return booking!.attachments.map((attachment) {
      final icon = _getFileIcon(attachment.fileName);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.blueGrey[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatBytes(attachment.size)} • ${DateFormat('MMM dd, yyyy').format(attachment.uploadedAt.toDate())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.download, color: Colors.blueGrey[700], size: 20),
            ],
          ),
        ),
      );
    }).toList();
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      default:
        return Icons.attachment;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  bool _hasAdminNotes() {
    final text = booking?.adminNotes ?? climb.adminNotes;
    return text != null && text.trim().isNotEmpty;
  }

  String _getAdminNotes() {
    return (booking?.adminNotes ?? climb.adminNotes)?.trim() ??
        'No admin notes available';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green[100]!;
      case 'Cancelled':
        return AppColors.borderLight;
      case 'Completed':
        return Colors.blue[100]!;
      default:
        return Colors.orange[100]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green[800]!;
      case 'Cancelled':
        return AppColors.textSecondary;
      case 'Completed':
        return Colors.blue[800]!;
      default:
        return Colors.orange[800]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      case 'Completed':
        return Icons.check_circle;
      default:
        return Icons.schedule;
    }
  }
}
