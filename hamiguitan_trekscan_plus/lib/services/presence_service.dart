import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_logger.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service to track user online/offline status in real-time
class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  static PresenceService get instance => _instance;

  PresenceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _presenceTimer;
  StreamSubscription<User?>? _authSubscription;
  // Tracks the userId whose presence is actively being updated so we can
  // fire markOffline when the session ends (logout or app dispose).
  String? _currentUserId;

  /// Initialize presence tracking for the current user.
  /// Updates Firestore every 30 seconds while the app is active.
  void initialize() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _startPresenceUpdates(user.uid);
      } else {
        // Mark offline before clearing state so logout is reflected immediately.
        if (_currentUserId != null) {
          unawaited(markOffline(_currentUserId!));
        }
        _stopPresenceUpdates();
      }
    });
  }

  /// Start updating user presence every 30 seconds.
  void _startPresenceUpdates(String userId) {
    _stopPresenceUpdates(); // Cancel any existing timer first.
    _currentUserId = userId;

    // Update immediately
    _updatePresence(userId, isOnline: true);

    // Then update every 30 seconds
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updatePresence(userId, isOnline: true);
    });
  }

  /// Stop presence updates. Does NOT write to Firestore — callers that need
  /// to mark the user offline must do so explicitly (see [markOffline] and
  /// [pausePresence]).
  void _stopPresenceUpdates() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    _currentUserId = null;
  }

  /// Update user's online status in Firestore
  Future<void> _updatePresence(String userId, {required bool isOnline}) async {
    try {
      // Use set with merge to avoid error if document doesn't exist yet
      await _firestore.collection('users').doc(userId).set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('Error updating presence: $e');
      }
    }
  }

  /// Mark user as offline (call when app is closing or user logs out)
  Future<void> markOffline(String userId) async {
    try {
      // Use set with merge to avoid error if document doesn't exist yet
      await _firestore.collection('users').doc(userId).set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('Error marking offline: $e');
      }
    }
  }

  /// Call when the app goes to background.
  ///
  /// Cancels the presence timer **before** writing to Firestore so the timer
  /// cannot fire within the next 30 s and re-mark the user as online.
  Future<void> pausePresence(String userId) async {
    _stopPresenceUpdates();
    await markOffline(userId);
  }

  /// Check if a user is online
  /// Returns true if user was active in the last 2 minutes
  Stream<bool> userOnlineStatus(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return false;

      final data = snapshot.data();
      final isOnline = data?['isOnline'] as bool? ?? false;
      final lastSeen = data?['lastSeen'] as Timestamp?;

      // If explicitly online, return true
      if (isOnline) return true;

      // Otherwise check if last seen was within 2 minutes (grace period)
      if (lastSeen != null) {
        final lastSeenTime = lastSeen.toDate();
        final now = DateTime.now();
        final difference = now.difference(lastSeenTime);
        return difference.inMinutes < 2;
      }

      return false;
    });
  }

  /// Dispose of subscriptions
  void dispose() {
    // Mark offline before disposal so the user's status is correct even if
    // the app is terminated without going through a proper lifecycle pause.
    if (_currentUserId != null) {
      unawaited(markOffline(_currentUserId!));
    }
    _presenceTimer?.cancel();
    _authSubscription?.cancel();
  }
}
