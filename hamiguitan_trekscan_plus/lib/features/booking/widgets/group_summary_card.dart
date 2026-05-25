import 'package:flutter/material.dart';

import '../../../models/group_booking.dart';
import '../../../theme/app_theme.dart';
import 'group_status_chip.dart';

/// Reusable card that represents a single [GroupBooking] in any list view.
///
/// Used by [MyBookingsScreen] (My Groups + Discover tabs) and anywhere else
/// a compact group overview is needed.  Tapping the card navigates to
/// [GroupDetailScreen] via the required [onTap] callback.
class GroupSummaryCard extends StatelessWidget {
  final GroupBooking group;
  final VoidCallback onTap;

  /// Show an "Organizer" badge in the meta row.
  final bool isOrganizer;

  /// Optional widget rendered below the meta row (e.g. action button).
  final Widget? trailing;

  /// Called when the user long-presses and selects "Leave group".
  /// Only show this for non-organizer members.
  final VoidCallback? onLeaveGroup;

  /// Called when the user long-presses and selects "Cancel group".
  /// Only show this for organizers.
  final VoidCallback? onCancelGroup;

  /// Called when the user long-presses and selects "Archive this group".
  final VoidCallback? onArchive;

  const GroupSummaryCard({
    super.key,
    required this.group,
    required this.onTap,
    this.isOrganizer = false,
    this.trailing,
    this.onLeaveGroup,
    this.onCancelGroup,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = group.trekDate.toDate();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: (onLeaveGroup != null || onCancelGroup != null || onArchive != null)
            ? () => _showLongPressMenu(context)
            : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.groupName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        if (group.affiliation.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            group.affiliation,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GroupStatusChip(status: group.status, compact: true),
                ],
              ),

              const SizedBox(height: 10),

              // ── Meta row ─────────────────────────────────────────────────
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _MetaItem(Icons.calendar_today_rounded, dateLabel),
                  _MetaItem(
                    Icons.people_rounded,
                    '${group.currentSlots}/${group.maxSlots}',
                  ),
                  _MetaItem(Icons.label_outline_rounded, group.trekTypeLabel),
                  if (isOrganizer)
                    _MetaItem(
                      Icons.manage_accounts_rounded,
                      'Organizer',
                      color: colors.primary,
                    ),
                ],
              ),

              // ── Trailing action ───────────────────────────────────────────
              if (trailing != null) ...[
                const SizedBox(height: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showLongPressMenu(BuildContext context) {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                group.groupName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 16),
            if (onLeaveGroup != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.borderLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.exit_to_app_outlined,
                    color: colors.textSecondary,
                  ),
                ),
                title: const Text('Leave group'),
                subtitle: const Text(
                  'Remove yourself from this group',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onLeaveGroup!();
                },
              ),
            if (onCancelGroup != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.borderLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.cancel_outlined,
                    color: colors.textSecondary,
                  ),
                ),
                title: const Text('Cancel group'),
                subtitle: const Text(
                  'Cancel this group booking',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onCancelGroup!();
                },
              ),
            if (onArchive != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.borderLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.archive_outlined,
                    color: colors.textSecondary,
                  ),
                ),
                title: const Text('Archive this group'),
                subtitle: const Text(
                  'Hide from your groups list',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onArchive!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Private helper ───────────────────────────────────────────────────────────

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaItem(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }
}
