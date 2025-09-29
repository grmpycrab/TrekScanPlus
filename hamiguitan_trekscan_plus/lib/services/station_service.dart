import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station_data.dart';

class StationService {
  static const String VISITED_STATIONS_KEY = 'visited_stations';

  final SharedPreferences prefs;
  List<StationData> _stations = [];

  StationService._(this.prefs);

  static Future<StationService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StationService._(prefs);
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

        // Get visited station IDs from SharedPreferences
        Set<String> visitedStationIds =
            prefs.getStringList(VISITED_STATIONS_KEY)?.toSet() ?? {};
        print('Visited station IDs: $visitedStationIds');

        _stations = jsonList.map((json) => StationData.fromJson(json)).toList();
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
    // Update station in memory
    var station = _stations.firstWhere((s) => s.id == stationId);
    station.updateVisited(isVisited);

    // Update visited stations in SharedPreferences
    Set<String> visitedStationIds =
        prefs.getStringList(VISITED_STATIONS_KEY)?.toSet() ?? {};
    if (isVisited) {
      visitedStationIds.add(stationId);
    } else {
      visitedStationIds.remove(stationId);
    }
    await prefs.setStringList(VISITED_STATIONS_KEY, visitedStationIds.toList());
  }

  Future<void> resetAllStations() async {
    for (var station in _stations) {
      station.updateVisited(false);
    }
    await prefs.remove(VISITED_STATIONS_KEY);
  }

  StationData? getStationById(String id) {
    try {
      return _stations.firstWhere((station) => station.id == id);
    } catch (e) {
      return null;
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
}
