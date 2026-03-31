import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/station_data.dart';
import '../../utils/app_logger.dart';

/// Service to sync user's visited stations to Firebase Firestore
/// This ensures visited stations are persisted across devices and app reinstalls
class FirestoreStationService {
  FirestoreStationService._internal();

  static final FirestoreStationService instance =
      FirestoreStationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Collection path for user data
  static const String usersCollection = 'users';

  /// Subcollection path for visited stations
  static const String visitedStationsSubcollection = 'visitedStations';

  /// Get the current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Get reference to current user's visited stations collection
  CollectionReference<Map<String, dynamic>>? get _userVisitedStationsRef {
    final userId = _currentUserId;
    if (userId == null) {
      return null;
    }
    return _firestore
        .collection(usersCollection)
        .doc(userId)
        .collection(visitedStationsSubcollection);
  }

  /// Save a visited station to Firestore
  /// This is called when a user scans/visits a station
  Future<void> saveVisitedStation(StationData station) async {
    try {
      if (_currentUserId == null) {
        if (kDebugMode) {
          AppLogger.i('No user logged in, cannot save visited station');
        }
        return;
      }

      final ref = _userVisitedStationsRef;
      if (ref == null) return;

      await ref.doc(station.id).set({
        'stationId': station.id,
        'stationName': station.name,
        'difficulty': station.difficulty,
        'elevation': station.elevation,
        'latitude': station.latitude,
        'longitude': station.longitude,
        'isVisited': true,
        'visitedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        AppLogger.i('${station.name} saved to Firestore');
      }
    } catch (e) {
      if (kDebugMode) AppLogger.i('Error saving visited station: $e');
      rethrow;
    }
  }

  /// Remove a visited station from Firestore (unmark as visited)
  Future<void> removeVisitedStation(String stationId) async {
    try {
      if (_currentUserId == null) {
        if (kDebugMode) {
          AppLogger.i('No user logged in, cannot remove visited station');
        }
        return;
      }

      final ref = _userVisitedStationsRef;
      if (ref == null) return;

      await ref.doc(stationId).delete();

      if (kDebugMode) {
        AppLogger.i('Station $stationId removed from Firestore');
      }
    } catch (e) {
      if (kDebugMode) AppLogger.i('Error removing visited station: $e');
      rethrow;
    }
  }

  /// Get all visited stations for the current user from Firestore
  Future<List<String>> getVisitedStationIds() async {
    try {
      if (_currentUserId == null) {
        if (kDebugMode) {
          AppLogger.i('No user logged in, cannot fetch visited stations');
        }
        return [];
      }

      final ref = _userVisitedStationsRef;
      if (ref == null) return [];

      final snapshot = await ref.get();
      final stationIds = snapshot.docs.map((doc) => doc.id).toList();

      if (kDebugMode) {
        AppLogger.i(
          'Fetched ${stationIds.length} visited stations from Firestore',
        );
      }

      return stationIds;
    } catch (e) {
      if (kDebugMode) AppLogger.i('Error fetching visited stations: $e');
      return [];
    }
  }

  /// Get real-time stream of visited stations
  /// Useful for UI that should update when stations are visited on another device
  Stream<List<String>> getVisitedStationsStream() {
    if (_currentUserId == null) {
      if (kDebugMode) {
        AppLogger.i('No user logged in, returning empty stream');
      }
      return const Stream.empty();
    }

    final ref = _userVisitedStationsRef;
    if (ref == null) return const Stream.empty();

    return ref.snapshots().map((snapshot) {
      final stationIds = snapshot.docs.map((doc) => doc.id).toList();
      if (kDebugMode) {
        AppLogger.i(
          'Visited stations stream updated: ${stationIds.length} stations',
        );
      }
      return stationIds;
    });
  }

  /// Sync local visited stations to Firestore
  /// Call this when app starts or when user logs in
  Future<void> syncVisitedStations(List<String> localVisitedStationIds) async {
    try {
      if (_currentUserId == null) {
        if (kDebugMode) {
          AppLogger.i('No user logged in, cannot sync visited stations');
        }
        return;
      }

      // Get remote visited stations
      final remoteIds = await getVisitedStationIds();

      // Find stations to add (in local but not in remote)
      final stationsToAdd = localVisitedStationIds.where(
        (id) => !remoteIds.contains(id),
      );

      // Add missing stations to remote
      for (final stationId in stationsToAdd) {
        final ref = _userVisitedStationsRef;
        if (ref != null) {
          await ref.doc(stationId).set({
            'stationId': stationId,
            'isVisited': true,
            'visitedAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      if (kDebugMode) {
        AppLogger.i('Synced ${stationsToAdd.length} stations to Firestore');
      }
    } catch (e) {
      if (kDebugMode) AppLogger.i('Error syncing visited stations: $e');
    }
  }

  /// Reset all visited stations for current user in Firestore
  Future<void> resetAllVisitedStations() async {
    try {
      if (_currentUserId == null) {
        if (kDebugMode) {
          AppLogger.i('No user logged in, cannot reset visited stations');
        }
        return;
      }

      final ref = _userVisitedStationsRef;
      if (ref == null) return;

      final snapshot = await ref.get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      if (kDebugMode) {
        AppLogger.i('All visited stations reset in Firestore');
      }
    } catch (e) {
      if (kDebugMode) AppLogger.i('Error resetting visited stations: $e');
      rethrow;
    }
  }

  /// Check if a specific station has been visited by current user
  Future<bool> isStationVisited(String stationId) async {
    try {
      if (_currentUserId == null) {
        if (kDebugMode) {
          AppLogger.i('No user logged in, cannot check visited status');
        }
        return false;
      }

      final ref = _userVisitedStationsRef;
      if (ref == null) return false;

      final doc = await ref.doc(stationId).get();
      return doc.exists;
    } catch (e) {
      if (kDebugMode) AppLogger.i('Error checking visited status: $e');
      return false;
    }
  }
}
