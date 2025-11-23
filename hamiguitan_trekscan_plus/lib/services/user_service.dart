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
        // Initialize social fields for new users
        data['postsCount'] = 0;
        data['followersCount'] = 0;
        data['followingCount'] = 0;
        data['followers'] = [];
        data['following'] = [];
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

  /// Toggle follow status between two users
  Future<void> toggleFollow(String followingUid, String followerUid) async {
    try {
      // Add to following list
      await _usersCollection.doc(followerUid).update({
        'following': FieldValue.arrayUnion([followingUid]),
        'followingCount': FieldValue.increment(1),
      });

      // Add to followers list
      await _usersCollection.doc(followingUid).update({
        'followers': FieldValue.arrayUnion([followerUid]),
        'followersCount': FieldValue.increment(1),
      });

      if (kDebugMode) {
        print('$followerUid now following $followingUid');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error toggling follow: $e');
        print(st);
      }
      rethrow;
    }
  }

  /// Unfollow a user
  Future<void> unfollow(String currentUid, String userToUnfollowUid) async {
    try {
      // First check if the user is actually following
      final isCurrentlyFollowing = await isFollowing(
        currentUid,
        userToUnfollowUid,
      );
      if (!isCurrentlyFollowing) {
        if (kDebugMode) {
          print(
            'User $currentUid is not following $userToUnfollowUid, skipping unfollow',
          );
        }
        return; // Don't proceed if not following
      }

      // Get current counts to prevent negative values
      final currentUserDoc = await _usersCollection.doc(currentUid).get();
      final targetUserDoc = await _usersCollection.doc(userToUnfollowUid).get();

      final currentFollowingCount =
          (currentUserDoc.data()?['followingCount'] as num?)?.toInt() ?? 0;
      final targetFollowersCount =
          (targetUserDoc.data()?['followersCount'] as num?)?.toInt() ?? 0;

      // Remove from following list
      final currentUserUpdate = <String, dynamic>{
        'following': FieldValue.arrayRemove([userToUnfollowUid]),
      };
      if (currentFollowingCount > 0) {
        currentUserUpdate['followingCount'] = FieldValue.increment(-1);
      }
      await _usersCollection.doc(currentUid).update(currentUserUpdate);

      // Remove from followers list
      final targetUserUpdate = <String, dynamic>{
        'followers': FieldValue.arrayRemove([currentUid]),
      };
      if (targetFollowersCount > 0) {
        targetUserUpdate['followersCount'] = FieldValue.increment(-1);
      }
      await _usersCollection.doc(userToUnfollowUid).update(targetUserUpdate);

      if (kDebugMode) {
        print('$currentUid unfollowed $userToUnfollowUid');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error unfollowing: $e');
        print(st);
      }
      rethrow;
    }
  }

  /// Check if current user is following a user
  Future<bool> isFollowing(String currentUid, String userUid) async {
    try {
      final userDoc = await _usersCollection.doc(currentUid).get();
      final userData = userDoc.data() ?? {};
      final following =
          (userData['following'] as List<dynamic>?)?.cast<String>() ?? [];
      return following.contains(userUid);
    } catch (e, st) {
      if (kDebugMode) {
        print('Error checking follow status: $e');
        print(st);
      }
      return false;
    }
  }

  /// Update user's post count
  Future<void> incrementPostCount(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        'postsCount': FieldValue.increment(1),
      });
      if (kDebugMode) {
        print('Post count incremented for $uid');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error incrementing post count: $e');
        print(st);
      }
      rethrow;
    }
  }

  /// Decrement user's post count (when post is deleted)
  Future<void> decrementPostCount(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        'postsCount': FieldValue.increment(-1),
      });
      if (kDebugMode) {
        print('Post count decremented for $uid');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error decrementing post count: $e');
        print(st);
      }
      rethrow;
    }
  }

  /// Fix negative counts for a user (repair data integrity)
  Future<void> fixNegativeCounts(String uid) async {
    try {
      final userDoc = await _usersCollection.doc(uid).get();
      final userData = userDoc.data() ?? {};

      final updates = <String, dynamic>{};

      // Fix followersCount
      final followersCount = (userData['followersCount'] as num?)?.toInt() ?? 0;
      final followersList =
          (userData['followers'] as List<dynamic>?)?.cast<String>() ?? [];
      if (followersCount < 0 || followersCount != followersList.length) {
        updates['followersCount'] = followersList.length;
      }

      // Fix followingCount
      final followingCount = (userData['followingCount'] as num?)?.toInt() ?? 0;
      final followingList =
          (userData['following'] as List<dynamic>?)?.cast<String>() ?? [];
      if (followingCount < 0 || followingCount != followingList.length) {
        updates['followingCount'] = followingList.length;
      }

      // Fix postsCount (cannot be negative)
      final postsCount = (userData['postsCount'] as num?)?.toInt() ?? 0;
      if (postsCount < 0) {
        updates['postsCount'] = 0;
      }

      if (updates.isNotEmpty) {
        await _usersCollection.doc(uid).update(updates);
        if (kDebugMode) {
          print('Fixed counts for $uid: $updates');
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error fixing negative counts: $e');
        print(st);
      }
      rethrow;
    }
  }
}
