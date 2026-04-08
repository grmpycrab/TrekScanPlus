// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/station_data.dart';
import '../../models/station_review.dart';
import '../../services/station_service.dart';
import '../../services/station_review_service.dart';
import '../../theme/color.dart';
import '../../components/trail_map.dart';
import '../../components/station_review_widgets.dart';
import '../../components/biodiversity_features_section.dart';
import '../../utils/app_logger.dart';
import '../../utils/station_image_path.dart';

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

// Top-level const maps replace switch statements in hot build paths — O(1),
// no closure allocation, and the maps are created exactly once.
const Map<String, IconData> _kWarningIcons = {
  'weather': Icons.wb_cloudy,
  'cliff': Icons.terrain,
  'slippery': Icons.waves,
  'wildlife': Icons.pets,
  'visibility': Icons.visibility_off,
};

const Map<String, Color> _kWarningColors = {
  'weather': Colors.blue,
  'cliff': Colors.red,
  'slippery': Colors.orange,
  'wildlife': Colors.brown,
  'visibility': Colors.purple,
};

const Map<String, IconData> _kMetadataIcons = {
  'viewingSpots': Icons.landscape,
  'restArea': Icons.chair,
  'waterSource': Icons.water_drop,
  'summitLog': Icons.book,
  'shelterType': Icons.house,
  'signalStrength': Icons.signal_cellular_alt,
};

// ---------------------------------------------------------------------------
// Extracted stateless widgets — const-constructible, never rebuilt on scroll
// ---------------------------------------------------------------------------

/// The two gradient overlays painted over the hero image.
/// Completely static — extracted so AnimatedBuilder's child arg carries it.
class _AppBarGradientOverlay extends StatelessWidget {
  const _AppBarGradientOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
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
            height: 280,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
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
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.grey[300], size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Difficulty badge + name + metric row shown at the bottom of the hero.
/// Passed as AnimatedBuilder's `child` so it is built once per station load.
class _HeroStationInfo extends StatelessWidget {
  const _HeroStationInfo({
    required this.station,
    required this.locationPrimary,
    this.locationSub,
    required this.averageRating,
    required this.reviewCount,
    required this.reviewLoading,
  });

  final StationData station;
  final String locationPrimary;
  final String? locationSub;
  final double averageRating;
  final int reviewCount;
  final bool reviewLoading;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getDifficultyColor(
                  station.difficulty,
                ).withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _getDifficultyColor(station.difficulty),
                  width: 1.5,
                ),
              ),
              child: Text(
                station.difficulty.toUpperCase(),
                style: TextStyle(
                  color: _getDifficultyColor(station.difficulty),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    station.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                StationRatingSummaryPill(
                  loading: reviewLoading,
                  average: averageRating,
                  count: reviewCount,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MetricBadge(
                    icon: Icons.height,
                    value: '${station.elevation}m',
                    label: 'ELEVATION',
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                Expanded(
                  child: _MetricBadge(
                    icon: Icons.directions_walk,
                    value: '${station.steps ?? 0}',
                    label: 'STEPS',
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                Expanded(
                  child: _MetricBadge(
                    icon: Icons.route,
                    value: '${station.distanceToNextKm ?? 0} km',
                    label: 'DISTANCE',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 15,
                  color: Colors.grey[300],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locationPrimary,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      if (locationSub != null)
                        Text(
                          locationSub!,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10.5,
                            height: 1.25,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stream-independent sections as standalone StatelessWidgets
// Extracted so StreamBuilder rebuilds never touch them.
// ---------------------------------------------------------------------------

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.description});
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'About this Station',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          description,
          textAlign: TextAlign.justify,
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _WarningsSection extends StatelessWidget {
  const _WarningsSection({required this.warnings});
  final Map<String, dynamic> warnings;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[800],
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Safety warnings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (warnings.isEmpty)
            const Text(
              'No specific warnings for this station.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            )
          else
            ...warnings.entries.map((e) {
              final key = e.key.toLowerCase();
              final color = _kWarningColors[key] ?? Colors.orange;
              final icon = _kWarningIcons[key] ?? Icons.warning_amber_rounded;
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
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.value,
                        style: const TextStyle(
                          color: AppColors.text,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({required this.metadata});
  final Map<String, dynamic> metadata;

  static String _formatKey(String key) {
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

  static String _formatValue(dynamic value) {
    if (value is bool) return value ? 'Available' : 'Not Available';
    if (value is List) return value.join(', ');
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (metadata.isEmpty) return const SizedBox.shrink();
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
          Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Additional information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...metadata.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _kMetadataIcons[entry.key] ?? Icons.info,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatKey(entry.key)}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(_formatValue(entry.value)),
                ],
              ),
            ),
          ),
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
  Timer? _heroSlideshowTimer;
  bool _heroSlideshowFromTimer = false;

  static const _heroSlideshowInterval = Duration(seconds: 4);
  static const _heroSlideDuration = Duration(milliseconds: 500);

  // -------------------------------------------------------------------------
  // Cached per-station derived values — computed once in initState, never
  // recomputed during StreamBuilder or scroll rebuilds.
  // -------------------------------------------------------------------------
  late final List<String> _imagePaths; // stationImageAssetPath resolved once
  late final String? _dmsLine;
  late final String? _decLine;
  late final String _locationPrimary;
  late final String? _locationSub;

  // Cached static subtree widgets — built once, reused across all rebuilds.
  late final Widget _descriptionSection;
  late final Widget _warningsSection;
  late final Widget _biodiversityFeaturesSection;
  late final Widget _metadataSection;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _imagePageController = PageController();

    // Resolve asset paths once — stationImageAssetPath may do string work.
    _imagePaths = station.images
        .map((img) => stationImageAssetPath(img))
        .toList(growable: false);

    // Compute coordinate strings once.
    _dmsLine = _computeDmsLine();
    _decLine = _computeDecimalLine();
    _locationPrimary = _dmsLine ?? _decLine ?? station.coordinates.trim();
    _locationSub = (_dmsLine != null && _decLine != null) ? _decLine : null;

    // Build stream-independent widgets once.
    _descriptionSection = _DescriptionSection(description: station.description);
    _warningsSection = _WarningsSection(
      warnings: station.trailDetails?.warnings ?? {},
    );
    _biodiversityFeaturesSection = station.trailDetails != null
        ? BiodiversityFeaturesSection(trailDetails: station.trailDetails!)
        : const SizedBox.shrink();
    _metadataSection = _MetadataSection(metadata: station.metadata);

    _preloadImages();
    _loadStationData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startHeroSlideshow());
  }

  @override
  void dispose() {
    _heroSlideshowTimer?.cancel();
    _scrollController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  void _startHeroSlideshow() {
    _heroSlideshowTimer?.cancel();
    if (station.images.length <= 1 || !mounted) return;
    _heroSlideshowTimer = Timer.periodic(_heroSlideshowInterval, (_) {
      if (!mounted || !_imagePageController.hasClients) return;
      _heroSlideshowFromTimer = true;
      _imagePageController.nextPage(
        duration: _heroSlideDuration,
        curve: Curves.easeInOut,
      );
    });
  }

  void _onHeroPageChanged(int virtualIndex, int imageCount) {
    _precacheNextImage(virtualIndex % imageCount);
    if (station.images.length <= 1) return;
    if (_heroSlideshowFromTimer) {
      _heroSlideshowFromTimer = false;
      return;
    }
    _heroSlideshowTimer?.cancel();
    _startHeroSlideshow();
  }

  // -------------------------------------------------------------------------
  // Image helpers
  // -------------------------------------------------------------------------

  Future<void> _preloadImages() async {
    if (_imagePaths.isEmpty) return;
    try {
      await precacheImage(AssetImage(_imagePaths[0]), context);
      if (_imagePaths.length > 1) {
        await precacheImage(AssetImage(_imagePaths[1]), context);
      }
    } catch (e) {
      AppLogger.e('Error preloading images: $e');
    }
  }

  void _precacheNextImage(int currentIndex) {
    if (_imagePaths.isEmpty) return;
    final nextIndex = (currentIndex + 1) % _imagePaths.length;
    precacheImage(
      AssetImage(_imagePaths[nextIndex]),
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
  // Coordinate helpers — called once in initState
  // -------------------------------------------------------------------------

  String? _computeDmsLine() {
    final c = station.coordinates;
    final n = RegExp(
      r"N:\s*(\d+)°(\d+)'([\d.]+)''",
      caseSensitive: false,
    ).firstMatch(c);
    final e = RegExp(
      r"E:\s*(\d+)°(\d+)'([\d.]+)''",
      caseSensitive: false,
    ).firstMatch(c);
    if (n != null && e != null) {
      return '${n[1]}° ${n[2]}′ ${n[3]}″ N · ${e[1]}° ${e[2]}′ ${e[3]}″ E';
    }
    return null;
  }

  String? _computeDecimalLine() {
    final lat = station.latitude;
    final lng = station.longitude;
    if (lat == null || lng == null) return null;
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(5)}° $ns, ${lng.abs().toStringAsFixed(5)}° $ew';
  }

  // -------------------------------------------------------------------------
  // Root build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: Colors.black,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: Material(
                  color: AppColors.cardBackground,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
                    child: StreamBuilder<List<StationReview>>(
                      stream: StationReviewService.instance.watchReviews(
                        station.id,
                      ),
                      builder: (context, snapshot) {
                        final reviews = snapshot.data ?? [];
                        final reviewLoading =
                            snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData;
                        final hasRouteSection =
                            allStations.isNotEmpty ||
                            station.nextStationId != null ||
                            _isEndStation(station.id);
                        final hasNext =
                            station.nextStationId != null ||
                            _isEndStation(station.id);
                        final isEnd = _isEndStation(station.id);
                        final routeDiffColor = _getDifficultyColor(
                          nextStationData?.difficulty ?? '',
                        );

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _descriptionSection,
                            const SizedBox(height: 32),
                            _biodiversityFeaturesSection,
                            if ((station.trailDetails?.warnings ?? {})
                                .isNotEmpty) ...[
                              const SizedBox(height: 32),
                              _warningsSection,
                            ],
                            if (hasRouteSection) ...[
                              const SizedBox(height: 32),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.07,
                                      ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accent,
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        14,
                                        16,
                                        16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 3,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: AppColors.accent,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              const Icon(
                                                Icons.map_outlined,
                                                size: 22,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Trail map & next station',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.text,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          if (allStations.isNotEmpty)
                                            RepaintBoundary(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: SizedBox(
                                                  height: 240,
                                                  child: TrailMap(
                                                    currentStation: station,
                                                    allStations: allStations,
                                                    height: 240,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (hasNext) ...[
                                            if (allStations.isNotEmpty)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 14,
                                                    ),
                                                child: Divider(
                                                  height: 1,
                                                  color: AppColors.border,
                                                ),
                                              )
                                            else
                                              const SizedBox(height: 14),
                                            if (isEnd) ...[
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(
                                                  14,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accent
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(
                                                      Icons.celebration,
                                                      color: AppColors.accent,
                                                      size: 24,
                                                    ),
                                                    SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        "You've reached the final station on this route!",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              AppColors.accent,
                                                          height: 1.4,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ] else if (nextStationData !=
                                                null) ...[
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      nextStationData!.name,
                                                      style: const TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppColors.text,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: routeDiffColor
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: routeDiffColor
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      nextStationData!
                                                          .difficulty
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: routeDiffColor,
                                                        letterSpacing: 0.6,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: AppColors.background,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.height,
                                                            size: 20,
                                                            color: AppColors
                                                                .primary,
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            '${nextStationData!.elevation}m',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color:
                                                                      AppColors
                                                                          .text,
                                                                ),
                                                          ),
                                                          Text(
                                                            'ELEVATION',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors
                                                                  .grey[500],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              letterSpacing:
                                                                  0.5,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 1,
                                                      height: 36,
                                                      color: AppColors.border,
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.route,
                                                            size: 20,
                                                            color: AppColors
                                                                .primary,
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            '${station.distanceToNextKm ?? 0} km',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color:
                                                                      AppColors
                                                                          .text,
                                                                ),
                                                          ),
                                                          Text(
                                                            'DISTANCE',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors
                                                                  .grey[500],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              letterSpacing:
                                                                  0.5,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 13,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accent,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.directions_walk,
                                                      size: 20,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      station.steps != null
                                                          ? '${station.steps} steps to next station'
                                                          : 'Distance in steps not available',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    const Icon(
                                                      Icons.arrow_forward,
                                                      size: 18,
                                                      color: Colors.white70,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ] else if (station.nextStationId !=
                                                null) ...[
                                              const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (station.metadata.isNotEmpty) ...[
                              const SizedBox(height: 32),
                              _metadataSection,
                            ],
                            const SizedBox(height: 32),
                            StationReviewsSectionBody(
                              stationId: station.id,
                              reviews: reviews,
                              loading: reviewLoading,
                              error: snapshot.error,
                            ),
                            const SizedBox(height: 40),
                          ],
                        );
                      },
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
        StreamBuilder<List<StationReview>>(
          stream: StationReviewService.instance.watchReviews(station.id),
          builder: (context, snapshot) {
            final reviews = snapshot.data ?? [];
            final avg = StationReview.averageRating(reviews);
            final reviewLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;

            return _HeroStationInfo(
              station: station,
              locationPrimary: _locationPrimary,
              locationSub: _locationSub,
              averageRating: avg,
              reviewCount: reviews.length,
              reviewLoading: reviewLoading,
            );
          },
        ), // rebuilds only on review updates
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
          expandedHeight: 460.0,
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
    if (_imagePaths.isEmpty) {
      return const ColoredBox(
        color: AppColors.border,
        child: Center(child: Icon(Icons.image_not_supported, size: 50)),
      );
    }

    final imageCount = _imagePaths.length;

    return PageView.builder(
      controller: _imagePageController,
      onPageChanged: (virtualIndex) {
        _onHeroPageChanged(virtualIndex, imageCount);
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
            _imagePaths[real], // pre-resolved path — no function call per frame
            fit: BoxFit.cover,
            // Decode at display width only; height is inferred to preserve
            // aspect ratio. Halves texture memory vs specifying both dims.
            cacheWidth: 600,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: AppColors.border,
              child: Center(child: Icon(Icons.image_not_supported, size: 50)),
            ),
          ),
        );
      },
    );
  }

  void _showFullscreenImage(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenImageViewer(
          imagePaths: _imagePaths, // pass pre-resolved paths
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fullscreen image viewer
// ---------------------------------------------------------------------------

class _FullscreenImageViewer extends StatefulWidget {
  // Accepts pre-resolved paths instead of raw image names.
  final List<String> imagePaths;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.imagePaths,
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
      initialPage: widget.imagePaths.length * 50 + widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageCount = widget.imagePaths.length;
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
          '${(_currentIndex % imageCount) + 1} / $imageCount',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          final real = index % imageCount;
          if (_currentIndex != real) setState(() => _currentIndex = real);
        },
        itemCount: imageCount * 100,
        physics: const PageScrollPhysics(),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: Image.asset(
                widget.imagePaths[index % imageCount],
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
