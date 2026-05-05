/// Resolves a station `images[]` entry from JSON to a full asset path.
///
/// Entries like `station_images/UNESCO Marker/file.jpg` live under [assets/].
/// Legacy plain filenames (e.g. `station1.jpg`) resolve under [assets/images/].
String stationImageAssetPath(String imageRef) {
  if (imageRef.startsWith('station_images/')) {
    return 'assets/$imageRef';
  }
  return 'assets/images/$imageRef';
}
