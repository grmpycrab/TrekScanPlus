import 'package:flutter/material.dart';
import '../../../models/member.dart';
import '../../../theme/app_theme.dart';

/// Card widget for displaying individual trekker information
/// Shows member details with edit/remove actions
class TrekkerCard extends StatelessWidget {
  final Member member;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final bool isPrimary;

  const TrekkerCard({
    super.key,
    required this.member,
    required this.index,
    required this.onEdit,
    required this.onRemove,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: isPrimary ? colors.primary : Colors.black12,
          width: isPrimary ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(colors),
                  const SizedBox(height: 8),
                  _buildDetails(colors),
                ],
              ),
            ),
            if (!isPrimary) ...[
              const SizedBox(width: 12),
              _buildActionButtons(colors),
            ],
          ],
        ),
      ),
    );
  }

  /// Build card header with name and primary badge
  Widget _buildHeader(AppTheme colors) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${member.firstName} ${member.lastName}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        if (isPrimary)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Primary',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ),
      ],
    );
  }

  /// Build member details (category, gender, birth date)
  Widget _buildDetails(AppTheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Category', member.category, colors),
        if (member.gender.isNotEmpty)
          _buildDetailRow('Gender', member.gender, colors),
        if (member.birthDate.isNotEmpty)
          _buildDetailRow('Birth Date', member.birthDate, colors),
      ],
    );
  }

  /// Build single detail row
  Widget _buildDetailRow(String label, String value, AppTheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Build action buttons for non-primary members
  Widget _buildActionButtons(AppTheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Tooltip(
            message: 'Edit',
            child: IconButton(
              onPressed: onEdit,
              icon: Icon(Icons.edit, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                foregroundColor: colors.primary,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: Tooltip(
            message: 'Remove',
            child: IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.delete_outline, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: colors.statusRejectedLight,
                foregroundColor: colors.statusRejectedDark,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
