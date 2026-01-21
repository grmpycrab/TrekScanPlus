import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/color.dart';
import '../../services/station_service.dart';
import '../../services/climb_session_service.dart';
//import '../../services/geofencing_service.dart';
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
              debugPrint('Scanner started successfully');
            },
            onDetect: (capture) async {
              try {
                final List<Barcode> barcodes = capture.barcodes;

                for (final barcode in barcodes) {
                  final String? rawValue = barcode.rawValue;

                  if (rawValue == null || rawValue.isEmpty) {
                    continue;
                  }

                  final StationData? station = StationService.instance
                      .getStationById(rawValue);

                  if (station != null) {
                    try {
                      await StationService.instance.updateStationVisited(
                        station.id,
                        true,
                      );
                    } catch (e) {
                      // Station marking failed but continue
                    }

                    if (!ClimbSessionService.isInitialized) {
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

                    if (activeSession != null &&
                        activeSession.status == 'ongoing') {
                      final isStationInSession = activeSession.visitedStations
                          .any((visit) => visit.stationId == station.id);

                      if (!isStationInSession) {
                        activeSession.addVisitedStation(station);
                      }

                      if (mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                StationDetailScreen(station: station),
                          ),
                        );
                      }
                    } else {
                      final newSession = await ClimbSessionService.instance
                          .createClimbSession(
                            name: station.name,
                            description: station.description,
                            trekType: 'regular_trek',
                          );
                      newSession.addVisitedStation(station);

                      if (mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                StationDetailScreen(station: station),
                          ),
                        );
                      }
                    }

                    return;
                  }
                }
              } catch (e) {
                try {
                  await controller?.start();
                } catch (e2) {
                  // Camera restart failed
                }
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
