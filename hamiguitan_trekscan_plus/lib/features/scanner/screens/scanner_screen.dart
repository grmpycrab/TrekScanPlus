import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';
import '../../../models/station_data.dart';
import '../viewmodels/scanner_view_model.dart';
import '../../stations/screens/station_detail_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  late final ScannerViewModel _vm;

  // MobileScannerController lives here because it is tightly coupled to the
  // MobileScanner widget lifecycle (stop/start around navigation, dispose
  // on widget disposal).
  MobileScannerController? _controller;

  // Flash state is pure UI — the controller owns the torch state, we only
  // mirror it here to drive the icon.
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm = ScannerViewModel();
    _vm.addListener(_onViewModelChanged);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initialize();
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    _vm.dispose();
    _controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> _initialize() async {
    // Dispose of any existing controller before creating a new one (e.g. on
    // app resume) to avoid resource leaks.
    _controller?.dispose();
    _controller = null;

    await _vm.initialize();

    if (!mounted) return;
    if (!_vm.permissionDenied) {
      setState(() {
        _controller = MobileScannerController();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // ViewModel listener
  // ---------------------------------------------------------------------------

  void _onViewModelChanged() {
    if (!mounted) return;

    // Geofence dialog: show when validating, dismiss when done.
    if (_vm.isValidatingGeofence) {
      _showGeofenceValidatingDialog();
    } else {
      _dismissGeofenceDialog();
    }

    // Consume pending error and show SnackBar.
    if (_vm.pendingError != null) {
      final err = _vm.pendingError!;
      _vm.clearError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.message),
          backgroundColor: err.isWarning ? Colors.orange : Colors.red,
        ),
      );
    }

    // Consume navigation request.
    if (_vm.stationToNavigate != null) {
      final station = _vm.stationToNavigate!;
      _vm.clearNavigationRequest();
      _navigateToStation(station);
    }

    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  void _showGeofenceValidatingDialog() {
    if (!mounted || !_vm.isValidatingGeofence) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Verifying location...',
                style: TextStyle(color: Colors.grey[300]),
              ),
            ],
          ),
        );
      },
    );
  }

  void _dismissGeofenceDialog() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation (kept in screen — requires BuildContext and controller pause)
  // ---------------------------------------------------------------------------

  /// Stops the camera, pushes the station detail screen,
  /// then restarts the camera when the user pops back.
  Future<void> _navigateToStation(StationData station) async {
    await _controller?.stop();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StationDetailScreen(station: station),
      ),
    );
    if (mounted) await _controller?.start();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_vm.permissionDenied || _vm.isLoading) {
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
              if (_vm.isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _initialize,
                  child: const Text('Grant Permission'),
                ),
            ],
          ),
        ),
      );
    }

    if (_controller == null) {
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
            controller: _controller!,
            errorBuilder: (context, error, child) {
              return Center(
                child: Text(
                  'Error initializing camera: $error',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
            onScannerStarted: (arguments) {
              AppLogger.i('Scanner started successfully');
            },
            onDetect: _vm.onDetect,
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
    final colors = context.colors;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacementNamed('/main');
                    }
                  },
                  child: Icon(
                    Icons.arrow_back,
                    color: colors.primary,
                    size: 28,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Tooltip(
                      message: _vm.geofencingEnabled
                          ? 'Geofencing: ON'
                          : 'Geofencing: OFF',
                      child: IconButton(
                        icon: Icon(
                          _vm.geofencingEnabled
                              ? Icons.location_on
                              : Icons.location_off,
                          color: _vm.geofencingEnabled
                              ? colors.primary
                              : Colors.orange,
                        ),
                        onPressed: () {
                          _vm.toggleGeofencing();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Geofencing ${_vm.geofencingEnabled ? 'enabled' : 'disabled'}',
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
                        color: colors.primary,
                      ),
                      onPressed: () => _controller?.switchCamera(),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: colors.primary,
                      ),
                      onPressed: () {
                        _controller?.toggleTorch();
                        setState(() => _isFlashOn = !_isFlashOn);
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
                onTap: () => _controller?.stop(),
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

// ---------------------------------------------------------------------------
// Custom painter — pure UI, stays in the screen file
// ---------------------------------------------------------------------------

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

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const length = 30.0;
    const padding = 4.0;

    // Top left
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

    // Top right
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

    // Bottom left
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

    // Bottom right
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
