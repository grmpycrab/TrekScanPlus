import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/color.dart';
import '../../services/station_service.dart';
import '../../services/geofencing_service.dart';
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
  late StationService stationService;
  bool _isLoading = true;
  String? _lastScannedCode;
  DateTime? _lastScanTime;

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
      stationService = await StationService.init();
      await stationService.loadStations(); // Load station data
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

  void _showGeofenceFailureDialog(
    BuildContext context,
    dynamic station,
    GeofenceCheckResult result,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Verification Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are too far from ${station.name} to scan this QR code.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Distance: ${GeofencingService.formatDistance(result.distanceMeters ?? 0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Required: ${GeofencingService.formatDistance(GeofencingService.GEOFENCE_RADIUS_METERS)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This geofence requirement ensures you are physically at the station location to verify authentic visits.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Continue scanning
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text(
              'Try Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
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
              if (capture.barcodes.isEmpty) return;

              final code = capture.barcodes.first.rawValue;
              if (code == null) return;

              // Debounce: Ignore if same code scanned within 2 seconds
              final now = DateTime.now();
              if (_lastScannedCode == code &&
                  _lastScanTime != null &&
                  now.difference(_lastScanTime!).inSeconds < 2) {
                return;
              }

              // Update last scanned info
              _lastScannedCode = code;
              _lastScanTime = now;

              final station = stationService.getStationById(code);

              if (station != null) {
                // Check geofence before allowing scan completion
                if (station.latitude != null && station.longitude != null) {
                  final geofenceResult = await GeofencingService.checkGeofence(
                    stationLat: station.latitude!,
                    stationLng: station.longitude!,
                    radiusMeters: GeofencingService.GEOFENCE_RADIUS_METERS,
                  );

                  if (!mounted) return;

                  if (!geofenceResult.isWithinGeofence) {
                    // User is outside geofence - show warning dialog
                    _showGeofenceFailureDialog(
                      context,
                      station,
                      geofenceResult,
                    );
                    // Reset scan tracking to allow retry
                    _lastScannedCode = null;
                    _lastScanTime = null;
                    return;
                  }
                }

                // Mark station as visited and save
                await stationService.updateStationVisited(code, true);

                if (!mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StationDetailScreen(station: station),
                  ),
                );

                // Reset scan tracking after successful navigation
                _lastScannedCode = null;
                _lastScanTime = null;
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid QR code - Station not found'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
                // Only allow retry after 2 seconds for invalid codes
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
                    color: AppColors.iconPrimary,
                    size: 28,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    IconButton(
                      icon: Image.asset(
                        'assets/icons/switch-camera.png',
                        width: 24,
                        height: 24,
                        color: AppColors.iconPrimary,
                      ),
                      onPressed: () {
                        // handle siwtch camera
                        controller?.switchCamera();
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: AppColors.iconPrimary,
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
                    color: AppColors.buttonText,
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
