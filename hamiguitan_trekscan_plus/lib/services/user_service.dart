import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserService {
  UserService._internal();

  static final UserService instance = UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Create or update a user document from a Firebase [User].
  ///
  /// If the document doesn't exist, it will be created with `createdAt`.
  /// `lastSeen` will always be updated to server timestamp.
  Future<void> createOrUpdateUserFromFirebase(User user) async {
    try {
      final docRef = _usersCollection.doc(user.uid);

      final doc = await docRef.get();

      final data = <String, dynamic>{
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'phoneNumber': user.phoneNumber,
        'providerData': user.providerData.map((p) => p.providerId).toList(),
        'lastSeen': FieldValue.serverTimestamp(),
      };

      if (!doc.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await docRef.set(data, SetOptions(merge: true));
        if (kDebugMode) {
          print('User document created for ${user.uid}');
        }
      } else {
        await docRef.set(data, SetOptions(merge: true));
        if (kDebugMode) {
          print('User document updated for ${user.uid}');
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error creating/updating user document: $e');
        print(st);
      }
      rethrow;
    }
  }

  /// Get user data once as a map
  Future<Map<String, dynamic>?> getUserOnce(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  /// Stream user document
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUser(String uid) {
    return _usersCollection.doc(uid).snapshots();
  }

  /// List users (simple pagination could be added)
  Future<List<Map<String, dynamic>>> listUsers({int limit = 50}) async {
    final snapshot = await _usersCollection.limit(limit).get();
    return snapshot.docs.map((d) {
      final m = d.data();
      m['id'] = d.id;
      return m;
    }).toList();
  }

  /// Delete user document
  Future<void> deleteUser(String uid) async {
    await _usersCollection.doc(uid).delete();
  }

  /// Update user personal information
  Future<void> updateUserInfo({
    required String uid,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? birthDate,
    String? gender,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (firstName != null) data['firstName'] = firstName;
      if (lastName != null) data['lastName'] = lastName;
      if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
      if (birthDate != null) data['birthDate'] = birthDate;
      if (gender != null) data['gender'] = gender;

      await _usersCollection.doc(uid).set(data, SetOptions(merge: true));
      if (kDebugMode) {
        print('User info updated for $uid');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error updating user info: $e');
        print(st);
      }
      rethrow;
    }
  }

  /// Update user name with cooldown check
  /// Returns true if name was updated, false if still in cooldown period
  Future<bool> updateUserName({
    required String uid,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final userDoc = await _usersCollection.doc(uid).get();
      final userData = userDoc.data() ?? {};

      // Check if there's a last name change timestamp
      final lastNameChangeTimestamp =
          userData['lastNameChangeAt'] as Timestamp?;

      if (lastNameChangeTimestamp != null) {
        final lastChangeDate = lastNameChangeTimestamp.toDate();
        final now = DateTime.now();
        final daysSinceLastChange = now.difference(lastChangeDate).inDays;

        // If less than 60 days have passed, deny the change
        if (daysSinceLastChange < 60) {
          return false;
        }
      }

      // Update name and set the new cooldown timestamp
      await _usersCollection.doc(uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'lastNameChangeAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('User name updated for $uid');
      }
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        print('Error updating user name: $e');
        print(st);
      }
      rethrow;
    }
  }

  /// Get time remaining until user can change name again (in days)
  /// Returns 0 if user can change now, or number of days remaining
  Future<int> getNameChangeCooldownDaysRemaining(String uid) async {
    try {
      final userDoc = await _usersCollection.doc(uid).get();
      final userData = userDoc.data() ?? {};

      final lastNameChangeTimestamp =
          userData['lastNameChangeAt'] as Timestamp?;

      if (lastNameChangeTimestamp == null) {
        return 0; // Never changed name, can change now
      }

      final lastChangeDate = lastNameChangeTimestamp.toDate();
      final now = DateTime.now();
      final daysSinceLastChange = now.difference(lastChangeDate).inDays;
      final daysRemaining = 60 - daysSinceLastChange;

      return daysRemaining > 0 ? daysRemaining : 0;
    } catch (e, st) {
      if (kDebugMode) {
        print('Error checking name change cooldown: $e');
        print(st);
      }
      return 0;
    }
  }
}
