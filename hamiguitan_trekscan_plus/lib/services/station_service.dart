import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station_data.dart';
import 'geofencing_service.dart';
import 'firestore_station_service.dart';

class StationService {
  static const String VISITED_STATIONS_KEY = 'visited_stations';

  final SharedPreferences prefs;
  List<StationData> _stations = [];
  String? _currentUserId;

  StationService._(this.prefs, {String? userId}) : _currentUserId = userId;

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
    final prefs = await SharedPreferences.getInstance();
    return StationService._(prefs, userId: userId);
  }

  /// Update the current user ID (call this when user changes)
  void setCurrentUser(String? userId) {
    _currentUserId = userId;
  }

  Future<List<StationData>> loadStations() async {
    if (_stations.isEmpty) {
      try {
        // Load stations data
        String jsonString = await rootBundle.loadString(
          'assets/data/stations_test.json',
        );
        print(
          'Successfully loaded JSON string: ${jsonString.substring(0, 100)}...',
        );
        List<dynamic> jsonList = json.decode(jsonString);
        print('Number of stations in JSON: ${jsonList.length}');

        // Get visited station IDs from SharedPreferences (user-scoped)
        Set<String> visitedStationIds =
            prefs.getStringList(_userVisitedStationsKey)?.toSet() ?? {};
        print('Visited station IDs: $visitedStationIds');

        // Sync with Firebase if user is logged in
        try {
          final firebaseVisitedIds = await FirestoreStationService.instance
              .getVisitedStationIds();
          visitedStationIds.addAll(firebaseVisitedIds);
          print('Synced ${firebaseVisitedIds.length} stations from Firebase');
        } catch (e) {
          print('Info: Firebase sync skipped (user may not be logged in): $e');
        }

        _stations = jsonList.map((json) {
          var station = StationData.fromJson(json);

          // Check if lat/lng are provided in JSON, otherwise try to parse from coordinates
          if (station.latitude == null || station.longitude == null) {
            print(
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
              print(
                'Successfully parsed coordinates for ${station.id}: (${station.latitude}, ${station.longitude})',
              );
            } else {
              print('Failed to parse coordinates for ${station.id}');
            }
          } else {
            print(
              'Station ${station.id} has lat/lng from JSON: (${station.latitude}, ${station.longitude})',
            );
          }
          return station;
        }).toList();
        print('Number of stations loaded into memory: ${_stations.length}');

        // Update visited status
        for (var station in _stations) {
          if (visitedStationIds.contains(station.id)) {
            station.updateVisited(true);
          }
        }
      } catch (e) {
        print('Error loading station data: $e');
        print('Stack trace: ${StackTrace.current}');
        _stations = [];
      }
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
        print('Warning: Failed to sync with Firestore: $firestoreError');
        // Don't rethrow - local update was successful
      }
    } catch (e) {
      print('Error updating station visited status: $e');
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
      print('Warning: Failed to reset visited stations in Firestore: $e');
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

  Future<String?> getQRKeyForStation(String stationId) async {
    return prefs.getString(_getUserQRKey(stationId));
  }
}
