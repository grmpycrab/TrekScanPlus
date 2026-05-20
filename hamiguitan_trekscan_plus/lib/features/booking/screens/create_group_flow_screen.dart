// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../../models/group_booking.dart';
import '../../../models/member.dart';
import '../../../services/group_booking_service.dart';
import '../../../services/pricing_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';
import '../providers/group_creation_provider.dart';
import '../widgets/trek_date_picker.dart';
import 'organizer_requests_screen.dart';

/// Entry point — wraps [_CreateGroupFlowScreen] with a scoped
/// [GroupCreationProvider] so the flow state is disposed on pop.
class CreateGroupFlowScreen extends StatelessWidget {
  const CreateGroupFlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GroupCreationProvider()..prefillFromAuth(),
      child: const _CreateGroupFlowScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal stateful screen
// ─────────────────────────────────────────────────────────────────────────────

class _CreateGroupFlowScreen extends StatefulWidget {
  const _CreateGroupFlowScreen();

  @override
  State<_CreateGroupFlowScreen> createState() => _CreateGroupFlowScreenState();
}

class _CreateGroupFlowScreenState extends State<_CreateGroupFlowScreen> {
  // ── Form keys ──────────────────────────────────────────────────────────────
  final _step0Key = GlobalKey<FormState>();
  final _step1Key = GlobalKey<FormState>();

  // ── Step 0 controllers ─────────────────────────────────────────────────────
  final _groupNameCtrl = TextEditingController();
  final _affiliationCtrl = TextEditingController();
  final _maxSlotsCtrl = TextEditingController(text: '10');
  final _notesCtrl = TextEditingController();

  // ── Step 1 controllers ─────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController(text: 'Filipino');
  final _addressCtrl = TextEditingController();

  static const _stepTitles = [
    'Group Setup',
    'Your Details',
    'Group Members',
    'Review & Submit',
  ];

  @override
  void initState() {
    super.initState();
    PricingService.instance.init();
    // Pre-fill organizer controllers from provider (already called prefillFromAuth)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<GroupCreationProvider>();
      _firstNameCtrl.text = p.organizerFirstName;
      _lastNameCtrl.text = p.organizerLastName;
      _phoneCtrl.text = p.organizerPhone;
    });
  }

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    _affiliationCtrl.dispose();
    _maxSlotsCtrl.dispose();
    _notesCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _nationalityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ── Commit helpers ─────────────────────────────────────────────────────────

  void _commitStep0() {
    final p = context.read<GroupCreationProvider>();
    p.groupName = _groupNameCtrl.text.trim();
    p.affiliation = _affiliationCtrl.text.trim();
    p.maxSlots = (int.tryParse(_maxSlotsCtrl.text.trim()) ?? 10).clamp(2, 50);
    p.notes = _notesCtrl.text.trim();
  }

  void _commitStep1() {
    final p = context.read<GroupCreationProvider>();
    p.organizerFirstName = _firstNameCtrl.text.trim();
    p.organizerLastName = _lastNameCtrl.text.trim();
    p.organizerPhone = _phoneCtrl.text.trim();
    p.organizerNationality = _nationalityCtrl.text.trim();
    p.organizerAddress = _addressCtrl.text.trim();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _next() {
    final p = context.read<GroupCreationProvider>();
    if (p.step == 0) {
      if (!_step0Key.currentState!.validate()) return;
      if (p.trekDate == null) {
        p.setError('Please select a trek date.');
        return;
      }
      if (p.isOffSeasonDate &&
          !PricingService.instance.isAllowedInOffSeason(p.trekType)) {
        p.setError(
          'Regular treks are not allowed during the off-season '
          '(July – September). Select Special, Research, or Government trek type.',
        );
        return;
      }
      _commitStep0();
    } else if (p.step == 1) {
      if (!_step1Key.currentState!.validate()) return;
      if (p.organizerBirthDate == null) {
        p.setError('Please enter your birth date.');
        return;
      }
      _commitStep1();
    }
    p.nextStep();
  }

  void _back() => context.read<GroupCreationProvider>().prevStep();

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final p = context.read<GroupCreationProvider>();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    p.setSubmitting(true);
    p.setError(null);
    try {
      final organizerMember = p.buildOrganizerMember();
      final group = GroupBooking(
        id: '',
        organizerId: user.uid,
        organizerName: organizerMember.fullName,
        groupName: p.groupName,
        trekDate: Timestamp.fromDate(p.trekDate!),
        trekType: p.trekType,
        bookingClassification: p.bookingClassification,
        seasonType: GroupBookingService.resolveSeasonType(p.trekDate!),
        affiliation: p.affiliation,
        maxSlots: p.maxSlots,
        guideRequired: p.guideRequired,
        scientistRequired: p.scientistRequired,
        notes: p.notes.isEmpty ? null : p.notes,
        organizerMember: organizerMember,
        guestMembers: List.unmodifiable(p.guestMembers),
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
      AppLogger.e('CreateGroupFlowScreen submit: $e');
      if (mounted) p.setError('Failed to create group: $e');
    } finally {
      if (mounted) p.setSubmitting(false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GroupCreationProvider>();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_stepTitles[p.step]),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _StepProgressBar(step: p.step, total: 4),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _StepBody(
              step: p.step,
              step0Key: _step0Key,
              step1Key: _step1Key,
              groupNameCtrl: _groupNameCtrl,
              affiliationCtrl: _affiliationCtrl,
              maxSlotsCtrl: _maxSlotsCtrl,
              notesCtrl: _notesCtrl,
              firstNameCtrl: _firstNameCtrl,
              lastNameCtrl: _lastNameCtrl,
              phoneCtrl: _phoneCtrl,
              nationalityCtrl: _nationalityCtrl,
              addressCtrl: _addressCtrl,
            ),
          ),
          if (p.errorMessage != null) _ErrorBanner(p.errorMessage!),
          _BottomBar(
            step: p.step,
            isSubmitting: p.isSubmitting,
            onBack: _back,
            onNext: _next,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  final int step;
  final int total;

  const _StepProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: List.generate(total, (i) {
        final active = i <= step;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < total - 1 ? 2 : 0),
            color: active ? Colors.white : colors.primary.withOpacity(0.35),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step body dispatcher
// ─────────────────────────────────────────────────────────────────────────────

class _StepBody extends StatelessWidget {
  final int step;
  final GlobalKey<FormState> step0Key;
  final GlobalKey<FormState> step1Key;
  final TextEditingController groupNameCtrl;
  final TextEditingController affiliationCtrl;
  final TextEditingController maxSlotsCtrl;
  final TextEditingController notesCtrl;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController nationalityCtrl;
  final TextEditingController addressCtrl;

  const _StepBody({
    required this.step,
    required this.step0Key,
    required this.step1Key,
    required this.groupNameCtrl,
    required this.affiliationCtrl,
    required this.maxSlotsCtrl,
    required this.notesCtrl,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.phoneCtrl,
    required this.nationalityCtrl,
    required this.addressCtrl,
  });

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case 0:
        return _Step0GroupSetup(
          formKey: step0Key,
          groupNameCtrl: groupNameCtrl,
          affiliationCtrl: affiliationCtrl,
          maxSlotsCtrl: maxSlotsCtrl,
          notesCtrl: notesCtrl,
        );
      case 1:
        return _Step1OrganizerDetails(
          formKey: step1Key,
          firstNameCtrl: firstNameCtrl,
          lastNameCtrl: lastNameCtrl,
          phoneCtrl: phoneCtrl,
          nationalityCtrl: nationalityCtrl,
          addressCtrl: addressCtrl,
        );
      case 2:
        return const _Step2Members();
      case 3:
        return const _Step3Review();
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 0 — Group Setup
// ─────────────────────────────────────────────────────────────────────────────

class _Step0GroupSetup extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController groupNameCtrl;
  final TextEditingController affiliationCtrl;
  final TextEditingController maxSlotsCtrl;
  final TextEditingController notesCtrl;

  const _Step0GroupSetup({
    required this.formKey,
    required this.groupNameCtrl,
    required this.affiliationCtrl,
    required this.maxSlotsCtrl,
    required this.notesCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GroupCreationProvider>();

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        children: [
          if (p.isOffSeasonDate && p.trekDate != null)
            _OffSeasonBanner(
              allowed: PricingService.instance.isAllowedInOffSeason(p.trekType),
            ),

          _SectionLabel('Group Details'),
          _FlowField(
            controller: groupNameCtrl,
            label: 'Group Name',
            hint: 'e.g. "UPLB Mountaineers Batch 2025"',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _FlowField(
            controller: affiliationCtrl,
            label: 'Affiliation / Organization',
            hint: 'e.g. "UPLB Mountaineers"',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _FlowField(
            controller: maxSlotsCtrl,
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

          const SizedBox(height: 20),
          _SectionLabel('Trek Details'),
          TrekDatePicker(
            selectedDate: p.trekDate,
            totalMembers: p.maxSlots,
            onDateSelected: (d) =>
                context.read<GroupCreationProvider>().setTrekDate(d),
          ),
          const SizedBox(height: 12),
          _FlowDropdown<String>(
            label: 'Trek Type',
            value: p.trekType,
            items: const {
              'regular_trek': 'Regular Trek',
              'special_trek': 'Special Trek',
              'research_trek': 'Research Trek',
              'government_official': 'Government / Official',
              'benchmarking_trek': 'Benchmarking',
            },
            onChanged: (v) =>
                context.read<GroupCreationProvider>().setTrekType(v!),
          ),
          const SizedBox(height: 12),
          _FlowDropdown<String>(
            label: 'Booking Classification',
            value: p.bookingClassification,
            items: const {
              'regular': 'Regular',
              'special': 'Special (needs Letter of Communication)',
              'government_official': 'Government / Official',
              'off_season': 'Off-Season (Special Approval)',
            },
            onChanged: (v) => context
                .read<GroupCreationProvider>()
                .setBookingClassification(v!),
          ),

          const SizedBox(height: 20),
          _SectionLabel('Group Services'),
          _ServiceToggle(
            value: p.guideRequired,
            title: 'Tour Guide',
            subtitle:
                '₱${PricingService.instance.guidePrice.toStringAsFixed(0)} — group-level',
            onChanged: context.read<GroupCreationProvider>().setGuideRequired,
          ),
          _ServiceToggle(
            value: p.scientistRequired,
            title: 'Scientist',
            subtitle:
                '₱${PricingService.instance.scientistPrice.toStringAsFixed(0)} — group-level',
            onChanged:
                context.read<GroupCreationProvider>().setScientistRequired,
          ),

          const SizedBox(height: 20),
          _SectionLabel('Notes (Optional)'),
          _FlowField(
            controller: notesCtrl,
            label: 'Additional Notes',
            hint: 'Instructions or reminders for joiners…',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Organizer Details
// ─────────────────────────────────────────────────────────────────────────────

class _Step1OrganizerDetails extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController nationalityCtrl;
  final TextEditingController addressCtrl;

  const _Step1OrganizerDetails({
    required this.formKey,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.phoneCtrl,
    required this.nationalityCtrl,
    required this.addressCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GroupCreationProvider>();

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        children: [
          _SectionLabel('Personal Information'),
          Row(
            children: [
              Expanded(
                child: _FlowField(
                  controller: firstNameCtrl,
                  label: 'First Name',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FlowField(
                  controller: lastNameCtrl,
                  label: 'Last Name',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FlowDropdown<String>(
            label: 'Gender',
            value: p.organizerGender,
            items: const {
              'male': 'Male',
              'female': 'Female',
              'other': 'Other / Prefer not to say',
            },
            onChanged: (v) =>
                context.read<GroupCreationProvider>().setOrganizerGender(v!),
          ),
          const SizedBox(height: 12),
          _DatePickerRow(
            label: 'Birth Date',
            date: p.organizerBirthDate,
            firstDate: DateTime(1920),
            lastDate: DateTime.now().subtract(const Duration(days: 365 * 8)),
            onChanged: (d) {
              if (d != null) {
                context
                    .read<GroupCreationProvider>()
                    .setOrganizerBirthDate(d);
              }
            },
          ),
          const SizedBox(height: 12),
          _FlowField(
            controller: phoneCtrl,
            label: 'Contact Number',
            hint: '+639XXXXXXXXX',
            keyboardType: TextInputType.phone,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _FlowField(
            controller: nationalityCtrl,
            label: 'Nationality',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _FlowField(
            controller: addressCtrl,
            label: 'Home Address',
            hint: 'City / Province',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),

          const SizedBox(height: 20),
          _SectionLabel('Booking Category'),
          _CategoryDropdown(
            value: p.organizerCategory,
            onChanged: (v) => context
                .read<GroupCreationProvider>()
                .setOrganizerCategory(v!),
          ),
          const SizedBox(height: 4),
          _PriceHint(
            label: 'Your entry fee',
            amount: p.organizerMemberCost,
          ),

          const SizedBox(height: 12),
          _ServiceToggle(
            value: p.organizerPorterRequested,
            title: 'Request a Porter',
            subtitle:
                '₱${PricingService.instance.porterPrice.toStringAsFixed(0)} — personal porter',
            onChanged: context
                .read<GroupCreationProvider>()
                .setOrganizerPorterRequested,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Group Members
// ─────────────────────────────────────────────────────────────────────────────

class _Step2Members extends StatelessWidget {
  const _Step2Members();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GroupCreationProvider>();
    final colors = context.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        // Slot counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people_outline, color: colors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${p.totalSlotsFilled} of ${p.maxSlots} trekker slots filled',
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${p.remainingSlots} left',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              if (p.porterCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${p.porterCount} porter${p.porterCount != 1 ? 's' : ''} automatically allocated (1 per 5 trekkers)',
                  style: TextStyle(
                    color: colors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Organizer row (non-removable)
        _MemberTile(
          name: '${p.organizerFirstName} ${p.organizerLastName}'.trim(),
          category: PricingService.instance
              .getCategoryDisplayName(p.organizerCategory),
          cost: p.organizerTotal,
          porterRequested: p.organizerPorterRequested,
          isOrganizer: true,
        ),
        const SizedBox(height: 8),

        // Guest members
        ...List.generate(p.guestMembers.length, (i) {
          final m = p.guestMembers[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MemberTile(
              name: m.fullName,
              category: PricingService.instance
                  .getCategoryDisplayName(m.category),
              cost: p.guestTotal(i),
              porterRequested: i < p.guestPorterRequested.length &&
                  p.guestPorterRequested[i],
              onRemove: () =>
                  context.read<GroupCreationProvider>().removeGuestMember(i),
            ),
          );
        }),

        const SizedBox(height: 8),

        if (p.canAddGuest)
          OutlinedButton.icon(
            icon: Icon(Icons.person_add_alt_1, color: colors.primary),
            label: Text(
              'Add Guest Member',
              style: TextStyle(color: colors.primary),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _showAddMemberSheet(context),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'Maximum slots reached. Remove a member to add another.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Members without an app account can be added here as guests.\n'
          'Registered users can join your group after it is created.',
          style: TextStyle(
            color: colors.textTertiary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showAddMemberSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<GroupCreationProvider>(),
        child: const _AddGuestMemberSheet(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Review & Submit
// ─────────────────────────────────────────────────────────────────────────────

class _Step3Review extends StatelessWidget {
  const _Step3Review();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GroupCreationProvider>();
    final colors = context.colors;
    final ps = PricingService.instance;

    String fmtDate(DateTime? d) => d == null
        ? '—'
        : '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/'
            '${d.year}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        // ── Group info ─────────────────────────────────────────────────────
        _ReviewCard(
          title: 'Group Information',
          rows: [
            _ReviewRow('Group Name', p.groupName),
            _ReviewRow('Affiliation', p.affiliation),
            _ReviewRow('Trek Date', fmtDate(p.trekDate)),
            _ReviewRow('Trek Type', _trekTypeLabel(p.trekType)),
            _ReviewRow('Classification', _classLabel(p.bookingClassification)),
            _ReviewRow('Max Slots', p.maxSlots.toString()),
            if (p.notes.isNotEmpty) _ReviewRow('Notes', p.notes),
          ],
        ),
        const SizedBox(height: 12),

        // ── Organizer ─────────────────────────────────────────────────────
        _ReviewCard(
          title: 'Organizer (You)',
          rows: [
            _ReviewRow(
                'Name',
                '${p.organizerFirstName} ${p.organizerLastName}',),
            _ReviewRow('Category',
                ps.getCategoryDisplayName(p.organizerCategory)),
            _ReviewRow('Entry Fee',
                '₱${p.organizerMemberCost.toStringAsFixed(0)}'),
            if (p.organizerPorterRequested)
              _ReviewRow('Porter',
                  '+₱${ps.porterPrice.toStringAsFixed(0)}'),
            _ReviewRow(
                'Subtotal', '₱${p.organizerTotal.toStringAsFixed(0)}',
                bold: true),
          ],
        ),
        const SizedBox(height: 12),

        // ── Guest members ─────────────────────────────────────────────────
        if (p.guestMembers.isNotEmpty) ...[
          _ReviewCard(
            title: 'Guest Members (${p.guestMembers.length})',
            rows: List.generate(p.guestMembers.length, (i) {
              final m = p.guestMembers[i];
              final porter = i < p.guestPorterRequested.length &&
                  p.guestPorterRequested[i];
              return _ReviewRow(
                m.fullName,
                '₱${p.guestTotal(i).toStringAsFixed(0)}'
                    '${porter ? ' (incl. porter)' : ''}',
              );
            }),
          ),
          const SizedBox(height: 12),
        ],

        // ── Services ──────────────────────────────────────────────────────
        if (p.guideRequired || p.scientistRequired)
          _ReviewCard(
            title: 'Group Services',
            rows: [
              if (p.guideRequired)
                _ReviewRow('Tour Guide',
                    '₱${ps.guidePrice.toStringAsFixed(0)}'),
              if (p.scientistRequired)
                _ReviewRow('Scientist',
                    '₱${ps.scientistPrice.toStringAsFixed(0)}'),
            ],
          ),
        if (p.guideRequired || p.scientistRequired) const SizedBox(height: 12),

        // ── Porter allocation ──────────────────────────────────────────────
        if (p.porterCount > 0) ...[
          _ReviewCard(
            title: 'Porter Allocation (1 per 5 trekkers)',
            rows: [
              _ReviewRow(
                '${p.porterCount} porter${p.porterCount != 1 ? 's' : ''}',
                '₱${(p.porterCount * PricingService.instance.porterPrice).toStringAsFixed(0)}',
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // ── Grand total ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.primary.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grand Total',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '₱${p.grandTotal.toStringAsFixed(0)}',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Payment is collected at the ranger station on trek day.',
          style: TextStyle(
            color: colors.textTertiary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _trekTypeLabel(String t) {
    const map = {
      'regular_trek': 'Regular Trek',
      'special_trek': 'Special Trek',
      'research_trek': 'Research Trek',
      'government_official': 'Government / Official',
      'benchmarking_trek': 'Benchmarking',
    };
    return map[t] ?? t;
  }

  String _classLabel(String c) {
    const map = {
      'regular': 'Regular',
      'special': 'Special',
      'government_official': 'Government / Official',
      'off_season': 'Off-Season',
    };
    return map[c] ?? c;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Guest Member bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddGuestMemberSheet extends StatefulWidget {
  const _AddGuestMemberSheet();

  @override
  State<_AddGuestMemberSheet> createState() => _AddGuestMemberSheetState();
}

class _AddGuestMemberSheetState extends State<_AddGuestMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController(text: 'Filipino');
  final _addressCtrl = TextEditingController();

  String _gender = 'male';
  DateTime? _birthDate;
  String _category = 'outside_davao_oriental';
  bool _porterRequested = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _nationalityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _add() {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the member\'s birth date.')),
      );
      return;
    }

    final birthDateStr =
        '${_birthDate!.year}-'
        '${_birthDate!.month.toString().padLeft(2, '0')}-'
        '${_birthDate!.day.toString().padLeft(2, '0')}';

    final member = Member(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      gender: _gender,
      birthDate: birthDateStr,
      contactNumber: _phoneCtrl.text.trim(),
      nationality: _nationalityCtrl.text.trim(),
      homeAddress: _addressCtrl.text.trim(),
      category: _category,
      hasAccount: false,
      memberStatus: 'complete',
      createdAt: Timestamp.now(),
    );

    context.read<GroupCreationProvider>().addGuestMember(
          member,
          porterRequested: _porterRequested,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Add Guest Member',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _FlowField(
                            controller: _firstNameCtrl,
                            label: 'First Name',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FlowField(
                            controller: _lastNameCtrl,
                            label: 'Last Name',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FlowDropdown<String>(
                      label: 'Gender',
                      value: _gender,
                      items: const {
                        'male': 'Male',
                        'female': 'Female',
                        'other': 'Other / Prefer not to say',
                      },
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                    const SizedBox(height: 12),
                    _DatePickerRow(
                      label: 'Birth Date',
                      date: _birthDate,
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now()
                          .subtract(const Duration(days: 365 * 8)),
                      onChanged: (d) => setState(() => _birthDate = d),
                    ),
                    const SizedBox(height: 12),
                    _FlowField(
                      controller: _phoneCtrl,
                      label: 'Contact Number',
                      hint: '+639XXXXXXXXX',
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _FlowField(
                      controller: _nationalityCtrl,
                      label: 'Nationality',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _FlowField(
                      controller: _addressCtrl,
                      label: 'Home Address',
                      hint: 'City / Province',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _CategoryDropdown(
                      value: _category,
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                    const SizedBox(height: 4),
                    _PriceHint(
                      label: 'Entry fee',
                      amount: PricingService.instance
                          .calculateMemberPrice(_category),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      value: _porterRequested,
                      onChanged: (v) => setState(() => _porterRequested = v),
                      title: Text(
                        'Request a Porter',
                        style: TextStyle(color: colors.text, fontSize: 14),
                      ),
                      subtitle: Text(
                        '+₱${PricingService.instance.porterPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 12),
                      ),
                      activeColor: colors.primary,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _add,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Add Member',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int step;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  const _BottomBar({
    required this.step,
    required this.isSubmitting,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLast = step == 3;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (step > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: isSubmitting ? null : onBack,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Back',
                    style: TextStyle(color: colors.textSecondary)),
              ),
            ),
          if (step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : (isLast ? onSubmit : onNext),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isLast ? 'Submit for Approval' : 'Next',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared local widgets
// ─────────────────────────────────────────────────────────────────────────────

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
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FlowField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  const _FlowField({
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
      style: TextStyle(color: colors.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
        filled: true,
        fillColor: colors.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
    );
  }
}

class _FlowDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const _FlowDropdown({
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
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
        filled: true,
        fillColor: colors.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
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

class _DatePickerRow extends StatelessWidget {
  final String label;
  final DateTime? date;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerRow({
    required this.label,
    required this.date,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final display = date == null
        ? label
        : '$label: ${date!.day.toString().padLeft(2, '0')}/'
            '${date!.month.toString().padLeft(2, '0')}/'
            '${date!.year}';

    return OutlinedButton.icon(
      icon: Icon(Icons.calendar_today, size: 17, color: colors.primary),
      label: Text(display, style: TextStyle(color: colors.text, fontSize: 14)),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        side: BorderSide(color: colors.border),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: colors.inputFill,
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ??
              (firstDate != null
                  ? firstDate!
                  : DateTime.now().add(const Duration(days: 7))),
          firstDate: firstDate ?? DateTime.now(),
          lastDate: lastDate ??
              DateTime.now().add(const Duration(days: 365)),
        );
        onChanged(picked);
      },
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cats = PricingService.instance.allCategories;

    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
        filled: true,
        fillColor: colors.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
      dropdownColor: colors.surface,
      style: TextStyle(color: colors.text, fontSize: 14),
      items: cats.entries
          .map((e) => DropdownMenuItem<String>(
                value: e.key,
                child: Text(e.value.displayName),
              ))
          .toList(),
      onChanged: onChanged,
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

class _PriceHint extends StatelessWidget {
  final String label;
  final double amount;

  const _PriceHint({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
      child: Text(
        '$label: ₱${amount.toStringAsFixed(0)}',
        style: TextStyle(
          color: colors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String category;
  final double cost;
  final bool porterRequested;
  final bool isOrganizer;
  final VoidCallback? onRemove;

  const _MemberTile({
    required this.name,
    required this.category,
    required this.cost,
    required this.porterRequested,
    this.isOrganizer = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.primary.withOpacity(0.1),
            child: Icon(
              isOrganizer ? Icons.star_outline : Icons.person_outline,
              size: 18,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name.isEmpty ? '(you)' : name,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (isOrganizer) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Organizer',
                          style: TextStyle(
                              color: colors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$category${porterRequested ? ' · Porter' : ''}',
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '₱${cost.toStringAsFixed(0)}',
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, color: colors.textTertiary, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.shade50,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final List<Widget> rows;

  const _ReviewCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              title,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Divider(height: 1),
          ...rows,
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _ReviewRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.text,
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
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
