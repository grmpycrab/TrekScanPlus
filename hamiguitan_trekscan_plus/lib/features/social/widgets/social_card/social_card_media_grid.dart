import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../theme/app_theme.dart';

/// Handles complex image grid layouts (1-5+ images).
/// Full-width presentation with 8px margin for responsiveness.
class SocialCardMediaGrid extends StatelessWidget {
  final List<String> imageUrls;
  final Function(int) onImageTap;

  const SocialCardMediaGrid({
    super.key,
    required this.imageUrls,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    // Add subtle side spacing so media doesn't touch card edges.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRRect(
        clipBehavior: Clip.hardEdge,
        borderRadius: BorderRadius.circular(10),
        child: _buildLayout(context),
      ),
    );
  }

  Widget _buildLayout(BuildContext context) {
    if (imageUrls.length == 1) return _buildSingleImage(context);
    if (imageUrls.length == 2) return _buildTwoImages(context);
    if (imageUrls.length == 3) return _buildThreeImages(context);
    if (imageUrls.length == 4) return _buildFourImages(context);
    return _buildFivePlusImages(context);
  }

  Widget _buildSingleImage(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep a stable, responsive preview height so long images don't make
        // the feed excessively tall. Full image is still visible on tap.
        final previewHeight = (constraints.maxWidth * 0.62).clamp(220.0, 300.0);
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final targetCacheWidth = (constraints.maxWidth * dpr)
            .clamp(540.0, 1080.0)
            .round();
        final targetCacheHeight = (previewHeight * dpr)
            .clamp(420.0, 1440.0)
            .round();

        return GestureDetector(
          onTap: () => onImageTap(0),
          child: SizedBox(
            width: double.infinity,
            height: previewHeight,
            child: Container(
              color: context.colors.surfaceVariant,
              child: CachedNetworkImage(
                imageUrl: imageUrls[0],
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholderFadeInDuration: Duration.zero,
                useOldImageOnUrlChange: true,
                placeholder: (context, url) => Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 22,
                    color: context.colors.textTertiary,
                  ),
                ),
                errorWidget: (context, url, error) {
                  return Container(
                    color: context.colors.borderLight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_rounded,
                          size: 48,
                          color: context.colors.textTertiary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image unavailable',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                memCacheWidth: targetCacheWidth,
                memCacheHeight: targetCacheHeight,
                filterQuality: FilterQuality.low,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTwoImages(BuildContext context) {
    final dividerColor = context.colors.borderLight;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(child: _buildImageTile(imageUrls[0], 0)),
          Container(width: 2, color: dividerColor),
          Expanded(child: _buildImageTile(imageUrls[1], 1)),
        ],
      ),
    );
  }

  Widget _buildThreeImages(BuildContext context) {
    final dividerColor = context.colors.borderLight;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(flex: 2, child: _buildImageTile(imageUrls[0], 0)),
          Container(width: 2, color: dividerColor),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildImageTile(imageUrls[1], 1)),
                Container(height: 2, color: dividerColor),
                Expanded(child: _buildImageTile(imageUrls[2], 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourImages(BuildContext context) {
    final dividerColor = context.colors.borderLight;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(flex: 2, child: _buildImageTile(imageUrls[0], 0)),
          Container(width: 2, color: dividerColor),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildImageTile(imageUrls[1], 1)),
                Container(height: 2, color: dividerColor),
                Expanded(child: _buildImageTile(imageUrls[2], 2)),
                Container(height: 2, color: dividerColor),
                Expanded(child: _buildImageTile(imageUrls[3], 3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFivePlusImages(BuildContext context) {
    final dividerColor = context.colors.borderLight;
    final hasMoreThanFour = imageUrls.length > 4;
    final displayCount = imageUrls.length - 4;
    return AspectRatio(
      aspectRatio: 1,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildImageTile(imageUrls[0], 0)),
                Container(width: 2, color: dividerColor),
                Expanded(child: _buildImageTile(imageUrls[1], 1)),
              ],
            ),
          ),
          Container(height: 2, color: dividerColor),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildImageTile(imageUrls[2], 2)),
                Container(width: 2, color: dividerColor),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImageTile(imageUrls[3], 3),
                      if (hasMoreThanFour)
                        Container(
                          color: Colors.black.withValues(alpha: 0.6),
                          child: Center(
                            child: Text(
                              '+$displayCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTile(String url, int index) {
    return GestureDetector(
      onTap: () => onImageTap(index),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dpr = MediaQuery.of(context).devicePixelRatio;
          final targetCacheWidth = (constraints.maxWidth * dpr)
              .clamp(240.0, 720.0)
              .round();
          final targetCacheHeight = (constraints.maxHeight * dpr)
              .clamp(240.0, 720.0)
              .round();

          return CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            useOldImageOnUrlChange: true,
            placeholder: (context, url) => Container(
              color: context.colors.surfaceVariant,
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 18,
                  color: context.colors.textTertiary,
                ),
              ),
            ),
            errorWidget: (context, url, error) {
              return Container(
                color: context.colors.borderLight,
                child: Icon(
                  Icons.broken_image,
                  size: 32,
                  color: context.colors.textTertiary,
                ),
              );
            },
            memCacheWidth: targetCacheWidth,
            memCacheHeight: targetCacheHeight,
            filterQuality: FilterQuality.low,
          );
        },
      ),
    );
  }
}
