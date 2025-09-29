import 'package:flutter/material.dart';
import '../../models/station_data.dart';
import '../../theme/color.dart';

class StationDetailScreen extends StatefulWidget {
  final StationData station;

  const StationDetailScreen({super.key, required this.station});

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  StationData get station => widget.station;

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStationInfo(),
                      const SizedBox(height: 24),
                      _buildDescription(),
                      if (station.warnings.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildWarnings(),
                      ],
                      if (station.flora.isNotEmpty ||
                          station.fauna.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildBiodiversity(),
                      ],
                      if (station.nextStationId != null) ...[
                        const SizedBox(height: 24),
                        _buildNextStation(),
                      ],
                      const SizedBox(height: 24),
                      _buildMetadata(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return const Scaffold(
        body: Center(child: Text('Error: Station data not available')),
      );
    }
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
        child: IntrinsicHeight(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Info Row
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 1,
                      child: _buildInfoItem(
                        Icons.height,
                        '${station.elevation} MASL',
                        'Elevation',
                      ),
                    ),
                    const SizedBox(width: 24),
                    Flexible(
                      flex: 1,
                      child: _buildInfoItem(
                        Icons.trending_up,
                        station.difficulty,
                        'Difficulty',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Location Info
              _buildCoordinates(),
              if (station.steps != null) ...[
                const SizedBox(height: 16),
                _buildInfoItem(
                  Icons.directions_walk,
                  '${station.steps} steps',
                  'From Previous Station',
                ),
              ],
              if (station.isCheckpoint) ...[
                const SizedBox(height: 16),
                _buildInfoItem(Icons.flag, 'Major Checkpoint', 'Station Type'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoordinates() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'North: ${_formatCoordinate(station.coordinates, 'N')}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                      ),
                      Text(
                        'East: ${_formatCoordinate(station.coordinates, 'E')}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    // Call platform clipboard API
                    // Add your clipboard functionality here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Coordinates copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Copy coordinates',
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCoordinate(String coordinates, String direction) {
    final regex = RegExp('$direction:(\\d+)°(\\d+)\'(\\d+\\.\\d+)\'\'');
    final match = regex.firstMatch(coordinates);
    if (match != null) {
      return '${match.group(1)}° ${match.group(2)}\' ${match.group(3)}"';
    }
    return coordinates;
  }

  Widget _buildInfoItem(IconData icon, String? value, String label) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value ?? 'Not available',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: value != null ? AppColors.textPrimary : Colors.grey,
                  ),
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

  IconData _getWarningIcon(String warningType) {
    switch (warningType.toLowerCase()) {
      case 'weather':
        return Icons.wb_cloudy;
      case 'cliff':
        return Icons.terrain;
      case 'slippery':
        return Icons.waves;
      case 'wildlife':
        return Icons.pets;
      case 'visibility':
        return Icons.visibility_off;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _getWarningColor(String warningType) {
    switch (warningType.toLowerCase()) {
      case 'weather':
        return Colors.blue;
      case 'cliff':
        return Colors.red;
      case 'slippery':
        return Colors.orange;
      case 'wildlife':
        return Colors.brown;
      case 'visibility':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  Widget _buildWarnings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Safety Warnings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (station.warnings.isEmpty)
              const Text(
                'No specific warnings for this station.',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...station.warnings.entries.map(
                (warning) => Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: _getWarningColor(warning.key).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getWarningColor(warning.key).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _getWarningIcon(warning.key),
                        color: _getWarningColor(warning.key),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
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
              'Local Biodiversity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (station.flora.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.eco, size: 20, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  const Text(
                    'Notable Flora',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...station.flora.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 28),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.green[300],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item, style: const TextStyle(height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (station.fauna.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.pets, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Notable Fauna',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...station.fauna.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 28),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item, style: const TextStyle(height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (station.flora.isEmpty && station.fauna.isEmpty)
              const Text(
                'No biodiversity information available for this station.',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
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

  Widget _buildNextStation() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.arrow_circle_right_outlined,
                  size: 24,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Next Station',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.flag_outlined, size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.nextStationName ?? 'Unknown Station',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (station.distanceToNextKm != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${station.distanceToNextKm} km ahead',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_walk,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    station.steps != null
                        ? '${station.steps} steps to next station'
                        : 'Distance in steps not available',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
