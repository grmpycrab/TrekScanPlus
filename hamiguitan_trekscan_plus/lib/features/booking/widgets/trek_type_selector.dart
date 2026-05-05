import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Trek type selector dropdown widget
/// Displays trek type options: Regular, Research, Creational (DIY)
class TrekTypeSelector extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onChanged;

  const TrekTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Purpose of Trek',
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
            value: selectedType,
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
            items: [
              DropdownMenuItem(
                value: 'regular',
                child: Row(
                  children: [
                    Icon(Icons.hiking, size: 20, color: colors.primary),
                    SizedBox(width: 12),
                    Text('Regular Trek'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'research',
                child: Row(
                  children: [
                    Icon(Icons.science, size: 20, color: colors.primary),
                    SizedBox(width: 12),
                    Text('Research Trek'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'creational',
                child: Row(
                  children: [
                    Icon(Icons.star, size: 20, color: colors.primary),
                    SizedBox(width: 12),
                    Text('Creational (DIY)'),
                  ],
                ),
              ),
            ],
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
}
