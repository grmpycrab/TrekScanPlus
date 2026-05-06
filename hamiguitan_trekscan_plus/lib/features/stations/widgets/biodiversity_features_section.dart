import 'package:flutter/material.dart';
import '../../../models/trail_details.dart';
import '../../../theme/app_theme.dart';

/// A single biodiversity feature button (icon + label)
class BiodiversityFeatureItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> items;
  final Color iconColor;

  const BiodiversityFeatureItem({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    this.iconColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEmpty = items.isEmpty;
    final tileColor = isEmpty ? colors.segmentBackground : colors.surface;
    final borderColor = isEmpty
        ? colors.border
        : iconColor.withValues(alpha: 0.3);
    final labelColor = isEmpty ? colors.textSecondary : colors.text;

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

  Widget _buildItemText(String item, AppTheme colors) {
    final baseStyle = TextStyle(fontSize: 14, color: colors.text, height: 1.4);

    if (_formatScientificNames && _looksLikeScientificName(item)) {
      return Text(item, style: baseStyle.copyWith(fontStyle: FontStyle.italic));
    }

    return Text(item, style: baseStyle);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
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
                    color: Colors.grey.shade400,
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          Text(
                            '${items.length} item${items.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
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
          Divider(height: 1, color: colors.border),

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
                      Expanded(child: _buildItemText(items[index], colors)),
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
                  backgroundColor: colors.primary,
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

final Map<String, _FeatureType> _staticFeatureTypes = {
  'plants': _FeatureType(
    label: 'Plants',
    icon: Icons.local_florist,
    color: Colors.green,
  ),
  'animals': _FeatureType(
    label: 'Animals',
    icon: Icons.pets,
    color: Colors.orange,
  ),
  'warnings': _FeatureType(
    label: 'Warnings',
    icon: Icons.warning_amber_rounded,
    color: Colors.orange,
  ),
};

/// The complete biodiversity features section
class BiodiversityFeaturesSection extends StatelessWidget {
  final TrailDetails trailDetails;

  const BiodiversityFeaturesSection({super.key, required this.trailDetails});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final featureTypes = <String, _FeatureType>{
      ..._staticFeatureTypes,
      'trailType': _FeatureType(
        label: 'Trail Type',
        icon: Icons.terrain,
        color: colors.primary,
      ),
      'facilities': _FeatureType(
        label: 'Facilities',
        icon: Icons.home,
        color: colors.notificationBooking,
      ),
      'utilities': _FeatureType(
        label: 'Utilities',
        icon: Icons.water_drop,
        color: colors.accent,
      ),
    };

    if (!trailDetails.hasData) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Biodiversity Features',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFeatureItem(
                  'trailType',
                  trailDetails.trailType,
                  featureTypes,
                ),
                const SizedBox(width: 10),
                _buildFeatureItem('plants', trailDetails.plants, featureTypes),
                const SizedBox(width: 10),
                _buildFeatureItem(
                  'animals',
                  trailDetails.animals,
                  featureTypes,
                ),
                const SizedBox(width: 10),
                _buildFeatureItem(
                  'facilities',
                  trailDetails.facilities,
                  featureTypes,
                ),
                const SizedBox(width: 10),
                _buildFeatureItem(
                  'utilities',
                  trailDetails.utilities,
                  featureTypes,
                ),
                const SizedBox(width: 10),
                _buildFeatureItem(
                  'warnings',
                  trailDetails.warnings.keys.toList(),
                  featureTypes,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    String key,
    List<String> items,
    Map<String, _FeatureType> featureTypes,
  ) {
    final feature = featureTypes[key]!;
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
