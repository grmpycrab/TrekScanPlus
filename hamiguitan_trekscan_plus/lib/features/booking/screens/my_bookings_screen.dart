// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/group_booking.dart';
import '../../../models/join_request.dart';
import '../../../services/group_booking_service.dart';
import '../../../theme/app_theme.dart';
import '../widgets/group_status_chip.dart';
import '../widgets/group_summary_card.dart';
import 'create_group_flow_screen.dart';
import 'group_detail_screen.dart';

/// Root of the "Book a Climb" tab.
///
/// Three tabs:
///   1. My Groups  — groups the user organises + groups they have joined
///   2. Discover   — all open groups with search/filter and live request state
///   3. Requests   — all join requests the current user has submitted
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Book a Climb',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
        ),
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(height: 1, thickness: 1, color: colors.border),
              TabBar(
                controller: _tabController,
                indicatorColor: colors.primary,
                indicatorWeight: 2,
                labelColor: colors.primary,
                unselectedLabelColor: colors.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                tabs: const [
                  Tab(text: 'My Groups'),
                  Tab(text: 'Discover'),
                  Tab(text: 'Requests'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: colors.primary),
            tooltip: 'Create new group',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreateGroupFlowScreen(),
              ),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MyGroupsTab(),
          _DiscoverTab(),
          _RequestsTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — My Groups
// ══════════════════════════════════════════════════════════════════════════════

class _MyGroupsTab extends StatelessWidget {
  const _MyGroupsTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _EmptyState(
        icon: Icons.account_circle_outlined,
        message: 'Sign in to see your groups.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _CreateGroupBanner(),
        _OrganizerGroupsSection(uid: uid),
        _JoinedGroupsSection(uid: uid),
      ],
    );
  }
}

// ── Create-group hero banner ──────────────────────────────────────────────────

class _CreateGroupBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan Your Trek',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create a group and invite fellow trekkers.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreateGroupFlowScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── "Groups I Organise" section ───────────────────────────────────────────────

class _OrganizerGroupsSection extends StatefulWidget {
  final String uid;
  const _OrganizerGroupsSection({required this.uid});

  @override
  State<_OrganizerGroupsSection> createState() =>
      _OrganizerGroupsSectionState();
}

class _OrganizerGroupsSectionState extends State<_OrganizerGroupsSection> {
  late final Stream<List<GroupBooking>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = GroupBookingService.instance.streamOrganizerGroups(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupBooking>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SectionSkeleton();
        }
        final groups = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.manage_accounts_rounded,
              title: 'Groups I Organize',
              count: groups.length,
            ),
            if (groups.isEmpty)
              _EmptySection(
                message: "You haven't created any groups yet.",
              )
            else
              ...groups.map(
                (g) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: GroupSummaryCard(
                    group: g,
                    isOrganizer: true,
                    onTap: () => _openDetail(context, g.id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── "Groups I Joined" section ─────────────────────────────────────────────────

class _JoinedGroupsSection extends StatefulWidget {
  final String uid;
  const _JoinedGroupsSection({required this.uid});

  @override
  State<_JoinedGroupsSection> createState() => _JoinedGroupsSectionState();
}

class _JoinedGroupsSectionState extends State<_JoinedGroupsSection> {
  late final Stream<List<GroupBooking>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = GroupBookingService.instance.streamJoinedGroups(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupBooking>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SectionSkeleton();
        }
        final groups = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.group_rounded,
              title: 'Groups I Joined',
              count: groups.length,
            ),
            if (groups.isEmpty)
              _EmptySection(
                message: "You haven't joined any groups yet.",
              )
            else
              ...groups.map(
                (g) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: GroupSummaryCard(
                    group: g,
                    onTap: () => _openDetail(context, g.id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Discover
// ══════════════════════════════════════════════════════════════════════════════

class _DiscoverTab extends StatefulWidget {
  const _DiscoverTab();

  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'all';

  late final Stream<Map<String, JoinRequest>> _myRequestsStream;
  late final Stream<List<GroupBooking>> _openGroupsStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _myRequestsStream = uid.isEmpty
        ? Stream.value(<String, JoinRequest>{})
        : GroupBookingService.instance
            .streamUserJoinRequests(uid)
            .map((list) => {for (final r in list) r.groupId: r});
    _openGroupsStream = GroupBookingService.instance.streamOpenGroups();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      children: [
        // ── Search + filter bar ──────────────────────────────────────────────
        Container(
          color: colors.surfaceVariant,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                style: TextStyle(color: colors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search groups or affiliations…',
                  hintStyle:
                      TextStyle(color: colors.textTertiary, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: colors.textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              color: colors.textSecondary, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(label: 'All', value: 'all', current: _typeFilter, onSelect: _setFilter),
                    _FilterChip(label: 'Regular', value: 'regular_trek', current: _typeFilter, onSelect: _setFilter),
                    _FilterChip(label: 'Special', value: 'special_trek', current: _typeFilter, onSelect: _setFilter),
                    _FilterChip(label: 'Research', value: 'research_trek', current: _typeFilter, onSelect: _setFilter),
                    _FilterChip(label: 'Gov\'t', value: 'government_official', current: _typeFilter, onSelect: _setFilter),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Group list ───────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<Map<String, JoinRequest>>(
            stream: _myRequestsStream,
            builder: (context, myReqSnap) {
              final myRequests = myReqSnap.data ?? {};
              return StreamBuilder<List<GroupBooking>>(
                stream: _openGroupsStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return const _ErrorState(message: 'Failed to load groups.');
                  }
                  final groups = (snap.data ?? []).where((g) {
                    final matchSearch = _searchQuery.isEmpty ||
                        g.groupName.toLowerCase().contains(_searchQuery) ||
                        g.affiliation.toLowerCase().contains(_searchQuery) ||
                        g.organizerName.toLowerCase().contains(_searchQuery);
                    final matchType =
                        _typeFilter == 'all' || g.trekType == _typeFilter;
                    return matchSearch && matchType;
                  }).toList();

                  if (groups.isEmpty) {
                    return _EmptyState(
                      icon: Icons.explore_off_rounded,
                      message: _searchQuery.isNotEmpty
                          ? 'No groups match your search.'
                          : 'No open groups at the moment.\nCheck back later!',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final g = groups[i];
                      final myReq = myRequests[g.id];
                      return GroupSummaryCard(
                        group: g,
                        isOrganizer: g.organizerId == uid,
                        onTap: () => _openDetail(context, g.id),
                        trailing: _DiscoverCardAction(
                          group: g,
                          myRequest: myReq,
                          currentUid: uid,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _setFilter(String v) => setState(() => _typeFilter = v);
}

// ── Card action widget (Discover tab) ─────────────────────────────────────────

class _DiscoverCardAction extends StatelessWidget {
  final GroupBooking group;
  final JoinRequest? myRequest;
  final String currentUid;

  const _DiscoverCardAction({
    required this.group,
    required this.myRequest,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isOrganizer = group.organizerId == currentUid;

    // Organizer of this group
    if (isOrganizer) {
      return _actionButton(
        context,
        icon: Icons.manage_accounts_rounded,
        label: 'Manage Group',
        bg: colors.primary,
        fg: Colors.white,
        onTap: () => _openDetail(context, group.id),
      );
    }

    // Already has a request
    if (myRequest != null) {
      return switch (myRequest!.status) {
        'pending' => _statusButton(
            icon: Icons.schedule_rounded,
            label: 'Pending Approval',
            color: const Color(0xFFE65100),
          ),
        'approved' => _statusButton(
            icon: Icons.check_circle_rounded,
            label: 'Joined',
            color: const Color(0xFF2E7D32),
          ),
        'declined' => _actionButton(
            context,
            icon: Icons.refresh_rounded,
            label: 'View & Reapply',
            bg: Colors.red.shade50,
            fg: Colors.red,
            onTap: () => _openDetail(context, group.id),
          ),
        _ => _actionButton(
            context,
            icon: Icons.info_outline_rounded,
            label: 'View Details',
            bg: colors.primary,
            fg: Colors.white,
            onTap: () => _openDetail(context, group.id),
          ),
      };
    }

    // No request yet — group must be open
    return _actionButton(
      context,
      icon: Icons.info_outline_rounded,
      label: 'View Details',
      bg: colors.primary,
      fg: Colors.white,
      onTap: () => _openDetail(context, group.id),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _statusButton({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: null,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Requests
// ══════════════════════════════════════════════════════════════════════════════

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _EmptyState(
        icon: Icons.account_circle_outlined,
        message: 'Sign in to see your requests.',
      );
    }

    return StreamBuilder<List<JoinRequest>>(
      stream: GroupBookingService.instance.streamUserJoinRequests(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const _ErrorState(message: 'Failed to load requests.');
        }

        final all = snap.data ?? [];
        if (all.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_outlined,
            message:
                "You haven't submitted any join requests yet.\nHead to Discover to find a group!",
          );
        }

        final pending =
            all.where((r) => r.status == 'pending').toList();
        final approved =
            all.where((r) => r.status == 'approved').toList();
        final declined =
            all.where((r) => r.status == 'declined').toList();
        final withdrawn =
            all.where((r) => r.status == 'withdrawn').toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (pending.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.schedule_rounded,
                title: 'Pending',
                count: pending.length,
                color: const Color(0xFFE65100),
              ),
              ...pending.map((r) => _RequestStatusCard(request: r)),
              const SizedBox(height: 8),
            ],
            if (approved.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.check_circle_rounded,
                title: 'Approved',
                count: approved.length,
                color: const Color(0xFF2E7D32),
              ),
              ...approved.map((r) => _RequestStatusCard(request: r)),
              const SizedBox(height: 8),
            ],
            if (declined.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.cancel_rounded,
                title: 'Declined',
                count: declined.length,
                color: const Color(0xFFC62828),
              ),
              ...declined.map((r) => _RequestStatusCard(request: r)),
              const SizedBox(height: 8),
            ],
            if (withdrawn.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.undo_rounded,
                title: 'Withdrawn',
                count: withdrawn.length,
              ),
              ...withdrawn.map((r) => _RequestStatusCard(request: r)),
            ],
          ],
        );
      },
    );
  }
}

// ── Single request status card ────────────────────────────────────────────────

class _RequestStatusCard extends StatelessWidget {
  final JoinRequest request;
  const _RequestStatusCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = request.createdAt.toDate();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Expanded(
                child: Text(
                  request.member.fullName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
              ),
              GroupStatusChip(status: request.status, compact: true),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Submitted $dateLabel',
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),

          // Decline reason banner
          if (request.isDeclined &&
              request.declineReason != null &&
              request.declineReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.declineReason!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.red, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // View group button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('View Group',
                  style: TextStyle(fontSize: 13)),
              onPressed: () => _openDetail(context, request.groupId),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared utility widgets
// ══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color? color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = color ?? colors.textSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: c,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: c),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colors.iconMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: Colors.red, fontSize: 14)),
        ],
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onSelect;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onSelect(value),
        selectedColor: colors.primary,
        backgroundColor: colors.inputFill,
        labelStyle: TextStyle(
          color: selected ? Colors.white : colors.textSecondary,
          fontWeight:
              selected ? FontWeight.w700 : FontWeight.normal,
        ),
        side: BorderSide(
          color: selected ? colors.primary : colors.border,
          width: 0.8,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ── Navigation helper ─────────────────────────────────────────────────────────

void _openDetail(BuildContext context, String groupId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)),
  );
}
