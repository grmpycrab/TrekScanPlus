import 'package:flutter/material.dart';

/// A drop-in replacement for [Image.asset] that:
///
/// - Calls [precacheImage] in [didChangeDependencies] so the image is warm
///   before the first frame paints (eliminates the cold-load flash).
/// - Sets [gaplessPlayback] to `true` so swapping [assetPath] at runtime
///   never shows a blank frame between the old and new image.
/// - Accepts [cacheWidth] / [cacheHeight] to decode the raster at a
///   constrained resolution — use this on large photos shown at small sizes to
///   cut GPU texture memory.
///
/// ### DecorationImage usage
///
/// When you need an [ImageProvider] (e.g. inside [DecorationImage] or
/// [BoxDecoration]) call the static [provider] factory instead of using this
/// widget:
///
/// ```dart
/// DecorationImage(
///   image: PrecachedAssetImage.provider('assets/images/foo.jpg', cacheWidth: 800),
///   fit: BoxFit.cover,
/// )
/// ```
///
/// The [provider] factory returns a [ResizeImage]-wrapped [AssetImage] whose
/// cache key matches what this widget uses internally, so both paths share the
/// same decoded bitmap in Flutter's image cache.
class PrecachedAssetImage extends StatefulWidget {
  const PrecachedAssetImage(
    this.assetPath, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.color,
    this.colorBlendMode,
    this.cacheWidth,
    this.cacheHeight,
    this.alignment = Alignment.center,
    this.errorBuilder,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Color? color;
  final BlendMode? colorBlendMode;

  /// Decode the raster at this pixel width. Use multiples of the logical size
  /// × device density (e.g. 24 dp × 3× = 72 for bottom-nav icons at 3×).
  final int? cacheWidth;

  /// Decode the raster at this pixel height.
  final int? cacheHeight;

  final Alignment alignment;
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Returns an [ImageProvider] suitable for [DecorationImage] or any other
  /// API that consumes an [ImageProvider] directly.
  ///
  /// If [cacheWidth] or [cacheHeight] is given the provider is wrapped in
  /// [ResizeImage] so Flutter decodes the bitmap at the constrained size,
  /// reducing both decode time and GPU texture memory.
  static ImageProvider provider(
    String assetPath, {
    int? cacheWidth,
    int? cacheHeight,
  }) {
    final base = AssetImage(assetPath);
    if (cacheWidth != null || cacheHeight != null) {
      return ResizeImage(base, width: cacheWidth, height: cacheHeight);
    }
    return base;
  }

  @override
  State<PrecachedAssetImage> createState() => _PrecachedAssetImageState();
}

class _PrecachedAssetImageState extends State<PrecachedAssetImage> {
  // Keep a reference so we don't allocate a new provider on every build.
  late ImageProvider _imageProvider;

  @override
  void initState() {
    super.initState();
    _imageProvider = PrecachedAssetImage.provider(
      widget.assetPath,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fires on first mount and whenever an InheritedWidget dependency changes
    // (locale, theme) which can affect asset variant resolution.
    _warmCache();
  }

  @override
  void didUpdateWidget(PrecachedAssetImage old) {
    super.didUpdateWidget(old);
    if (old.assetPath != widget.assetPath ||
        old.cacheWidth != widget.cacheWidth ||
        old.cacheHeight != widget.cacheHeight) {
      _imageProvider = PrecachedAssetImage.provider(
        widget.assetPath,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
      );
      _warmCache();
    }
  }

  void _warmCache() {
    precacheImage(_imageProvider, context).catchError((_) {
      // Silent — errorBuilder on the Image widget handles render-time failures.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: _imageProvider,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      color: widget.color,
      colorBlendMode: widget.colorBlendMode,
      alignment: widget.alignment,
      // Never show a blank frame when switching asset paths (e.g. nav icon
      // color changes or slideshow advances).
      gaplessPlayback: true,
      errorBuilder: widget.errorBuilder,
    );
  }
}
