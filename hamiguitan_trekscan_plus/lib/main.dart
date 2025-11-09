import 'dart:async';

import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/main/main_screen.dart';
import 'services/station_service.dart';
import 'services/connectivity_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stationService = await StationService.init();
  await stationService.loadStations();

  // Start connectivity monitoring
  ConnectivityService.instance.start();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _connectivitySub;

  @override
  void initState() {
    super.initState();

    // Listen for connectivity changes and show a snackbar via the global scaffold messenger
    _connectivitySub = ConnectivityService.instance.statusStream.listen((
      status,
    ) {
      _showConnectivitySnack(status);
    });
  }

  void _showConnectivitySnack(ConnectionStatus status) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    Color background;
    String message;
    Duration duration = const Duration(seconds: 3);

    switch (status) {
      case ConnectionStatus.connecting:
        background = Colors.grey.shade700;
        message = 'Connecting...';
        duration = const Duration(seconds: 2);
        break;
      case ConnectionStatus.online:
        background = Colors.green.shade600;
        message = 'Online';
        break;
      case ConnectionStatus.offline:
        background = Colors.red.shade600;
        message = 'Offline — check your connection';
        break;
    }

    // Remove any existing snackbars then show the new one positioned at the top
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        // make the content fill available width and center the text
        content: SizedBox(
          width: double.infinity,
          child: Center(child: Text(message, textAlign: TextAlign.center)),
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        // place the floating SnackBar at the top by giving a top margin
        margin: const EdgeInsets.only(top: 12, left: 16, right: 16),
        elevation: 6,
        duration: duration,
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Hamiguitan TrekScan+',
      theme: ThemeData(
        primaryColor: const Color(0xFF252B30),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF252B30)),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}
