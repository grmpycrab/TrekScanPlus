import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/climb.dart';
import '../../../models/booking_model.dart';
import '../../../models/member.dart';
import '../../../theme/color.dart';
import 'price_summary_widget.dart';
import '../models/document_requirements.dart';

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
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                ),
                decoration: BoxDecoration(
                  color: SharedColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: SharedColors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Simple header with title and close
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  climb.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 24),
                            onPressed: onClose,
                            padding: const EdgeInsets.all(8),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                      indent: 20,
                      endIndent: 20,
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
                            const SizedBox(height: 20),
                            // Booking dates section
                            _buildSectionTitle('Booking Dates'),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Date Booked',
                              _formatDate(climb.dateBooked),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              'Target Trek Date',
                              _formatDate(climb.targetDate),
                            ),
                            if (climb.computedStatus() != 'Pending')
                              const SizedBox(height: 8),
                            if (climb.computedStatus() != 'Pending')
                              _buildDetailRow(
                                'Date Approved',
                                _formatDate(climb.dateApproved),
                              ),
                            const SizedBox(height: 20),
                            // Trek information section
                            _buildSectionTitle('Trek Information'),
                            const SizedBox(height: 12),
                            _buildDetailRow('Trek Type', climb.type),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              'Total Participants',
                              booking != null
                                  ? '${booking!.members.length}'
                                  : 'N/A',
                            ),
                            if (booking != null) const SizedBox(height: 8),
                            if (booking != null)
                              _buildDetailRow(
                                'Affiliation',
                                booking!.affiliation,
                              ),
                            if (booking != null) const SizedBox(height: 8),
                            if (booking != null)
                              _buildDetailRow(
                                'Contact Number',
                                booking!.phoneNumber,
                              ),
                            if (booking != null) const SizedBox(height: 8),
                            if (booking != null)
                              _buildDetailRow('Hometown', booking!.hometown),
                            if (booking != null && booking!.members.isNotEmpty)
                              const SizedBox(height: 20),
                            if (booking != null && booking!.members.isNotEmpty)
                              _buildMembersSection(),
                            if (booking != null) const SizedBox(height: 20),
                            if (booking != null)
                              PriceSummaryWidget(
                                members: booking!.members,
                                estimatedTotalPrice: 0.0,
                              ),
                            if (booking != null &&
                                booking!.attachments.isNotEmpty)
                              const SizedBox(height: 20),
                            if (booking != null &&
                                booking!.attachments.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('Attachments'),
                                  const SizedBox(height: 12),
                                  ..._buildAttachmentsList(),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                      indent: 20,
                      endIndent: 20,
                    ),
                    // Actions row
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          if (onEdit != null) ...[
                            SizedBox(
                              height: 36,
                              child: OutlinedButton(
                                onPressed:
                                    (climb.computedStatus() == 'Cancelled' ||
                                        climb.computedStatus() == 'Approved')
                                    ? null
                                    : onEdit,
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  disabledForegroundColor: Colors.grey.shade400,
                                ),
                                child: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Submit or Close button
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      booking != null &&
                                          booking!.isDraft &&
                                          onSubmit != null
                                      ? Colors.green
                                      : AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed:
                                    booking != null &&
                                        booking!.isDraft &&
                                        onSubmit != null
                                    ? onSubmit
                                    : onClose,
                                child: Text(
                                  booking != null &&
                                          booking!.isDraft &&
                                          onSubmit != null
                                      ? 'Submit'
                                      : 'Close',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(status), color: statusColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                if (_hasAdminNotes())
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _getAdminNotes(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
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
          final docStatus = _getDocumentCompletionStatus(member);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SharedColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: member.isPrimaryContact
                      ? AppColors.primary
                      : AppColors.borderBlack26,
                  width: 3,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        member.fullName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    if (member.isPrimaryContact)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'Primary',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Document completion indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: docStatus['isComplete']
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        docStatus['isComplete']
                            ? Icons.check_circle
                            : Icons.pending,
                        size: 14,
                        color: docStatus['isComplete']
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        docStatus['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: docStatus['isComplete']
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Gender', member.gender),
                const SizedBox(height: 6),
                _buildDetailRow('Birth Date', member.birthDate),
                const SizedBox(height: 6),
                _buildDetailRow('Contact', member.contactNumber),
                const SizedBox(height: 6),
                _buildDetailRow('Category', member.categoryDisplayName),
              ],
            ),
          );
        }),
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
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SharedColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatBytes(attachment.size)} • ${DateFormat('MMM dd').format(attachment.uploadedAt.toDate())}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.download, color: AppColors.primary, size: 18),
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

  Map<String, dynamic> _getDocumentCompletionStatus(Member member) {
    if (booking == null) {
      return {'isComplete': false, 'label': 'No booking data'};
    }

    // Get required documents for this member's category
    final docRequirements = DocumentRequirements.getDocumentsForCategory(
      member.category,
    );
    if (docRequirements == null || docRequirements.requiredDocs.isEmpty) {
      return {'isComplete': true, 'label': 'No documents required'};
    }

    final requiredCount = docRequirements.requiredDocs.length;
    int uploadedCount = 0;

    // Check how many documents have been uploaded
    for (final attachment in booking!.attachments) {
      // Simple heuristic: check if filename contains category keywords
      final fileName = attachment.fileName.toLowerCase();
      for (final docField in docRequirements.requiredDocs) {
        final docKeyword = docField.name.toLowerCase().replaceAll(' ', '_');
        if (fileName.contains(docKeyword) ||
            fileName.contains(member.category)) {
          uploadedCount++;
          break;
        }
      }
    }

    // If no attachments but documents required, show as incomplete
    if (booking!.attachments.isEmpty && requiredCount > 0) {
      return {'isComplete': false, 'label': '0/$requiredCount documents'};
    }

    final isComplete = uploadedCount >= requiredCount;
    return {
      'isComplete': isComplete,
      'label': isComplete
          ? '✓ Documents complete'
          : '$uploadedCount/$requiredCount documents',
    };
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Cancelled':
        return Colors.grey;
      case 'Completed':
        return Colors.blue;
      case 'Declined':
      case 'Rejected':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      default:
        return AppColors.primary;
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
