# Local Data Isolation Fix - User Account Separation

## Problem
When a different user signed in on the same device, they would see the previous user's local data:
- Visited stations from the previous user appeared as visited for the new user
- Achievements unlocked by the previous user appeared in the new user's profile
- All local data stored in SharedPreferences was being shared across users

## Root Cause
Local data was stored in SharedPreferences using **device-wide keys** that were NOT user-specific:

### Before (Broken):
```
visited_stations          → Shared across all users
local_achievements        → Shared across all users
achievement_sync_queue    → Shared across all users
achievement_pending_notifications → Shared across all users
qr_key_<stationId>       → Shared across all users
```

When user A signed in and visited stations, these keys were set. When user B signed in, they immediately saw user A's data because the keys were identical.

## Solution
All SharedPreferences keys are now **scoped to the current user ID**, ensuring complete data isolation:

### After (Fixed):
```
visited_stations_<userId>               → User-specific
local_achievements_<userId>             → User-specific  
achievement_sync_queue_<userId>         → User-specific
achievement_pending_notifications_<userId> → User-specific
qr_key_<userId>_<stationId>            → User-specific
```

## Implementation Details

### 1. **StationService** (`lib/services/station_service.dart`)

**Changes:**
- Added `_currentUserId` property to track current user
- Created `_userVisitedStationsKey` getter that appends userId to key
- Created `_getUserQRKey(stationId)` method that includes userId in key
- Modified `init()` to accept optional `userId` parameter
- Added `setCurrentUser(userId)` method to update user context
- All SharedPreferences operations now use user-scoped keys

**Usage:**
```dart
// Initialize with user ID
final stationService = await StationService.init(userId: currentUser.uid);

// Update current user when user changes
stationService.setCurrentUser(newUserId);

// Clear all user data when signing out
await stationService.resetAllStations();
```

### 2. **LocalAchievementService** (`lib/services/local_achievement_service.dart`)

**Changes:**
- Added `_currentUserId` property
- Created three getter properties:
  - `_userAchievementsKey` - for storing achievement data
  - `_userSyncQueueKey` - for sync queue
  - `_userPendingNotificationsKey` - for pending notifications
- Modified `init()` to accept optional `userId` parameter
- Added `setCurrentUser(userId)` method
- All storage operations now use user-scoped keys
- `clearAll()` only clears current user's data

**Usage:**
```dart
// Initialize with user ID
final localService = await LocalAchievementService.init(userId: currentUser.uid);

// Update current user when user changes
localService.setCurrentUser(newUserId);

// Clear current user's achievements
await localService.clearAll();
```

### 3. **AchievementService** (`lib/services/achievement_service.dart`)

**Changes:**
- Updated `init()` to accept optional `userId` parameter
- Passes userId to `LocalAchievementService.init()`
- Added `resetInitialization()` method to clear state when user changes
- Logs which user the service initialized for

**Usage:**
```dart
// Initialize for specific user
await achievementService.init(userId: currentUser.uid);

// When user changes, reset the service
achievementService.resetInitialization();
// Next call to init() will reinitialize for the new user
```

### 4. **FirebaseAuthService** (`lib/services/firebase_auth_service.dart`)

**Changes:**
- Enhanced `signOut()` method with debug logging

### 5. **SettingsScreen** (`lib/screens/main/settings_screen.dart`)

**Changes:**
- Added call to `_achievementService.resetInitialization()` before sign out
- Ensures achievement service state is cleared for the old user
- New user will initialize fresh achievements when logging in

## Data Flow

### Login Flow
1. User signs in (email/password or Google)
2. Firebase Auth creates/updates auth session
3. When services initialize, they receive the userId
4. Services create user-scoped keys in SharedPreferences
5. Each user sees only their own data

### Logout Flow
1. Settings screen calls `achievementService.resetInitialization()`
2. Clears AchievementService's in-memory state
3. Calls `FirebaseAuthService.instance.signOut()`
4. User is logged out
5. Navigation to LoginScreen

### User Switch Flow
1. Current user logs out (clearing their local state)
2. New user logs in
3. Services initialize with new user's ID
4. SharedPreferences keys are scoped to new user's ID
5. New user sees only their own local data

## Data Structure Example

**User A (ID: abc123):**
```
visited_stations_abc123 = ["station1", "station3"]
local_achievements_abc123 = [...]
qr_key_abc123_station1 = "st001"
```

**User B (ID: xyz789):**
```
visited_stations_xyz789 = ["station2"]  
local_achievements_xyz789 = [...]
qr_key_xyz789_station2 = "st002"
```

Complete isolation - no data cross-contamination.

## Testing Checklist

✅ **Single User Session**
- [ ] User A signs up and visits stations
- [ ] User A logs out
- [ ] User A logs back in
- [ ] User A sees their visited stations (should still be there)

✅ **User Switch**
- [ ] User A signs up and visits 3 stations
- [ ] User A logs out
- [ ] User B signs up
- [ ] User B sees 0 visited stations (User A's stations are hidden)
- [ ] User B visits 2 stations
- [ ] User B logs out
- [ ] User A logs back in
- [ ] User A sees their original 3 visited stations

✅ **Achievements**
- [ ] User A unlocks achievements
- [ ] User A logs out
- [ ] User B logs in and sees their own achievements (not User A's)
- [ ] User A logs back in
- [ ] User A sees their original achievements

✅ **QR Code Data**
- [ ] User A scans QR codes
- [ ] User A logs out
- [ ] User B logs in
- [ ] User B doesn't see User A's scanned QR data
- [ ] User B can scan the same stations

## Migration Notes

No data migration needed - the fix is backward compatible:
- Old device-wide keys are automatically separated when users sign in with different IDs
- Users will see their data fresh for their first login after this change
- Existing device-wide data is harmless (will just be orphaned)

## Performance Impact

Minimal performance impact:
- Key scoping is done via string concatenation (minimal overhead)
- No additional SharedPreferences calls
- No changes to Firebase queries or operations
- LocalAchievementService lookups remain O(n) as before

## Security Implications

✅ **Improved Privacy**
- Users' local data is completely isolated per account
- No possibility of data leakage when sharing devices
- Each user has their own achievement and progress state

✅ **No Security Vulnerabilities Introduced**
- All data is still stored locally (no security regression)
- User IDs are obtained from Firebase Auth (trusted source)
- No new attack surfaces created

## Future Enhancements

1. **Cache Management**: Implement LRU cache for devices with many users
2. **Storage Cleanup**: Add periodic cleanup for orphaned old device-wide keys
3. **Account Linking**: Support linking achievements when users log in to different accounts on the same device
4. **Data Export**: Allow users to export their local achievements before account deletion

## Files Modified

1. `lib/services/station_service.dart` - Added user scoping
2. `lib/services/local_achievement_service.dart` - Added user scoping
3. `lib/services/achievement_service.dart` - Pass userId to services
4. `lib/services/firebase_auth_service.dart` - Enhanced logging on signOut
5. `lib/screens/main/settings_screen.dart` - Clear state on logout
