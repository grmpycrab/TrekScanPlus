import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/color.dart';
import '../../services/station_service.dart';
import '../../services/climb_session_service.dart';
import '../../services/geofencing_service.dart';
import '../../services/achievement_service.dart';
import '../../models/station_data.dart';
//import '../../components/achievement_notification.dart';
import 'station_detail_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? controller;
  bool isFlashOn = false;
  bool hasPermission = false;
  late AchievementService achievementService;
  bool _isLoading = true;
  bool _geofencingEnabled = true; // Tap location icon to toggle
  bool _isProcessingQR = false; // Prevent duplicate QR processing

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    final status = await Permission.camera.request();
    setState(() {
      hasPermission = status.isGranted;
    });

    if (hasPermission) {
      controller = MobileScannerController();
      achievementService = AchievementService();

      // Ensure StationService is loaded
      if (!StationService.instance.isLoaded) {
        await StationService.instance.loadStations();
      }

      await achievementService.init(); // Initialize achievements

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeScanner();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPermission || _isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Camera permission is required',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _initializeScanner,
                  child: const Text('Grant Permission'),
                ),
            ],
          ),
        ),
      );
    }

    if (controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: controller!,
            errorBuilder: (context, error, child) {
              return Center(
                child: Text(
                  'Error initializing camera: $error',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
            onScannerStarted: (arguments) {
              debugPrint('✅ Scanner started successfully');
            },
            onDetect: (capture) async {
              // Prevent processing multiple QR detections simultaneously
              if (_isProcessingQR) {
                debugPrint('⏭️ Already processing QR, skipping...');
                return;
              }

              _isProcessingQR = true;

              try {
                final List<Barcode> barcodes = capture.barcodes;
                debugPrint(
                  '🔍 QR Detection triggered: ${barcodes.length} barcode(s) detected',
                );

                for (final barcode in barcodes) {
                  final String? rawValue = barcode.rawValue;
                  debugPrint(
                    '📱 Barcode detected - Type: ${barcode.format}, Value: $rawValue',
                  );

                  if (rawValue == null || rawValue.isEmpty) {
                    debugPrint('⚠️ Empty barcode value, skipping');
                    continue;
                  }

                  final StationData? station = StationService.instance
                      .getStationById(rawValue);

                  if (station != null) {
                    debugPrint(
                      '✅ Station found: ${station.name} (ID: ${station.id})',
                    );

                    debugPrint('🔄 Attempting to mark station as visited...');
                    // Fire and forget - don't wait for Firestore update
                    // This prevents hanging when offline
                    StationService.instance
                        .updateStationVisited(station.id, true)
                        .then((_) => debugPrint('✅ Station marked as visited'))
                        .catchError(
                          (e) => debugPrint(
                            '⚠️ Error updating station visited: $e',
                          ),
                        );

                    debugPrint(
                      '🧗 ClimbSessionService.isInitialized: ${ClimbSessionService.isInitialized}',
                    );

                    if (!ClimbSessionService.isInitialized) {
                      debugPrint(
                        '❌ Service NOT initialized, showing snackbar and returning',
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Service not initialized. Please restart.',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    final activeSession = ClimbSessionService.instance
                        .getActiveSession();
                    debugPrint(
                      '🧗 Active session: ${activeSession?.id ?? "None"}',
                    );

                    if (activeSession != null &&
                        activeSession.status == 'ongoing') {
                      debugPrint('✅ Using existing active session');
                      final isStationInSession = activeSession.visitedStations
                          .any((visit) => visit.stationId == station.id);

                      if (!isStationInSession) {
                        activeSession.addVisitedStation(station);
                      }

                      // Check geofencing if enabled - navigate only if validated
                      if (_geofencingEnabled &&
                          station.latitude != null &&
                          station.longitude != null) {
                        debugPrint(
                          '🔍 Geofencing enabled, verifying location...',
                        );
                        try {
                          final geofenceResult =
                              await GeofencingService.checkGeofence(
                                stationLat: station.latitude!,
                                stationLng: station.longitude!,
                                radiusMeters:
                                    GeofencingService.GEOFENCE_RADIUS_METERS,
                              ).timeout(
                                const Duration(seconds: 5),
                                onTimeout: () {
                                  debugPrint(
                                    '⏱️ Geofence check timed out after 5 seconds',
                                  );
                                  return GeofenceCheckResult(
                                    isWithinGeofence: false,
                                    distanceMeters: null,
                                    errorMessage:
                                        'Location check timed out. Try enabling location services.',
                                  );
                                },
                              );

                          if (geofenceResult.errorMessage != null) {
                            debugPrint(
                              '⚠️ Geofence error: ${geofenceResult.errorMessage}',
                            );
                          }

                          if (!geofenceResult.isWithinGeofence &&
                              geofenceResult.errorMessage == null &&
                              geofenceResult.distanceMeters != null) {
                            // Only block if we have a valid location and user is too far
                            debugPrint(
                              '❌ NOT within geofence. Distance: ${geofenceResult.distanceMeters?.toStringAsFixed(2) ?? "unknown"} meters',
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'You are too far from the station (${geofenceResult.distanceMeters?.toStringAsFixed(0) ?? "?"} meters away)',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }

                          if (geofenceResult.errorMessage != null) {
                            debugPrint(
                              '⚠️ Location unavailable - allowing scan for testing',
                            );
                          } else {
                            debugPrint(
                              '✅ Geofence verified! Distance: ${geofenceResult.distanceMeters?.toStringAsFixed(2) ?? "0"} meters',
                            );
                          }
                        } catch (e) {
                          debugPrint('❌ Error during geofence check: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not verify location: $e'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                          return;
                        }
                      }

                      // Geofencing passed or disabled - navigate
                      if (mounted) {
                        debugPrint('📱 Navigating to station detail screen...');
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                StationDetailScreen(station: station),
                          ),
                        );
                      }
                      return; // Exit after navigation
                    } else {
                      debugPrint('🚀 Creating new climb session...');
                      final newSession = await ClimbSessionService.instance
                          .createClimbSession(
                            name: station.name,
                            description: station.description,
                            trekType: 'regular_trek',
                          );
                      debugPrint('✅ Climb session created: ${newSession.id}');
                      newSession.addVisitedStation(station);

                      // Check geofencing if enabled - navigate only if validated
                      if (_geofencingEnabled &&
                          station.latitude != null &&
                          station.longitude != null) {
                        debugPrint(
                          '🔍 Geofencing enabled, verifying location...',
                        );
                        try {
                          final geofenceResult =
                              await GeofencingService.checkGeofence(
                                stationLat: station.latitude!,
                                stationLng: station.longitude!,
                                radiusMeters:
                                    GeofencingService.GEOFENCE_RADIUS_METERS,
                              ).timeout(
                                const Duration(seconds: 5),
                                onTimeout: () {
                                  debugPrint(
                                    '⏱️ Geofence check timed out after 5 seconds',
                                  );
                                  return GeofenceCheckResult(
                                    isWithinGeofence: false,
                                    distanceMeters: null,
                                    errorMessage:
                                        'Location check timed out. Try enabling location services.',
                                  );
                                },
                              );

                          if (geofenceResult.errorMessage != null) {
                            debugPrint(
                              '⚠️ Geofence error: ${geofenceResult.errorMessage}',
                            );
                          }

                          if (!geofenceResult.isWithinGeofence &&
                              geofenceResult.errorMessage == null &&
                              geofenceResult.distanceMeters != null) {
                            // Only block if we have a valid location and user is too far
                            debugPrint(
                              '❌ NOT within geofence. Distance: ${geofenceResult.distanceMeters?.toStringAsFixed(2) ?? "unknown"} meters',
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'You are too far from the station (${geofenceResult.distanceMeters?.toStringAsFixed(0) ?? "?"} meters away)',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }

                          if (geofenceResult.errorMessage != null) {
                            debugPrint(
                              '⚠️ Location unavailable - allowing scan for testing',
                            );
                          } else {
                            debugPrint(
                              '✅ Geofence verified! Distance: ${geofenceResult.distanceMeters?.toStringAsFixed(2) ?? "0"} meters',
                            );
                          }
                        } catch (e) {
                          debugPrint('❌ Error during geofence check: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not verify location: $e'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                          return;
                        }
                      }

                      // Geofencing passed or disabled - navigate
                      if (mounted) {
                        debugPrint('📱 Navigating to station detail screen...');
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                StationDetailScreen(station: station),
                          ),
                        );
                      }
                      return; // Exit after navigation
                    }
                  } else {
                    debugPrint('❌ Station NOT found for QR value: $rawValue');
                  }
                }
              } catch (e) {
                debugPrint('❌ CRITICAL ERROR in QR detection: $e');
                try {
                  await controller?.start();
                } catch (e2) {
                  debugPrint('❌ Camera restart failed: $e2');
                }
              } finally {
                _isProcessingQR = false;
              }
            },
          ),
          _buildOverlay(),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return CustomPaint(painter: ScannerOverlay(), child: Container());
  }

  Widget _buildControls() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // If there's a route to pop, pop it. Otherwise navigate back to main
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacementNamed('/main');
                    }
                  },
                  child: Icon(
                    Icons.arrow_back,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    // Geofencing toggle (testing only)
                    Tooltip(
                      message: _geofencingEnabled
                          ? 'Geofencing: ON'
                          : 'Geofencing: OFF',
                      child: IconButton(
                        icon: Icon(
                          _geofencingEnabled
                              ? Icons.location_on
                              : Icons.location_off,
                          color: _geofencingEnabled
                              ? AppColors.primary
                              : Colors.orange,
                        ),
                        onPressed: () {
                          setState(() {
                            _geofencingEnabled = !_geofencingEnabled;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Geofencing ${_geofencingEnabled ? 'enabled' : 'disabled'}',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: Image.asset(
                        'assets/icons/switch-camera.png',
                        width: 24,
                        height: 24,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        // handle siwtch camera
                        controller?.switchCamera();
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        controller?.toggleTorch();
                        setState(() {
                          isFlashOn = !isFlashOn;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.only(bottom: 32),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  controller?.stop();
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: SharedColors.white,
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    const cutOutSize = 300.0;
    final cutOutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cutOutSize,
      height: cutOutSize,
    );

    // Draw overlay with cutout
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(
          RRect.fromRectAndRadius(cutOutRect, const Radius.circular(12)),
        ),
      ),
      paint,
    );

    // Draw corners
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const length = 30.0;
    const padding = 4.0;

    // Top left corner
    canvas.drawLine(
      cutOutRect.topLeft.translate(padding, padding),
      cutOutRect.topLeft.translate(length + padding, padding),
      borderPaint,
    );
    canvas.drawLine(
      cutOutRect.topLeft.translate(padding, padding),
      cutOutRect.topLeft.translate(padding, length + padding),
      borderPaint,
    );

    // Top right corner
    canvas.drawLine(
      cutOutRect.topRight.translate(-padding, padding),
      cutOutRect.topRight.translate(-(length + padding), padding),
      borderPaint,
    );
    canvas.drawLine(
      cutOutRect.topRight.translate(-padding, padding),
      cutOutRect.topRight.translate(-padding, length + padding),
      borderPaint,
    );

    // Bottom left corner
    canvas.drawLine(
      cutOutRect.bottomLeft.translate(padding, -padding),
      cutOutRect.bottomLeft.translate(length + padding, -padding),
      borderPaint,
    );
    canvas.drawLine(
      cutOutRect.bottomLeft.translate(padding, -padding),
      cutOutRect.bottomLeft.translate(padding, -(length + padding)),
      borderPaint,
    );

    // Bottom right corner
    canvas.drawLine(
      cutOutRect.bottomRight.translate(-padding, -padding),
      cutOutRect.bottomRight.translate(-(length + padding), -padding),
      borderPaint,
    );
    canvas.drawLine(
      cutOutRect.bottomRight.translate(-padding, -padding),
      cutOutRect.bottomRight.translate(-padding, -(length + padding)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
