import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../theme/new_color.dart';
import '../../models/station_data.dart';

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

class _TrailMapState extends State<TrailMap> {
  late MapController _mapController;
  bool _isOnline = true;
  late final Connectivity _connectivity;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _connectivity = Connectivity();
    _checkConnectivity();
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
      debugPrint('Error checking connectivity: $e');
      if (mounted) {
        setState(() {
          _isOnline = true; // Assume online if check fails
        });
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Build trail polylines connecting all stations in order
  List<Polyline> _buildTrailPolylines() {
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
          // Determine color based on whether this segment is ahead or behind current station
          final isCompleted = _isStationBefore(currentStationData.id);
          final color = isCompleted ? Colors.green[300] : Colors.blue[400];

          polylines.add(
            Polyline(
              points: [
                LatLng(
                  currentStationData.latitude!,
                  currentStationData.longitude!,
                ),
                LatLng(nextStation.latitude!, nextStation.longitude!),
              ],
              color: color ?? Colors.blue,
              strokeWidth: 4.0,
              isDotted: !isCompleted, // Dotted line for upcoming trail
            ),
          );
        }
      }
    }

    return polylines;
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
      final isCompletedStation = _isStationBefore(station.id);

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
          child: Container(
            width: isCurrentStation ? 28 : 22,
            height: isCurrentStation ? 28 : 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrentStation
                  ? Colors.red
                  : isCompletedStation
                  ? Colors.green
                  : Colors.blue,
              border: Border.all(
                color: Colors.white,
                width: isCurrentStation ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isCurrentStation
                ? const Icon(Icons.location_on, color: Colors.white, size: 14)
                : Center(
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
                      _mapController.fitBounds(bounds);
                    }
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                                                  color: AppColors.textSecondary,
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
                          }).toList(),
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
                    _buildLegendItem(Colors.blue, 'Upcoming'),
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
