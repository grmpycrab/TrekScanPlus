import 'dart:async';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/e_certificate_service.dart';
import '../../../components/e_certificate_badge.dart';

class BannerSlideshow extends StatefulWidget {
  const BannerSlideshow({
    super.key,
    required this.isCollapsed,
    required this.onToggle,
  });

  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  State<BannerSlideshow> createState() => _BannerSlideshowState();
}

class _BannerSlideshowState extends State<BannerSlideshow> {
  int _currentIndex = 0;
  Timer? _timer;

  static const double _expandedHeight = 180;
  static const double _collapsedHeight = 52;

  final List<String> _bannerImages = [
    'assets/images/station10.jpg',
    'assets/images/station3.jpg',
    'assets/station_images/Lantawan 2/20241030_154550.jpg',
  ];

  late BoxDecoration _containerDecoration;
  late BoxDecoration _gradientDecoration;

  @override
  void initState() {
    super.initState();
    _startAutoplay();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colors = context.colors;
    _containerDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: colors.border.withValues(alpha: 0.45),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
    _gradientDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          colors.primary.withValues(alpha: 0.92),
          colors.primary.withValues(alpha: 0.6),
          Colors.black.withValues(alpha: 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ),
    );
  }

  void _startAutoplay() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(
          () => _currentIndex = (_currentIndex + 1) % _bannerImages.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: widget.onToggle,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        clipBehavior: Clip.hardEdge,
        decoration: _containerDecoration,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          height: widget.isCollapsed ? _collapsedHeight : _expandedHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Crossfade slideshow images ──────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 1200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  ),
                  child: child,
                ),
                child: Image.asset(
                  _bannerImages[_currentIndex],
                  key: ValueKey(_currentIndex),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) =>
                      ColoredBox(color: colors.primary),
                ),
              ),

              // ── Dark gradient overlay (always visible) ───────────────────
              DecoratedBox(decoration: _gradientDecoration),

              // ── Expanded content (crossfades out when collapsing) ────────
              IgnorePointer(
                ignoring: widget.isCollapsed,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: widget.isCollapsed ? 0.0 : 1.0,
                  child: OverflowBox(
                    maxHeight: _expandedHeight,
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'Mt. Hamiguitan TrekScan+',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0, 1),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Discover · Trek · Experience',
                            style: TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 11,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.8,
                              height: 1.4,
                              shadows: [
                                Shadow(
                                  color: Colors.black45,
                                  offset: Offset(0, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Page indicator dots
                              ...List.generate(
                                _bannerImages.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: _currentIndex == i ? 22 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: _currentIndex == i
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.45),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Collapse affordance pill
                              _ActionPill(
                                icon: Icons.keyboard_arrow_up_rounded,
                                label: 'Hide',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Collapsed strip (crossfades in when collapsing) ──────────
              IgnorePointer(
                ignoring: !widget.isCollapsed,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: widget.isCollapsed ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.terrain_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Mt. Hamiguitan TrekScan+',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ActionPill(
                          icon: Icons.keyboard_arrow_down_rounded,
                          label: 'Show',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Trophy badge (hidden when collapsed to avoid overlap) ─────
              Positioned(
                top: 6,
                right: 6,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: widget.isCollapsed ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: widget.isCollapsed,
                    child: ECertificateBadge(
                      certificateService: ECertificateService.instance,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small frosted-glass pill used as a tap affordance label inside the banner.
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 13),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
