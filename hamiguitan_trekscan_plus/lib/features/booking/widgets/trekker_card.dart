import 'package:flutter/material.dart';
import '../../../models/member.dart';
import '../../../theme/color.dart';

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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: SharedColors.white,
        border: Border.all(
          color: isPrimary ? AppColors.primary : AppColors.borderBlack12,
          width: isPrimary ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            _buildDetails(),
            if (!isPrimary) ...[
              const SizedBox(height: 12),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  /// Build card header with name and primary badge
  Widget _buildHeader() {
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
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Primary',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  /// Build member details (category, gender, birth date)
  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Category', member.category),
        if (member.gender.isNotEmpty) _buildDetailRow('Gender', member.gender),
        if (member.birthDate.isNotEmpty)
          _buildDetailRow('Birth Date', member.birthDate),
      ],
    );
  }

  /// Build single detail row
  Widget _buildDetailRow(String label, String value) {
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
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Edit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('Remove'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }
}
