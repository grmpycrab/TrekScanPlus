# Notification Persistence Fix - Issue & Solution

## Problem Identified

**Issue**: Notifications were not being created when switching between accounts, making it appear as if notifications weren't persisting across account switches.

**Root Cause**: The Firestore security rules were too restrictive on the notifications subcollection. The original rules required that `request.auth.uid == userId` for ALL operations, including `create`.

### Original (Incorrect) Rules:
```dart
match /notifications/{notificationId} {
  allow create: if request.auth != null && request.auth.uid == userId;
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
  allow delete: if request.auth != null && request.auth.uid == userId;
}
```

### The Problem:
When **User A** likes **User B's** post:
1. The app calls `_sendLikeNotification()` with `postOwnerId = User B's ID`
2. The code tries to **write** to `users/[User B ID]/notifications/{notificationId}`
3. **BUT**: User A (the current authenticated user) is trying to write to User B's collection
4. The rule `allow create: if request.auth.uid == userId` **DENIES** this because `request.auth.uid` is User A's ID, not User B's ID
5. Result: **PERMISSION_DENIED error**, notification never created ❌

## Solution

### Updated (Correct) Rules:
```dart
match /notifications/{notificationId} {
  allow create: if request.auth != null; // Any authenticated user can CREATE notifications
  allow read: if request.auth != null && request.auth.uid == userId; // Only owner can READ
  allow write: if request.auth != null && request.auth.uid == userId; // Only owner can UPDATE
  allow delete: if request.auth != null && request.auth.uid == userId; // Only owner can DELETE
}
```

### Why This Works:
- ✅ **Any authenticated user** can create notifications for any other user (for likes/comments/replies)
- ✅ **Only the notification owner** can read their own notifications
- ✅ **Only the notification owner** can update (mark as read) their notifications
- ✅ **Only the notification owner** can delete their notifications
- ✅ **Security maintained**: Unauthorized reads/writes still blocked by owner check

## Implementation Details

### What Changed:
1. Modified `/firestore.rules` - Changed `create` rule from restrictive to permissive
2. Deployed rules to Firebase with: `firebase deploy --only firestore:rules`

### Files Modified:
- `firestore.rules` - Line ~25

### Deployment Status:
✅ **Successfully deployed** to Firebase on [Current Date/Time]

## Testing the Fix

### To Verify Notifications Work:

1. **Login as User A** in the app
2. **Create a post** (or have an existing post)
3. **Logout**
4. **Login as User B**
5. **Like User A's post**
6. **Check the logs** - Should see:
   ```
   📤 Sending like notification to [User A ID] from [User B Name] on post [ID]
   ✅ Created new like notification for post [ID] from [User B Name]
   ```
7. **Logout**
8. **Login back as User A**
9. **Tap the notification bell** - Should see the like notification from User B ✅

### Debug Logs to Expect:

**When notification created (User B liking User A's post):**
```
📤 Sending like notification to [User A ID] from [User B Name] on post [ID]
✅ Created new like notification for post [ID] from [User B Name]
```

**When User A logs back in and views notifications:**
```
🔔 Subscribing to notification stream for user: [User A ID]
🔔 Notifications snapshot received: 1 notifications for [User A ID]
🔔 Notification data: {title: New Like, message: [User B Name] liked your post, ...}
```

## Code Context

### Where Notifications Are Sent:

**File**: `lib/services/social_sharing_service.dart`

**Method**: `toggleLike()`
```dart
// Like
await likeRef.set({...});

// Send notification to post owner (only if it's not their own post)
if (postOwnerId != null && postOwnerId != user.uid) {
  await _sendLikeNotification(
    postOwnerId,  // <-- This is User B's ID
    user.displayName ?? 'Someone',  // <-- This is User A
    postId,
  );
}
```

**Method**: `_sendLikeNotification()`
```dart
Future<void> _sendLikeNotification(
  String postOwnerId,  // User B's ID
  String likerName,     // User A's name
  String postId,
) async {
  try {
    print('📤 Sending like notification to $postOwnerId from $likerName on post $postId');
    
    final notificationRef = _firestore
        .collection('users')
        .doc(postOwnerId)  // <-- Writing to User B's collection
        .collection('notifications');
    
    // Writes to users/[User B ID]/notifications/{notificationId}
    await notificationRef.add(notifMap);
    
    print('✅ Created new like notification for post $postId from $likerName');
  } catch (e) {
    print('❌ Error sending like notification: $e');
  }
}
```

### Firestore Path Structure:
```
users/
  [User A ID]/
    notifications/
      [notification doc 1]  ← User B can CREATE this
      [notification doc 2]  ← User B can CREATE this
  [User B ID]/
    notifications/
      [notification doc 1]  ← User A can CREATE this
```

## Why This Was Missed Initially

The notification system looked correct at first glance because:
1. ✅ The notification creation code was present
2. ✅ The database structure was correct
3. ✅ The UI components were in place
4. ❌ **But**: The Firestore rules silently rejected writes without throwing visible errors

The `print()` and emoji logging added to `_sendLikeNotification()` revealed this by showing:
- 📤 logs showed notification creation was **attempted**
- ❌ No ✅ success logs appeared, meaning creation **failed silently**

## Performance Impact

✅ **No performance degradation** - The rules are actually simpler now (fewer auth checks on create)

## Security Implications

✅ **Security is maintained** because:
- Users cannot read other users' notifications (read rule restricts to owner only)
- Users cannot update other users' notifications (write rule restricts to owner only)
- The `create` rule only requires authentication (not ownership), which is appropriate since notifications are meant to be created BY other users FOR the post owner

## Related Files

- `firestore.rules` - Security rules for database access
- `lib/services/notification_services.dart` - Notification service with logging
- `lib/services/social_sharing_service.dart` - Where notifications are sent
- `lib/screens/main/home_screen.dart` - Where notifications are displayed
- `NOTIFICATION_TESTING_GUIDE.md` - Step-by-step testing instructions

