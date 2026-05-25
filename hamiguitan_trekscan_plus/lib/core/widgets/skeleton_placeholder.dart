import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// ─── Shared animation scope ───────────────────────────────────────────────────

/// Provides a single looping shimmer position to all [SkeletonBox] descendants.
///
/// Wrap your skeleton list with this once — every box inside shares the same
/// sweep so they all animate in perfect sync.
///
/// ```dart
/// SkeletonShimmer(
///   child: Column(children: [MySkeleton(), MySkeleton()]),
/// )
/// ```
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    // pos travels from -0.5 → 1.5 so the highlight band sweeps fully in/out
    _anim = Tween<double>(begin: -0.5, end: 1.5).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => _ShimmerScope(
        position: _anim.value,
        child: child!,
      ),
      child: widget.child,
    );
  }
}

/// InheritedWidget that carries the current shimmer sweep position.
class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.position, required super.child});

  /// 0 = highlight at left edge, 1 = highlight at right edge.
  final double position;

  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.position;

  @override
  bool updateShouldNotify(_ShimmerScope old) => old.position != position;
}

// ─── Atomic skeleton primitives ───────────────────────────────────────────────

/// A rectangle filled with an animated shimmer gradient.
///
/// Must be a descendant of [SkeletonShimmer] for the animation to run;
/// falls back to a static muted fill if no ancestor is found.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 6,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final base = isDark ? const Color(0xFF252525) : const Color(0xFFE4E4E4);
    final highlight = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF2F2F2);

    final pos = _ShimmerScope.of(context) ?? 0.5;

    // Animate a highlight band across the gradient via stops.
    // When pos = 0 → band at far left; pos = 1 → band at far right.
    final stops = [
      (pos - 0.25).clamp(0.0, 1.0),
      pos.clamp(0.0, 1.0),
      (pos + 0.25).clamp(0.0, 1.0),
    ];

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [base, highlight, base],
          stops: stops,
        ),
      ),
    );
  }
}

/// Full-width single-line skeleton (text placeholder).
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    super.key,
    this.width,
    this.height = 13,
    this.borderRadius = 4,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => SkeletonBox(
        width: width,
        height: height,
        borderRadius: borderRadius,
      );
}

/// Circle skeleton (avatar placeholder).
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) => SkeletonBox(
        width: radius * 2,
        height: radius * 2,
        borderRadius: radius,
      );
}
