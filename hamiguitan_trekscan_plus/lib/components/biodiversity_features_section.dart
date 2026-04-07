import 'package:flutter/material.dart';
import '../models/trail_details.dart';
import '../theme/color.dart';

/// A single biodiversity feature button (icon + label)
class BiodiversityFeatureItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> items;
  final Color iconColor;

  const BiodiversityFeatureItem({
    Key? key,
    required this.label,
    required this.icon,
    required this.items,
    this.iconColor = Colors.blue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isEmpty = items.isEmpty;
    final tileColor = isEmpty
        ? AppColors.segmentBackground
        : AppColors.cardBackground;
    final borderColor = isEmpty
        ? AppColors.border
        : iconColor.withValues(alpha: 0.3);
    final labelColor = isEmpty ? AppColors.textSecondary : AppColors.text;

    return GestureDetector(
      onTap: isEmpty ? null : () => _showDetailsBottomSheet(context),
      child: Opacity(
        opacity: isEmpty ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tileColor,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FeatureDetailsSheet(
        title: label,
        icon: icon,
        items: items,
        iconColor: iconColor,
      ),
    );
  }
}

/// Bottom sheet that displays detailed information for a feature
class _FeatureDetailsSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final Color iconColor;

  static const Set<String> _nonScientificPrefixes = {
    'Philippine',
    'Forest',
    'Mountain',
    'White-eared',
    'Long-tailed',
  };

  const _FeatureDetailsSheet({
    required this.title,
    required this.icon,
    required this.items,
    required this.iconColor,
  });

  bool get _formatScientificNames {
    final normalized = title.toLowerCase();
    return normalized == 'plants' || normalized == 'animals';
  }

  bool _looksLikeScientificName(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty || cleaned.contains('(') || cleaned.contains(')')) {
      return false;
    }

    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length < 2 || parts.length > 3) return false;

    final first = parts.first;
    if (_nonScientificPrefixes.contains(first)) return false;
    if (!RegExp(r'^[A-Z][a-z]+$').hasMatch(first)) return false;

    for (final part in parts.skip(1)) {
      if (!RegExp(r'^(subsp\.|var\.|[a-z-]+)$').hasMatch(part)) {
        return false;
      }
    }

    return true;
  }

  Widget _buildItemText(String item) {
    const baseStyle = TextStyle(
      fontSize: 14,
      color: AppColors.text,
      height: 1.4,
    );

    if (_formatScientificNames && _looksLikeScientificName(item)) {
      return Text(item, style: baseStyle.copyWith(fontStyle: FontStyle.italic));
    }

    return Text(item, style: baseStyle);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.iconGrey400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            '${items.length} item${items.length != 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1, color: AppColors.border),

          // List of items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: iconColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildItemText(items[index])),
                    ],
                  ),
                );
              },
            ),
          ),

          // Close button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feature type mapping: icon, color, and label
class _FeatureType {
  final String label;
  final IconData icon;
  final Color color;

  _FeatureType({required this.label, required this.icon, required this.color});
}

final Map<String, _FeatureType> _featureTypes = {
  'trailType': _FeatureType(
    label: 'Trail Type',
    icon: Icons.terrain,
    color: AppColors.primary,
  ),
  'plants': _FeatureType(
    label: 'Plants',
    icon: Icons.local_florist,
    color: AppColors.statusApproved,
  ),
  'animals': _FeatureType(
    label: 'Animals',
    icon: Icons.pets,
    color: AppColors.statusPending,
  ),
  'facilities': _FeatureType(
    label: 'Facilities',
    icon: Icons.home,
    color: AppColors.notificationBooking,
  ),
  'utilities': _FeatureType(
    label: 'Utilities',
    icon: Icons.water_drop,
    color: AppColors.accent,
  ),
  'warnings': _FeatureType(
    label: 'Warnings',
    icon: Icons.warning_amber_rounded,
    color: AppColors.statusPending,
  ),
};

/// The complete biodiversity features section
class BiodiversityFeaturesSection extends StatelessWidget {
  final TrailDetails trailDetails;

  const BiodiversityFeaturesSection({Key? key, required this.trailDetails})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!trailDetails.hasData) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Biodiversity Features',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFeatureItem('trailType', trailDetails.trailType),
                const SizedBox(width: 10),
                _buildFeatureItem('plants', trailDetails.plants),
                const SizedBox(width: 10),
                _buildFeatureItem('animals', trailDetails.animals),
                const SizedBox(width: 10),
                _buildFeatureItem('facilities', trailDetails.facilities),
                const SizedBox(width: 10),
                _buildFeatureItem('utilities', trailDetails.utilities),
                const SizedBox(width: 10),
                _buildFeatureItem(
                  'warnings',
                  trailDetails.warnings.keys.toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String key, List<String> items) {
    final feature = _featureTypes[key]!;
    // For warnings, convert the warning messages to a list
    final displayItems = key == 'warnings'
        ? trailDetails.warnings.values.toList()
        : items;

    return SizedBox(
      width: 84,
      child: BiodiversityFeatureItem(
        label: feature.label,
        icon: feature.icon,
        items: displayItems,
        iconColor: feature.color,
      ),
    );
  }
}
