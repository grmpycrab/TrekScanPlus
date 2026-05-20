// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/group_booking.dart';
import '../../../services/group_booking_service.dart';
import '../../../services/pricing_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';
import 'organizer_requests_screen.dart';

/// Screen for creating a new [GroupBooking].
///
/// The organizer fills in group metadata (name, date, type, classification,
/// slots, services).  On success, navigates to [OrganizerRequestsScreen].
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameCtrl = TextEditingController();
  final _affiliationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _maxSlotsCtrl = TextEditingController(text: '10');

  DateTime? _trekDate;
  String _trekType = 'regular_trek';
  String _bookingClassification = 'regular';
  bool _guideRequired = false;
  bool _scientistRequired = false;
  bool _isSubmitting = false;

  bool get _isOffSeason =>
      _trekDate != null && PricingService.instance.isOffSeason(_trekDate!);

  bool get _allowedInOffSeason =>
      PricingService.instance.isAllowedInOffSeason(_trekType);

  @override
  void initState() {
    super.initState();
    PricingService.instance.init();
  }

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    _affiliationCtrl.dispose();
    _notesCtrl.dispose();
    _maxSlotsCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_trekDate == null) {
      _snack('Please select a trek date.', isError: true);
      return;
    }
    if (_isOffSeason && !_allowedInOffSeason) {
      _snack(
        'Regular treks are not allowed during the off-season (July – September). '
        'Please select Special, Research, or Government trek type.',
        isError: true,
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      final maxSlots =
          (int.tryParse(_maxSlotsCtrl.text.trim()) ?? 10).clamp(2, 50);
      final group = GroupBooking(
        id: '',
        organizerId: user.uid,
        organizerName: user.displayName ?? user.email ?? 'Organizer',
        groupName: _groupNameCtrl.text.trim(),
        trekDate: Timestamp.fromDate(_trekDate!),
        trekType: _trekType,
        bookingClassification: _bookingClassification,
        seasonType: GroupBookingService.resolveSeasonType(_trekDate!),
        affiliation: _affiliationCtrl.text.trim(),
        maxSlots: maxSlots,
        guideRequired: _guideRequired,
        scientistRequired: _scientistRequired,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      final groupId =
          await GroupBookingService.instance.createGroupBooking(group);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrganizerRequestsScreen(groupId: groupId),
        ),
      );
    } catch (e) {
      AppLogger.e('CreateGroupScreen submit: $e');
      if (mounted) _snack('Failed to create group: $e', isError: true);
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Create a Group'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_isOffSeason && _trekDate != null)
              _OffSeasonBanner(allowed: _allowedInOffSeason),

            // ── Group details ────────────────────────────────────────────────
            _SectionLabel('Group Details'),
            _Field(
              controller: _groupNameCtrl,
              label: 'Group Name',
              hint: 'e.g. "UPLB Mountaineers Batch 2025"',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _affiliationCtrl,
              label: 'Affiliation / Organization',
              hint: 'e.g. "UPLB Mountaineers"',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _maxSlotsCtrl,
              label: 'Max Trekkers (including yourself)',
              hint: '2 – 50',
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 2 || n > 50) {
                  return 'Enter a number between 2 and 50';
                }
                return null;
              },
            ),

            // ── Trek details ─────────────────────────────────────────────────
            const SizedBox(height: 20),
            _SectionLabel('Trek Details'),
            _DateRow(
              date: _trekDate,
              onChanged: (d) => setState(() => _trekDate = d),
            ),
            const SizedBox(height: 12),
            _Dropdown<String>(
              label: 'Trek Type',
              value: _trekType,
              items: const {
                'regular_trek': 'Regular Trek',
                'special_trek': 'Special Trek',
                'research_trek': 'Research Trek',
                'government_official': 'Government / Official',
                'benchmarking_trek': 'Benchmarking',
              },
              onChanged: (v) => setState(() {
                _trekType = v!;
                // Auto-set classification for government type
                if (_trekType == 'government_official') {
                  _bookingClassification = 'government_official';
                }
              }),
            ),
            const SizedBox(height: 12),
            _Dropdown<String>(
              label: 'Booking Classification',
              value: _bookingClassification,
              items: const {
                'regular': 'Regular',
                'special': 'Special (needs Letter of Communication)',
                'government_official': 'Government / Official',
                'off_season': 'Off-Season (Special Approval)',
              },
              onChanged: (v) =>
                  setState(() => _bookingClassification = v!),
            ),

            // ── Group services ───────────────────────────────────────────────
            const SizedBox(height: 20),
            _SectionLabel('Group Services'),
            _ServiceToggle(
              value: _guideRequired,
              title: 'Tour Guide',
              subtitle:
                  '₱${PricingService.instance.guidePrice.toStringAsFixed(0)} — group-level',
              onChanged: (v) => setState(() => _guideRequired = v),
            ),
            _ServiceToggle(
              value: _scientistRequired,
              title: 'Scientist',
              subtitle:
                  '₱${PricingService.instance.scientistPrice.toStringAsFixed(0)} — group-level',
              onChanged: (v) => setState(() => _scientistRequired = v),
            ),

            // ── Notes ────────────────────────────────────────────────────────
            const SizedBox(height: 20),
            _SectionLabel('Notes (Optional)'),
            _Field(
              controller: _notesCtrl,
              label: 'Additional Notes',
              hint: 'Instructions, requirements, or reminders for joiners…',
              maxLines: 3,
            ),

            const SizedBox(height: 32),
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
                        'Create Group',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
          fontSize: 14,
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

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
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
      items: items.entries
          .map((e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _DateRow extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  const _DateRow({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = date == null
        ? 'Select Trek Date'
        : '${date!.day}/${date!.month}/${date!.year}';

    return OutlinedButton.icon(
      icon: Icon(Icons.calendar_today, size: 18, color: colors.primary),
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
          initialDate: date ?? DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        onChanged(picked);
      },
    );
  }
}

class _ServiceToggle extends StatelessWidget {
  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  const _ServiceToggle({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: TextStyle(color: colors.text, fontSize: 14)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colors.textSecondary, fontSize: 12),
      ),
      activeColor: colors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _OffSeasonBanner extends StatelessWidget {
  final bool allowed;
  const _OffSeasonBanner({required this.allowed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: allowed
            ? Colors.orange.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: allowed ? Colors.orange : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            allowed ? Icons.warning_amber_rounded : Icons.block,
            color: allowed ? Colors.orange : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              allowed
                  ? 'This date falls in the off-season (July – September). '
                      'Special, Research, and Government treks are permitted.'
                  : 'Regular treks are not allowed during the off-season '
                      '(July – September). Change the trek type to proceed.',
              style: TextStyle(
                fontSize: 12,
                color: allowed ? Colors.orange.shade800 : Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
