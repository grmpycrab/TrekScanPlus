import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/main/main_screen.dart';
import 'services/station_service.dart';
import 'services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stationService = await StationService.init();
  await stationService.loadStations();

  // Start connectivity monitoring
  ConnectivityService.instance.start();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
