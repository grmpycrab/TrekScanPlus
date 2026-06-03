// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/join_request.dart';
import '../../../models/member.dart';
import '../../../models/booking_model.dart';
import '../../../services/group_booking_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';

/// Bottom sheet that lets a join-request member edit their personal details,
/// porter preference, and documents.
///
/// Available when request status is 'pending' or 'changes_required'.
class EditJoinRequestSheet extends StatefulWidget {
  final JoinRequest request;

  const EditJoinRequestSheet({super.key, required this.request});

  @override
  State<EditJoinRequestSheet> createState() => _EditJoinRequestSheetState();
}

class _EditJoinRequestSheetState extends State<EditJoinRequestSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _nationalityCtrl;
  late final TextEditingController _addressCtrl;

  late String _gender;
  late String _category;
  late bool _porterRequested;

  late List<Attachment> _existingAttachments;
  final List<PlatformFile> _newFiles = [];

  bool _saving = false;
  String? _savingMessage;

  static const _genders = ['male', 'female', 'other'];
  static const _categories = {
    'student': 'Student',
    'senior_citizen': 'Senior Citizen',
    'davao_oriental_resident': 'Davao Oriental Resident',
    'ocfdo': 'OCFDO Member',
    'outside_davao_oriental': 'Outside Davao Oriental',
    'children_8_15': 'Children (8–15)',
    'mfsm': 'MFSM Member',
  };

  @override
  void initState() {
    super.initState();
    final m = widget.request.member;
    _firstNameCtrl = TextEditingController(text: m.firstName);
    _lastNameCtrl = TextEditingController(text: m.lastName);
    _contactCtrl = TextEditingController(text: m.contactNumber);
    _nationalityCtrl = TextEditingController(text: m.nationality);
    _addressCtrl = TextEditingController(text: m.homeAddress);
    _gender = m.gender;
    _category = m.category;
    _porterRequested = widget.request.porterRequested;
    _existingAttachments = List.from(widget.request.attachments);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _contactCtrl.dispose();
    _nationalityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
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

  Future<void> _deleteExisting(Attachment att) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Remove "${att.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await GroupBookingService.instance.deleteJoinRequestAttachment(
        widget.request.groupId,
        widget.request.id,
        att,
      );
      setState(() => _existingAttachments.remove(att));
    } catch (e) {
      AppLogger.e('Delete attachment failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete "${att.fileName}"'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _savingMessage = 'Saving details...';
    });

    try {
      // Build updated Member
      final updatedMember = Member(
        id: widget.request.member.id,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        gender: _gender,
        birthDate: widget.request.member.birthDate,
        contactNumber: _contactCtrl.text.trim(),
        nationality: _nationalityCtrl.text.trim(),
        homeAddress: _addressCtrl.text.trim(),
        category: _category,
        isPrimaryContact: widget.request.member.isPrimaryContact,
        hasAccount: widget.request.member.hasAccount,
        userId: widget.request.member.userId,
        createdAt: widget.request.member.createdAt,
        updatedAt: Timestamp.now(),
      );

      // Save member details + porter
      await GroupBookingService.instance.updateJoinRequestDetails(
        widget.request.groupId,
        widget.request.id,
        member: updatedMember,
        porterRequested: _porterRequested,
      );

      // Upload new files
      if (_newFiles.isNotEmpty) {
        setState(() => _savingMessage = 'Uploading files...');
        for (final file in _newFiles) {
          await GroupBookingService.instance.uploadJoinRequestAttachment(
            widget.request.groupId,
            widget.request.id,
            file,
            memberName: updatedMember.fullName,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request updated successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Edit join request failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
        child: Form(
          key: _formKey,
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
                  Icon(Icons.edit_rounded, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Edit My Request',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Personal details ──────────────────────────────────
              _SectionHeader('Personal Details', colors),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      decoration: _decor('First Name'),
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      decoration: _decor('Last Name'),
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactCtrl,
                decoration: _decor('Contact Number'),
                keyboardType: TextInputType.phone,
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nationalityCtrl,
                decoration: _decor('Nationality'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: _decor('Home Address'),
                validator: _required,
              ),
              const SizedBox(height: 12),

              // Gender dropdown
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: _decor('Gender'),
                items: _genders
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(
                              g[0].toUpperCase() + g.substring(1)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _gender = v);
                },
              ),
              const SizedBox(height: 12),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _category,
                decoration: _decor('Category'),
                items: _categories.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 16),

              // ── Porter preference ─────────────────────────────────
              _SectionHeader('Services', colors),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.backpack_rounded,
                        size: 18, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Porter Requested',
                          style: TextStyle(
                              fontSize: 14, color: colors.text)),
                    ),
                    Switch(
                      value: _porterRequested,
                      onChanged: (v) =>
                          setState(() => _porterRequested = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Documents ─────────────────────────────────────────
              _SectionHeader('Documents', colors),
              const SizedBox(height: 10),

              if (_existingAttachments.isNotEmpty) ...[
                Text('Current Files',
                    style: TextStyle(
                        fontSize: 12, color: colors.textSecondary)),
                const SizedBox(height: 6),
                ..._existingAttachments.map(
                  (att) => _AttachmentRow(
                    att: att,
                    onDelete: _saving ? null : () => _deleteExisting(att),
                    colors: colors,
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (_newFiles.isNotEmpty) ...[
                Text('New Files (will be uploaded)',
                    style: TextStyle(
                        fontSize: 12, color: colors.textSecondary)),
                const SizedBox(height: 6),
                ..._newFiles.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.insert_drive_file,
                            size: 16, color: colors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f.name,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          icon: const Icon(Icons.close,
                              color: Colors.red),
                          onPressed: () =>
                              setState(() => _newFiles.remove(f)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],

              OutlinedButton.icon(
                onPressed: _saving ? null : _pickFiles,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Files'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                      _saving ? (_savingMessage ?? 'Saving...') : 'Save Changes'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decor(String label) => InputDecoration(
        labelText: label,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AppTheme colors;
  const _SectionHeader(this.title, this.colors);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: colors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  final Attachment att;
  final VoidCallback? onDelete;
  final AppTheme colors;
  const _AttachmentRow(
      {required this.att, required this.onDelete, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file,
                size: 16, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(att.fileName,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
