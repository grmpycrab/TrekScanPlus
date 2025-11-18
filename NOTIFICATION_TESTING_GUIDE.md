# Notification System Testing Guide

## Current Implementation Status

The notification system has been enhanced with comprehensive debug logging to trace issues with notification persistence across account switches.

### What Was Fixed

1. **Timestamp Handling**: Notifications now use `FieldValue.serverTimestamp()` instead of client-side local time
2. **Error Handling**: Added try-catch blocks to gracefully handle Firestore query failures
3. **Debug Logging**: Enhanced logging with emoji markers for easy log tracking

### Debug Log Markers

- 🔔 = Notification stream events
- 📤 = Sending notifications
- ✅ = Successful operation
- ❌ = Error occurred
- ⚠️  = Warning/fallback behavior

## Testing Steps to Reproduce Issue & Verify Fix

### Scenario 1: Basic Notification Flow (Same Account)

1. **Login to Account A**
   - Open app and login with first account email/password
   - Wait for "AchievementService initialized" log
   - Watch console for 🔔 logs showing notification stream subscribed

2. **Create a Post**
   - Tap + (floating action button)
   - Select an image from device
   - Add caption
   - Tap Post
   - Verify logs show: "Post created with ID: ..."

3. **Like Your Own Post** 
   - Scroll to find your post
   - Tap the heart icon
   - You should NOT get a notification (Firestore rules prevent self-notifications)
   - Logs should show: "📤 Sending like notification"

### Scenario 2: Cross-Account Notification (Primary Test)

**Prerequisites**: You need 2 separate test accounts

1. **On Device With Account A Logged In**:
   - Tap 🔔 notification bell (top right)
   - Verify notification stream shows 0 notifications
   - Go back home
   - Check console for: "🔔 Home notification bell stream snapshot received"

2. **Switch to Account B**:
   - Tap settings
   - Logout (watch for: "✅ User signed out successfully")
   - Login with Account B credentials
   - Wait for achievements to load
   - Check console for: "🔔 Subscribing to notification stream for user: [Account B ID]"

3. **Account B Creates a Post**:
   - Create a post on Account B
   - Wait for: "Post created with ID: [ID]"
   - Note the post ID for reference

4. **Account B Likes Their Own Post**:
   - Like the post you just created
   - No notification (self-like prevention)

### Scenario 3: Test Notification Persistence (Main Issue)

This tests if notifications persist when you switch accounts and come back.

1. **Account B Goes Offline Temporarily**:
   - Keep Account B logged in
   - Create a post and note its ID
   - Leave the app running or minimize

2. **Switch to Account A**:
   - Logout from Account B
   - Login with Account A
   - Wait for app to fully load

3. **Account A Likes Account B's Post**:
   - Find Account B's post (it should be public)
   - Tap heart to like
   - Console should show:
     ```
     📤 Sending like notification to [Account B ID] from [Account A Name] on post [ID]
     ✅ Created new like notification...
     ```
   - Verify notification was saved to Firestore

4. **Switch Back to Account B**:
   - Logout from Account A  
   - Login back into Account B
   - **CRITICAL POINT**: Check if notification appears!
   - Console should show:
     ```
     🔔 Subscribing to notification stream for user: [Account B ID]
     🔔 Home notification bell stream snapshot received
     🔔 Has data: true, Docs: 1
     ```
   - If you see "Docs: 0" → **Notification didn't persist** (BUG)
   - If you see "Docs: 1" → **Notification persisted** (SUCCESS)

5. **Tap Notification Bell**:
   - Open the NotificationScreen  
   - Should see notification from Account A
   - Console shows full notification details

## Expected Console Output for Successful Flow

### When logging in:
```
AchievementService initialized successfully for user: [USER_ID]
🔔 Subscribing to notification stream for user: [USER_ID]
🔔 Home notification bell stream snapshot received
🔔 Has data: true, Docs: 0
```

### When sending a notification:
```
📤 Sending like notification to [RECIPIENT_ID] from [SENDER_NAME] on post [POST_ID]
✅ Created new like notification for post [POST_ID] from [SENDER_NAME]
```

### When notification arrives:
```
🔔 Home notification bell stream snapshot received
🔔 Has data: true, Docs: 1
🔔 Notification data: {title: New Like, message: [Name] liked your post, ...}
```

## If Notifications Not Appearing

### Check These Logs:

1. **Permission Denied Error**:
   ```
   ❌ Home notification stream error: PlatformException(permission-denied, Missing or insufficient permissions...)
   ```
   - Solution: Check Firestore rules in `firestore.rules`
   - Verify: `users/{userId}/notifications` rules allow user to read their own

2. **No Snapshot Logs**:
   - Notification stream not subscribing at all
   - Check if `if (_firebaseUser != null)` condition is true
   - Verify Firebase Auth is properly initialized

3. **Stream Returns 0 Notifications**:
   - Notification created but query returns nothing
   - Check if 'timestamp' field exists on notifications
   - Verify 'isRead' field is being set correctly

## Firestore Rules (Should Be Set Correctly)

```dart
// Notifications subcollection: users can read/write their own
match /notifications/{notificationId} {
  allow create: if request.auth != null && request.auth.uid == userId;
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
  allow delete: if request.auth != null && request.auth.uid == userId;
}
```

## Files Modified for Debugging

1. `lib/services/notification_services.dart` - Enhanced logging
2. `lib/services/social_sharing_service.dart` - Enhanced logging
3. `lib/screens/main/home_screen.dart` - Added StreamBuilder logging

## Next Steps

1. Run the app with these changes
2. Execute Scenario 3 above
3. Check console output
4. If notifications don't persist:
   - Share the complete console output (looking for 🔔 and ❌ logs)
   - Verify Firestore console shows notifications were created
   - Check if userId is consistent across logout/login cycles

## Manual Firestore Verification

To manually verify notifications are being stored:

1. Go to Firebase Console
2. Navigate to Firestore Database
3. Find: `users` → `[Account B ID]` → `notifications`
4. Should see documents with:
   - `title`: "New Like"
   - `message`: "[Account A Name] liked your post"
   - `isRead`: false
   - `timestamp`: Server time (not client time)

