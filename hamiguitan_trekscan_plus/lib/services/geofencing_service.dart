import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class GeofencingService {
  static const double GEOFENCE_RADIUS_METERS =
      500; // 500 meters for testing (can be reduced to 100 later)

  /// Request location permissions from user
  static Future<bool> requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      return result == LocationPermission.whileInUse ||
          result == LocationPermission.always;
    }

    if (permission == LocationPermission.deniedForever) {
      // Open app settings if permission is permanently denied
      await Geolocator.openLocationSettings();
      return false;
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current user location
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check permission first
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      // Check if services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
      return position;
    } catch (e) {
      return null;
    }
  }

  /// Calculate distance between two coordinates in meters using Haversine formula
  static double calculateDistance({
    required double userLat,
    required double userLng,
    required double stationLat,
    required double stationLng,
  }) {
    const R = 6371000; // Earth's radius in meters

    final lat1Rad = _toRadians(userLat);
    final lat2Rad = _toRadians(stationLat);
    final deltaLat = _toRadians(stationLat - userLat);
    final deltaLng = _toRadians(stationLng - userLng);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = R * c;

    return distance;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Check if user is within geofence of a station
  static Future<GeofenceCheckResult> checkGeofence({
    required double stationLat,
    required double stationLng,
    required double radiusMeters,
  }) async {
    try {
      final userPosition = await getCurrentLocation();

      if (userPosition == null) {
        return GeofenceCheckResult(
          isWithinGeofence: false,
          distanceMeters: null,
          errorMessage: 'Unable to get current location',
        );
      }

      final distance = calculateDistance(
        userLat: userPosition.latitude,
        userLng: userPosition.longitude,
        stationLat: stationLat,
        stationLng: stationLng,
      );

      final isWithin = distance <= radiusMeters;

      return GeofenceCheckResult(
        isWithinGeofence: isWithin,
        distanceMeters: distance,
        userLat: userPosition.latitude,
        userLng: userPosition.longitude,
      );
    } catch (e) {
      return GeofenceCheckResult(
        isWithinGeofence: false,
        distanceMeters: null,
        errorMessage: 'Geofence check failed: $e',
      );
    }
  }

  /// Format distance for display
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    }
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }

  /// Parse coordinates from string format "N:06°44'10.65'' E:126°08'29.99''"
  static Map<String, double>? parseCoordinates(String coordinates) {
    try {
      // Handle invalid coordinates
      if (coordinates.contains('--') || coordinates.isEmpty) return null;

      final parts = coordinates.split(' ');
      if (parts.length < 2) return null;

      final latStr = parts[0].trim();
      final lngStr = parts[1].trim();

      final lat = _parseCoordinate(latStr);
      final lng = _parseCoordinate(lngStr);

      if (lat == null || lng == null) return null;

      return {'latitude': lat, 'longitude': lng};
    } catch (e) {
      return null;
    }
  }

  /// Parse individual coordinate value like "N:06°44'10.65''" or "E:126°08'29.99''"
  static double? _parseCoordinate(String coord) {
    try {
      // Format: "N:06°44'10.65''" or "E:126°08'29.99''"
      // Extract the direction (N, S, E, W)
      final direction = coord[0].toUpperCase();

      // Remove direction and special characters
      String cleanCoord = coord.substring(1).replaceAll(':', '');

      // Replace all special characters with spaces
      cleanCoord = cleanCoord
          .replaceAll('°', ' ')
          .replaceAll("'", ' ')
          .replaceAll('"', ' ')
          .replaceAll("''", ' ')
          .trim();

      // Split by spaces and filter empty strings
      final parts = cleanCoord
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();

      if (parts.length < 3) return null;

      final degrees = double.tryParse(parts[0]) ?? 0.0;
      final minutes = double.tryParse(parts[1]) ?? 0.0;
      final seconds = double.tryParse(parts[2]) ?? 0.0;

      double result = degrees + (minutes / 60) + (seconds / 3600);

      // Apply sign based on direction
      if (direction == 'S' || direction == 'W') {
        result = -result;
      }

      return result;
    } catch (e) {
      return null;
    }
  }
}

/// Result class for geofence checks
class GeofenceCheckResult {
  final bool isWithinGeofence;
  final double? distanceMeters;
  final double? userLat;
  final double? userLng;
  final String? errorMessage;

  GeofenceCheckResult({
    required this.isWithinGeofence,
    this.distanceMeters,
    this.userLat,
    this.userLng,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;

  String getDisplayMessage() {
    if (hasError) return errorMessage!;

    if (isWithinGeofence) {
      return 'Within geofence (${GeofencingService.formatDistance(distanceMeters ?? 0)} away)';
    }
    return 'Outside geofence (${GeofencingService.formatDistance(distanceMeters ?? 0)} away)';
  }
}
