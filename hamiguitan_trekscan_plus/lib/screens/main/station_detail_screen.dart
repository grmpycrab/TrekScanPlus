import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/station_data.dart';
import '../../services/station_service.dart';
import '../../theme/color.dart';
import '../../components/trail_map.dart';
import '../../utils/app_logger.dart';

class StationDetailScreen extends StatefulWidget {
  final StationData station;

  const StationDetailScreen({super.key, required this.station});

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  StationData get station => widget.station;
  StationData? nextStationData;
  List<StationData> allStations = [];
  late ScrollController _scrollController;
  late PageController _imagePageController;
  double _scrollOffset = 0.0;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _imagePageController = PageController();
    _imagePageController.addListener(_onImagePageChanged);
    _preloadImages();
    _loadStationData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _imagePageController.removeListener(_onImagePageChanged);
    _imagePageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  void _onImagePageChanged() {
    setState(() {
      _currentImageIndex = _imagePageController.page?.round() ?? 0;
      // Pre-cache the next image
      _precacheNextImage();
    });
  }

  Future<void> _preloadImages() async {
    if (station.images.isEmpty) return;

    try {
      // Pre-cache the first two images for smooth experience
      await precacheImage(
        AssetImage('assets/images/${station.images[0]}'),
        context,
      );
      if (station.images.length > 1) {
        await precacheImage(
          AssetImage('assets/images/${station.images[1]}'),
          context,
        );
      }
    } catch (e) {
      AppLogger.e('Error preloading images: $e');
    }
  }

  void _precacheNextImage() {
    final nextIndex = (_currentImageIndex + 1) % station.images.length;
    precacheImage(
      AssetImage('assets/images/${station.images[nextIndex]}'),
      context,
    ).catchError((e) {
      AppLogger.e('Error precaching image: $e');
    });
  }

  Future<void> _loadStationData() async {
    try {
      // Ensure stations are loaded
      if (!StationService.instance.isLoaded) {
        await StationService.instance.loadStations();
      }

      if (mounted) {
        final allStationsLoaded = StationService.instance.getAllStations();
        StationData? nextStation;

        if (station.nextStationId != null) {
          nextStation = StationService.instance.getStationById(
            station.nextStationId!,
          );
        }

        setState(() {
          allStations = allStationsLoaded;
          nextStationData = nextStation;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading station data: $e');
    }
  }

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

  bool _isEndStation(String stationId) {
    const endStationIds = [
      'i73hl7b7g3', // Station 13: Hidden Garden
      'r5kntj3sae', // Station 16: Twin Falls
      'mr2l529okj', // Station 14: Peak
    ];
    return endStationIds.contains(stationId);
  }

  Color _getAppBarIconColor() {
    // Start white over photo, transition to black as user scrolls
    final progress = (_scrollOffset / 100).clamp(0.0, 1.0);
    return Color.lerp(Colors.white, Colors.black, progress)!;
  }

  Color _getAppBarTextColor() {
    // Same transition for text
    final progress = (_scrollOffset / 100).clamp(0.0, 1.0);
    return Color.lerp(Colors.white, AppColors.text, progress)!;
  }

  Color _getAppBarBackgroundColor() {
    // Gradually show white background as user scrolls
    final progress = (_scrollOffset / 150).clamp(0.0, 1.0);
    return Color.lerp(Colors.transparent, Colors.white, progress)!;
  }

  Widget _buildImageCarousel() {
    if (station.images.isEmpty) {
      return Container(
        decoration: BoxDecoration(color: AppColors.border),
        child: const Icon(Icons.image_not_supported, size: 50),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // PageView carousel with looping
        PageView.builder(
          controller: _imagePageController,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index % station.images.length;
            });
          },
          itemBuilder: (context, index) {
            final imageIndex = index % station.images.length;
            final imagePath = station.images[imageIndex];

            return GestureDetector(
              onTap: () => _showFullscreenImage(imageIndex),
              child: Image.asset(
                'assets/images/$imagePath',
                fit: BoxFit.cover,
                cacheHeight: 800,
                cacheWidth: 600,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(color: AppColors.border),
                    child: const Icon(Icons.image_not_supported, size: 50),
                  );
                },
              ),
            );
          },
          // Create infinite carousel by using a large number
          itemCount: station.images.length * 100,
          physics: const PageScrollPhysics(),
        ),
        // Image indicators (dots)
        if (station.images.length > 1)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: _buildImageIndicators(),
          ),
      ],
    );
  }

  Widget _buildImageIndicators() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            station.images.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentImageIndex == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentImageIndex == index
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullscreenImage(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenImageViewer(
          images: station.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          controller: _scrollController,
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
                          if (allStations.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildTrailMap(),
                          ],
                          // Show next station or end station card
                          if (station.nextStationId != null ||
                              _isEndStation(station.id)) ...[
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
        color: Colors.black.withValues(alpha: 0.6),
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
      backgroundColor: _getAppBarBackgroundColor(),
      elevation: _scrollOffset > 50 ? 4 : 0,
      shadowColor: Colors.black.withOpacity(0.1),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: _getAppBarIconColor()),
        onPressed: () {
          // Pop with the station data so parent can update
          Navigator.pop(context, widget.station);
        },
      ),
      title: Text(
        " ${station.name}",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _getAppBarTextColor(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        expandedTitleScale: 1.0,
        background: Stack(
          fit: StackFit.expand,
          children: [
            _buildImageCarousel(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.8),
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
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.3),
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
                    color: Colors.black.withValues(alpha: 0.05),
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
                    color: Colors.black.withValues(alpha: 0.05),
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
            textAlign: TextAlign.justify,
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
                    color: _getWarningColor(warning.key).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getWarningColor(
                        warning.key,
                      ).withValues(alpha: 0.3),
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
                          style: TextStyle(color: AppColors.text, height: 1.5),
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
                          color: AppColors.primary.withValues(alpha: 0.5),
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

  Widget _buildTrailMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.map, size: 24, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'Trail Map',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 320,
            child: TrailMap(
              currentStation: station,
              allStations: allStations,
              height: 320,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNextStation() {
    // Don't show next station section for end stations
    if (_isEndStation(station.id)) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag, size: 24, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'End Station',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.celebration, color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This is the final station on this route!',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
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
            if (nextStationData != null) ...[
              // Display actual next station data
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
                          nextStationData!.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(
                              nextStationData!.difficulty,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            nextStationData!.difficulty.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getDifficultyColor(
                                nextStationData!.difficulty,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Display elevation and distance info for next station
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.height, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Elevation: ${nextStationData!.elevation}m',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.route, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Distance: ${station.distanceToNextKm ?? 0} km',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Steps info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
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
            ] else ...[
              // Loading or no next station
              if (station.nextStationId != null)
                const Center(child: CircularProgressIndicator())
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'This is the final station!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Use a high initial page to support infinite scroll
    final centerPage = widget.images.length * 50 + widget.initialIndex;
    _pageController = PageController(initialPage: centerPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${(_currentIndex % widget.images.length) + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index % widget.images.length;
          });
        },
        itemBuilder: (context, index) {
          final imageIndex = index % widget.images.length;
          final imagePath = widget.images[imageIndex];

          return GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: Image.asset(
                'assets/images/$imagePath',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.image_not_supported,
                    color: Colors.white,
                    size: 50,
                  );
                },
              ),
            ),
          );
        },
        itemCount: widget.images.length * 100,
        physics: const PageScrollPhysics(),
      ),
    );
  }
}
