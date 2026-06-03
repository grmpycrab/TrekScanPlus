import 'package:flutter/material.dart';

/// Reusable status badge for [GroupBooking] and [JoinRequest] statuses.
///
/// Covers every valid status in both lifecycles so callers never see a
/// plain-grey "unknown" chip during normal operation.
class GroupStatusChip extends StatelessWidget {
  final String status;

  /// When [compact] is true the chip uses smaller font / padding — useful
  /// inside list-card rows where space is tight.
  final bool compact;

  const GroupStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _resolve(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 9 : 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status → (label, color, icon)
  // ---------------------------------------------------------------------------

  static (String, Color, IconData) _resolve(String status) {
    return switch (status) {
      // ── Group statuses ──────────────────────────────────────────────────────
      'open' => ('Open', const Color(0xFF2E7D32), Icons.lock_open_rounded),
      'full' => ('Full', const Color(0xFFE65100), Icons.group),
      'pending_review' => (
        'Under Review',
        const Color(0xFF0277BD),
        Icons.hourglass_bottom_rounded,
      ),
      'approved' => (
        'Approved',
        const Color(0xFF1565C0),
        Icons.check_circle_rounded,
      ),
      'changes_required' => (
        'Changes Required',
        const Color(0xFFF57F17),
        Icons.edit_note_rounded,
      ),
      'declined' => ('Declined', const Color(0xFFC62828), Icons.cancel_rounded),
      'completed' => ('Completed', const Color(0xFF00695C), Icons.flag_rounded),
      'cancelled' => (
        'Cancelled',
        const Color(0xFF546E7A),
        Icons.block_rounded,
      ),
      'draft' => ('Draft', const Color(0xFF6A1B9A), Icons.edit_note_rounded),
      // ── Join-request statuses ───────────────────────────────────────────────
      'pending' => ('Pending', const Color(0xFFE65100), Icons.schedule_rounded),
      'withdrawn' => ('Withdrawn', const Color(0xFF546E7A), Icons.undo_rounded),
      // ── Fallback ────────────────────────────────────────────────────────────
      _ => (status, const Color(0xFF607D8B), Icons.info_outline_rounded),
    };
  }
}
