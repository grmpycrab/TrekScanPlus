import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Category selector dropdown for trekker classification
/// Used for pricing and document requirement determination
class CategorySelector extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onChanged;
  final String label;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onChanged,
    this.label = 'Your Category',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
            boxShadow: [
              BoxShadow(
                color: SharedColors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            icon: Icon(Icons.arrow_drop_down, color: colors.primary),
            style: TextStyle(
              fontSize: 15,
              color: colors.text,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: colors.surface,
            items: _buildCategoryItems(),
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ),
      ],
    );
  }

  /// Build category dropdown items with labels
  List<DropdownMenuItem<String>> _buildCategoryItems() {
    return const [
      DropdownMenuItem(value: 'student', child: Text('Student (50%)')),
      DropdownMenuItem(
        value: 'senior_citizen',
        child: Text('Senior Citizen (20%)'),
      ),
      DropdownMenuItem(
        value: 'dav_oriental_resident',
        child: Text('Davao Oriental Resident (50%)'),
      ),
      DropdownMenuItem(
        value: 'outdoor_club_federation',
        child: Text('Outdoor Club Federation (67%)'),
      ),
      DropdownMenuItem(
        value: 'children',
        child: Text('Children 8-15 years old (50%)'),
      ),
      DropdownMenuItem(value: 'mfsm', child: Text('MFSM Member (25%)')),
    ];
  }
}
