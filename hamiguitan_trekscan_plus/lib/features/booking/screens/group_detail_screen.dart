// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/booking_model.dart';
import '../../../models/group_booking.dart';
import '../../../models/join_request.dart';
import '../../../models/member.dart';
import '../../../services/group_booking_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';
import '../widgets/group_status_chip.dart';
import 'join_request_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Public API
// ══════════════════════════════════════════════════════════════════════════════

/// The central entity screen for a [GroupBooking].
///
/// Dynamically adapts tabs and content based on the caller's role:
///   - [GroupRole.visitor]          → Overview only
///   - [GroupRole.pendingRequester] → Overview only (with pending-state CTA)
///   - [GroupRole.approvedMember]   → Overview · Members · Documents
///   - [GroupRole.organizer]        → Overview · Members · Requests · Documents · Settings
class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

// ── Role enum ─────────────────────────────────────────────────────────────────

enum GroupRole { visitor, pendingRequester, approvedMember, organizer }

GroupRole _deriveRole(
    GroupBooking group, JoinRequest? myRequest, String uid) {
  if (uid.isEmpty) return GroupRole.visitor;
  if (group.organizerId == uid) return GroupRole.organizer;
  if (myRequest?.isApproved == true) return GroupRole.approvedMember;
  if (myRequest?.isPending == true) return GroupRole.pendingRequester;
  return GroupRole.visitor;
}

// ══════════════════════════════════════════════════════════════════════════════
// Screen state
// ══════════════════════════════════════════════════════════════════════════════

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  GroupRole? _lastRole;

  // Stream state — avoids nested StreamBuilders rebuilding the full Scaffold.
  GroupBooking? _group;
  JoinRequest? _myRequest;
  bool _loading = true;
  String? _errorMessage;
  late StreamSubscription<GroupBooking?> _groupSub;
  late StreamSubscription<JoinRequest?> _requestSub;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _groupSub = GroupBookingService.instance
        .streamGroup(widget.groupId)
        .listen(
          (group) => setState(() {
            _group = group;
            _loading = false;
            _errorMessage = group == null ? 'Group not found.' : null;
          }),
          onError: (e) => setState(() {
            _loading = false;
            _errorMessage = 'Failed to load group.';
          }),
        );
    _requestSub = GroupBookingService.instance
        .streamMyRequest(widget.groupId, uid)
        .listen((req) => setState(() => _myRequest = req));
  }

  @override
  void dispose() {
    _groupSub.cancel();
    _requestSub.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  void _syncTabs(GroupRole role) {
    final count = _tabCount(role);
    if (_tabController == null ||
        _tabController!.length != count ||
        _lastRole != role) {
      _tabController?.dispose();
      _tabController = TabController(length: count, vsync: this);
      _lastRole = role;
    }
  }

  int _tabCount(GroupRole role) => switch (role) {
        GroupRole.visitor => 1,
        GroupRole.pendingRequester => 1,
        GroupRole.approvedMember => 3,
        GroupRole.organizer => 5,
      };

  List<Tab> _tabs(GroupRole role) => switch (role) {
        GroupRole.visitor || GroupRole.pendingRequester => const [
            Tab(text: 'Overview'),
          ],
        GroupRole.approvedMember => const [
            Tab(text: 'Overview'),
            Tab(text: 'Members'),
            Tab(text: 'Documents'),
          ],
        GroupRole.organizer => const [
            Tab(text: 'Overview'),
            Tab(text: 'Members'),
            Tab(text: 'Requests'),
            Tab(text: 'Documents'),
            Tab(text: 'Settings'),
          ],
      };

  List<Widget> _tabViews(
    GroupBooking group,
    GroupRole role,
    JoinRequest? myRequest,
  ) =>
      switch (role) {
        GroupRole.visitor || GroupRole.pendingRequester => [
            _OverviewTab(
                group: group, role: role, myRequest: myRequest),
          ],
        GroupRole.approvedMember => [
            _OverviewTab(
                group: group, role: role, myRequest: myRequest),
            _MembersTab(group: group, role: role),
            _DocumentsTab(
                group: group, role: role, myRequest: myRequest),
          ],
        GroupRole.organizer => [
            _OverviewTab(
                group: group, role: role, myRequest: myRequest),
            _MembersTab(group: group, role: role),
            _RequestsTab(group: group),
            _DocumentsTab(
                group: group, role: role, myRequest: myRequest),
            _SettingsTab(group: group),
          ],
      };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _LoadingScaffold(groupId: widget.groupId);
    if (_errorMessage != null) return _ErrorScaffold(message: _errorMessage!);

    final group = _group!;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final role = _deriveRole(group, _myRequest, uid);
    _syncTabs(role);

    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(group.groupName, overflow: TextOverflow.ellipsis),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController!,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: _tabController!.length > 3,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: _tabs(role),
        ),
      ),
      body: TabBarView(
        controller: _tabController!,
        children: _tabViews(group, role, _myRequest),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB — Overview
// ══════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  final GroupBooking group;
  final GroupRole role;
  final JoinRequest? myRequest;

  const _OverviewTab({
    required this.group,
    required this.role,
    required this.myRequest,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _StatusBanner(group: group),
        const SizedBox(height: 16),
        _TrekInfoCard(group: group),
        const SizedBox(height: 12),
        _OrganizerCard(group: group),
        if (group.notes != null && group.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _NotesCard(title: 'Notes', body: group.notes!),
        ],
        if (group.adminNotes != null && group.adminNotes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _NotesCard(
            title: 'Admin Notes',
            body: group.adminNotes!,
            isAdmin: true,
          ),
        ],
        const SizedBox(height: 20),
        _RoleCTA(group: group, role: role, myRequest: myRequest),
      ],
    );
  }
}

// ── Status banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final GroupBooking group;
  const _StatusBanner({required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = group.trekDate.toDate();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border, width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Stat(Icons.calendar_today_rounded, dateLabel),
                _Stat(
                  Icons.people_rounded,
                  '${group.currentSlots}/${group.maxSlots} trekkers',
                ),
                _Stat(Icons.label_outline_rounded, group.trekTypeLabel),
                if (group.guideRequired)
                  _Stat(Icons.person_pin_circle_rounded, 'Guide'),
                if (group.scientistRequired)
                  _Stat(Icons.science_rounded, 'Scientist'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GroupStatusChip(status: group.status),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final c = context.colors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}

// ── Trek info card ────────────────────────────────────────────────────────────

class _TrekInfoCard extends StatelessWidget {
  final GroupBooking group;
  const _TrekInfoCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = group.trekDate.toDate();

    return _InfoCard(
      title: 'Trek Information',
      icon: Icons.terrain_rounded,
      children: [
        _InfoRow('Group Name', group.groupName),
        _InfoRow('Affiliation', group.affiliation),
        _InfoRow(
          'Trek Date',
          '${_weekday(date.weekday)}, ${date.day} ${_month(date.month)} ${date.year}',
        ),
        _InfoRow('Trek Type', group.trekTypeLabel),
        _InfoRow('Classification', group.classificationLabel),
        _InfoRow('Season', group.seasonType == 'off_season' ? 'Off-Season' : 'Regular'),
        _InfoRow('Max Group Size', '${group.maxSlots} trekkers'),
        if (group.status == 'open' || group.status == 'full')
          _InfoRow(
            'Available Slots',
            group.availableSlots > 0
                ? '${group.availableSlots} remaining'
                : 'Full',
            valueColor: group.availableSlots > 0
                ? colors.success
                : colors.error,
          ),
      ],
    );
  }

  String _weekday(int d) => const [
        '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
      ][d];

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

// ── Organizer card ────────────────────────────────────────────────────────────

class _OrganizerCard extends StatelessWidget {
  final GroupBooking group;
  const _OrganizerCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Organizer',
      icon: Icons.manage_accounts_rounded,
      children: [
        _InfoRow('Name', group.organizerName),
        if (group.organizerMember != null) ...[
          _InfoRow('Category',
              group.organizerMember!.categoryDisplayName),
          if (group.organizerMember!.contactNumber.isNotEmpty)
            _InfoRow('Contact', group.organizerMember!.contactNumber),
        ],
      ],
    );
  }
}

// ── Notes card ────────────────────────────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  final String title;
  final String body;
  final bool isAdmin;
  const _NotesCard(
      {required this.title, required this.body, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAdmin
            ? colors.info.withOpacity(0.07)
            : colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAdmin
              ? colors.info.withOpacity(0.3)
              : colors.border,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAdmin ? Icons.admin_panel_settings_rounded : Icons.notes_rounded,
                size: 14,
                color: isAdmin ? colors.info : colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isAdmin ? colors.info : colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: colors.text,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Role-based CTA ────────────────────────────────────────────────────────────

class _RoleCTA extends StatelessWidget {
  final GroupBooking group;
  final GroupRole role;
  final JoinRequest? myRequest;

  const _RoleCTA({
    required this.group,
    required this.role,
    required this.myRequest,
  });

  @override
  Widget build(BuildContext context) {
    return switch (role) {
      GroupRole.visitor => _VisitorCTA(group: group),
      GroupRole.pendingRequester =>
        _PendingCTA(request: myRequest!, group: group),
      GroupRole.approvedMember => _ApprovedCTA(group: group),
      GroupRole.organizer => const SizedBox.shrink(),
    };
  }
}

class _VisitorCTA extends StatelessWidget {
  final GroupBooking group;
  const _VisitorCTA({required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canJoin = group.isOpen;

    return Column(
      children: [
        if (!canJoin)
          _InfoBanner(
            icon: Icons.info_outline_rounded,
            message: group.status == 'full'
                ? 'This group is full. No slots available.'
                : 'This group is no longer accepting requests.',
            color: colors.textSecondary,
          ),
        if (canJoin)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.how_to_reg_rounded),
              label: const Text(
                'Request to Join',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JoinRequestScreen(group: group),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }
}

class _PendingCTA extends StatefulWidget {
  final JoinRequest request;
  final GroupBooking group;
  const _PendingCTA({required this.request, required this.group});

  @override
  State<_PendingCTA> createState() => _PendingCTAState();
}

class _PendingCTAState extends State<_PendingCTA> {
  bool _withdrawing = false;

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        title: Text('Withdraw Request',
            style: TextStyle(color: ctx.colors.text)),
        content: Text(
          'Are you sure you want to withdraw your join request?\n'
          'You can reapply later if the group is still open.',
          style:
              TextStyle(color: ctx.colors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: ctx.colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _withdrawing = true);
    try {
      await GroupBookingService.instance.withdrawJoinRequest(
        widget.group.id,
        widget.request.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request withdrawn.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('withdraw: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  color: Colors.orange, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request Pending',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Awaiting organizer review. You will be notified once a decision is made.',
                      style: TextStyle(
                          fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: _withdrawing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.red),
                  )
                : const Icon(Icons.undo_rounded, size: 16),
            label: const Text('Withdraw Request',
                style: TextStyle(fontSize: 13)),
            onPressed: _withdrawing ? null : _withdraw,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red.withOpacity(0.6)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ApprovedCTA extends StatelessWidget {
  final GroupBooking group;
  const _ApprovedCTA({required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're in!",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  'You are an approved member of this group.',
                  style: TextStyle(
                      fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB — Members
// ══════════════════════════════════════════════════════════════════════════════

class _MembersTab extends StatelessWidget {
  final GroupBooking group;
  final GroupRole role;

  const _MembersTab({required this.group, required this.role});

  bool get _showContact => role == GroupRole.organizer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Organizer ────────────────────────────────────────────────────────
        if (group.organizerMember != null) ...[
          _MemberSectionLabel('Organizer', Icons.manage_accounts_rounded),
          _MemberTile(
            member: group.organizerMember!,
            showContact: _showContact,
          ),
          const SizedBox(height: 16),
        ],

        // ── Guest members ────────────────────────────────────────────────────
        if (group.guestMembers.isNotEmpty) ...[
          _MemberSectionLabel(
            'Guest Members (${group.guestMembers.length})',
            Icons.person_add_rounded,
          ),
          ...group.guestMembers.map(
            (m) =>
                _MemberTile(member: m, showContact: _showContact),
          ),
          const SizedBox(height: 16),
        ],

        // ── Approved joiners (from join requests) ────────────────────────────
        _MemberSectionLabel('Approved Joiners', Icons.group_rounded),
        StreamBuilder<List<JoinRequest>>(
          stream: GroupBookingService.instance.streamJoinRequests(
            group.id,
            statusFilter: 'approved',
          ),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final approved = snap.data ?? [];
            if (approved.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'No approved joiners yet.',
                  style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textSecondary),
                ),
              );
            }
            return Column(
              children: approved
                  .map(
                    (r) => _JoinerTile(
                      request: r,
                      showContact: _showContact,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _MemberSectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;
  const _MemberSectionLabel(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: colors.textSecondary),
          const SizedBox(width: 5),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: colors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Member member;
  final bool showContact;

  const _MemberTile({required this.member, this.showContact = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 0.8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.primary.withOpacity(0.12),
            child: Text(
              member.firstName.isNotEmpty
                  ? member.firstName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.text),
                ),
                Text(
                  member.categoryDisplayName,
                  style: TextStyle(
                      fontSize: 12, color: colors.textSecondary),
                ),
                if (showContact && member.contactNumber.isNotEmpty)
                  Text(
                    member.contactNumber,
                    style: TextStyle(
                        fontSize: 12, color: colors.textSecondary),
                  ),
              ],
            ),
          ),
          GroupStatusChip(status: member.memberStatus, compact: true),
        ],
      ),
    );
  }
}

class _JoinerTile extends StatelessWidget {
  final JoinRequest request;
  final bool showContact;

  const _JoinerTile({required this.request, this.showContact = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = request.member;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 0.8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green.withOpacity(0.12),
            child: Text(
              m.firstName.isNotEmpty ? m.firstName[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.fullName,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.text),
                ),
                Text(
                  m.categoryDisplayName,
                  style: TextStyle(
                      fontSize: 12, color: colors.textSecondary),
                ),
                if (showContact && m.contactNumber.isNotEmpty)
                  Text(
                    m.contactNumber,
                    style: TextStyle(
                        fontSize: 12, color: colors.textSecondary),
                  ),
                if (request.porterRequested)
                  Text(
                    '+ Porter requested',
                    style: TextStyle(
                        fontSize: 11,
                        color: colors.warning),
                  ),
              ],
            ),
          ),
          const GroupStatusChip(
              status: 'approved', compact: true),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB — Requests  (organizer only)
// ══════════════════════════════════════════════════════════════════════════════

class _RequestsTab extends StatefulWidget {
  final GroupBooking group;
  const _RequestsTab({required this.group});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _innerTabs;

  @override
  void initState() {
    super.initState();
    _innerTabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _innerTabs.dispose();
    super.dispose();
  }

  Future<void> _approve(JoinRequest r) async {
    try {
      await GroupBookingService.instance
          .approveJoinRequest(r.groupId, r.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${r.userDisplayName} approved.'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      AppLogger.e('approve: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _decline(JoinRequest r) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('Decline Request',
              style: TextStyle(color: colors.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Declining ${r.userDisplayName}\'s request.',
                style: TextStyle(
                    color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: TextStyle(color: colors.text),
                decoration: InputDecoration(
                  hintText: 'Reason for declining (optional)…',
                  hintStyle:
                      TextStyle(color: colors.textTertiary),
                  filled: true,
                  fillColor: colors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style:
                      TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white),
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await GroupBookingService.instance.declineJoinRequest(
        r.groupId,
        r.id,
        reason: reasonCtrl.text.trim().isEmpty
            ? null
            : reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${r.userDisplayName} declined.'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      AppLogger.e('decline: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Container(
          color: colors.surfaceVariant,
          child: TabBar(
            controller: _innerTabs,
            indicatorColor: colors.primary,
            labelColor: colors.primary,
            unselectedLabelColor: colors.textSecondary,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Declined'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTabs,
            children: [
              _RequestList(
                groupId: widget.group.id,
                statusFilter: 'pending',
                onApprove: _approve,
                onDecline: _decline,
              ),
              _RequestList(
                groupId: widget.group.id,
                statusFilter: 'approved',
              ),
              _RequestList(
                groupId: widget.group.id,
                statusFilter: 'declined',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Request list ─────────────────────────────────────────────────────────────

class _RequestList extends StatelessWidget {
  final String groupId;
  final String statusFilter;
  final Future<void> Function(JoinRequest)? onApprove;
  final Future<void> Function(JoinRequest)? onDecline;

  const _RequestList({
    required this.groupId,
    required this.statusFilter,
    this.onApprove,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<List<JoinRequest>>(
      stream: GroupBookingService.instance.streamJoinRequests(
        groupId,
        statusFilter: statusFilter,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text('Failed to load requests.',
                style: TextStyle(color: colors.textSecondary)),
          );
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 52, color: colors.iconMuted),
                const SizedBox(height: 10),
                Text(
                  'No $statusFilter requests',
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) => _RequestCard(
            request: requests[i],
            onApprove: onApprove,
            onDecline: onDecline,
          ),
        );
      },
    );
  }
}

// ── Request card ─────────────────────────────────────────────────────────────

class _RequestCard extends StatefulWidget {
  final JoinRequest request;
  final Future<void> Function(JoinRequest)? onApprove;
  final Future<void> Function(JoinRequest)? onDecline;

  const _RequestCard(
      {required this.request, this.onApprove, this.onDecline});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _acting = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final r = widget.request;
    final m = r.member;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.primary.withOpacity(0.12),
                child: Text(
                  m.firstName.isNotEmpty
                      ? m.firstName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.fullName,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.text),
                    ),
                    Text(
                      m.categoryDisplayName,
                      style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              GroupStatusChip(status: r.status, compact: true),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Details
          _DetailRow('Contact', m.contactNumber),
          _DetailRow('Address', m.homeAddress),
          _DetailRow('Nationality', m.nationality),
          if (r.porterRequested)
            _DetailRow('Porter', 'Requested',
                valueColor: colors.warning),
          if (r.notes != null && r.notes!.isNotEmpty)
            _DetailRow('Notes', r.notes!),
          if (r.declineReason != null &&
              r.declineReason!.isNotEmpty)
            _DetailRow('Decline Reason', r.declineReason!,
                valueColor: colors.error),

          // Attachments indicator
          if (r.attachments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.attach_file_rounded,
                    size: 13, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${r.attachments.length} document${r.attachments.length > 1 ? 's' : ''} attached',
                  style: TextStyle(
                      fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ],

          // Pending actions
          if (r.isPending &&
              (widget.onApprove != null ||
                  widget.onDecline != null)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _acting
                        ? null
                        : () async {
                            setState(() => _acting = true);
                            await widget.onDecline?.call(r);
                            if (mounted) {
                              setState(() => _acting = false);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                    ),
                    child: _acting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red),
                          )
                        : const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _acting
                        ? null
                        : () async {
                            setState(() => _acting = true);
                            await widget.onApprove?.call(r);
                            if (mounted) {
                              setState(() => _acting = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                    ),
                    child: _acting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: colors.textTertiary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 12,
                  color: valueColor ?? colors.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB — Documents
// ══════════════════════════════════════════════════════════════════════════════

class _DocumentsTab extends StatelessWidget {
  final GroupBooking group;
  final GroupRole role;
  final JoinRequest? myRequest;

  const _DocumentsTab({
    required this.group,
    required this.role,
    required this.myRequest,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Letter of Communication
        if (group.letterOfCommunication != null) ...[
          _DocSectionLabel('Letter of Communication'),
          _AttachmentTile(att: group.letterOfCommunication!),
          const SizedBox(height: 14),
        ],

        // Group-level member documents
        if (group.attachments.isNotEmpty) ...[
          _DocSectionLabel(
              'Member Documents (${group.attachments.length})'),
          ...group.attachments.map((a) => _AttachmentTile(att: a)),
          const SizedBox(height: 14),
        ],

        // Organizer: show all join-request attachments
        if (role == GroupRole.organizer) ...[
          _DocSectionLabel('Join Request Documents'),
          StreamBuilder<List<JoinRequest>>(
            stream: GroupBookingService.instance
                .streamJoinRequests(group.id),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator());
              }
              final withDocs = (snap.data ?? [])
                  .where((r) => r.attachments.isNotEmpty)
                  .toList();
              if (withDocs.isEmpty) {
                return Text(
                  'No join-request documents uploaded yet.',
                  style: TextStyle(
                      fontSize: 13, color: colors.textSecondary),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: withDocs
                    .expand((r) => r.attachments.map(
                          (a) => _AttachmentTile(
                            att: a,
                            owner: r.userDisplayName,
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],

        // Approved member: show only their own request's attachments
        if (role == GroupRole.approvedMember &&
            myRequest != null &&
            myRequest!.attachments.isNotEmpty) ...[
          _DocSectionLabel('Your Documents'),
          ...myRequest!.attachments
              .map((a) => _AttachmentTile(att: a)),
        ],

        // Empty state
        if (group.letterOfCommunication == null &&
            group.attachments.isEmpty &&
            role != GroupRole.organizer &&
            (myRequest == null || myRequest!.attachments.isEmpty))
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_off_rounded,
                      size: 52, color: colors.iconMuted),
                  const SizedBox(height: 12),
                  Text(
                    'No documents available.',
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DocSectionLabel extends StatelessWidget {
  final String title;
  const _DocSectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: context.colors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final Attachment att;
  final String? owner;
  const _AttachmentTile({required this.att, this.owner});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isImage = _isImage(att.mimeType);
    final sizeLabel = _formatSize(att.size);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border, width: 0.8),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isImage
                ? Icons.image_rounded
                : Icons.insert_drive_file_rounded,
            color: colors.primary,
            size: 20,
          ),
        ),
        title: Text(
          att.fileName,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.text),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (owner != null)
              Text(
                owner!,
                style: TextStyle(
                    fontSize: 11, color: colors.textSecondary),
              ),
            if (sizeLabel.isNotEmpty || att.memberName != null)
              Text(
                [
                  if (att.memberName != null &&
                      att.memberName != owner)
                    att.memberName!,
                  if (sizeLabel.isNotEmpty) sizeLabel,
                ].join(' · '),
                style: TextStyle(
                    fontSize: 11, color: colors.textTertiary),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.copy_rounded,
              size: 18, color: colors.textSecondary),
          tooltip: 'Copy download link',
          onPressed: () {
            Clipboard.setData(
                ClipboardData(text: att.downloadURL));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Download link copied to clipboard.'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isImage(String? mime) =>
      mime != null &&
      (mime.startsWith('image/') ||
          mime == 'image/jpeg' ||
          mime == 'image/png');

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB — Settings  (organizer only)
// ══════════════════════════════════════════════════════════════════════════════

class _SettingsTab extends StatefulWidget {
  final GroupBooking group;
  const _SettingsTab({required this.group});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool _updating = false;

  Future<void> _changeStatus(String newStatus,
      {String confirmTitle = 'Confirm',
      required String confirmBody,
      Color actionColor = Colors.red}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          title:
              Text(confirmTitle, style: TextStyle(color: colors.text)),
          content: Text(confirmBody,
              style: TextStyle(
                  color: colors.textSecondary, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: Colors.white),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _updating = true);
    try {
      await GroupBookingService.instance
          .updateGroupStatus(widget.group.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Group status updated to "$newStatus".'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('updateGroupStatus: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = widget.group.status;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Current status card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border, width: 0.8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Status',
                      style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    GroupStatusChip(status: status),
                  ],
                ),
              ),
              Text(
                '${widget.group.currentSlots}/${widget.group.maxSlots}\ntrekkers',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: colors.text,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'LIFECYCLE CONTROLS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: colors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),

        const SizedBox(height: 12),

        // Status-specific actions
        if (status == 'open') ...[
          _ActionTile(
            icon: Icons.send_rounded,
            title: 'Submit for Admin Review',
            subtitle:
                'Lock the group and send it to the admin for approval.',
            color: colors.primary,
            onTap: _updating
                ? null
                : () => _changeStatus(
                      'pending_review',
                      confirmTitle: 'Submit for Review?',
                      confirmBody:
                          'This will close the group to new join requests and submit it to the admin for approval.',
                      actionColor: colors.primary,
                    ),
          ),
        ],

        if (status == 'pending_review')
          _InfoBanner(
            icon: Icons.hourglass_bottom_rounded,
            message:
                'Your group is under admin review. No action needed.',
            color: colors.info,
          ),

        if (status == 'approved') ...[
          _ActionTile(
            icon: Icons.flag_rounded,
            title: 'Mark as Completed',
            subtitle: 'The trek has ended and all records are final.',
            color: Colors.teal,
            onTap: _updating
                ? null
                : () => _changeStatus(
                      'completed',
                      confirmTitle: 'Mark as Completed?',
                      confirmBody:
                          'This marks the trek as done. This cannot be undone.',
                      actionColor: Colors.teal,
                    ),
          ),
        ],

        // Cancel always available (if not already terminal)
        if (!['completed', 'cancelled'].contains(status)) ...[
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.block_rounded,
            title: 'Cancel Group',
            subtitle:
                'Cancel this group. All join requests will be declined.',
            color: Colors.red,
            onTap: _updating
                ? null
                : () => _changeStatus(
                      'cancelled',
                      confirmTitle: 'Cancel Group?',
                      confirmBody:
                          'This will cancel the group and notify all members. This cannot be undone.',
                      actionColor: Colors.red,
                    ),
          ),
        ],

        if (_updating)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 0.8),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: onTap != null ? colors.text : colors.textTertiary),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
              fontSize: 12,
              color: onTap != null
                  ? colors.textSecondary
                  : colors.textTertiary),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: onTap != null ? colors.textSecondary : colors.textTertiary,
        ),
        onTap: onTap,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ══════════════════════════════════════════════════════════════════════════════

// ── Info card (generic key-value table) ───────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12, color: colors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ?? colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info banner (inline notices) ─────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _InfoBanner({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: color.withOpacity(0.25), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 12, color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scaffolds for loading/error states ───────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  final String groupId;
  const _LoadingScaffold({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loading…'),
        backgroundColor: context.colors.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        backgroundColor: context.colors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 52, color: Colors.red),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(
                    color: Colors.red, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
