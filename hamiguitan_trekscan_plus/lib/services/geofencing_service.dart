// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../utils/app_logger.dart';

class GeofencingService {
  static const double GEOFENCE_RADIUS_METERS =
      100; // 100 meters geofence radius

  /// Shows an explanatory dialog describing WHY location access is needed,
  /// then triggers the OS permission request only if the user proceeds.
  ///
  /// Call this instead of [requestLocationPermission] when a [BuildContext]
  /// is available (e.g., from a button press inside a widget). The dialog is
  /// skipped entirely when permission is already granted.
  static Future<bool> requestWithRationale(BuildContext context) async {
    final current = await Geolocator.checkPermission();

    // Already granted — nothing to explain.
    if (current == LocationPermission.whileInUse ||
        current == LocationPermission.always) {
      return true;
    }

    // Permanently denied — direct to system settings with an explanation.
    if (current == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      final open = await showDialog<bool>(
        context: context,
        builder: (_) => const _LocationSettingsDialog(),
      );
      if (open == true) await Geolocator.openLocationSettings();
      return false;
    }

    // Permission not yet requested — show rationale first.
    if (!context.mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LocationRationaleDialog(),
    );
    if (proceed != true) return false;
    return requestLocationPermission();
  }

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

  /// Get current user location with optimized settings for faster acquisition
  static Future<Position?> getCurrentLocation({
    bool forceRefresh = false,
  }) async {
    try {
      // First, ensure location services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.w('Location services are disabled');
        return null;
      }

      // Check and request permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        AppLogger.d('Requesting location permission...');
        final result = await Geolocator.requestPermission();
        if (result != LocationPermission.whileInUse &&
            result != LocationPermission.always) {
          AppLogger.w('Location permission denied by user');
          return null;
        }
      } else if (permission == LocationPermission.deniedForever) {
        AppLogger.w(
          'Location permission permanently denied. Please enable in Settings.',
        );
        return null;
      }

      // Try to get last known position first (fastest)
      if (!forceRefresh) {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          final timeDiff = DateTime.now().difference(lastPosition.timestamp);
          // Use last position if less than 5 minutes old for geofencing
          if (timeDiff.inSeconds < 300) {
            AppLogger.d('Using cached location (${timeDiff.inSeconds}s old)');
            return lastPosition;
          }
        }
      }

      // Use MEDIUM accuracy for faster results (better for geofencing tests)
      AppLogger.d('Fetching fresh location with MEDIUM accuracy...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      AppLogger.d(
        'Location acquired: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      AppLogger.e('Error getting location: $e');
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
      // Get location with refresh for accurate geofence validation
      final userPosition = await getCurrentLocation(forceRefresh: true);

      if (userPosition == null) {
        return GeofenceCheckResult(
          isWithinGeofence: false,
          distanceMeters: null,
          errorMessage:
              'Unable to get current location. Please enable location services and grant permissions.',
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

// ── Location permission dialogs ───────────────────────────────────────────────

/// Shown before the OS permission prompt when permission is `denied`.
/// Explains WHY location is collected and how data flows before the user
/// decides whether to grant access.
class _LocationRationaleDialog extends StatelessWidget {
  const _LocationRationaleDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.location_on_outlined,
                color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Location Access', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TrekScan+ uses your location to:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            SizedBox(height: 12),
            _BulletRow(
              icon: Icons.explore_outlined,
              text:
                  'Verify you are physically at a trail station before marking it as visited.',
            ),
            SizedBox(height: 8),
            _BulletRow(
              icon: Icons.map_outlined,
              text:
                  'Compare your position against Mt. Hamiguitan trail coordinates stored on-device — no live GPS upload occurs.',
            ),
            SizedBox(height: 8),
            _BulletRow(
              icon: Icons.cloud_sync_outlined,
              text:
                  'Sync only your visited-stations list and trek progress to Firestore — raw GPS coordinates are never stored in the cloud.',
            ),
            SizedBox(height: 16),
            Text(
              'Location is read once per station scan and is not tracked continuously in the background.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not Now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Allow Location'),
        ),
      ],
    );
  }
}

/// Shown when permission is `deniedForever` — prompts the user to open
/// system settings since the OS will no longer show a permission dialog.
class _LocationSettingsDialog extends StatelessWidget {
  const _LocationSettingsDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.location_off_outlined, color: Colors.orange),
          SizedBox(width: 10),
          Text('Location Blocked', style: TextStyle(fontSize: 17)),
        ],
      ),
      content: const Text(
        'Location permission was previously denied. To enable station check-ins, please open Settings and grant location access to TrekScan+.',
        style: TextStyle(fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Open Settings'),
        ),
      ],
    );
  }
}

class _BulletRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BulletRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }
}
