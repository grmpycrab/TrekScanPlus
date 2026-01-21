import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/main/book_a_climb.dart';
import 'screens/social/post_detail_screen.dart';
import 'screens/splash_screen.dart';
import 'services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/station_service.dart';
import 'services/connectivity_service.dart';
import 'services/booking_service.dart';
import 'services/permission_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_manager.dart';
import 'services/presence_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/app_theme_builder.dart';
import 'services/climb_session_service.dart';
import 'components/notification_banner.dart';

// Global navigator key for deep linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize only essential services (parallel operations)
  await Future.wait([
    ThemeService().initialize(),
    dotenv.load(fileName: ".env"),
  ]);

  // Start lightweight connectivity monitoring
  ConnectivityService.instance.start();

  // Initialize Firebase (MUST complete before running app)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase init error: $e');
    // Don't continue if Firebase fails - it's critical for auth
    rethrow;
  }

  // Run app - Firebase is guaranteed to be ready
  runApp(
    ChangeNotifierProvider(create: (_) => ThemeService(), child: const MyApp()),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _permissionsRequested = false;
  bool _servicesInitialized = false;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Hide splash screen quickly
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });

    // Listen to auth changes (Firebase is ready)
    try {
      FirebaseAuthService.instance.authStateChanges.listen((user) async {
        if (user != null) {
          // Initialize ClimbSessionService for any authenticated user (verified or not)
          // This allows app to work even if email verification is pending
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeVerifiedUserServices(user.uid);
          });

          // Check if user is verified for additional verification-only services
          final isVerified = await FirebaseAuthService.instance
              .isEmailVerified();
          if (isVerified) {
            // Additional services for verified users can go here if needed
            debugPrint('✅ User email verified');
          } else {
            debugPrint('⏳ User email not yet verified');
          }
        } else {
          // User logged out, reset flags
          _servicesInitialized = false;
          _permissionsRequested = false;
        }
      });
    } catch (e) {
      debugPrint('⚠️ Auth listener error: $e');
    }

    // Also check for existing user synchronously
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      debugPrint('👤 Found existing user: ${currentUser.email}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeVerifiedUserServices(currentUser.uid);
      });
    } else {
      // Initialize in offline mode anyway for the app to work
      debugPrint('🔌 No user logged in, initializing in offline mode');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ClimbSessionService.isInitialized) {
          _initializeVerifiedUserServices(
            'offline_${DateTime.now().millisecondsSinceEpoch}',
          );
        }
      });
    }

    // Defer all heavy initialization to after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCriticalServices();
      _deferredInitializeStations();
      _deferredHandleDeepLinks();
    });
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
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        // App going to background or closing
        PresenceService.instance.markOffline(user.uid);
      } else if (state == AppLifecycleState.resumed) {
        // App coming back to foreground
        PresenceService.instance.initialize();
      }
    }
  }

  /// Initialize critical services asynchronously
  Future<void> _initializeCriticalServices() async {
    // Run these in background without blocking UI
    unawaited(
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          await NotificationService().initialize();
          PresenceService.instance.initialize();
        } catch (e) {
          debugPrint(
            '⚠️ Non-critical service initialization: $e (offline mode)',
          );
        }
      }),
    );
  }

  /// Initialize services for verified users
  Future<void> _initializeVerifiedUserServices(String userId) async {
    if (_servicesInitialized) return;

    debugPrint('🚀 Initializing services for verified user: $userId');

    // Initialize ClimbSessionService with user ID (offline-first)
    try {
      await ClimbSessionService.init(userId: userId);
      debugPrint('✅ ClimbSessionService initialized (offline-first)');
    } catch (e) {
      debugPrint('⚠️ ClimbSessionService: $e (offline mode available)');
    }

    // Start booking listener in background (non-blocking)
    unawaited(
      Future.delayed(const Duration(milliseconds: 300), () async {
        try {
          BookingService.instance.startBookingStatusListener(userId);
        } catch (e) {
          debugPrint('⚠️ Booking service: $e');
        }
      }),
    );

    // Initialize FCM and notifications in background
    unawaited(_initializeFCM());
    unawaited(
      Future.microtask(() => NotificationService().listenToBookingUpdates()),
    );

    if (!_permissionsRequested) {
      _permissionsRequested = true;
      // Defer permission requests to avoid blocking startup
      unawaited(
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) _requestPermissions();
        }),
      );
    }

    _servicesInitialized = true;
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

  /// Handle deep link when app is launched from closed state
  Future<void> _handleInitialDeepLink() async {
    try {
      final appLinks = AppLinks();
      final link = await appLinks.getInitialLink();
      if (link != null) {
        debugPrint('🔗 [DeepLink] Initial link: $link');
        _handleDeepLink(link.toString());
      }
    } catch (e) {
      debugPrint('❌ [DeepLink] Error getting initial link: $e');
    }
  }

  /// Listen for deep links when app is running
  void _listenToDeepLinks() {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen(
      (Uri link) {
        debugPrint('🔗 [DeepLink] Received link: $link');
        _handleDeepLink(link.toString());
      },
      onError: (err) {
        debugPrint('❌ [DeepLink] Stream error: $err');
      },
    );
  }

  /// Route user to the correct screen based on deep link
  void _handleDeepLink(String link) {
    try {
      final uri = Uri.parse(link);
      debugPrint(
        '🔗 [DeepLink] Parsed URI - scheme: ${uri.scheme}, path: ${uri.path}, host: ${uri.host}',
      );

      // Handle both https://trekscanplus.app/posts/{postId} and trekscanplus://posts/{postId}
      String? postId;

      if (uri.scheme == 'https' && uri.host == 'trekscanplus.app') {
        // Handle https://trekscanplus.app/posts/{postId}
        if (uri.path.startsWith('/posts/')) {
          postId = uri.path.replaceFirst('/posts/', '');
        }
      } else if (uri.scheme == 'trekscanplus') {
        // Handle trekscanplus://posts/{postId}
        if (uri.host == 'posts' && uri.path.isNotEmpty) {
          postId = uri.path.replaceFirst('/', '');
        }
      }

      if (postId != null && postId.isNotEmpty) {
        debugPrint('🔗 [DeepLink] Navigating to post: $postId');
        navigatorKey.currentState?.pushNamed('/post-detail', arguments: postId);
      } else {
        debugPrint('⚠️ [DeepLink] Could not extract postId from link');
      }
    } catch (e) {
      debugPrint('❌ [DeepLink] Error handling deep link: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (mounted) {
      try {
        await PermissionService.instance.requestInitialPermissions(context);
      } catch (e) {
        debugPrint('Permission request error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen on initial load
    if (_showSplash) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }

    return _buildMainApp();
  }

  Widget _buildMainApp() {
    return StreamBuilder<User?>(
      stream: FirebaseAuthService.instance.authStateChanges,
      initialData: FirebaseAuthService.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;

        // Show loading screen while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // No user logged in
        if (user == null) {
          return _buildApp(const LoginScreen());
        }

        // User logged in, check verification status
        return FutureBuilder<bool>(
          future: FirebaseAuthService.instance.isEmailVerified(),
          builder: (context, verificationSnapshot) {
            if (verificationSnapshot.connectionState ==
                ConnectionState.waiting) {
              return _buildApp(
                const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final isVerified = verificationSnapshot.data ?? false;
            final isEmailPasswordUser = user.providerData.any(
              (info) => info.providerId == 'password',
            );

            Widget initialScreen;
            if (isEmailPasswordUser && !isVerified) {
              // Email not verified, show verification screen
              initialScreen = const EmailVerificationScreen();
            } else {
              // Email verified or Google user, show main screen
              // Initialize services for verified users
              if (isVerified) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _initializeVerifiedUserServices(user.uid);
                });
              }
              initialScreen = const MainScreen();
            }

            return _buildApp(initialScreen);
          },
        );
      },
    );
  }

  Widget _buildApp(Widget home) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        final themeData = AppThemeBuilder.getThemeData(
          themeService.selectedTheme,
          themeService.selectedMode,
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Hamiguitan TrekScan+',
          navigatorKey: navigatorKey,
          theme: themeData,
          builder: (context, child) => Stack(
            children: [
              child!,
              NotificationBannerOverlay(key: NotificationManager.overlayKey),
            ],
          ),
          home: home,
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignUpScreen(),
            '/verify-email': (context) => const EmailVerificationScreen(),
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

  /// Deferred station initialization (happens after UI is rendered)
  void _deferredInitializeStations() {
    unawaited(
      Future.microtask(() async {
        try {
          debugPrint('🔄 Loading stations in background...');
          final stationService = await StationService.init();
          await stationService.loadStations();
          debugPrint('✅ Stations loaded successfully');
        } catch (error) {
          debugPrint('❌ Failed to load stations: $error');
        }
      }),
    );
  }

  /// Deferred deep link initialization (happens after UI is rendered)
  void _deferredHandleDeepLinks() {
    unawaited(_handleInitialDeepLink());
    _listenToDeepLinks();
  }
}
