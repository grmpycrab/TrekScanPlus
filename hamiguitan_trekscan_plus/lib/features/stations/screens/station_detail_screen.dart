// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/station_data.dart';
import '../models/station_review.dart';
import '../services/station_review_service.dart';
import '../../../theme/color.dart';
import '../widgets/trail_map.dart';
import '../widgets/station_review_widgets.dart';
import '../widgets/biodiversity_features_section.dart';
import '../../../utils/app_logger.dart';
import '../viewmodels/station_detail_view_model.dart';

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
  late final StationDetailViewModel _vm;

  late final ScrollController _scrollController;
  late final PageController _imagePageController;
  Timer? _heroSlideshowTimer;
  bool _heroSlideshowFromTimer = false;

  static const _heroSlideshowInterval = Duration(seconds: 4);
  static const _heroSlideDuration = Duration(milliseconds: 500);

  // Cached static subtree widgets — built once, reused across all rebuilds.
  late final Widget _descriptionSection;
  late final Widget _warningsSection;
  late final Widget _biodiversityFeaturesSection;
  late final Widget _metadataSection;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _vm = StationDetailViewModel(widget.station);
    _vm.addListener(_onVmChanged);

    _scrollController = ScrollController();
    _imagePageController = PageController();

    // Build stream-independent widgets once — _vm.station == widget.station.
    _descriptionSection = _DescriptionSection(
      description: _vm.station.description,
    );
    _warningsSection = _WarningsSection(
      warnings: _vm.station.trailDetails?.warnings ?? {},
    );
    _biodiversityFeaturesSection = _vm.station.trailDetails != null
        ? BiodiversityFeaturesSection(trailDetails: _vm.station.trailDetails!)
        : const SizedBox.shrink();
    _metadataSection = _MetadataSection(metadata: _vm.station.metadata);

    _preloadImages();
    _vm.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startHeroSlideshow());
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _heroSlideshowTimer?.cancel();
    _scrollController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------------------
  // Slideshow
  // -------------------------------------------------------------------------

  void _startHeroSlideshow() {
    _heroSlideshowTimer?.cancel();
    if (_vm.station.images.length <= 1 || !mounted) return;
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
    if (_vm.station.images.length <= 1) return;
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
    if (_vm.imagePaths.isEmpty) return;
    try {
      await precacheImage(AssetImage(_vm.imagePaths[0]), context);
      if (_vm.imagePaths.length > 1) {
        await precacheImage(AssetImage(_vm.imagePaths[1]), context);
      }
    } catch (e) {
      AppLogger.e('Error preloading images: $e');
    }
  }

  void _precacheNextImage(int currentIndex) {
    if (_vm.imagePaths.isEmpty) return;
    final nextIndex = (currentIndex + 1) % _vm.imagePaths.length;
    precacheImage(
      AssetImage(_vm.imagePaths[nextIndex]),
      context,
    ).catchError((e) => AppLogger.e('Error precaching image: $e'));
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
                        _vm.station.id,
                      ),
                      builder: (context, snapshot) {
                        final reviews = snapshot.data ?? [];
                        final reviewLoading =
                            snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData;
                        final hasRouteSection = _vm.hasRouteSection;
                        final hasNext = _vm.hasNext;
                        final isEnd = _vm.isEndStation;
                        final routeDiffColor = _getDifficultyColor(
                          _vm.nextStationData?.difficulty ?? '',
                        );

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _descriptionSection,
                            const SizedBox(height: 32),
                            _biodiversityFeaturesSection,
                            if ((_vm.station.trailDetails?.warnings ?? {})
                                .isNotEmpty) ...[
                              const SizedBox(height: 32),
                              _warningsSection,
                            ],
                            if (hasRouteSection) ...[
                              const SizedBox(height: 32),
                              _buildRouteSection(
                                hasNext: hasNext,
                                isEnd: isEnd,
                                routeDiffColor: routeDiffColor,
                              ),
                            ],
                            if (_vm.station.metadata.isNotEmpty) ...[
                              const SizedBox(height: 32),
                              _metadataSection,
                            ],
                            const SizedBox(height: 32),
                            StationReviewsSectionBody(
                              stationId: _vm.station.id,
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
    final staticBackground = Stack(
      fit: StackFit.expand,
      children: [
        _buildImageCarousel(),
        const _AppBarGradientOverlay(),
        StreamBuilder<List<StationReview>>(
          stream: StationReviewService.instance.watchReviews(_vm.station.id),
          builder: (context, snapshot) {
            final reviews = snapshot.data ?? [];
            final avg = StationReview.averageRating(reviews);
            final reviewLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;

            return _HeroStationInfo(
              station: _vm.station,
              locationPrimary: _vm.locationPrimary,
              locationSub: _vm.locationSub,
              averageRating: avg,
              reviewCount: reviews.length,
              reviewLoading: reviewLoading,
            );
          },
        ),
      ],
    );

    return AnimatedBuilder(
      animation: _scrollController,
      child: staticBackground,
      builder: (context, background) {
        final offset = _scrollController.hasClients
            ? _scrollController.offset
            : 0.0;

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
            ' ${_vm.station.name}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color.lerp(Colors.white, AppColors.text, iconT),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: EdgeInsets.zero,
            expandedTitleScale: 1.0,
            background: background,
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Image carousel
  // -------------------------------------------------------------------------

  Widget _buildImageCarousel() {
    if (_vm.imagePaths.isEmpty) {
      return const ColoredBox(
        color: AppColors.border,
        child: Center(child: Icon(Icons.image_not_supported, size: 50)),
      );
    }

    final imageCount = _vm.imagePaths.length;

    return PageView.builder(
      controller: _imagePageController,
      onPageChanged: (virtualIndex) {
        _onHeroPageChanged(virtualIndex, imageCount);
      },
      itemCount: imageCount * 999,
      physics: const PageScrollPhysics(),
      itemBuilder: (context, virtualIndex) {
        final real = virtualIndex % imageCount;
        return GestureDetector(
          onTap: () => _showFullscreenImage(real),
          child: Image.asset(
            _vm.imagePaths[real],
            fit: BoxFit.cover,
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
          imagePaths: _vm.imagePaths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Route section
  // -------------------------------------------------------------------------

  Widget _buildRouteSection({
    required bool hasNext,
    required bool isEnd,
    required Color routeDiffColor,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRouteHeader(),
                const SizedBox(height: 12),
                if (_vm.allStations.isNotEmpty) _buildRouteMap(),
                if (hasNext) ...[
                  if (_vm.allStations.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1, color: AppColors.border),
                    )
                  else
                    const SizedBox(height: 14),
                  if (isEnd)
                    _buildEndRouteCard()
                  else if (_vm.nextStationData != null)
                    _buildNextRouteCard(routeDiffColor)
                  else if (_vm.branchNextStations.isNotEmpty)
                    _buildBranchRoutesCard()
                  else if (_vm.station.nextStationId != null &&
                      _vm.allStations.isEmpty)
                    const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteHeader() {
    return Row(
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
        const Icon(Icons.map_outlined, size: 22, color: AppColors.primary),
        const SizedBox(width: 8),
        const Text(
          'Trail Route',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildRouteMap() {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 240,
          child: TrailMap(
            currentStation: _vm.station,
            allStations: _vm.allStations,
            height: 240,
          ),
        ),
      ),
    );
  }

  Widget _buildEndRouteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.celebration, color: AppColors.accent, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "You've reached the final station on this route!",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextRouteCard(Color routeDiffColor) {
    final next = _vm.nextStationData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                next.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: routeDiffColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: routeDiffColor.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                next.difficulty.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _buildRouteMetric(
                  icon: Icons.height,
                  value: '${next.elevation}m',
                  label: 'ELEVATION',
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              Expanded(
                child: _buildRouteMetric(
                  icon: Icons.route,
                  value: '${_vm.station.distanceToNextKm ?? 0} km',
                  label: 'DISTANCE',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.directions_walk, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                _vm.station.steps != null
                    ? '${_vm.station.steps} steps to next station'
                    : 'Distance in steps not available',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward, size: 18, color: Colors.white70),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBranchRoutesCard() {
    const routeLabels = {
      '6mm4kle34g': 'Hidden Garden Route',
      'mr2l529okj': 'Summit Route',
      '44r5tebjrc': 'Black Mountain & Twin Falls',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.fork_right,
                color: AppColors.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Multiple routes branch from here',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._vm.branchNextStations.map((branch) {
          final color = _getDifficultyColor(branch.difficulty);
          final routeLabel = routeLabels[branch.id];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.directions_walk, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      if (routeLabel != null)
                        Text(
                          routeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    branch.difficulty.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRouteMetric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fullscreen image viewer
// ---------------------------------------------------------------------------

class _FullscreenImageViewer extends StatefulWidget {
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
