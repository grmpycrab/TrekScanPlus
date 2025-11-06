import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: Material(
                  color: Colors.white,
                  elevation: 6,
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    padding: const EdgeInsets.only(top: 20), // Add top padding
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStationInfo(),
                          _buildDescription(),
                          if (station.warnings.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildWarnings(),
                          ],
                          if (station.flora.isNotEmpty ||
                              station.fauna.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildBiodiversity(),
                          ],
                          if (station.nextStationId != null) ...[
                            const SizedBox(height: 32),
                            _buildNextStation(),
                          ],
                          if (station.metadata.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildMetadata(),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
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

  Widget _buildMetricBadge(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey[400], size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 400.0,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: Text(
        "STATION ${station.id}",
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        expandedTitleScale: 1.0,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/${station.images.first}',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(color: Colors.grey[300]),
                  child: const Icon(Icons.image_not_supported, size: 50),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 200,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(station.difficulty),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      station.difficulty.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    station.name,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildMetricBadge(
                        Icons.height,
                        '${station.elevation}m',
                        'ELEVATION',
                      ),
                      const SizedBox(width: 12),
                      _buildMetricBadge(
                        Icons.directions_walk,
                        '${station.steps ?? 0}',
                        'STEPS',
                      ),
                      const SizedBox(width: 12),
                      _buildMetricBadge(
                        Icons.route,
                        '${station.distanceToNextKm ?? 0} km',
                        'DISTANCE',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationInfo() {
    final lat = _formatCoordinate(station.coordinates, 'N');
    final lng = _formatCoordinate(station.coordinates, 'E');

    Future<void> copyToClipboard(String text) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coordinates copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          // Latitude box
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LATITUDE',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lat,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, color: AppColors.primary),
                    onPressed: () => copyToClipboard(lat),
                    tooltip: 'Copy latitude',
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Longitude box
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LONGITUDE',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lng,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, color: AppColors.primary),
                    onPressed: () => copyToClipboard(lng),
                    tooltip: 'Copy longitude',
                    splashRadius: 20,
                  ),
                ],
              ),
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

  Widget _buildDescription() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "1",
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'About This Station',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            station.description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
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
