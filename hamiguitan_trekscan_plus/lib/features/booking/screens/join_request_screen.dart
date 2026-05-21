// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/group_booking.dart';
import '../../../models/join_request.dart';
import '../../../models/member.dart';
import '../../../services/group_booking_service.dart';
import '../../../services/pricing_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';
import '../models/document_requirements.dart';

/// Form for submitting a [JoinRequest] to an existing [GroupBooking].
///
/// Receives the target [group] as a constructor parameter.
/// On success, shows a confirmation and pops back to the group list.
class JoinRequestScreen extends StatefulWidget {
  final GroupBooking group;
  const JoinRequestScreen({super.key, required this.group});

  @override
  State<JoinRequestScreen> createState() => _JoinRequestScreenState();
}

class _JoinRequestScreenState extends State<JoinRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  // Personal info fields
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController(text: 'Filipino');
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _gender = 'male';
  String _category = 'outside_davao_oriental';
  DateTime? _birthDate;
  bool _porterRequested = false;
  bool _isSubmitting = false;

  // document uploads keyed by DocumentField.name
  final Map<String, List<PlatformFile>> _docFiles = {};

  double get _memberPrice =>
      PricingService.instance.calculateMemberPrice(_category);

  double get _porterPrice =>
      _porterRequested ? PricingService.instance.porterPrice : 0;

  double get _estimatedTotal => _memberPrice + _porterPrice;

  @override
  void initState() {
    super.initState();
    PricingService.instance.init();
    _prefillFromAuth();
  }

  void _prefillFromAuth() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null) {
      final parts = user!.displayName!.split(' ');
      if (parts.isNotEmpty) _firstNameCtrl.text = parts.first;
      if (parts.length > 1) {
        _lastNameCtrl.text = parts.sublist(1).join(' ');
      }
    }
  }

  List<String> _missingDocs() {
    final required =
        DocumentRequirements.getRequiredDocumentsForCategory(_category);
    return required.where((d) => (_docFiles[d] ?? []).isEmpty).toList();
  }

  Future<void> _pickFiles(String docName) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() => _docFiles[docName] = result.files);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _contactCtrl.dispose();
    _nationalityCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      _snack('Please select your birth date.', isError: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final missing = _missingDocs();
    if (missing.isNotEmpty) {
      _snack('Please upload: ${missing.join(', ')}', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final member = Member(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        gender: _gender,
        birthDate:
            '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-'
            '${_birthDate!.day.toString().padLeft(2, '0')}',
        contactNumber: _contactCtrl.text.trim(),
        nationality: _nationalityCtrl.text.trim(),
        homeAddress: _addressCtrl.text.trim(),
        category: _category,
      );

      final request = JoinRequest(
        id: '',
        groupId: widget.group.id,
        userId: user.uid,
        userDisplayName:
            '${member.firstName} ${member.lastName}'.trim(),
        member: member,
        porterRequested: _porterRequested,
        notes: _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        createdAt: Timestamp.now(),
      );

      final requestId =
          await GroupBookingService.instance.submitJoinRequest(request);

      final memberName =
          '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
      for (final entry in _docFiles.entries) {
        for (final file in entry.value) {
          try {
            await GroupBookingService.instance.uploadJoinRequestAttachment(
              widget.group.id,
              requestId,
              file,
              memberName: memberName,
            );
          } catch (e) {
            AppLogger.w('Upload skipped (${file.name}): $e');
          }
        }
      }

      if (!mounted) return;
      _showSuccessSheet();
    } catch (e) {
      AppLogger.e('JoinRequestScreen submit: $e');
      if (mounted) _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showSuccessSheet() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Colors.green, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Request Submitted!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your request to join "${widget.group.groupName}" has been sent. '
              'The organizer will review and notify you of their decision.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close sheet
                  Navigator.of(context).pop(); // back to group list
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Back to Groups'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(widget.group.groupName, overflow: TextOverflow.ellipsis),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Group summary banner
            _GroupBanner(group: widget.group),
            const SizedBox(height: 20),

            // ── Personal information ────────────────────────────────────
            _SectionLabel('Your Information'),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _firstNameCtrl,
                    label: 'First Name',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Field(
                    controller: _lastNameCtrl,
                    label: 'Last Name',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GenderRow(
              value: _gender,
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 12),
            _BirthDateRow(
              date: _birthDate,
              onChanged: (d) => setState(() => _birthDate = d),
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _contactCtrl,
              label: 'Contact Number',
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _nationalityCtrl,
              label: 'Nationality',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _addressCtrl,
              label: 'Home Address',
              maxLines: 2,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            // ── Category ────────────────────────────────────────────────
            const SizedBox(height: 20),
            _SectionLabel('Trekker Category'),
            _CategoryDropdown(
              value: _category,
              onChanged: (v) => setState(() => _category = v),
            ),

            // ── Required documents ───────────────────────────────────────
            const SizedBox(height: 20),
            _SectionLabel('Required Documents'),
            _DocUploadSection(
              category: _category,
              docFiles: _docFiles,
              onPick: _pickFiles,
            ),

            // ── Add-ons ─────────────────────────────────────────────────
            const SizedBox(height: 20),
            _SectionLabel('Add-ons'),
            SwitchListTile(
              value: _porterRequested,
              onChanged: (v) => setState(() => _porterRequested = v),
              title: Text('Porter Service',
                  style: TextStyle(color: colors.text, fontSize: 14)),
              subtitle: Text(
                '+₱${PricingService.instance.porterPrice.toStringAsFixed(0)} — carries your gear',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              activeColor: colors.primary,
              contentPadding: EdgeInsets.zero,
            ),

            // ── Notes ───────────────────────────────────────────────────
            const SizedBox(height: 8),
            _SectionLabel('Notes to Organizer (Optional)'),
            _Field(
              controller: _notesCtrl,
              label: 'Additional Notes',
              hint: 'Any questions or special concerns…',
              maxLines: 3,
            ),

            // ── Price summary ────────────────────────────────────────────
            const SizedBox(height: 20),
            _PriceSummary(
              category: _category,
              memberPrice: _memberPrice,
              porterPrice: _porterPrice,
              total: _estimatedTotal,
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Join Request',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Local widgets
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Document upload section
// ---------------------------------------------------------------------------

class _DocUploadSection extends StatelessWidget {
  final String category;
  final Map<String, List<PlatformFile>> docFiles;
  final Future<void> Function(String docName) onPick;

  const _DocUploadSection({
    required this.category,
    required this.docFiles,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final docType = DocumentRequirements.getDocumentsForCategory(category);
    if (docType == null || docType.requiredDocs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No documents required for this category.',
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in docType.requiredDocs) ...[
          _DocFieldRow(
            field: field,
            files: docFiles[field.name] ?? [],
            onPick: () => onPick(field.name),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DocFieldRow extends StatelessWidget {
  final DocumentField field;
  final List<PlatformFile> files;
  final VoidCallback onPick;

  const _DocFieldRow({
    required this.field,
    required this.files,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasFiles = files.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasFiles
              ? Colors.green.withOpacity(0.6)
              : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            leading: Icon(
              hasFiles
                  ? Icons.check_circle_rounded
                  : Icons.upload_file_rounded,
              color: hasFiles ? Colors.green : colors.primary,
              size: 22,
            ),
            title: Text(
              field.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
            subtitle: Text(
              field.description,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
            trailing: TextButton(
              onPressed: onPick,
              child: Text(
                hasFiles ? 'Change' : 'Upload',
                style: TextStyle(fontSize: 12, color: colors.primary),
              ),
            ),
          ),
          if (hasFiles)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: files.map((f) {
                  return Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      f.name,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                    avatar: const Icon(Icons.insert_drive_file_rounded,
                        size: 14),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupBanner extends StatelessWidget {
  final GroupBooking group;
  const _GroupBanner({required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = group.trekDate.toDate();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.groupName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(group.affiliation,
              style: TextStyle(fontSize: 13, color: colors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [
              _BannerInfo(Icons.calendar_today, dateLabel),
              _BannerInfo(Icons.person, group.organizerName),
              _BannerInfo(
                Icons.people,
                '${group.availableSlots} slot${group.availableSlots == 1 ? '' : 's'} left',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BannerInfo(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: colors.textSecondary)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: colors.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: colors.textSecondary),
        hintStyle: TextStyle(color: colors.textTertiary),
        filled: true,
        fillColor: colors.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
    );
  }
}

class _GenderRow extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _GenderRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Text('Gender', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        const SizedBox(width: 16),
        for (final g in ['male', 'female', 'other'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                g[0].toUpperCase() + g.substring(1),
                style: TextStyle(
                  fontSize: 12,
                  color: value == g ? Colors.white : colors.text,
                ),
              ),
              selected: value == g,
              selectedColor: colors.primary,
              onSelected: (_) => onChanged(g),
            ),
          ),
      ],
    );
  }
}

class _BirthDateRow extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;
  const _BirthDateRow({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = date == null
        ? 'Select Birth Date'
        : '${date!.day.toString().padLeft(2, '0')}/'
            '${date!.month.toString().padLeft(2, '0')}/'
            '${date!.year}';

    return OutlinedButton.icon(
      icon: Icon(Icons.cake_outlined, size: 18, color: colors.primary),
      label: Text(label, style: TextStyle(color: colors.text)),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: colors.inputFill,
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ??
              DateTime.now().subtract(const Duration(days: 365 * 18)),
          firstDate: DateTime(1930),
          lastDate: DateTime.now(),
        );
        onChanged(picked);
      },
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final categories = PricingService.instance.allCategories;

    return DropdownButtonFormField<String>(
      value: categories.containsKey(value) ? value : categories.keys.first,
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle: TextStyle(color: colors.textSecondary),
        filled: true,
        fillColor: colors.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      dropdownColor: colors.surface,
      style: TextStyle(color: colors.text, fontSize: 14),
      items: categories.entries.map((e) {
        final discount = e.value.discountPercent;
        final label = discount > 0
            ? '${e.value.displayName} ($discount% off)'
            : e.value.displayName;
        return DropdownMenuItem(value: e.key, child: Text(label));
      }).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _PriceSummary extends StatelessWidget {
  final String category;
  final double memberPrice;
  final double porterPrice;
  final double total;

  const _PriceSummary({
    required this.category,
    required this.memberPrice,
    required this.porterPrice,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = PricingService.instance.basePricePerPerson;
    final discount = PricingService.instance.getDiscountPercent(category);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated Price',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 10),
          _priceRow('Base price', '₱${base.toStringAsFixed(0)}',
              color: colors.textSecondary),
          if (discount > 0)
            _priceRow(
              'Discount ($discount%)',
              '−₱${(base - memberPrice).toStringAsFixed(0)}',
              color: Colors.green,
            ),
          _priceRow(
            'Trek fee',
            '₱${memberPrice.toStringAsFixed(0)}',
            color: colors.text,
          ),
          if (porterPrice > 0)
            _priceRow(
              'Porter',
              '₱${porterPrice.toStringAsFixed(0)}',
              color: colors.textSecondary,
            ),
          const Divider(height: 16),
          _priceRow(
            'Total',
            '₱${total.toStringAsFixed(0)}',
            bold: true,
            color: colors.primary,
          ),
          const SizedBox(height: 4),
          Text(
            'Final amount confirmed by admin upon approval.',
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
