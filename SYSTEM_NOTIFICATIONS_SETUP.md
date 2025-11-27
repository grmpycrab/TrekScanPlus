# System Notifications Setup - Final Steps

## ✅ Completed

### Backend Cloud Function
- **File**: `functions/index.js`
- **Added**: `sendBookingStatusNotification` function
- **Functionality**: Triggers on booking updates, fetches user's FCM token, sends FCM messages
- **Status**: Code added, ready to deploy

### Flutter App - FCM Token Management
- **File**: `lib/services/notification_service.dart`
- **Updates**:
  1. `initialize()` now calls `getFCMToken()` to save token on app startup
  2. `getFCMToken()` retrieves token and saves to Firestore under `users/{userId}/fcmToken`
  3. `_saveFCMTokenToFirestore()` handles token updates
  4. `onTokenRefresh` listener updates Firestore when FCM token changes
  5. `lastTokenUpdate` timestamp stored for debugging

### Flow
```
1. User logs in → App initializes NotificationService
2. NotificationService.initialize() called → getFCMToken() executes
3. FCM token retrieved and saved to: users/{userId}/fcmToken
4. Cloud Function monitors bookings collection
5. Admin updates booking status → Cloud Function triggers
6. Cloud Function queries users/{userId}/fcmToken
7. FCM message sent to device
8. System notification appears (even if app closed)
9. If app is running, FCM also triggers in-app handlers
```

## 📋 Immediate Next Steps

### Step 1: Deploy Cloud Function to Firebase
```bash
cd functions
firebase deploy --only functions:sendBookingStatusNotification
```

**Expected Output**:
```
✔  Deploy complete!

Function URL: ...
```

**Verification**:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to Functions
4. Verify `sendBookingStatusNotification` is deployed with status "Running"

### Step 2: Build and Run Updated App
The updated NotificationService will automatically:
- Get FCM token on initialization
- Save it to Firestore
- Listen for token refreshes
- Update Firestore when token changes

```bash
flutter pub get
flutter run
```

**Verification**:
1. Check app logs for: `✅ [NotificationService] FCM Token saved to Firestore`
2. Go to Firebase Console → Firestore → Collections → users
3. Find logged-in user's document
4. Verify `fcmToken` field exists with a long token string
5. Verify `lastTokenUpdate` timestamp is current

### Step 3: End-to-End Testing

**Prerequisite**: Must have both Cloud Function deployed AND app running once to save FCM token

**Test Scenario 1** - App Open (In-App Notification):
1. Keep app open
2. Open [Firebase Admin Dashboard](https://your-admin-dashboard.com) in browser
3. Find any pending booking
4. Change status to: "Approved", "Rejected", or "Changes Required"
5. Look at app - should see notification banner immediately

**Expected Result**: ✅ Notification appears in app within 1-2 seconds

**Test Scenario 2** - App Closed (System Notification):
1. Close app completely (kill the process, not just minimize)
2. Open Admin Dashboard in browser
3. Change booking status for the logged-in user
4. Look at phone home screen/notification area
5. System notification should appear

**Expected Result**: ✅ Notification appears on phone even though app is closed

**Test Scenario 3** - App in Background:
1. Open app, go through login
2. Press Home button (don't kill, just background)
3. From Admin Dashboard, update a booking
4. Bring app to foreground
5. Should see notification (either banner or system depending on Android version)

**Expected Result**: ✅ Notification received

## 🔍 Debugging if Notifications Don't Work

### Check 1: FCM Token Stored?
1. Firebase Console → Firestore → Collections → users
2. Click on current user's document
3. Look for `fcmToken` field
4. If missing: Logs show `❌ [NotificationService] Failed to get FCM token` - check permissions
5. If present: Token saved correctly, proceed to Check 2

### Check 2: Cloud Function Deployed?
1. Firebase Console → Functions
2. Look for `sendBookingStatusNotification` 
3. If red X: Click function name to see error logs
4. If green checkmark: Function deployed, proceed to Check 3

### Check 3: Cloud Function Triggered?
1. Firebase Console → Functions
2. Click `sendBookingStatusNotification` → Logs
3. Update a booking from Admin Dashboard
4. Refresh logs - should see new entries
5. If no logs: Check that you're updating booking for user with stored FCM token
6. If logs show errors: Check error message and see "Common Errors" below

### Check 4: Android Permissions
1. Settings → Apps → TrekScanPlus → Notifications
2. Verify "Allow notifications" is enabled
3. Verify notification channel for app is enabled

### Check 5: FCM Service
1. Firebase Console → Cloud Messaging → Overview
2. Verify service is enabled

## ⚠️ Common Errors & Solutions

### Error: "User document has no fcmToken field"
**Cause**: App was upgraded but user hasn't logged in again
**Solution**: 
1. In app, log out and log back in
2. This triggers NotificationService.initialize() → saves token
3. Check Firestore to verify fcmToken now exists

### Error: "admin is not defined" in Cloud Function logs
**Cause**: Missing Firebase Admin SDK initialization
**Solution**: 
1. Ensure `const admin = require('firebase-admin');` at top of functions/index.js
2. Ensure `admin.initializeApp();` is called
3. Redeploy: `firebase deploy --only functions`

### Error: "getToken() returns null"
**Cause**: 
- App not properly configured for FCM
- Google Play Services not installed on test device
- Permissions not granted
**Solution**:
1. Ensure `google-services.json` is in `android/app/`
2. Verify `android/build.gradle` has Firebase dependencies
3. On test device: Settings → Google → Manage Google Account → Verification → Verify device
4. Reinstall app: `flutter clean && flutter run`

### Error: "Cloud Function executed but no notification received"
**Cause**:
- Notification channel not created (Android)
- Permissions not granted (Android 13+)
- Invalid FCM token
**Solution**:
1. Check app logs for `✅ [NotificationService] Firebase Cloud Messaging initialized`
2. Check `⚡ [NotificationService] Android notification channel created successfully`
3. Check phone settings: Settings → Notifications → TrekScanPlus → Allowed

## 📊 Testing Checklist

- [ ] Cloud Function deployed to Firebase
- [ ] App rebuilt and runs without errors
- [ ] App logs show: `✅ [NotificationService] FCM token saved to Firestore`
- [ ] Firestore user document has `fcmToken` field with a token string
- [ ] In-app notification works when app open (existing feature, should already work)
- [ ] System notification appears when app closed (new feature)
- [ ] System notification appears when app in background
- [ ] Multiple booking status changes tested (Approved, Rejected, Changes Required)
- [ ] Tested with different test users

## 📝 Code Reference

### NotificationService Changes
**Location**: `lib/services/notification_service.dart`

```dart
// On initialization
Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _initializeFirebaseMessaging();
    await getFCMToken();  // ← NEW: Saves token to Firestore
}

// Get and save token
Future<String?> getFCMToken() async {
    final token = await _firebaseMessaging.getToken();
    // ← NEW: Saves to users/{userId}/fcmToken
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'fcmToken': token, 'lastTokenUpdate': DateTime.now()}, 
             SetOptions(merge: true));
    return token;
}

// Listen for token refresh
_firebaseMessaging.onTokenRefresh.listen((newToken) {
    // ← NEW: Updates token when it changes
    _saveFCMTokenToFirestore(newToken);
});
```

### Cloud Function Changes
**Location**: `functions/index.js`

```javascript
exports.sendBookingStatusNotification = functions
    .region(region)
    .firestore
    .document('bookings/{bookingId}')
    .onUpdate(async (change, context) => {
        // Checks if status changed
        // Gets user's FCM token from Firestore
        // Sends FCM message with formatted notification
        // Updates notification based on status:
        // - "approved" → ✅ Booking Approved
        // - "rejected" → ❌ Booking Rejected  
        // - "changes_required" → ⚠️ Changes Required
        // - "pending" → ⏳ Booking Update
    });
```

## 🎯 Success Indicators

✅ **Deployment Complete When**:
1. Cloud Function shows "Running" in Firebase Console
2. App logs show FCM token saved message
3. Firestore shows fcmToken in user documents
4. System notifications appear on phone when booking updated (even if app closed)

✅ **System Notifications Working When**:
1. Close app completely
2. Update booking from admin dashboard
3. Phone notification appears within 2-3 seconds
4. Click notification → App opens to booking detail

## 📞 Support

If notifications still don't work after all checks:
1. Check Firebase Cloud Messaging logs in Console
2. Verify Android notification channel created: `adb shell dumpsys notification | grep booking_updates`
3. Check device notification settings aren't silenced
4. Verify all Firebase dependencies are latest versions
5. Try on a different device to rule out device-specific issues

---

**Summary**: The backend Cloud Function and app token management are now set up. Just deploy the function and verify FCM tokens are being saved to Firestore. Then test!
