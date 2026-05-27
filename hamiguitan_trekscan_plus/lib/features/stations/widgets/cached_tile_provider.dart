import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// A [TileProvider] that caches downloaded OSM tile fragments on the device
/// using [CachedNetworkImageProvider] (backed by flutter_cache_manager).
///
/// Benefits:
/// - Tiles that have already been fetched load at 0 ms from disk, eliminating
///   the grey-grid flicker on repeated pan/zoom.
/// - Works with Firestore offline persistence: the map stays usable for
///   previously-visited areas even when the device is offline.
/// - No extra dependency required — reuses cached_network_image which is
///   already in the project.
///
/// Usage:
/// ```dart
/// TileLayer(
///   urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
///   userAgentPackageName: 'org.trekscanplus.mt_hamiguitan_app',
///   tileProvider: CachedTileProvider(),
/// )
/// ```
class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: headers,
    );
  }
}
