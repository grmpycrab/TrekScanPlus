# Quick Deployment Guide - System Notifications

## One-Command Deployment

### 1️⃣ Deploy Cloud Function
Open terminal in project root and run:
```bash
cd functions
firebase deploy --only functions:sendBookingStatusNotification
```

Wait for completion message.

### 2️⃣ Rebuild Flutter App
```bash
cd ..
flutter clean
flutter pub get
flutter run
```

### 3️⃣ Quick Verification
After app opens:
1. Check logs for: `✅ [NotificationService] FCM token saved to Firestore`
2. Open Firebase Console → Firestore → Collections → users
3. Find your user → Should see `fcmToken` field with a token string

### 4️⃣ Test Notifications
**Close App** → Update booking from admin → **Check phone for notification**

---

## What Changed

### Backend (`functions/index.js`)
- ✅ NEW `sendBookingStatusNotification` function added
- Triggers when booking status changes
- Sends FCM message to user's device

### Frontend (`lib/services/notification_service.dart`)
- ✅ `initialize()` now saves FCM token to Firestore on app startup
- ✅ `getFCMToken()` retrieves and saves token
- ✅ `onTokenRefresh` listener handles token changes
- ✅ `_saveFCMTokenToFirestore()` updates user document

---

## Expected Results

✅ **App Logs** (first time running updated version):
```
🔑 [NotificationService] FCM Token: eN8JQI2qCXI...
💾 [NotificationService] FCM token saved to Firestore
✅ [NotificationService] Initialized successfully
```

✅ **Firestore User Document** (should have these new fields):
```json
{
  "fcmToken": "eN8JQI2qCXI...",
  "lastTokenUpdate": Timestamp(...)
}
```

✅ **System Notification** (when booking updated with app closed):
- Notification appears on phone home screen
- Title: "✅ Booking Approved" / "❌ Booking Rejected" / "⚠️ Changes Required"
- Can click to open app

---

## Troubleshooting Quick Links

| Issue | Check |
|-------|-------|
| Cloud Function won't deploy | `firebase deploy --debug` to see detailed error |
| FCM token not saving | App logs show error? Check user is logged in |
| No notifications on phone | Verify fcmToken exists in Firestore user document |
| Notifications only in-app | Cloud Function may not be deployed - check Firebase Console |
| Notification shows but wrong title | Check Cloud Function is using correct status values |

---

**That's it!** Notifications should now work even when app is closed. 🎉
