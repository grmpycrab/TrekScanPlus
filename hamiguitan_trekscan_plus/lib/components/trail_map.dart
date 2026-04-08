// ignore_for_file: use_key_in_widget_constructors, deprecated_member_use, use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/app_logger.dart';
import '../../theme/new_color.dart';
import '../../models/station_data.dart';

/// A named section of the trail. Camp 3 is the hub where the trail branches
/// into separate segments; each is represented as an independent instance.
class _TrailSegment {
  final String id;
  final List<String> stationIds;
  final List<LatLng> path;

  const _TrailSegment({
    required this.id,
    required this.stationIds,
    required this.path,
  });
}

class TrailMap extends StatefulWidget {
  final StationData currentStation;
  final List<StationData> allStations;
  final double height;

  const TrailMap({
    super.key,
    required this.currentStation,
    required this.allStations,
    this.height = 300,
  });

  @override
  State<TrailMap> createState() => _TrailMapState();
}

class _TrailMapState extends State<TrailMap>
    with SingleTickerProviderStateMixin {
  late MapController _mapController;
  bool _isOnline = true;
  late final Connectivity _connectivity;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;
  List<_TrailSegment> _segments = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _connectivity = Connectivity();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.95,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(
      begin: 0.30,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _checkConnectivity();
    _loadTrailPath();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final isOnline =
          result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet);

      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }

      // Listen for connectivity changes
      _connectivity.onConnectivityChanged.listen((result) {
        if (mounted) {
          final connected =
              result.contains(ConnectivityResult.mobile) ||
              result.contains(ConnectivityResult.wifi) ||
              result.contains(ConnectivityResult.ethernet);
          setState(() {
            _isOnline = connected;
          });
        }
      });
    } catch (e) {
      AppLogger.e('Error checking connectivity: $e');
      if (mounted) {
        setState(() {
          _isOnline = true; // Assume online if check fails
        });
      }
    }
  }

  Future<void> _loadTrailPath() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/trail_path.json',
      );
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final segmentsData = data['segments'] as List<dynamic>;
      final segments = segmentsData.map((s) {
        final stationIds = (s['stationIds'] as List<dynamic>).cast<String>();
        final pathData = s['path'] as List<dynamic>;
        final path = pathData
            .map(
              (p) => LatLng(
                (p['lat'] as num).toDouble(),
                (p['lng'] as num).toDouble(),
              ),
            )
            .toList();
        return _TrailSegment(
          id: s['id'] as String,
          stationIds: stationIds,
          path: path,
        );
      }).toList();
      if (mounted) setState(() => _segments = segments);
    } catch (e) {
      AppLogger.e('Failed to load trail path: $e');
      // _segments stays empty — falls back to straight station-to-station lines
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Build trail polylines for the branching trail.
  /// Uses segments from trail_path.json when loaded, otherwise falls back
  /// to straight station-to-station lines.
  List<Polyline> _buildTrailPolylines() {
    if (_segments.isEmpty) {
      return _buildStraightPolylines();
    }

    // Identify the "active" segment — the one where the current station
    // appears at the highest index. This correctly resolves Camp 3:
    // it is the LAST entry of the main segment (index 7) but the FIRST
    // entry of every branch (index 0), so the main segment wins when the
    // trekker is at Camp 3. Branch segments win once the trekker enters them.
    int activeSegIdx = 0;
    int bestStationIdx = -1;
    for (int i = 0; i < _segments.length; i++) {
      final idx = _segments[i].stationIds.indexOf(widget.currentStation.id);
      if (idx > bestStationIdx) {
        bestStationIdx = idx;
        activeSegIdx = i;
      }
    }

    final visitedIds = widget.allStations
        .where((s) => s.isVisited)
        .map((s) => s.id)
        .toSet();

    final polylines = <Polyline>[];

    for (int i = 0; i < _segments.length; i++) {
      final seg = _segments[i];

      if (i == activeSegIdx) {
        // Split the active segment at the current station's closest point.
        final lat = widget.currentStation.latitude;
        final lng = widget.currentStation.longitude;
        int splitIdx = 0;
        if (lat != null && lng != null && seg.path.isNotEmpty) {
          final pt = LatLng(lat, lng);
          double bestDist = _sqDist(seg.path[0], pt);
          for (int j = 1; j < seg.path.length; j++) {
            final d = _sqDist(seg.path[j], pt);
            if (d < bestDist) {
              bestDist = d;
              splitIdx = j;
            }
          }
        }

        // Completed portion (before current position) — solid green.
        if (splitIdx > 0) {
          polylines.add(
            Polyline(
              points: seg.path.sublist(0, splitIdx + 1),
              color: Colors.green.shade500,
              strokeWidth: 5.0,
            ),
          );
        }

        // Current/upcoming portion — accent colour.
        if (splitIdx < seg.path.length - 1) {
          polylines.add(
            Polyline(
              points: seg.path.sublist(splitIdx),
              color: AppColors.accent,
              strokeWidth: 4.5,
            ),
          );
        }
      } else {
        // Non-active segment: green if its last station has been visited,
        // otherwise blue dotted (upcoming / not taken yet).
        final lastId = seg.stationIds.last;
        final isCompleted = visitedIds.contains(lastId);
        polylines.add(
          Polyline(
            points: seg.path,
            color: isCompleted ? Colors.green.shade500 : Colors.blue.shade400,
            strokeWidth: isCompleted ? 5.0 : 3.0,
            isDotted: !isCompleted,
          ),
        );
      }
    }

    return polylines;
  }

  /// Fallback: straight lines between each consecutive station pair.
  List<Polyline> _buildStraightPolylines() {
    final polylines = <Polyline>[];
    final stations = widget.allStations;

    // Connect stations in sequence based on nextStationId
    for (int i = 0; i < stations.length - 1; i++) {
      final currentStationData = stations[i];
      final nextStationId = currentStationData.nextStationId;

      if (nextStationId != null) {
        // Find the next station
        final nextStation = stations.firstWhere(
          (s) => s.id == nextStationId,
          orElse: () => currentStationData,
        );

        if (currentStationData.latitude != null &&
            currentStationData.longitude != null &&
            nextStation.latitude != null &&
            nextStation.longitude != null) {
          final isCompleted = _isStationBefore(currentStationData.id);
          final isCurrentSegment =
              currentStationData.id == widget.currentStation.id;

          final Color segmentColor;
          final double strokeWidth;
          final bool dotted;

          if (isCompleted) {
            segmentColor = Colors.green.shade500;
            strokeWidth = 5.0;
            dotted = false;
          } else if (isCurrentSegment) {
            segmentColor = AppColors.accent;
            strokeWidth = 4.5;
            dotted = false;
          } else {
            segmentColor = Colors.blue.shade400;
            strokeWidth = 3.0;
            dotted = true;
          }

          polylines.add(
            Polyline(
              points: [
                LatLng(
                  currentStationData.latitude!,
                  currentStationData.longitude!,
                ),
                LatLng(nextStation.latitude!, nextStation.longitude!),
              ],
              color: segmentColor,
              strokeWidth: strokeWidth,
              isDotted: dotted,
            ),
          );
        }
      }
    }

    return polylines;
  }

  /// Squared lat/lng distance (sufficient for closest-point lookup).
  double _sqDist(LatLng a, LatLng b) {
    final dlat = a.latitude - b.latitude;
    final dlng = a.longitude - b.longitude;
    return dlat * dlat + dlng * dlng;
  }

  /// Check if a station is before the current station in the trail
  bool _isStationBefore(String stationId) {
    final currentIndex = widget.allStations.indexWhere(
      (s) => s.id == widget.currentStation.id,
    );
    final stationIndex = widget.allStations.indexWhere(
      (s) => s.id == stationId,
    );

    return stationIndex < currentIndex;
  }

  /// Build station markers
  List<Marker> _buildStationMarkers() {
    return widget.allStations.map((station) {
      final isCurrentStation = station.id == widget.currentStation.id;
      final isVisitedStation = station.isVisited;

      if (station.latitude == null || station.longitude == null) {
        return Marker(point: LatLng(0, 0), child: Container());
      }

      return Marker(
        point: LatLng(station.latitude!, station.longitude!),
        child: GestureDetector(
          onTap: () {
            _mapController.move(
              LatLng(station.latitude!, station.longitude!),
              _mapController.camera.zoom,
            );
          },
          child: isCurrentStation
              ? AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: _pulseScale.value,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withValues(
                                  alpha: _pulseOpacity.value,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isVisitedStation ? Colors.green : Colors.blue,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
        ),
      );
    }).toList();
  }

  /// Calculate bounds to fit all stations
  LatLngBounds _calculateBounds() {
    final stations = widget.allStations
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();

    if (stations.isEmpty) {
      return LatLngBounds(LatLng(6.7, 126.1), LatLng(6.8, 126.2));
    }

    double minLat = stations[0].latitude!;
    double maxLat = stations[0].latitude!;
    double minLng = stations[0].longitude!;
    double maxLng = stations[0].longitude!;

    for (final station in stations) {
      minLat = station.latitude! < minLat ? station.latitude! : minLat;
      maxLat = station.latitude! > maxLat ? station.latitude! : maxLat;
      minLng = station.longitude! < minLng ? station.longitude! : minLng;
      maxLng = station.longitude! > maxLng ? station.longitude! : maxLng;
    }

    // Add padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _calculateBounds();

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (_isOnline)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  widget.currentStation.latitude ?? 6.73,
                  widget.currentStation.longitude ?? 126.14,
                ),
                initialZoom: 13,
                maxZoom: 18,
                minZoom: 10,
                onMapReady: () {
                  // Fit all stations in view
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted && _isOnline) {
                      _mapController.fitCamera(
                        CameraFit.bounds(
                          bounds: bounds,
                          padding: const EdgeInsets.fromLTRB(24, 64, 24, 110),
                        ),
                      );
                    }
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'hamiguitan_trekscan_plus',
                  tileSize: 256,
                  backgroundColor: Colors.transparent,
                  // Add proper headers to comply with OSM tile policy
                  additionalOptions: const {
                    'User-Agent':
                        'HamiguitanTrekScanPlus/1.0 (https://trekscanplus.app)',
                  },
                ),
                PolylineLayer(polylines: _buildTrailPolylines()),
                MarkerLayer(markers: _buildStationMarkers()),
              ],
            )
          else
            // Offline fallback UI with station list
            Container(
              color: Colors.grey[50],
              child: Column(
                children: [
                  // Offline banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      border: Border(
                        bottom: BorderSide(color: Colors.amber[300]!, width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off,
                          color: Colors.amber[700],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Offline Mode - Trail Map Unavailable',
                          style: TextStyle(
                            color: Colors.amber[900],
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stations list fallback
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trail Stations (Offline View)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...widget.allStations.asMap().entries.map((entry) {
                            final index = entry.key;
                            final station = entry.value;
                            final isCurrentStation =
                                station.id == widget.currentStation.id;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCurrentStation
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : AppColors.background,
                                border: Border.all(
                                  color: isCurrentStation
                                      ? Colors.red
                                      : AppColors.border,
                                  width: isCurrentStation ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCurrentStation
                                              ? Colors.red
                                              : Colors.grey[400],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              station.name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isCurrentStation
                                                    ? Colors.red
                                                    : Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (station.latitude != null &&
                                                station.longitude != null)
                                              Text(
                                                '${station.latitude!.toStringAsFixed(4)}, ${station.longitude!.toStringAsFixed(4)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isCurrentStation)
                                        Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Legend (only show when online)
          if (_isOnline)
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(Colors.red, 'You are here'),
                    const SizedBox(height: 8),
                    _buildLegendItem(Colors.green, 'Completed'),
                    const SizedBox(height: 8),
                    _buildLegendItem(Colors.blue, 'Not Visited'),
                  ],
                ),
              ),
            ),
          // Current location badge (only show when online)
          if (_isOnline)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      widget.currentStation.name.split(':')[0],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black87),
        ),
      ],
    );
  }
}
