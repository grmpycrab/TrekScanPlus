import 'package:flutter/foundation.dart';

import '../../../models/station_data.dart';
import '../../../services/station_service.dart';
import '../../../utils/app_logger.dart';
import '../utils/station_image_path.dart';

// Station IDs where the trail ends (no further progress).
const Set<String> _kEndStationIds = {'i73hl7b7g3', 'r5kntj3sae', 'mr2l529okj'};

// Station IDs where the trail branches into multiple routes.
// Maps hub station ID → ordered list of first-station IDs on each branch.
// Exported so the screen's _buildBranchRoutesCard can reference branch labels
// via the ViewModel's branchNextStations list without importing this map.
const Map<String, List<String>> kBranchHubs = {
  'utvrrkfkh9': [
    '6mm4kle34g', // Pygmy Field → Mossy Forest → Tinagong Dagat → Hidden Garden
    'mr2l529okj', // Mt. Hamiguitan Summit
    '44r5tebjrc', // Black Mountain ↔ Twin Falls
  ],
};

/// ViewModel for the station detail screen.
///
/// Accepts [StationData] as a constructor arg (already loaded by the caller).
/// Computes pure derived values synchronously then loads supplementary route
/// data asynchronously via [initialize].
class StationDetailViewModel extends ChangeNotifier {
  final StationData station;

  // Computed once in constructor — pure, synchronous.
  late final List<String> imagePaths;
  late final String locationPrimary;
  late final String? locationSub;

  // Loaded asynchronously via initialize().
  List<StationData> allStations = [];
  StationData? nextStationData;
  List<StationData> branchNextStations = [];

  // -------------------------------------------------------------------------
  // Derived convenience getters used by the screen's build logic
  // -------------------------------------------------------------------------

  bool get isEndStation => _kEndStationIds.contains(station.id);
  List<String> get branchIds => kBranchHubs[station.id] ?? [];

  bool get hasRouteSection =>
      allStations.isNotEmpty ||
      station.nextStationId != null ||
      isEndStation ||
      branchIds.isNotEmpty;

  bool get hasNext =>
      station.nextStationId != null || isEndStation || branchIds.isNotEmpty;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------

  StationDetailViewModel(this.station) {
    imagePaths = station.images
        .map(stationImageAssetPath)
        .toList(growable: false);

    final dmsLine = _computeDmsLine();
    final decLine = _computeDecimalLine();
    locationPrimary = dmsLine ?? decLine ?? station.coordinates.trim();
    locationSub = (dmsLine != null && decLine != null) ? decLine : null;
  }

  // -------------------------------------------------------------------------
  // Async init
  // -------------------------------------------------------------------------

  Future<void> initialize() async {
    try {
      if (!StationService.instance.isLoaded) {
        await StationService.instance.loadStations();
      }

      final loaded = StationService.instance.getAllStations();
      final next = station.nextStationId != null
          ? StationService.instance.getStationById(station.nextStationId!)
          : null;
      final branches = branchIds
          .map(StationService.instance.getStationById)
          .whereType<StationData>()
          .toList();

      allStations = loaded;
      nextStationData = next;
      branchNextStations = branches;
      notifyListeners();
    } catch (e) {
      AppLogger.e('StationDetailViewModel.initialize error: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Coordinate helpers — called once in constructor
  // -------------------------------------------------------------------------

  String? _computeDmsLine() {
    final c = station.coordinates;
    final n = RegExp(
      r"N:\s*(\d+)°(\d+)'([\d.]+)''",
      caseSensitive: false,
    ).firstMatch(c);
    final e = RegExp(
      r"E:\s*(\d+)°(\d+)'([\d.]+)''",
      caseSensitive: false,
    ).firstMatch(c);
    if (n != null && e != null) {
      return '${n[1]}° ${n[2]}′ ${n[3]}″ N · ${e[1]}° ${e[2]}′ ${e[3]}″ E';
    }
    return null;
  }

  String? _computeDecimalLine() {
    final lat = station.latitude;
    final lng = station.longitude;
    if (lat == null || lng == null) return null;
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(5)}° $ns, '
        '${lng.abs().toStringAsFixed(5)}° $ew';
  }
}
