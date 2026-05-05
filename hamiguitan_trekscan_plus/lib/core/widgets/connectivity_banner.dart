import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/connectivity_service.dart';

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  Timer? _hideTimer;
  bool _showBanner = false;
  ConnectionStatus? _lastStatus;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _showTemporarily() {
    _hideTimer?.cancel();

    if (mounted) {
      setState(() {
        _showBanner = true;
      });

      _hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showBanner = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectionStatus>(
      stream: ConnectivityService.instance.statusStream,
      initialData: ConnectivityService.instance.currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? ConnectionStatus.connecting;

        // Show banner when status changes
        if (status != _lastStatus) {
          _lastStatus = status;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTemporarily();
          });
        }

        final show = _showBanner;

        Color background;
        String message;

        switch (status) {
          case ConnectionStatus.connecting:
            message = 'Connecting...';
            background = Colors.grey.shade700;
            break;
          case ConnectionStatus.offline:
            message = 'Offline — check your connection';
            background = Colors.red.shade600;
            break;
          case ConnectionStatus.online:
            message = 'Online';
            background = Colors.green.shade600;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: show ? 36 : 0,
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Container(
                width: double.infinity,
                height: 36, // Fixed height for the banner content
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(color: background),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

