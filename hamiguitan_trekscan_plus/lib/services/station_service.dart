import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/station_data.dart';

class StationService {
  // Singleton pattern
  static final StationService _instance = StationService._internal();
  factory StationService() => _instance;
  StationService._internal();

  // In-memory cache of station data
  Map<String, StationData> _stations = {};

  // Initialize with local data
  Future<void> initialize() async {
    try {
      // Load data from local JSON file
      final String jsonString = await rootBundle.loadString(
        'assets/data/stations.json',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      _stations = Map.fromEntries(
        (jsonData['stations'] as List).map((station) {
          final stationData = StationData.fromJson(station);
          return MapEntry(stationData.id, stationData);
        }),
      );
    } catch (e) {
      print('Error loading station data: $e');
      // Load fallback data
      _loadFallbackData();
    }
  }

  // Get station by QR code key
  Future<StationData?> getStationById(String id) async {
    // First check local cache
    if (_stations.containsKey(id)) {
      return _stations[id];
    }

    // In a real app, you might want to fetch from an API here
    // if the station isn't found locally
    return null;
  }

  // Update station data
  Future<void> updateStation(StationData updatedStation) async {
    _stations[updatedStation.id] = updatedStation;
    // In a real app, you would also persist this to storage or API
  }

  // Get all visited stations
  List<StationData> getVisitedStations() {
    return _stations.values.where((station) => station.isVisited).toList();
  }

  // Get all unvisited stations
  List<StationData> getUnvisitedStations() {
    return _stations.values.where((station) => !station.isVisited).toList();
  }

  // Fallback data in case local JSON fails to load
  void _loadFallbackData() {
    _stations = {
      'hu2c5c0kfn': StationData(
        id: 'hu2c5c0kfn',
        name: 'UNESCO Marker Entry Point',
        description:
            'The gateway to Mt. Hamiguitan Range Wildlife Sanctuary, '
            'marked by the UNESCO World Heritage Site marker. This is where your '
            'journey begins, and you\'ll need to register and meet your guide here.',
        difficulty: 'Easy',
        elevation: 449,
        coordinates: 'N:06°44\'10.65\'\' E:126°08\'29.99\'\'',
        images: ['assets/stations/entry_point.jpg'],
        isCheckpoint: true,
        warnings: {
          'registration': 'Must register at the ranger station',
          'guide': 'Required to have a guide before proceeding',
        },
      ),
      'x9ab3dksl1': StationData(
        id: 'x9ab3dksl1',
        name: 'Mossy-Pygmy Forest',
        description:
            'A unique ecosystem featuring stunted trees covered in moss. '
            'The trees here have adapted to the ultramafic soil conditions, '
            'resulting in their distinctive dwarf appearance.',
        difficulty: 'Difficult',
        elevation: 1214,
        coordinates: 'N:06°43\'12.97\'\' E:126°11\'00.22\'\'',
        images: ['assets/stations/mossy_forest.jpg'],
        flora: [
          'Nepenthes hamiguitanensis',
          'Dwarf trees',
          'Various moss species',
        ],
        fauna: [
          'Philippine Eagle (occasionally sighted)',
          'Endemic butterflies',
        ],
        steps: 1595,
        isCheckpoint: true,
      ),
      'p7yx2mnsw4': StationData(
        id: 'p7yx2mnsw4',
        name: 'Tinagong Dagat',
        description:
            'Also known as the "Hidden Sea," this area offers a '
            'spectacular view of the surrounding landscape. On clear days, '
            'you can see both the Pacific Ocean and Davao Gulf.',
        difficulty: 'Difficult',
        elevation: 1108,
        coordinates: 'N:06°42\'27.55\'\' E:126°11\'43.11\'\'',
        images: ['assets/stations/tinagong_dagat.jpg'],
        steps: 8895,
        warnings: {
          'weather': 'Check weather conditions before proceeding',
          'hydration': 'Ensure adequate water supply',
        },
        metadata: {
          'viewingSpots': ['North View', 'South View', 'Ocean View'],
          'restArea': true,
          'waterSource': false,
        },
      ),
      'k4wd8vbth9': StationData(
        id: 'k4wd8vbth9',
        name: 'Peak',
        description:
            'The summit of Mt. Hamiguitan stands at 1,641 meters above '
            'sea level. The peak offers a 360-degree view of the surrounding '
            'landscape and is often shrouded in clouds.',
        difficulty: 'Difficult',
        elevation: 1641,
        coordinates: 'N:06°44\'23.90\'\' E:126°10\'55.25\'\'',
        images: ['assets/stations/peak.jpg'],
        steps: 6342,
        isCheckpoint: true,
        warnings: {
          'weather': 'Be cautious of sudden weather changes',
          'exposure': 'Limited shelter available',
        },
        metadata: {
          'summitLog': true,
          'shelterType': 'basic',
          'signalStrength': 'moderate',
        },
      ),
    };
  }
}
