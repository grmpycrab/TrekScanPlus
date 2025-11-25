import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/main/book_a_climb.dart';
import 'screens/social/post_detail_screen.dart';
import 'services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/station_service.dart';
import 'services/connectivity_service.dart';
import 'services/booking_service.dart';
import 'services/permission_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_manager.dart';
import 'components/notification_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
  bool _permissionsRequested = false;

  @override
  void initState() {
    super.initState();
    // Listen to auth changes and start booking status listener when user logs in
    FirebaseAuthService.instance.authStateChanges.listen((user) {
      if (user != null) {
        BookingService.instance.startBookingStatusListener(user.uid);
        _initializeFCM();

        // Request permissions once user is authenticated
        if (!_permissionsRequested) {
          _permissionsRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _requestPermissions();
          });
        }
      }
    });
  }

  Future<void> _initializeFCM() async {
    try {
      await FCMService().initialize(
        onMessageReceived: (message) {
          // Show in-app banner for foreground notifications
          final title = message.notification?.title ?? 'Notification';
          final body = message.notification?.body ?? '';
          final actionType = message.data['actionType'] as String?;

          // Determine notification type based on actionType
          final notificationType = _getNotificationType(actionType);

          if (notificationType == NotificationBannerType.success) {
            NotificationManager.showSuccess(title: title, message: body);
          } else if (notificationType == NotificationBannerType.warning) {
            NotificationManager.showWarning(title: title, message: body);
          } else if (notificationType == NotificationBannerType.error) {
            NotificationManager.showError(title: title, message: body);
          } else {
            NotificationManager.showInfo(title: title, message: body);
          }
        },
        onMessageOpened: (message) {
          // Handle navigation when notification is tapped
          debugPrint('🔔 Notification opened: ${message.data}');
          _handleNotificationNavigation(message);
        },
      );
      debugPrint('✅ FCM initialized successfully');
    } catch (e) {
      debugPrint('❌ FCM initialization error: $e');
    }
  }

  NotificationBannerType _getNotificationType(String? actionType) {
    return switch (actionType) {
      'booking_approved' => NotificationBannerType.success,
      'booking_rejected' => NotificationBannerType.error,
      'booking_pending' => NotificationBannerType.warning,
      'follow_request' => NotificationBannerType.info,
      'post_liked' => NotificationBannerType.success,
      'post_commented' => NotificationBannerType.info,
      _ => NotificationBannerType.info,
    };
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    final actionType = message.data['actionType'] as String?;
    final actionData = message.data['actionData'] as String?;

    debugPrint('🔔 ActionType: $actionType, ActionData: $actionData');

    if (actionType == 'post' && actionData != null) {
      Navigator.pushNamed(context, '/post-detail', arguments: actionData);
    } else if (actionType == 'booking' && actionData != null) {
      Navigator.pushNamed(context, '/book-climb', arguments: actionData);
    } else if (actionType?.startsWith('booking_') == true) {
      // Navigate to booking tab in MainScreen
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  Future<void> _requestPermissions() async {
    // Wait a bit for UI to settle after login
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      await PermissionService.instance.requestInitialPermissions(context);
    }
  }

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
          builder: (context, child) => Stack(
            children: [
              child!,
              NotificationBannerOverlay(key: NotificationManager.overlayKey),
            ],
          ),
          home: snapshot.connectionState == ConnectionState.waiting
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : (user != null ? const MainScreen() : const LoginScreen()),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignUpScreen(),
            '/main': (context) => const MainScreen(),
          },
          onGenerateRoute: (settings) {
            // Handle routes with arguments
            if (settings.name == '/post-detail') {
              final postId = settings.arguments as String?;
              if (postId != null) {
                return MaterialPageRoute(
                  builder: (context) => PostDetailScreen(postId: postId),
                );
              }
            }

            // Handle book-climb route with optional bookingId argument
            if (settings.name == '/book-climb') {
              final bookingId = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (context) =>
                    BookAClimbScreen(highlightBookingId: bookingId),
              );
            }

            return null;
          },
        );
      },
    );
  }
}
