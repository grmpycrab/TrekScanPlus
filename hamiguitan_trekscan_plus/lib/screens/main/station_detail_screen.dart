import 'package:flutter/material.dart';
import '../../models/station_data.dart';
import '../../theme/color.dart';

class StationDetailScreen extends StatelessWidget {
  final StationData station;

  const StationDetailScreen({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStationInfo(),
                  const SizedBox(height: 24),
                  _buildDescription(),
                  if (station.warnings.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildWarnings(),
                  ],
                  if (station.flora.isNotEmpty || station.fauna.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildBiodiversity(),
                  ],
                  const SizedBox(height: 24),
                  _buildMetadata(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(station.name),
        background: Image.asset(
          'assets/images/${station.images.first}',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Icon(Icons.image_not_supported, size: 50),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStationInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildInfoItem(
                  Icons.height,
                  '${station.elevation} MASL',
                  'Elevation',
                ),
                const SizedBox(width: 24),
                _buildInfoItem(
                  Icons.trending_up,
                  station.difficulty,
                  'Difficulty',
                ),
              ],
            ),
            if (station.steps != null) ...[
              const SizedBox(height: 16),
              _buildInfoItem(
                Icons.directions_walk,
                '${station.steps} steps',
                'From Previous',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About this Station',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              station.description,
              style: TextStyle(color: AppColors.textPrimary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarnings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Important Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...station.warnings.entries.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning.value,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiodiversity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Biodiversity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (station.flora.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Notable Flora:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...station.flora.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.eco, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(item),
                    ],
                  ),
                ),
              ),
            ],
            if (station.fauna.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Notable Fauna:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...station.fauna.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.pets, size: 16),
                      const SizedBox(width: 8),
                      Text(item),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata() {
    if (station.metadata.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...station.metadata.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(
                      _getMetadataIcon(entry.key),
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatMetadataKey(entry.key)}: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(_formatMetadataValue(entry.value)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMetadataIcon(String key) {
    switch (key) {
      case 'viewingSpots':
        return Icons.landscape;
      case 'restArea':
        return Icons.chair;
      case 'waterSource':
        return Icons.water_drop;
      case 'summitLog':
        return Icons.book;
      case 'shelterType':
        return Icons.house;
      case 'signalStrength':
        return Icons.signal_cellular_alt;
      default:
        return Icons.info;
    }
  }

  String _formatMetadataKey(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _formatMetadataValue(dynamic value) {
    if (value is bool) {
      return value ? 'Available' : 'Not Available';
    } else if (value is List) {
      return value.join(', ');
    }
    return value.toString();
  }
}
