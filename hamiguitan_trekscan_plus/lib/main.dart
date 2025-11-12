import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/main/main_screen.dart';
import 'services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/station_service.dart';
import 'services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
    return StreamBuilder<User?>(
      stream: FirebaseAuthService.instance.authStateChanges,
      initialData: FirebaseAuthService.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Hamiguitan TrekScan+',
          theme: ThemeData(
            primaryColor: const Color(0xFF252B30),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF252B30),
            ),
            useMaterial3: true,
          ),
          home: snapshot.connectionState == ConnectionState.waiting
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : (user != null ? const MainScreen() : const LoginScreen()),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignUpScreen(),
            '/main': (context) => const MainScreen(),
          },
        );
      },
    );
  }
}
