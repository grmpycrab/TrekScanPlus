import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/climb.dart';
import '../models/booking_model.dart';

class BookingDetailsModal extends StatelessWidget {
  final Climb climb;
  final BookingModel? booking;
  final VoidCallback onClose;

  const BookingDetailsModal({
    super.key,
    required this.climb,
    this.booking,
    required this.onClose,
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
        color: Colors.black.withOpacity(0.5),
        child: GestureDetector(
          onTap: () {}, // Prevent closing when tapping inside modal
          child: Center(
            child: Material(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
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
                        color: Colors.blueGrey[700],
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
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  climb.name,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
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
                              'Number of Porters:',
                              '${booking?.numberOfPorters ?? 'N/A'}',
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              'Affiliation:',
                              booking?.affiliation ?? 'Not provided',
                            ),
                            const SizedBox(height: 24),
                            // Notes section
                            if (booking?.notes != null &&
                                booking!.notes!.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('Your Notes'),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      booking!.notes!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            // Admin notes section
                            if (_hasAdminNotes())
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle(
                                    "Admin's Notes",
                                    icon: Icons.admin_panel_settings,
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blue[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      _getAdminNotes(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
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
                    // Close button at bottom
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blueGrey[700],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: onClose,
                          child: const Text('Close'),
                        ),
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
        border: Border.all(color: statusTextColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(status), color: statusTextColor, size: 28),
          const SizedBox(width: 12),
          Column(
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
            ],
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
            border: Border.all(color: Colors.grey[300]!),
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
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
    // This would check for admin notes in the booking model
    // For now, we check if there's an admin notes field (you may need to add this to BookingModel)
    return false; // Placeholder - update when admin notes field is added to BookingModel
  }

  String _getAdminNotes() {
    // Return admin notes from booking model when available
    return 'No admin notes available';
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      case 'Expired':
        return Icons.schedule;
      default:
        return Icons.schedule;
    }
  }
}
