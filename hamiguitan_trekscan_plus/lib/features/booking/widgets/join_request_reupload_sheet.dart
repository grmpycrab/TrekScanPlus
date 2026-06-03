// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/join_request.dart';
import '../../../models/booking_model.dart';
import '../../../services/group_booking_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';

/// Bottom sheet shown to a group join-request member when the organizer has
/// set their request status to `changes_required`.
///
/// Allows the member to:
///   - Read the organizer's note explaining what is wrong
///   - Delete individual existing attachments
///   - Upload replacement / additional files
///   - Resubmit (resets status → pending, clears the organizer's note)
class JoinRequestReuploadSheet extends StatefulWidget {
  final JoinRequest request;
  final VoidCallback onResubmitted;

  const JoinRequestReuploadSheet({
    super.key,
    required this.request,
    required this.onResubmitted,
  });

  @override
  State<JoinRequestReuploadSheet> createState() =>
      _JoinRequestReuploadSheetState();
}

class _JoinRequestReuploadSheetState extends State<JoinRequestReuploadSheet> {
  late List<Attachment> _existingAttachments;
  final List<PlatformFile> _newFiles = [];
  bool _isLoading = false;
  String? _loadingMessage;

  @override
  void initState() {
    super.initState();
    _existingAttachments = List.from(widget.request.attachments);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true,
    );
    if (result != null && mounted) {
      setState(() => _newFiles.addAll(result.files));
    }
  }

  Future<void> _deleteExisting(Attachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Remove "${attachment.fileName}" from your request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Deleting file...';
    });
    try {
      await GroupBookingService.instance.deleteJoinRequestAttachment(
        widget.request.groupId,
        widget.request.id,
        attachment,
      );
      setState(() => _existingAttachments.remove(attachment));
    } catch (e) {
      AppLogger.e('Failed to delete join request attachment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete "${attachment.fileName}"'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resubmit() async {
    if (_existingAttachments.isEmpty && _newFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please upload at least one document before resubmitting.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Uploading files...';
    });

    try {
      for (final file in _newFiles) {
        await GroupBookingService.instance.uploadJoinRequestAttachment(
          widget.request.groupId,
          widget.request.id,
          file,
          memberName:
              '${widget.request.member.firstName} ${widget.request.member.lastName}'
                  .trim(),
        );
      }

      setState(() => _loadingMessage = 'Resubmitting request...');
      await GroupBookingService.instance.resubmitJoinRequest(
        widget.request.groupId,
        widget.request.id,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onResubmitted();
      }
    } catch (e) {
      AppLogger.e('Failed to resubmit join request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resubmit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.upload_file, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  'Update Your Documents',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Organizer note
            if (widget.request.changesNote != null &&
                widget.request.changesNote!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 18, color: Colors.amber.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Organizer Note',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.request.changesNote!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

            // Existing files
            if (_existingAttachments.isNotEmpty) ...[
              Text(
                'Current Files',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colors.text),
              ),
              const SizedBox(height: 8),
              ..._existingAttachments.map(
                (att) => _FileRow(
                  attachment: att,
                  onDelete: _isLoading ? null : () => _deleteExisting(att),
                  colors: colors,
                ),
              ),
              const SizedBox(height: 16),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'No files uploaded yet. Please upload your documents below.',
                  style:
                      TextStyle(fontSize: 13, color: Colors.red.shade700),
                ),
              ),

            // New files
            if (_newFiles.isNotEmpty) ...[
              Text(
                'New Files (will be uploaded)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colors.text),
              ),
              const SizedBox(height: 8),
              ..._newFiles.map(
                (file) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file,
                          size: 18, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(file.name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon:
                            const Icon(Icons.close, color: Colors.red),
                        onPressed: () =>
                            setState(() => _newFiles.remove(file)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickFiles,
                icon: const Icon(Icons.add),
                label: const Text('Add Files'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _resubmit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(_isLoading
                    ? (_loadingMessage ?? 'Please wait...')
                    : 'Resubmit Request'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onDelete;
  final AppTheme colors;

  const _FileRow(
      {required this.attachment,
      required this.onDelete,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file,
                size: 18, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(attachment.fileName,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              iconSize: 20,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete file',
            ),
          ],
        ),
      ),
    );
  }
}
