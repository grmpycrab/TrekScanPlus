# Badge Display - Testing & Verification Guide

## ✅ What Was Fixed

The `AchievementService` is now automatically initialized when users log in, ensuring achievements are loaded and available immediately on all screens.

### Before Fix
```
Login
  ↓
MainScreen (no initialization)
  ↓
ProfileScreen opens
  ↓
❌ "No achievements unlocked yet" (service never initialized)
```

### After Fix
```
Login
  ↓
MainScreen initializes AchievementService
  ↓
ProfileScreen opens
  ↓
✅ Achievements display correctly (service already initialized)
```

## Testing the Badge Display

### Test 1: View Profile After Login
1. Open the app
2. Log in with your account
3. Tap the Profile icon in bottom navigation
4. **Expected**: 
   - If you have unlocked achievements, they appear in the "Achievements" section
   - Shows count like "X of Y unlocked"
   - Shows percentage completed
   - Displays unlocked badges with unlock dates

### Test 2: View Badges in Settings
1. Log in
2. Tap Settings (last icon in bottom navigation)
3. Badges should display in the main settings view or badge gallery
4. **Expected**:
   - Unlocked badges show colored
   - Locked badges show with lock overlay
   - Can filter by rarity, category, difficulty

### Test 3: Unlock New Badge While App Running
1. Log in
2. Open Scanner screen
3. Scan a station QR code
4. Achievement unlocks and shows notification
5. Navigate to Profile
6. **Expected**: New achievement appears immediately in profile

### Test 4: Multi-Device Sync
1. **Device A**: Log in, scan stations to unlock 3 achievements
2. **Device B**: Log in with same account
3. Navigate to Profile on Device B
4. **Expected**: All 3 achievements from Device A appear on Device B

### Test 5: Different Users on Same Device
1. **User A**: Log in, unlock achievements A1, A2, A3
2. Log out
3. **User B**: Log in
4. Open Profile
5. **Expected**: Only User B's achievements show (NOT A1, A2, A3)
6. Log out, log back in as User A
7. **Expected**: User A's achievements A1, A2, A3 appear again

## Debugging Information

### Check Logs During Login
When the app starts, you should see these log messages:

```
I/flutter ( ####): AchievementService initialized successfully for user: [USER_ID]
I/flutter ( ####): AchievementService initialized in MainScreen
```

If you see these logs, initialization is working correctly.

### Possible Issues & Fixes

**Issue**: Badges still not showing
- **Solution**: Make sure you have unlocked at least one achievement by scanning a station
- **Check**: Settings > Badge Gallery shows any badges at all?

**Issue**: Different badges on different screens
- **Solution**: The services might still be initializing. Wait 2-3 seconds after login before opening Profile
- **Check**: Look at console logs for initialization messages

**Issue**: Old user's badges appearing after logout
- **Solution**: This should not happen anymore (resetInitialization() clears state)
- **Check**: Make sure logged out completely (back to login screen)

**Issue**: Badges not syncing from Firebase
- **Solution**: This requires unlocking achievements on one device and logging in on another
- **Prerequisites**: 
  - Both devices using same Firebase project (check google-services.json)
  - Both devices using same user account
  - Network connectivity available

### Viewing System State

To view what achievements are currently stored, check:

**ProfileScreen Console Output**:
```dart
// In _buildBadgesSection():
final unlockedAchievements = achievementService.getUnlockedAchievements();
// This now calls an initialized service instead of empty list
```

**SharedPreferences Data** (developer mode):
- Achievements stored with key: `local_achievements_[USER_ID]`
- Sync queue stored with key: `achievement_sync_queue_[USER_ID]`
- Pending notifications with key: `achievement_pending_notifications_[USER_ID]`

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│              App Startup                     │
│            (main.dart)                       │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│         User Authenticates                   │
│    (LoginScreen → Firebase Auth)             │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│    StreamBuilder detects user logged in      │
│    (main.dart → MainScreen)                  │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│   MainScreen.initState() → NEW!              │
│   _initializeAchievements()                  │
│   AchievementService.init() ← CALLED HERE   │
└────────────────┬────────────────────────────┘
                 │
     ┌───────────┼───────────┐
     │           │           │
     ▼           ▼           ▼
  HOME     STATIONS     SCANNER
     │           │           │
     └─────┬─────┴─────┬─────┘
           │           │
           ▼           ▼
      PROFILE       SETTINGS
   (Ready to show  (Ready to show
    achievements)   achievements)
```

## Code Changes Summary

### File 1: `lib/screens/main/main_screen.dart`
- Added import: `import '../../services/achievement_service.dart';`
- Added field: `final AchievementService _achievementService = AchievementService();`
- Added `initState()` with `_initializeAchievements()` call
- Achievements load once when app starts

### File 2: `lib/screens/main/profile_screen.dart`
- Added `_initializeAchievements()` method
- Updated `initState()` to call it
- Provides fallback initialization if needed

## Next Steps

1. **Verify**: Run the app and check Profile screen for achievements
2. **Test**: Try the testing scenarios above
3. **Report**: If issues persist, check console logs and report the error message

## Related Services

- **LocalAchievementService**: Manages persistent storage with user-scoped keys
- **AchievementService**: Central logic and Firebase sync
- **FirebaseAuthService**: User authentication
- **ConnectivityService**: Monitors online/offline status
- **StationService**: Manages station data

## Performance Notes

- Achievements loaded once on login (efficient)
- In-memory cache used by all screens (fast access)
- Sync happens in background (doesn't block UI)
- Offline-first approach (uses local cache if offline)

---

**Questions?** Check the logs in VS Code debug console or `flutter logs` terminal for detailed information.
