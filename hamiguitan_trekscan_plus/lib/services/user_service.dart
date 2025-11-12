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
}
