import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station_data.dart';
import 'geofencing_service.dart';
import 'firestore_station_service.dart';
import 'e_certificate_service.dart';
import '../../utils/app_logger.dart';

class StationService extends ChangeNotifier {
  static const String VISITED_STATIONS_KEY = 'visited_stations';
  static StationService? _instance;

  final SharedPreferences prefs;
  List<StationData> _stations = [];
  String? _currentUserId;
  bool _isLoaded = false;
  bool _isLoading = false;
  String? _loadError;

  StationService._(this.prefs, {String? userId}) : _currentUserId = userId;

  /// Get singleton instance
  static StationService get instance {
    if (_instance == null) {
      throw StateError('StationService not initialized. Call init() first.');
    }
    return _instance!;
  }

  /// Check if instance is initialized
  static bool get isInitialized => _instance != null;

  /// Get loading state
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  /// Get the key for visited stations scoped to current user
  String get _userVisitedStationsKey {
    if (_currentUserId == null) return VISITED_STATIONS_KEY;
    return '${VISITED_STATIONS_KEY}_$_currentUserId';
  }

  /// Get the key for QR codes scoped to current user
  String _getUserQRKey(String stationId) {
    if (_currentUserId == null) return 'qr_key_$stationId';
    return 'qr_key_${_currentUserId}_$stationId';
  }

  static Future<StationService> init({String? userId}) async {
    if (_instance != null) {
      if (userId != null) {
        _instance!.setCurrentUser(userId);
      }
      return _instance!;
    }

    final prefs = await SharedPreferences.getInstance();
    _instance = StationService._(prefs, userId: userId);
    return _instance!;
  }

  /// Update the current user ID (call this when user changes)
  void setCurrentUser(String? userId) {
    _currentUserId = userId;
  }

  Future<List<StationData>> loadStations() async {
    // Return immediately if already loaded
    if (_isLoaded) {
      return List.unmodifiable(_stations);
    }

    // If already loading, wait for completion
    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return List.unmodifiable(_stations);
    }

    _isLoading = true;
    _loadError = null;
    notifyListeners();

    if (_stations.isEmpty) {
      try {
        // Load stations data
        String jsonString = await rootBundle.loadString(
          'assets/data/stations_test.json',
        );
        AppLogger.i(
          'Successfully loaded JSON string: ${jsonString.substring(0, 100)}...',
        );
        List<dynamic> jsonList = json.decode(jsonString);
        AppLogger.i('Number of stations in JSON: ${jsonList.length}');

        // Get visited station IDs from SharedPreferences (user-scoped)
        Set<String> visitedStationIds =
            prefs.getStringList(_userVisitedStationsKey)?.toSet() ?? {};
        AppLogger.i('Visited station IDs: $visitedStationIds');

        // Sync with Firebase if user is logged in
        try {
          final firebaseVisitedIds = await FirestoreStationService.instance
              .getVisitedStationIds();
          visitedStationIds.addAll(firebaseVisitedIds);
          AppLogger.i(
            'Synced ${firebaseVisitedIds.length} stations from Firebase',
          );
        } catch (e) {
          AppLogger.i(
            'Info: Firebase sync skipped (user may not be logged in): $e',
          );
        }

        _stations = jsonList.map((json) {
          var station = StationData.fromJson(json);

          // Check if lat/lng are provided in JSON, otherwise try to parse from coordinates
          if (station.latitude == null || station.longitude == null) {
            AppLogger.i(
              'Station ${station.id} missing lat/lng, attempting to parse from coordinates: ${station.coordinates}',
            );
            final coords = GeofencingService.parseCoordinates(
              station.coordinates,
            );
            if (coords != null) {
              station = StationData(
                id: station.id,
                name: station.name,
                description: station.description,
                difficulty: station.difficulty,
                elevation: station.elevation,
                coordinates: station.coordinates,
                images: station.images,
                latitude: coords['latitude'],
                longitude: coords['longitude'],
                metadata: station.metadata,
                lastScanned: station.lastScanned,
                steps: station.steps,
                nextStationId: station.nextStationId,
                nextStationName: station.nextStationName,
                distanceToNextKm: station.distanceToNextKm,
                flora: station.flora,
                fauna: station.fauna,
                warnings: station.warnings,
                isCheckpoint: station.isCheckpoint,
                isVisited: station.isVisited,
              );
              AppLogger.i(
                'Successfully parsed coordinates for ${station.id}: (${station.latitude}, ${station.longitude})',
              );
            } else {
              AppLogger.i('Failed to parse coordinates for ${station.id}');
            }
          } else {
            AppLogger.i(
              'Station ${station.id} has lat/lng from JSON: (${station.latitude}, ${station.longitude})',
            );
          }
          return station;
        }).toList();
        AppLogger.i(
          'Number of stations loaded into memory: ${_stations.length}',
        );

        // Update visited status
        for (var station in _stations) {
          if (visitedStationIds.contains(station.id)) {
            station.updateVisited(true);
          }
        }
      } catch (e) {
        AppLogger.i('Error loading station data: $e');
        AppLogger.i('Stack trace: ${StackTrace.current}');
        _stations = [];
        _loadError = e.toString();
      } finally {
        _isLoaded = true;
        _isLoading = false;
        notifyListeners();
      }
    } else {
      _isLoaded = true;
      _isLoading = false;
    }
    return List.unmodifiable(_stations);
  }

  Future<void> updateStationVisited(String stationId, bool isVisited) async {
    try {
      // Find the station by ID or temporary ID
      var station = _stations.firstWhere(
        (s) =>
            s.id == stationId ||
            (s.id.startsWith('stn') && s.id.substring(3) == stationId),
      );

      // Update station in memory
      station.updateVisited(isVisited);

      // Store both the actual ID and QR code (if different)
      Set<String> visitedStationIds =
          prefs.getStringList(VISITED_STATIONS_KEY)?.toSet() ?? {};

      if (isVisited) {
        visitedStationIds.add(station.id);
        // If this is a QR code different from station.id, store it too
        if (stationId != station.id) {
          await prefs.setString(_getUserQRKey(station.id), stationId);
        }
      } else {
        visitedStationIds.remove(station.id);
        await prefs.remove(_getUserQRKey(station.id));
      }

      await prefs.setStringList(
        _userVisitedStationsKey,
        visitedStationIds.toList(),
      );

      // Sync with Firebase Firestore
      try {
        if (isVisited) {
          await FirestoreStationService.instance.saveVisitedStation(station);
        } else {
          await FirestoreStationService.instance.removeVisitedStation(
            station.id,
          );
        }
      } catch (firestoreError) {
        AppLogger.i('Warning: Failed to sync with Firestore: $firestoreError');
        // Don't rethrow - local update was successful
      }

      // Check and award e-certificates when station is visited (Phase 1)
      if (isVisited) {
        try {
          final certificateService = ECertificateService.instance;
          final visitedStations = getVisitedStations();

          final awardedCertificate = await certificateService
              .checkAndAwardCertificate(visitedStations);

          if (awardedCertificate != null) {
            AppLogger.i(
              'Certificate awarded: ${awardedCertificate.certificateType.name}',
            );
            // TODO: Trigger UI notification/dialog to show certificate earned
            // This will be implemented in Phase 2 (UI phase)
          }
        } catch (certificateError) {
          AppLogger.i(
            'Warning: Failed to check certificate eligibility: $certificateError',
          );
          // Don't rethrow - this is non-critical
        }
      }
    } catch (e) {
      AppLogger.i('Error updating station visited status: $e');
      rethrow;
    }
  }

  Future<void> resetAllStations() async {
    for (var station in _stations) {
      station.updateVisited(false);
    }
    await prefs.remove(_userVisitedStationsKey);
    // Also clear QR codes for current user
    if (_currentUserId != null) {
      final keysToRemove = prefs
          .getKeys()
          .where((key) => key.startsWith('qr_key_${_currentUserId}_'))
          .toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
    }

    // Reset in Firebase as well
    try {
      await FirestoreStationService.instance.resetAllVisitedStations();
    } catch (e) {
      AppLogger.i('Warning: Failed to reset visited stations in Firestore: $e');
      // Don't rethrow - local reset was successful
    }
  }

  StationData? getStationById(String id) {
    try {
      // First try to find by exact ID
      return _stations.firstWhere((station) => station.id == id);
    } catch (e) {
      try {
        // Check the metadata for alternative keys
        return _stations.firstWhere((station) {
          // Check if the station has metadata with alternative keys
          if (station.metadata.containsKey('altKeys')) {
            List<String> altKeys = List<String>.from(
              station.metadata['altKeys'],
            );
            return altKeys.contains(id);
          }
          return false;
        });
      } catch (e) {
        try {
          // If still not found and the ID starts with 'stn', try to match by number
          if (id.startsWith('stn')) {
            return _stations.firstWhere((s) => s.id == id);
          }
        } catch (e) {
          // Ignore and return null
        }
        return null;
      }
    }
  }

  List<StationData> getAllStations() {
    return List.unmodifiable(_stations);
  }

  List<StationData> getVisitedStations() {
    return _stations.where((station) => station.isVisited).toList();
  }

  List<StationData> getUnvisitedStations() {
    return _stations.where((station) => !station.isVisited).toList();
  }

  /// Calculate total distance based on visited stations
  /// Camp 3 (Station 8) is a central hub with three routes:
  /// Route A: Camp 3 → Pygmy Field → Lantawan 3 → Tinagong Dagat → Hidden Garden
  /// Route B: Camp 3 → Black Mountain ↔ Twin Falls (bidirectional)
  /// Route C: Camp 3 → Peak
  double getTotalDistance() {
    final visitedStations = getVisitedStations();
    if (visitedStations.isEmpty) return 0.0;

    final stationMap = {for (var s in _stations) s.id: s};
    final visitedIds = visitedStations.map((s) => s.id).toSet();

    // Calculate base distance: Station 1 → Camp 3 (sequential)
    double baseDistance = 0.0;
    const camp3Id = 'utvrrkfkh9'; // Station 8: Camp 3

    var currentId = '56okrkt0pb'; // Station 1: UNESCO Marker
    while (currentId != camp3Id) {
      final current = stationMap[currentId];
      if (current == null || current.nextStationId == null) break;

      if (current.distanceToNextKm != null) {
        baseDistance += current.distanceToNextKm!;
      }
      currentId = current.nextStationId!;
    }

    // Define the three routes from Camp 3
    final routeA = [
      '6mm4kle34g', // Station 9: Pygmy Field
      'g5uabiveqd', // Station 10/11: Lantawan 3 / Mossy Forest
      '79t42cmo77', // Station 12: Tinagong Dagat
      'i73hl7b7g3', // Station 13: Hidden Garden
    ];

    final routeB = [
      '44r5tebjrc', // Station 15: Black Mountain
      'r5kntj3sae', // Station 16: Twin Falls
    ];

    final routeC = [
      'mr2l529okj', // Station 14: Peak
    ];

    // Calculate distance for each route taken
    double routeDistances = 0.0;

    // Check Route A (sequential path from Camp 3)
    if (routeA.any((id) => visitedIds.contains(id))) {
      double routeADistance = 0.0;
      var prevId = camp3Id;

      for (final stationId in routeA) {
        if (visitedIds.contains(stationId)) {
          final prevStation = stationMap[prevId];
          if (prevStation?.distanceToNextKm != null) {
            routeADistance += prevStation!.distanceToNextKm!;
          }
          prevId = stationId;
        } else {
          break; // Stop if we hit an unvisited station
        }
      }
      routeDistances = routeADistance > routeDistances
          ? routeADistance
          : routeDistances;
    }

    // Check Route B (Black Mountain ↔ Twin Falls)
    if (routeB.any((id) => visitedIds.contains(id))) {
      double routeBDistance = 0.0;

      // Distance from Camp 3 to first visited station in Route B
      if (visitedIds.contains('44r5tebjrc')) {
        // Black Mountain
        final peakStation =
            stationMap['mr2l529okj']; // Peak has distance to Black Mountain
        if (peakStation?.distanceToNextKm != null) {
          routeBDistance +=
              peakStation!.distanceToNextKm!; // 4.9 km to Black Mountain
        }

        // If Twin Falls is also visited, add distance between them
        if (visitedIds.contains('r5kntj3sae')) {
          final blackMtnStation = stationMap['44r5tebjrc'];
          if (blackMtnStation?.distanceToNextKm != null) {
            routeBDistance +=
                blackMtnStation!.distanceToNextKm!; // 1.3 km to Twin Falls
          }
        }
      } else if (visitedIds.contains('r5kntj3sae')) {
        // Only Twin Falls visited
        // Assume same path through Black Mountain
        final peakStation = stationMap['mr2l529okj'];
        final blackMtnStation = stationMap['44r5tebjrc'];
        if (peakStation?.distanceToNextKm != null &&
            blackMtnStation?.distanceToNextKm != null) {
          routeBDistance +=
              peakStation!.distanceToNextKm! +
              blackMtnStation!.distanceToNextKm!;
        }
      }
      routeDistances = routeBDistance > routeDistances
          ? routeBDistance
          : routeDistances;
    }

    // Check Route C (Peak)
    if (routeC.any((id) => visitedIds.contains(id))) {
      double routeCDistance = 0.0;
      final hiddenGardenStation =
          stationMap['i73hl7b7g3']; // Hidden Garden has distance to Peak
      if (hiddenGardenStation?.distanceToNextKm != null) {
        routeCDistance =
            hiddenGardenStation!.distanceToNextKm!; // 4.9 km to Peak
      }
      routeDistances = routeCDistance > routeDistances
          ? routeCDistance
          : routeDistances;
    }

    // Return total: base distance + longest route taken from Camp 3
    return baseDistance + routeDistances;
  }

  /// Calculate total time spent trekking in minutes
  /// Based on the time between first and last scanned station
  int getTotalTimeMinutes() {
    final visitedStations = getVisitedStations();
    if (visitedStations.isEmpty) return 0;

    // Filter stations that have lastScanned timestamp
    final stationsWithTime = visitedStations
        .where((s) => s.lastScanned != null)
        .toList();

    if (stationsWithTime.isEmpty) return 0;

    // Sort by scan time
    stationsWithTime.sort((a, b) => a.lastScanned!.compareTo(b.lastScanned!));

    final firstScan = stationsWithTime.first.lastScanned!;
    final lastScan = stationsWithTime.last.lastScanned!;

    return lastScan.difference(firstScan).inMinutes;
  }

  /// Get trek start date (first scanned station)
  DateTime? getTrekStartDate() {
    final visitedStations = getVisitedStations();
    if (visitedStations.isEmpty) return null;

    final stationsWithTime = visitedStations
        .where((s) => s.lastScanned != null)
        .toList();

    if (stationsWithTime.isEmpty) return null;

    stationsWithTime.sort((a, b) => a.lastScanned!.compareTo(b.lastScanned!));
    return stationsWithTime.first.lastScanned;
  }

  /// Get trek end date (last scanned station)
  DateTime? getTrekEndDate() {
    final visitedStations = getVisitedStations();
    if (visitedStations.isEmpty) return null;

    final stationsWithTime = visitedStations
        .where((s) => s.lastScanned != null)
        .toList();

    if (stationsWithTime.isEmpty) return null;

    stationsWithTime.sort((a, b) => b.lastScanned!.compareTo(a.lastScanned!));
    return stationsWithTime.first.lastScanned;
  }

  Future<String?> getQRKeyForStation(String stationId) async {
    return prefs.getString(_getUserQRKey(stationId));
  }
}
