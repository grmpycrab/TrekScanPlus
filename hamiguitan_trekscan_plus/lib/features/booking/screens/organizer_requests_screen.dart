// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/group_booking.dart';
import '../../../models/join_request.dart';
import '../../../services/group_booking_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';

/// Organizer's review panel for a specific group booking.
///
/// Shows a tabbed view of join requests by status (Pending / Approved / Declined).
/// Organizers can approve or decline pending requests from this screen.
class OrganizerRequestsScreen extends StatefulWidget {
  final String groupId;
  const OrganizerRequestsScreen({super.key, required this.groupId});

  @override
  State<OrganizerRequestsScreen> createState() =>
      _OrganizerRequestsScreenState();
}

class _OrganizerRequestsScreenState extends State<OrganizerRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  GroupBooking? _group;
  bool _loadingGroup = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadGroup();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadGroup() async {
    final g = await GroupBookingService.instance.getGroupBooking(widget.groupId);
    if (mounted) setState(() { _group = g; _loadingGroup = false; });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _approve(JoinRequest request) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    try {
      await GroupBookingService.instance.approveJoinRequest(
        request.groupId,
        request.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${request.userDisplayName} approved.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('approveJoinRequest: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _decline(JoinRequest request) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Declining ${request.userDisplayName}\'s join request.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: TextStyle(color: colors.text),
                decoration: InputDecoration(
                  hintText: 'Reason for declining (optional)…',
                  hintStyle: TextStyle(color: colors.textTertiary),
                  filled: true,
                  fillColor: colors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await GroupBookingService.instance.declineJoinRequest(
        request.groupId,
        request.id,
        reason: reasonCtrl.text.trim().isEmpty
            ? null
            : reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${request.userDisplayName} declined.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('declineJoinRequest: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final groupName = _group?.groupName ?? 'Group Requests';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(groupName, overflow: TextOverflow.ellipsis),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Declined'),
          ],
        ),
      ),
      body: _loadingGroup
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_group != null) _GroupSummaryBar(group: _group!),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _RequestList(
                        groupId: widget.groupId,
                        statusFilter: 'pending',
                        onApprove: _approve,
                        onDecline: _decline,
                      ),
                      _RequestList(
                        groupId: widget.groupId,
                        statusFilter: 'approved',
                      ),
                      _RequestList(
                        groupId: widget.groupId,
                        statusFilter: 'declined',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group summary bar
// ---------------------------------------------------------------------------

class _GroupSummaryBar extends StatelessWidget {
  final GroupBooking group;
  const _GroupSummaryBar({required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = group.trekDate.toDate();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    return Container(
      width: double.infinity,
      color: colors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          _Stat(Icons.calendar_today, dateLabel),
          _Stat(Icons.people,
              '${group.currentSlots}/${group.maxSlots} trekkers'),
          _Stat(Icons.label_outline, group.trekTypeLabel),
          _Stat(Icons.circle,
              group.status.replaceAll('_', ' ').toUpperCase(),
              color: _statusColor(group.status)),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'open' => Colors.green,
      'full' => Colors.orange,
      'approved' => Colors.blue,
      'declined' => Colors.red,
      _ => Colors.grey,
    };
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _Stat(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = color ?? colors.textSecondary;
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

// ---------------------------------------------------------------------------
// Request list tab
// ---------------------------------------------------------------------------

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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load requests',
                style: TextStyle(color: colors.textSecondary)),
          );
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 56, color: colors.textTertiary),
                const SizedBox(height: 10),
                Text(
                  'No $statusFilter requests',
                  style: TextStyle(color: colors.textSecondary, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _RequestCard(
            request: requests[i],
            onApprove: onApprove,
            onDecline: onDecline,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Request card
// ---------------------------------------------------------------------------

class _RequestCard extends StatefulWidget {
  final JoinRequest request;
  final Future<void> Function(JoinRequest)? onApprove;
  final Future<void> Function(JoinRequest)? onDecline;

  const _RequestCard({
    required this.request,
    this.onApprove,
    this.onDecline,
  });

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
        border: Border.all(color: colors.border),
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
                  m.firstName.isNotEmpty ? m.firstName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
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
                        color: colors.text,
                      ),
                    ),
                    Text(
                      m.categoryDisplayName,
                      style: TextStyle(
                          fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: r.status),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Member details
          _detailRow('Contact', m.contactNumber),
          _detailRow('Address', m.homeAddress),
          _detailRow('Nationality', m.nationality),
          if (r.porterRequested)
            _detailRow('Porter', 'Requested', valueColor: Colors.orange),
          if (r.notes != null && r.notes!.isNotEmpty)
            _detailRow('Notes', r.notes!),
          if (r.declineReason != null && r.declineReason!.isNotEmpty)
            _detailRow('Decline Reason', r.declineReason!,
                valueColor: Colors.red),

          // Action buttons (pending only)
          if (r.isPending && (widget.onApprove != null || widget.onDecline != null)) ...[
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
                            if (mounted) setState(() => _acting = false);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _acting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.red),
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
                            if (mounted) setState(() => _acting = false);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _acting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
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

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: colors.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: valueColor ?? colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('Approved', Colors.green),
      'declined' => ('Declined', Colors.red),
      _ => ('Pending', Colors.orange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
