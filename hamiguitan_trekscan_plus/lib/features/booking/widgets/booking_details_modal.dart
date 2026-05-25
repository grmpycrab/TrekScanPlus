import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/climb.dart';
import '../../../models/booking_model.dart';
import '../../../models/member.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/status_helpers.dart';
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

  static final _dateFmt = DateFormat('MMMM dd, yyyy');

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    return _dateFmt.format(date);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Computed once here so _buildStatusSection and inline guards all read the
    // same value without re-running DateTime.now() + string parsing each time.
    final status = climb.computedStatus();
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
                  color: colors.surface,
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
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  climb.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.textSecondary,
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
                      color: colors.border,
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
                            _buildStatusSection(colors, status),
                            const SizedBox(height: 20),
                            // Booking dates section
                            _buildSectionTitle('Booking Dates', colors),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Date Booked',
                              _formatDate(climb.dateBooked),
                              colors,
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              'Target Trek Date',
                              _formatDate(climb.targetDate),
                              colors,
                            ),
                            if (status != 'Pending')
                              const SizedBox(height: 8),
                            if (status != 'Pending')
                              _buildDetailRow(
                                'Date Approved',
                                _formatDate(climb.dateApproved),
                                colors,
                              ),
                            const SizedBox(height: 20),
                            // Trek information section
                            _buildSectionTitle('Trek Information', colors),
                            const SizedBox(height: 12),
                            _buildDetailRow('Trek Type', climb.type, colors),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              'Total Participants',
                              booking != null
                                  ? '${booking!.members.length}'
                                  : 'N/A',
                              colors,
                            ),
                            if (booking != null) const SizedBox(height: 8),
                            if (booking != null)
                              _buildDetailRow(
                                'Affiliation',
                                booking!.affiliation,
                                colors,
                              ),
                            if (booking != null) const SizedBox(height: 8),
                            if (booking != null)
                              _buildDetailRow(
                                'Contact Number',
                                booking!.phoneNumber,
                                colors,
                              ),
                            if (booking != null) const SizedBox(height: 8),
                            if (booking != null)
                              _buildDetailRow(
                                'Hometown',
                                booking!.hometown,
                                colors,
                              ),
                            if (booking != null && booking!.members.isNotEmpty)
                              const SizedBox(height: 20),
                            if (booking != null && booking!.members.isNotEmpty)
                              _buildMembersSection(colors),
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
                              _buildAttachmentsSection(colors),
                          ],
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: colors.border,
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
                                    (status == 'Cancelled' ||
                                        status == 'Approved')
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
                                      : colors.primary,
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

  Widget _buildStatusSection(AppTheme colors, String status) {
    final statusColor = BookingStatusHelper.color(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(BookingStatusHelper.icon(status), color: statusColor, size: 24),
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
                        color: colors.textSecondary,
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

  Widget _buildSectionTitle(String title, AppTheme colors) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.text,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, AppTheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.text,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection(AppTheme colors) {
    if (booking == null || booking!.members.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Group Members', colors),
        const SizedBox(height: 12),
        ...booking!.members.asMap().entries.map((entry) {
          final member = entry.value;
          final docStatus = _getDocumentCompletionStatus(member);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: member.isPrimaryContact
                      ? colors.primary
                      : Colors.black26,
                  width: 3,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: SharedColors.black.withValues(alpha: 0.03),
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
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
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'Primary',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.primary,
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
                _buildDetailRow('Gender', member.gender, colors),
                const SizedBox(height: 6),
                _buildDetailRow('Birth Date', member.birthDate, colors),
                const SizedBox(height: 6),
                _buildDetailRow('Contact', member.contactNumber, colors),
                const SizedBox(height: 6),
                _buildDetailRow('Category', member.categoryDisplayName, colors),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAttachmentsSection(AppTheme colors) {
    if (booking == null || booking!.attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group attachments by memberName (old uploads without a name go under 'Other')
    final grouped = <String, List<Attachment>>{};
    for (final att in booking!.attachments) {
      final key = (att.memberName != null && att.memberName!.isNotEmpty)
          ? att.memberName!
          : 'Other Documents';
      grouped.putIfAbsent(key, () => []).add(att);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Attachments', colors),
        const SizedBox(height: 12),
        ...grouped.entries.map(
          (entry) =>
              _buildMemberAttachmentGroup(entry.key, entry.value, colors),
        ),
      ],
    );
  }

  Widget _buildMemberAttachmentGroup(
    String memberName,
    List<Attachment> attachments,
    AppTheme colors,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: SharedColors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: Icon(Icons.person, color: colors.primary, size: 16),
          ),
          title: Text(
            memberName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          subtitle: Text(
            '${attachments.length} file${attachments.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
          iconColor: colors.primary,
          collapsedIconColor: colors.textSecondary,
          initiallyExpanded: true,
          shape: const Border(), // removes ExpansionTile's own border
          children: attachments
              .map((att) => _buildAttachmentTile(att, colors))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildAttachmentTile(Attachment attachment, AppTheme colors) {
    final icon = _getFileIcon(attachment.fileName);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatBytes(attachment.size)} • ${DateFormat('MMM dd, yyyy').format(attachment.uploadedAt.toDate())}',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(
            Icons.insert_drive_file_outlined,
            color: Colors.grey.shade400,
            size: 16,
          ),
        ],
      ),
    );
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
}
