// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/station_data.dart';
import '../../services/station_service.dart';
import '../../theme/color.dart';
import '../../components/trail_map.dart';
import '../../utils/app_logger.dart';

// ---------------------------------------------------------------------------
// Top-level pure functions — no closure allocations per build
// ---------------------------------------------------------------------------

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

// Set lookup is O(1) vs List.contains O(n)
bool _isEndStation(String stationId) {
  const ids = {'i73hl7b7g3', 'r5kntj3sae', 'mr2l529okj'};
  return ids.contains(stationId);
}

// ---------------------------------------------------------------------------
// Extracted stateless widgets — const-constructible, never rebuilt on scroll
// ---------------------------------------------------------------------------

/// The two gradient overlays painted over the hero image.
/// Completely static — extracted so AnimatedBuilder's child arg carries it.
class _AppBarGradientOverlay extends StatelessWidget {
  const _AppBarGradientOverlay();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: const [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.3, 0.5, 0.7, 1.0],
              colors: [
                Color(0x4D000000),
                Colors.transparent,
                Colors.transparent,
                Color(0x80000000),
                Color(0xCC000000),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xCC000000),
                  Color(0x99000000),
                  Color(0x4D000000),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single metric badge (elevation / steps / distance) in the hero.
class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
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
}

/// Difficulty badge + name + metric row shown at the bottom of the hero.
/// Passed as AnimatedBuilder's `child` so it is built once per station load.
class _HeroStationInfo extends StatelessWidget {
  const _HeroStationInfo({required this.station});

  final StationData station;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              _MetricBadge(
                icon: Icons.height,
                value: '${station.elevation}m',
                label: 'ELEVATION',
              ),
              const SizedBox(width: 12),
              _MetricBadge(
                icon: Icons.directions_walk,
                value: '${station.steps ?? 0}',
                label: 'STEPS',
              ),
              const SizedBox(width: 12),
              _MetricBadge(
                icon: Icons.route,
                value: '${station.distanceToNextKm ?? 0} km',
                label: 'DISTANCE',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dark coordinate box with a copy button.
class _CoordBox extends StatelessWidget {
  const _CoordBox({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 6,
            offset: Offset(0, 2),
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
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
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
            onPressed: onCopy,
            tooltip: 'Copy $label',
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

/// Bullet-point list item used in the biodiversity section.
class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

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

  late final ScrollController _scrollController;
  late final PageController _imagePageController;

  // Only the dot-indicator needs this; rebuilt via setState only on page swipe.
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _imagePageController = PageController();
    // No addListener on _scrollController — AnimatedBuilder handles reactivity.
    _preloadImages();
    _loadStationData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Image helpers
  // -------------------------------------------------------------------------

  Future<void> _preloadImages() async {
    if (station.images.isEmpty) return;
    try {
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

  void _precacheNextImage(int currentIndex) {
    if (station.images.isEmpty) return;
    final nextIndex = (currentIndex + 1) % station.images.length;
    precacheImage(
      AssetImage('assets/images/${station.images[nextIndex]}'),
      context,
    ).catchError((e) => AppLogger.e('Error precaching image: $e'));
  }

  // -------------------------------------------------------------------------
  // Data
  // -------------------------------------------------------------------------

  Future<void> _loadStationData() async {
    try {
      if (!StationService.instance.isLoaded) {
        await StationService.instance.loadStations();
      }
      if (!mounted) return;

      final loaded = StationService.instance.getAllStations();
      final next = station.nextStationId != null
          ? StationService.instance.getStationById(station.nextStationId!)
          : null;

      setState(() {
        allStations = loaded;
        nextStationData = next;
      });
    } catch (e) {
      AppLogger.e('Error loading station data: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Root build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
          ],
        ),
      );
    } catch (e) {
      return const Scaffold(
        body: Center(child: Text('Error: Station data not available')),
      );
    }
  }

  // -------------------------------------------------------------------------
  // SliverAppBar — performance-critical
  // -------------------------------------------------------------------------

  Widget _buildAppBar() {
    // Build the static background subtree ONCE here.
    // It is passed as AnimatedBuilder's `child` and reused every frame,
    // so the carousel and overlays are never reconstructed during scroll.
    final staticBackground = Stack(
      fit: StackFit.expand,
      children: [
        _buildImageCarousel(), // rebuilds only on page swipe
        const _AppBarGradientOverlay(), // const, never rebuilds
        _HeroStationInfo(
          station: station,
        ), // rebuilds only when station changes
      ],
    );

    return AnimatedBuilder(
      animation: _scrollController,
      child: staticBackground, // ← zero work here; handed to builder as-is
      builder: (context, background) {
        final offset = _scrollController.hasClients
            ? _scrollController.offset
            : 0.0;

        // Clamp once, reuse for both color lerps.
        final iconT = (offset / 100).clamp(0.0, 1.0);
        final bgT = (offset / 150).clamp(0.0, 1.0);

        return SliverAppBar(
          expandedHeight: 400.0,
          pinned: true,
          elevation: offset > 50 ? 4.0 : 0.0,
          shadowColor: const Color(0x1A000000),
          backgroundColor: Color.lerp(Colors.transparent, Colors.white, bgT),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Color.lerp(Colors.white, Colors.black, iconT),
            ),
            onPressed: () => Navigator.pop(context, widget.station),
          ),
          title: Text(
            ' ${station.name}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color.lerp(Colors.white, AppColors.text, iconT),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: EdgeInsets.zero,
            expandedTitleScale: 1.0,
            background: background, // pre-built child — no work done here
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Image carousel
  // -------------------------------------------------------------------------

  Widget _buildImageCarousel() {
    if (station.images.isEmpty) {
      return ColoredBox(
        color: AppColors.border,
        child: const Center(child: Icon(Icons.image_not_supported, size: 50)),
      );
    }

    final imageCount = station.images.length;

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _imagePageController,
          // SINGLE source of truth for page changes.
          // Removed the duplicate PageController addListener that caused a
          // second setState for every fractional-pixel swipe animation frame.
          onPageChanged: (virtualIndex) {
            final real = virtualIndex % imageCount;
            if (_currentImageIndex != real) {
              setState(() => _currentImageIndex = real);
              _precacheNextImage(real);
            }
          },
          // Large enough to feel infinite; much smaller than ×100 to reduce
          // the internal page-offset arithmetic Flutter does every frame.
          itemCount: imageCount * 999,
          physics: const PageScrollPhysics(),
          itemBuilder: (context, virtualIndex) {
            final real = virtualIndex % imageCount;
            return GestureDetector(
              onTap: () => _showFullscreenImage(real),
              child: Image.asset(
                'assets/images/${station.images[real]}',
                fit: BoxFit.cover,
                // Decode at display width only; height is inferred to preserve
                // aspect ratio. Halves texture memory vs specifying both dims.
                cacheWidth: 600,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: AppColors.border,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 50),
                  ),
                ),
              ),
            );
          },
        ),
        if (imageCount > 1)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            // RepaintBoundary keeps dot repaints from dirtying the image layer.
            child: RepaintBoundary(child: _buildImageIndicators()),
          ),
      ],
    );
  }

  Widget _buildImageIndicators() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(station.images.length, (index) {
            final active = _currentImageIndex == index;
            // AnimatedContainer avoids a janky jump when the active dot changes.
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? Colors.white : const Color(0x80FFFFFF),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
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

  // -------------------------------------------------------------------------
  // Content sections — no scroll dependency; rebuilt only by setState
  // -------------------------------------------------------------------------

  Widget _buildStationInfo() {
    final lat = _formatCoordinate(station.coordinates, 'N');
    final lng = _formatCoordinate(station.coordinates, 'E');

    Future<void> copy(String text) async {
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: _CoordBox(
              label: 'LATITUDE',
              value: lat,
              onCopy: () => copy(lat),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CoordBox(
              label: 'LONGITUDE',
              value: lng,
              onCopy: () => copy(lng),
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
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
                  '1',
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

  Widget _buildWarnings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
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
              ...station.warnings.entries.map((e) {
                final color = _warningColor(e.key);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_warningIcon(e.key), color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.value,
                          style: TextStyle(color: AppColors.text, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  IconData _warningIcon(String type) {
    switch (type.toLowerCase()) {
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

  Color _warningColor(String type) {
    switch (type.toLowerCase()) {
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

  Widget _buildBiodiversity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                (item) => _BulletItem(text: item, color: Colors.green[300]!),
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
                (item) => _BulletItem(
                  text: item,
                  color: AppColors.primary.withValues(alpha: 0.5),
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
        padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      _metadataIcon(entry.key),
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

  IconData _metadataIcon(String key) {
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
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? ''
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _formatMetadataValue(dynamic value) {
    if (value is bool) return value ? 'Available' : 'Not Available';
    if (value is List) return value.join(', ');
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
        // RepaintBoundary: map canvas stays isolated from scroll layer repaints.
        RepaintBoundary(
          child: ClipRRect(
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
        ),
      ],
    );
  }

  Widget _buildNextStation() {
    if (_isEndStation(station.id)) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
        padding: const EdgeInsets.all(16),
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

// ---------------------------------------------------------------------------
// Fullscreen image viewer
// ---------------------------------------------------------------------------

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
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(
      initialPage: widget.images.length * 50 + widget.initialIndex,
    );
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
          final real = index % widget.images.length;
          if (_currentIndex != real) setState(() => _currentIndex = real);
        },
        itemCount: widget.images.length * 100,
        physics: const PageScrollPhysics(),
        itemBuilder: (context, index) {
          final imagePath = widget.images[index % widget.images.length];
          return GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: Image.asset(
                'assets/images/$imagePath',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.image_not_supported,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
