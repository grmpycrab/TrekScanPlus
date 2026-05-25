import 'dart:async';
import 'dart:io';
import '../../utils/app_logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum ConnectionStatus { connecting, online, offline }

class ConnectivityService {
  ConnectivityService._internal();

  static final ConnectivityService instance = ConnectivityService._internal();

  final _controller = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _controller.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.connecting;
  ConnectionStatus get currentStatus => _currentStatus;

  StreamSubscription? _connectivitySub;

  /// Start listening to connectivity changes. Call this once during app init.
  void start() {
    // If already started, do nothing
    if (_connectivitySub != null) return;

    // Emit initial connecting status
    _updateStatus(ConnectionStatus.connecting);

    // Listen to platform connectivity changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      // For each connectivity event, verify actual internet access
      _verifyInternetAndEmit();
    });

    // Also do an initial verification
    _verifyInternetAndEmit();
  }

  Future<void> _verifyInternetAndEmit() async {
    // Immediately mark as connecting while we check
    _updateStatus(ConnectionStatus.connecting);

    try {
      // Try to lookup a reliable host
      final results = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 4));
      if (results.isNotEmpty && results.first.rawAddress.isNotEmpty) {
        _updateStatus(ConnectionStatus.online);
        return;
      }
      _updateStatus(ConnectionStatus.offline);
    } on TimeoutException catch (_) {
      _updateStatus(ConnectionStatus.offline);
    } on SocketException catch (_) {
      _updateStatus(ConnectionStatus.offline);
    } catch (e) {
      if (kDebugMode) AppLogger.i('Connectivity check error: $e');
      _updateStatus(ConnectionStatus.offline);
    }
  }

  void _updateStatus(ConnectionStatus status) {
    if (_currentStatus == status) return;
    _currentStatus = status;
    _controller.add(status);
  }

  // Cycles between simulated offline and the last real connectivity state.
  // Restricted to debug builds only; no-ops in release.
  bool _debugOfflineActive = false;
  bool get isDebugOfflineActive => _debugOfflineActive;

  void debugToggleOffline() {
    if (!kDebugMode) return;
    _debugOfflineActive = !_debugOfflineActive;
    _updateStatus(
      _debugOfflineActive ? ConnectionStatus.offline : ConnectionStatus.online,
    );
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _controller.close();
  }
}
