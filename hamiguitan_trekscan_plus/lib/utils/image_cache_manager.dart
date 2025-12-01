import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheManager {
  static const int maxCacheSize = 100; // Maximum number of images to cache
  static const Duration cacheTimeout = Duration(days: 7); // Cache for 7 days

  /// Pre-load images for better performance
  static Future<void> preloadImages(
    List<String> imageUrls,
    BuildContext context,
  ) async {
    for (final url in imageUrls.take(5)) {
      // Only preload first 5 images
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (e) {
        debugPrint('Failed to preload image: $url, Error: $e');
      }
    }
  }

  /// Clear old cache entries to free up memory
  static Future<void> clearOldCache() async {
    try {
      final cacheManager = DefaultCacheManager();
      await cacheManager.emptyCache();
      debugPrint('Image cache cleared successfully');
    } catch (e) {
      debugPrint('Failed to clear image cache: $e');
    }
  }

  /// Get optimized cache size based on image dimensions
  static int getOptimizedCacheSize(double width, double height) {
    // Calculate appropriate cache size to balance quality and memory
    final maxDimension = width > height ? width : height;

    if (maxDimension > 800) {
      return 800;
    } else if (maxDimension > 400) {
      return 600;
    } else {
      return 400;
    }
  }
}
