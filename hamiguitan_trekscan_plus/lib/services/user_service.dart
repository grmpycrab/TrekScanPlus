import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'notification_services.dart';

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
        data['pendingFollowRequests'] = [];
        data['sentFollowRequests'] = [];
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

  /// Delete user document and all associated data (cascade deletion)
  Future<void> deleteUser(String uid) async {
    try {
      final batch = _firestore.batch();

      if (kDebugMode) {
        print('Starting cascade deletion for user: $uid');
      }

      // 1. Delete subcollections under users/{uid}
      final subcollections = [
        'achievements',
        'notifications',
        'bookmarks',
        'visitedStations',
      ];

      for (final subcollection in subcollections) {
        final subcollectionRef = _usersCollection
            .doc(uid)
            .collection(subcollection);
        final subcollectionDocs = await subcollectionRef.get();

        for (final doc in subcollectionDocs.docs) {
          batch.delete(doc.reference);
        }

        if (kDebugMode) {
          print(
            'Deleting ${subcollectionDocs.docs.length} documents from $subcollection',
          );
        }
      }

      // 2. Delete user's posts and their subcollections
      final postsQuery = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .get();

      if (kDebugMode) {
        print('Deleting ${postsQuery.docs.length} posts');
      }

      for (final postDoc in postsQuery.docs) {
        // Delete post subcollections (likes, comments)
        final likesSnapshot = await postDoc.reference.collection('likes').get();
        for (final likeDoc in likesSnapshot.docs) {
          batch.delete(likeDoc.reference);
        }

        final commentsSnapshot = await postDoc.reference
            .collection('comments')
            .get();
        for (final commentDoc in commentsSnapshot.docs) {
          // Delete comment likes and replies
          final commentLikesSnapshot = await commentDoc.reference
              .collection('likes')
              .get();
          for (final commentLikeDoc in commentLikesSnapshot.docs) {
            batch.delete(commentLikeDoc.reference);
          }

          final repliesSnapshot = await commentDoc.reference
              .collection('replies')
              .get();
          for (final replyDoc in repliesSnapshot.docs) {
            // Delete reply likes
            final replyLikesSnapshot = await replyDoc.reference
                .collection('likes')
                .get();
            for (final replyLikeDoc in replyLikesSnapshot.docs) {
              batch.delete(replyLikeDoc.reference);
            }
            batch.delete(replyDoc.reference);
          }

          batch.delete(commentDoc.reference);
        }

        // Delete the post itself
        batch.delete(postDoc.reference);
      }

      // 3. Delete user's bookings
      final bookingsQuery = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: uid)
          .get();

      if (kDebugMode) {
        print('Deleting ${bookingsQuery.docs.length} bookings');
      }

      for (final bookingDoc in bookingsQuery.docs) {
        batch.delete(bookingDoc.reference);
      }

      // 4. Clean up follower/following relationships
      final userDoc = await _usersCollection.doc(uid).get();
      final userData = userDoc.data();

      if (userData != null) {
        // Remove this user from followers' following lists
        final followers = List<String>.from(userData['followers'] ?? []);
        for (final followerId in followers) {
          final followerRef = _usersCollection.doc(followerId);
          batch.update(followerRef, {
            'following': FieldValue.arrayRemove([uid]),
            'followingCount': FieldValue.increment(-1),
          });
        }

        // Remove this user from following users' followers lists
        final following = List<String>.from(userData['following'] ?? []);
        for (final followingId in following) {
          final followingRef = _usersCollection.doc(followingId);
          batch.update(followingRef, {
            'followers': FieldValue.arrayRemove([uid]),
            'followersCount': FieldValue.increment(-1),
          });
        }

        // Clean up pending follow requests
        final pendingRequests = List<String>.from(
          userData['pendingFollowRequests'] ?? [],
        );
        for (final requesterId in pendingRequests) {
          final requesterRef = _usersCollection.doc(requesterId);
          batch.update(requesterRef, {
            'sentFollowRequests': FieldValue.arrayRemove([uid]),
          });
        }

        final sentRequests = List<String>.from(
          userData['sentFollowRequests'] ?? [],
        );
        for (final targetId in sentRequests) {
          final targetRef = _usersCollection.doc(targetId);
          batch.update(targetRef, {
            'pendingFollowRequests': FieldValue.arrayRemove([uid]),
          });
        }

        if (kDebugMode) {
          print(
            'Cleaning up ${followers.length} followers and ${following.length} following',
          );
        }
      }

      // 5. Delete Storage files (profile photos, post images)
      try {
        final storage = FirebaseStorage.instance;

        // Delete user's profile photo
        try {
          final profilePhotoRef = storage.ref().child('users/$uid/profile.jpg');
          await profilePhotoRef.delete();
          if (kDebugMode) {
            print('Deleted profile photo');
          }
        } catch (e) {
          // Profile photo might not exist, ignore
          if (kDebugMode) {
            print('No profile photo to delete or error: $e');
          }
        }

        // Delete user's post images folder
        try {
          final postsFolder = storage.ref().child('posts/$uid');
          final postsList = await postsFolder.listAll();
          for (final item in postsList.items) {
            await item.delete();
          }
          if (kDebugMode) {
            print('Deleted ${postsList.items.length} post images');
          }
        } catch (e) {
          // Posts folder might not exist, ignore
          if (kDebugMode) {
            print('No post images to delete or error: $e');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error deleting storage files: $e');
        }
        // Continue with deletion even if storage cleanup fails
      }

      // 6. Finally, delete the user document
      batch.delete(_usersCollection.doc(uid));

      // Commit all deletions
      await batch.commit();

      if (kDebugMode) {
        print('Successfully completed cascade deletion for user: $uid');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error deleting user: $e');
        print(st);
      }
      rethrow;
    }
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

  /// Send follow request (adds to pending list)
  Future<void> toggleFollow(String followingUid, String followerUid) async {
    try {
      // Check if request already pending
      final followingUserDoc = await _usersCollection.doc(followingUid).get();
      final pendingRequests =
          (followingUserDoc.data()?['pendingFollowRequests'] as List<dynamic>?)
              ?.cast<String>() ??
          [];

      if (pendingRequests.contains(followerUid)) {
        if (kDebugMode) {
          print(
            'Follow request already pending from $followerUid to $followingUid',
          );
        }
        return; // Request already sent, prevent duplicates
      }

      // Get follower's name for notification
      final followerDoc = await _usersCollection.doc(followerUid).get();
      final followerData = followerDoc.data() ?? {};
      final followerName =
          followerData['displayName'] as String? ??
          followerData['email'] as String? ??
          'Someone';

      // Add to pending follow requests (target user)
      await _usersCollection.doc(followingUid).update({
        'pendingFollowRequests': FieldValue.arrayUnion([followerUid]),
      });

      // Add to sent follow requests (requester)
      await _usersCollection.doc(followerUid).update({
        'sentFollowRequests': FieldValue.arrayUnion([followingUid]),
      });

      // Send follow request notification
      await NotificationService().sendFollowRequest(
        followingUid,
        followerUid,
        followerName,
      );

      if (kDebugMode) {
        print('Follow request sent from $followerUid to $followingUid');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error toggling follow: $e');
        print(st);
      }
      rethrow;
    }
  }

  /// Accept a follow request
  Future<void> acceptFollowRequest(
    String currentUid,
    String requesterUid,
  ) async {
    try {
      // Get current counts
      final currentUserDoc = await _usersCollection.doc(currentUid).get();
      final requesterDoc = await _usersCollection.doc(requesterUid).get();

      final currentFollowersCount =
          (currentUserDoc.data()?['followersCount'] as num?)?.toInt() ?? 0;
      final requesterFollowingCount =
          (requesterDoc.data()?['followingCount'] as num?)?.toInt() ?? 0;

      // Add to following list (requester) and remove from sent requests
      final requesterUpdate = <String, dynamic>{
        'following': FieldValue.arrayUnion([currentUid]),
        'sentFollowRequests': FieldValue.arrayRemove([currentUid]),
      };
      requesterUpdate['followingCount'] = requesterFollowingCount + 1;
      await _usersCollection.doc(requesterUid).update(requesterUpdate);

      // Add to followers list (current user) and remove from pending requests
      final currentUpdate = <String, dynamic>{
        'followers': FieldValue.arrayUnion([requesterUid]),
        'pendingFollowRequests': FieldValue.arrayRemove([requesterUid]),
      };
      currentUpdate['followersCount'] = currentFollowersCount + 1;
      await _usersCollection.doc(currentUid).update(currentUpdate);

      if (kDebugMode) {
        print('$currentUid accepted follow request from $requesterUid');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error accepting follow request: $e');
        print(st);
      }
      rethrow;
    }
  }

  /// Reject a follow request (remove from pending lists)
  Future<void> rejectFollowRequest(
    String currentUid,
    String requesterUid,
  ) async {
    try {
      // Remove from pending requests (current user)
      await _usersCollection.doc(currentUid).update({
        'pendingFollowRequests': FieldValue.arrayRemove([requesterUid]),
      });

      // Remove from sent requests (requester)
      await _usersCollection.doc(requesterUid).update({
        'sentFollowRequests': FieldValue.arrayRemove([currentUid]),
      });

      if (kDebugMode) {
        print('$currentUid rejected follow request from $requesterUid');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error rejecting follow request: $e');
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

  /// Check if a follow request is pending
  Future<bool> isPendingFollowRequest(
    String currentUid,
    String targetUid,
  ) async {
    try {
      final userDoc = await _usersCollection.doc(currentUid).get();
      final userData = userDoc.data() ?? {};
      final sentRequests =
          (userData['sentFollowRequests'] as List<dynamic>?)?.cast<String>() ??
          [];
      return sentRequests.contains(targetUid);
    } catch (e, st) {
      if (kDebugMode) {
        print('Error checking pending follow request: $e');
        print(st);
      }
      return false;
    }
  }

  /// Cancel a sent follow request
  Future<void> cancelFollowRequest(String currentUid, String targetUid) async {
    try {
      // Remove from sent requests (current user)
      await _usersCollection.doc(currentUid).update({
        'sentFollowRequests': FieldValue.arrayRemove([targetUid]),
      });

      // Remove from pending requests (target user)
      await _usersCollection.doc(targetUid).update({
        'pendingFollowRequests': FieldValue.arrayRemove([currentUid]),
      });

      if (kDebugMode) {
        print('$currentUid cancelled follow request to $targetUid');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error cancelling follow request: $e');
        print(st);
      }
      rethrow;
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
