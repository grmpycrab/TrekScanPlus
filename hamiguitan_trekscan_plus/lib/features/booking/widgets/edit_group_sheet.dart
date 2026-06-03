// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/group_booking.dart';
import '../../../services/group_booking_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';

/// Bottom sheet that lets the organizer edit a group booking.
/// Only available when [GroupBookingService.isEditable] returns true
/// (status is 'open' or 'changes_required').
class EditGroupSheet extends StatefulWidget {
  final GroupBooking group;

  const EditGroupSheet({super.key, required this.group});

  @override
  State<EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends State<EditGroupSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _affiliationCtrl;
  late final TextEditingController _maxSlotsCtrl;
  late final TextEditingController _notesCtrl;

  late DateTime _trekDate;
  late String _trekType;
  late bool _guideRequired;
  late bool _scientistRequired;

  bool _saving = false;

  static const _trekTypes = {
    'regular_trek': 'Regular Trek',
    'special_trek': 'Special Trek',
    'government_official': 'Government Official',
    'research_trek': 'Research Trek',
    'benchmarking_trek': 'Benchmarking Trek',
  };

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _nameCtrl = TextEditingController(text: g.groupName);
    _affiliationCtrl = TextEditingController(text: g.affiliation);
    _maxSlotsCtrl =
        TextEditingController(text: g.maxSlots.toString());
    _notesCtrl = TextEditingController(text: g.notes ?? '');
    _trekDate = g.trekDate.toDate();
    _trekType = g.trekType;
    _guideRequired = g.guideRequired;
    _scientistRequired = g.scientistRequired;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _affiliationCtrl.dispose();
    _maxSlotsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _trekDate.isAfter(DateTime.now())
          ? _trekDate
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _trekDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final newMaxSlots = int.tryParse(_maxSlotsCtrl.text.trim()) ?? widget.group.maxSlots;
    if (newMaxSlots < widget.group.currentSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Max slots cannot be less than current members (${widget.group.currentSlots}).',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await GroupBookingService.instance.updateGroupBooking(
        widget.group.id,
        groupName: _nameCtrl.text.trim(),
        trekDate: Timestamp.fromDate(_trekDate),
        maxSlots: newMaxSlots,
        trekType: _trekType,
        affiliation: _affiliationCtrl.text.trim(),
        guideRequired: _guideRequired,
        scientistRequired: _scientistRequired,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group details updated.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Edit group failed: $e');
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
    final dateLabel =
        '${_trekDate.day.toString().padLeft(2, '0')}/'
        '${_trekDate.month.toString().padLeft(2, '0')}/'
        '${_trekDate.year}';

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
              // Handle
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
                    'Edit Group Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Group name
              TextFormField(
                controller: _nameCtrl,
                decoration: _decor('Group Name', Icons.group_rounded),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Affiliation
              TextFormField(
                controller: _affiliationCtrl,
                decoration:
                    _decor('Affiliation / School / Company', Icons.business_rounded),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Trek date picker
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 18, color: colors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Trek Date: $dateLabel',
                          style: TextStyle(
                              fontSize: 15, color: colors.text),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: colors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Max slots
              TextFormField(
                controller: _maxSlotsCtrl,
                decoration: _decor(
                  'Max Trekkers (min: ${widget.group.currentSlots})',
                  Icons.people_rounded,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 2) return 'Must be at least 2';
                  if (n < widget.group.currentSlots) {
                    return 'Cannot be less than current members (${widget.group.currentSlots})';
                  }
                  if (n > 50) return 'Maximum is 50';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Trek type
              DropdownButtonFormField<String>(
                value: _trekType,
                decoration: _decor('Trek Type', Icons.terrain_rounded),
                items: _trekTypes.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _trekType = v);
                },
              ),
              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _notesCtrl,
                decoration: _decor('Notes (optional)', Icons.notes_rounded),
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 14),

              // Guide / Scientist toggles
              _Toggle(
                label: 'Guide Required',
                icon: Icons.person_pin_circle_rounded,
                value: _guideRequired,
                onChanged: (v) => setState(() => _guideRequired = v),
                colors: colors,
              ),
              const SizedBox(height: 8),
              _Toggle(
                label: 'Scientist Required',
                icon: Icons.science_rounded,
                value: _scientistRequired,
                onChanged: (v) => setState(() => _scientistRequired = v),
                colors: colors,
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
                  label: Text(_saving ? 'Saving...' : 'Save Changes'),
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

  InputDecoration _decor(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

class _Toggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppTheme colors;

  const _Toggle({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 14, color: colors.text)),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
