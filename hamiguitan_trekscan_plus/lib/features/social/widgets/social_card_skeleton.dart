import 'package:flutter/material.dart';
import '../../../core/widgets/skeleton_placeholder.dart';

/// Structural placeholder for [SocialCard] shown during initial feed load.
///
/// Mirrors the card's exact layout — header, caption lines, media block, and
/// action row — so there is zero layout shift when real content arrives.
///
/// Wrap one or more of these in a [SkeletonShimmer] so they animate in sync:
/// ```dart
/// SkeletonShimmer(
///   child: Column(children: [SocialCardSkeleton(), SocialCardSkeleton()]),
/// )
/// ```
class SocialCardSkeleton extends StatelessWidget {
  const SocialCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildCaption(),
          _buildMedia(),
          _buildActions(),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  // avatar circle | name + timestamp column | follow pill | ··· icon
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SkeletonCircle(radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: 130, height: 13),
                const SizedBox(height: 5),
                const SkeletonLine(width: 80, height: 11),
              ],
            ),
          ),
          // Follow button placeholder
          const SkeletonBox(width: 72, height: 28, borderRadius: 20),
          const SizedBox(width: 10),
          // ··· menu placeholder
          const SkeletonBox(width: 22, height: 22, borderRadius: 4),
        ],
      ),
    );
  }

  // ── Caption ─────────────────────────────────────────────────────────────────
  // 2 full-width lines + 1 partial line
  Widget _buildCaption() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLine(height: 13),
          SizedBox(height: 6),
          SkeletonLine(height: 13),
          SizedBox(height: 6),
          SkeletonLine(width: 180, height: 13),
        ],
      ),
    );
  }

  // ── Media ───────────────────────────────────────────────────────────────────
  // Full-width image block — matches typical single-image post height
  Widget _buildMedia() {
    return const SkeletonBox(height: 220, borderRadius: 0);
  }

  // ── Actions ─────────────────────────────────────────────────────────────────
  // divider + like / comment / share / bookmark placeholders
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          const SkeletonBox(height: 1.5, borderRadius: 0),
          const SizedBox(height: 12),
          Row(
            children: [
              // Like icon + count
              const SkeletonBox(width: 24, height: 24, borderRadius: 4),
              const SizedBox(width: 6),
              const SkeletonLine(width: 28, height: 12),
              const SizedBox(width: 20),
              // Comment icon + count
              const SkeletonBox(width: 24, height: 24, borderRadius: 4),
              const SizedBox(width: 6),
              const SkeletonLine(width: 28, height: 12),
              const SizedBox(width: 20),
              // Share icon + count
              const SkeletonBox(width: 24, height: 24, borderRadius: 4),
              const SizedBox(width: 6),
              const SkeletonLine(width: 28, height: 12),
              const Spacer(),
              // Bookmark icon
              const SkeletonBox(width: 24, height: 24, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}
