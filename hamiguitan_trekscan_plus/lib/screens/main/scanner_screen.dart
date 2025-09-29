import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/station_data.dart';
import '../../theme/color.dart';
import '../../services/station_service.dart';
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
      await StationService().initialize(); // Initialize station data
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
    if (!hasPermission) {
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

              final stationService = StationService();
              final station = await stationService.getStationById(code);

              if (station != null) {
                // Mark station as visited and save
                final updatedStation = StationData(
                  id: station.id,
                  name: station.name,
                  description: station.description,
                  difficulty: station.difficulty,
                  elevation: station.elevation,
                  coordinates: station.coordinates,
                  images: station.images,
                  metadata: station.metadata,
                  lastScanned: DateTime.now(),
                  steps: station.steps,
                  nextStationId: station.nextStationId,
                  flora: station.flora,
                  fauna: station.fauna,
                  warnings: station.warnings,
                  isCheckpoint: station.isCheckpoint,
                  isVisited: true,
                );

                await stationService.updateStation(updatedStation);

                if (!mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        StationDetailScreen(station: updatedStation),
                  ),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid QR code or station not found'),
                    backgroundColor: Colors.red,
                  ),
                );
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
                  onTap: () => Navigator.pop(context),
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
