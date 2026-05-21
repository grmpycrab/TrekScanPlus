import 'dart:async';
import 'package:flutter/material.dart';

import 'config/app_init.dart';
import 'core/app_startup_controller.dart';
import 'core/providers/app_providers.dart';
import 'core/widgets/auth_gate.dart';
import 'core/services/presence_service.dart';
import 'screens/splash_screen.dart';
import 'utils/app_logger.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppInit.initialize();
    runApp(AppProviders(child: const MyApp()));
  }, (error, stack) {
    // Firestore streams emit permission-denied when the auth token is
    // revoked on sign-out. This is expected — swallow it silently.
    final msg = error.toString();
    if (msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED')) {
      AppLogger.w('Firestore stream closed on sign-out (expected): $error');
      return;
    }
    AppLogger.e('Unhandled error: $error\n$stack');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppStartupController _controller;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = AppStartupController(
      isMounted: () => mounted,
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showSplash = false);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PresenceService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _controller.handleLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }
    return AuthGate(
      onServicesInitNeeded: _controller.initializeUserServices,
      onLogout: _controller.resetForLogout,
    );
  }
}
