import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../utils/app_logger.dart';
import 'dart:io';

/// Service for handling both local and push notifications
/// Watches for booking updates and notifies users in real-time
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  static const String _channelId = 'booking_updates';
  static const String _channelName = 'Booking Updates';

  static const String _trekChannelId = 'trek_session_reminders';
  static const String _trekChannelName = 'Trek Session Reminders';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  bool _isInitialized = false;

  /// Initialize notification service
  /// Call this once in the app's main or during app initialization
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize local notifications
      await _initializeLocalNotifications();

      // Initialize Firebase Cloud Messaging
      await _initializeFirebaseMessaging();

      // Get and save FCM token for backend to use
      await getFCMToken();

      _isInitialized = true;
      AppLogger.i('[NotificationService] Initialized successfully');
    } catch (e) {
      AppLogger.i('[NotificationService] Initialization failed: $e');
    }
  }

  /// Initialize local notifications platform
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(onDidReceiveLocalNotification: null);

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _localNotifications.initialize(initializationSettings);

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Notifications for booking updates',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      const AndroidNotificationChannel trekChannel = AndroidNotificationChannel(
        _trekChannelId,
        _trekChannelName,
        description: 'Reminders for active trek sessions',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.createNotificationChannel(trekChannel);
    }
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Request notification permissions on iOS
    if (Platform.isIOS) {
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    }

    // Request notification permissions on Android 13+
    if (Platform.isAndroid) {
      try {
        final notificationPermission = await _firebaseMessaging
            .requestPermission(
              alert: true,
              announcement: false,
              badge: true,
              sound: true,
            );
        AppLogger.i(
          '[NotificationService] Android notification permission: ${notificationPermission.authorizationStatus}',
        );
      } catch (e) {
        AppLogger.i(
          '[NotificationService] Failed to request Android notification permission: $e',
        );
      }
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.i(
        '[NotificationService] Foreground message received: ${message.notification?.title}',
      );
      _showLocalNotification(
        title: message.notification?.title ?? 'Booking Update',
        body: message.notification?.body ?? '',
      );
    });

    // Handle background/terminated messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppLogger.i(
        'NotificationService] Message opened from background: ${message.notification?.title}',
      );
      // Handle navigation to booking screen here if needed
    });

    // Handle terminated state messages
    final RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      AppLogger.i(
        '[NotificationService] App opened from terminated state with message: ${initialMessage.notification?.title}',
      );
    }

    // Listen for FCM token changes and update Firestore
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        AppLogger.i('[NotificationService] FCM token refreshed');
      }
      _saveFCMTokenToFirestore(newToken);
    });

    AppLogger.i('[NotificationService] Firebase Cloud Messaging initialized');
  }

  /// Save FCM token to Firestore
  Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': DateTime.now(),
        }, SetOptions(merge: true));
        if (kDebugMode) {
          AppLogger.i('[NotificationService] FCM token updated in Firestore');
        }
      }
    } catch (e) {
      AppLogger.i(
        '[NotificationService] Failed to save FCM token to Firestore: $e',
      );
    }
  }

  /// Show a local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    AppLogger.i(
      '[NotificationService] Showing local notification: $title - $body',
    );

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Notifications for booking updates',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            showProgress: false,
            autoCancel: true,
          );

      const DarwinNotificationDetails iosPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _localNotifications.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
      AppLogger.i(
        '[NotificationService] Notification shown with ID: $notificationId',
      );
    } catch (e) {
      AppLogger.i('[NotificationService] Failed to show notification: $e');
    }
  }

  /// Show a reminder notification for an active trek session that has been
  /// idle for [inactiveFor].
  ///
  /// Includes a human-readable summary of progress (stations, distance, elapsed)
  /// and warns that the session will be auto-completed after 72 h of inactivity.
  Future<void> showTrekSessionReminder({
    required String sessionName,
    required Duration inactiveFor,
    required int stationsVisited,
    required double distanceKm,
    required Duration elapsed,
    required Duration autoCompleteIn,
  }) async {
    if (!_isInitialized) return;

    final idleHours = inactiveFor.inHours;
    final idleMinutes = inactiveFor.inMinutes % 60;
    final idleLabel = idleHours > 0
        ? '${idleHours}h ${idleMinutes}m'
        : '${idleMinutes}m';

    final elapsedHours = elapsed.inHours;
    final elapsedMins = elapsed.inMinutes % 60;
    final elapsedLabel = elapsedHours > 0
        ? '${elapsedHours}h ${elapsedMins}m'
        : '${elapsedMins}m';

    final distLabel = distanceKm > 0
        ? '${distanceKm.toStringAsFixed(1)} km'
        : '—';

    final autoCompleteHours = autoCompleteIn.inHours;

    final body =
        'You have an active trek "$sessionName". '
        'Last scan: $idleLabel ago · '
        '$stationsVisited station${stationsVisited == 1 ? '' : 's'} · '
        '$distLabel · $elapsedLabel trekking time. '
        'Auto-complete in ${autoCompleteHours}h if no activity.';

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            _trekChannelId,
            _trekChannelName,
            channelDescription: 'Reminders for active trek sessions',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            playSound: true,
            enableVibration: true,
            autoCancel: true,
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Use a fixed ID (9001) so repeated reminders replace the previous one.
      await _localNotifications.show(
        9001,
        '🥾 Active Trek Session',
        body,
        details,
        payload: 'trek_session_reminder',
      );
      AppLogger.i('[NotificationService] Trek session reminder sent');
    } catch (e) {
      AppLogger.i('[NotificationService] Failed to show trek reminder: $e');
    }
  }

  /// Get FCM token for the device
  Future<String?> getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        AppLogger.i('[NotificationService] FCM Token obtained');
      }

      // Save FCM token to Firestore for backend to use
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': DateTime.now(),
        }, SetOptions(merge: true));
        if (kDebugMode) {
          AppLogger.i('[NotificationService] FCM token saved to Firestore');
        }
      }

      return token;
    } catch (e) {
      AppLogger.i('[NotificationService] Failed to get FCM token: $e');
      return null;
    }
  }

  /// Listen to booking updates for current user and show notifications
  /// This creates a Firestore listener that triggers even when app is closed
  Future<void> listenToBookingUpdates() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        AppLogger.i('[NotificationService] No user logged in');
        return;
      }

      AppLogger.i(
        '[NotificationService] Listening to booking updates for user: ${user.uid}',
      );

      FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('lastModified', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              AppLogger.i(
                '[NotificationService] Firestore snapshot received with ${snapshot.docChanges.length} changes, total docs: ${snapshot.docs.length}',
              );

              for (var docChange in snapshot.docChanges) {
                AppLogger.i(
                  '[NotificationService] Document change type: ${docChange.type}, docId: ${docChange.doc.id}',
                );

                // Show notification on both modified and added documents
                // (in case the app was closed when booking was created)
                if (docChange.type == DocumentChangeType.modified ||
                    docChange.type == DocumentChangeType.added) {
                  final data = docChange.doc.data() as Map<String, dynamic>;
                  final status = data['status'] as String?;
                  final adminNotes = data['adminNotes'] as String?;
                  final lastModified = data['lastModified'] as Timestamp?;

                  // Only show notification if document was modified recently (within last 2 minutes)
                  // to avoid spamming notifications on app restart
                  if (lastModified != null) {
                    final modifiedTime = lastModified.toDate();
                    final now = DateTime.now();
                    final diff = now.difference(modifiedTime);

                    AppLogger.i(
                      '[NotificationService] Document modified ${diff.inSeconds} seconds ago',
                    );

                    // Only notify if modified within last 2 minutes
                    if (diff.inMinutes <= 2) {
                      String notificationTitle = 'Booking Updated';
                      String notificationBody = '';

                      // Generate notification based on status
                      if (status?.toLowerCase() == 'approved') {
                        notificationTitle = 'Booking Approved!';
                        notificationBody =
                            'Your booking has been approved and is ready to go.';
                      } else if (status?.toLowerCase() == 'rejected') {
                        notificationTitle = 'Booking Rejected';
                        notificationBody =
                            adminNotes ?? 'Your booking was rejected.';
                      } else if (status?.toLowerCase() == 'changes required') {
                        notificationTitle = 'Changes Required';
                        notificationBody =
                            adminNotes ??
                            'Admin notes: Please review and update.';
                      } else if (status?.toLowerCase() == 'pending') {
                        notificationTitle = 'Booking Submitted';
                        notificationBody =
                            'Your booking has been submitted for review.';
                      }

                      AppLogger.i(
                        '[NotificationService] Booking status: $status, Will notify',
                      );

                      _showLocalNotification(
                        title: notificationTitle,
                        body: notificationBody,
                        payload: docChange.doc.id,
                      );
                    } else {
                      AppLogger.i(
                        '[NotificationService] Document too old (${diff.inSeconds}s), skipping notification',
                      );
                    }
                  }
                } else {
                  AppLogger.i(
                    '[NotificationService] Ignoring document change type: ${docChange.type}',
                  );
                }
              }
            },
            onError: (error) {
              AppLogger.i(
                '[NotificationService] Error listening to bookings: $error',
              );
            },
          );
    } catch (e) {
      AppLogger.i('[NotificationService] Failed to setup booking listener: $e');
    }
  }

  /// Send a test notification (for debugging)
  Future<void> sendTestNotification() async {
    await _showLocalNotification(
      title: 'Test Notification',
      body: 'This is a test notification from TrekScanPlus',
    );
  }

  /// Dispose resources
  void dispose() {
    // Clean up if needed
  }
}
