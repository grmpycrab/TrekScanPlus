# Firebase Achievement Synchronization

## Overview
Achievements are now properly synchronized between local storage and Firebase. This ensures users see their achievements across all devices and login sessions.

## Architecture

### Two-Way Sync
```
Firebase ←→ Local Storage ←→ In-Memory Cache
```

1. **Local → Firebase**: When achievements are unlocked locally
2. **Firebase → Local**: When user logs in on a new device
3. **In-Memory**: Current app session uses cached data

## Data Flow

### Login/Initialization (Firebase → Local)

When `AchievementService.init()` is called:

```dart
1. Load achievements from JSON (badge.json)
2. Merge with LOCAL achievements (preserves local unlock status)
3. Merge with FIREBASE achievements (source of truth for authenticated users)
4. Sync any pending local achievements to Firebase
```

**Result**: User sees all their achievements they unlocked on any device.

### Achievement Unlock (Local → Firebase)

When user visits a station and unlocks an achievement:

```dart
1. Unlock achievement locally
2. Add to local storage
3. Add to Firebase sync queue
4. When online, sync to Firebase
5. Remove from sync queue once synced
```

## Implementation Details

### 1. **Init Sequence** (`achievement_service.dart`)

```dart
Future<void> init({String? userId}) async {
  // 1. Load from JSON
  await _loadAchievementsFromJson();
  
  // 2. Merge with LOCAL data
  await _mergeWithLocalAchievements();
  
  // 3. Merge with FIREBASE data (if authenticated)
  if (currentUserId != null) {
    await _mergeWithFirebaseAchievements(currentUserId);
  }
  
  // 4. Sync pending to Firebase
  await _syncPendingToFirebase();
}
```

### 2. **Firebase Merge** (`_mergeWithFirebaseAchievements`)

- Fetches all achievements from Firestore for current user
- Updates local in-memory list with Firebase unlock status
- Marks notifications as shown (so users don't see duplicate notifications)
- Saves merged data to local storage

```dart
if (firebaseAchievement != null && firebaseAchievement.isUnlocked) {
  _allAchievements[i] = achievement.copyWith(
    isUnlocked: true,
    unlockedAt: firebaseAchievement.unlockedAt,
    isNotificationShown: true, // Don't re-notify for existing achievements
  );
  await _localService.saveAchievement(_allAchievements[i]);
}
```

### 3. **Unlock & Sync** (`_unlockAchievementLocally`)

When achievement is unlocked:

```dart
Future<void> _unlockAchievementLocally(Achievement achievement) async {
  // Unlock locally
  final unlockedAchievement = achievement.copyWith(
    isUnlocked: true,
    unlockedAt: DateTime.now(),
    isNotificationShown: false, // User hasn't seen notification yet
  );
  
  // Save to local storage
  await _localService.unlockAchievement(unlockedAchievement);
  
  // Add to sync queue (will sync when online)
  await _localService.addToSyncQueue(achievement.id);
  
  // Add to pending notifications (user will see the dialog)
  await _localService.addToPendingNotifications(achievement.id);
}
```

### 4. **Firebase Sync** (`_syncPendingToFirebase`)

Syncs achievements from local sync queue to Firebase:

```dart
// For each achievement in sync queue:
1. Get achievement details from local storage
2. Write to Firestore: users/{userId}/achievements/{achievementId}
3. Update user's badges array: users/{userId}.badges
4. Remove from sync queue
5. Continue with next (if one fails, others still sync)
```

## Firebase Structure

### Achievements Collection
```
users/{userId}/achievements/{achievementId}
├── id: "station1_gate"
├── name: "Limestone Gate Passer"
├── description: "..."
├── category: "trail_completion"
├── icon: "footprints"
├── rarity: "common"
├── difficulty: "easy"
├── unlockedAt: "2024-01-15T10:30:00Z"
└── syncedAt: [Server Timestamp]
```

### User Badges Array
```
users/{userId}
├── ...other user data...
├── badges: ["station1_gate", "station2_mossy", "station3_explorer"]
└── ...
```

## Offline Support

### Unlock While Offline
1. Achievement is saved to local storage immediately
2. Added to sync queue
3. User sees unlock notification
4. When device comes online, achievement syncs to Firebase

### Login While Offline
1. User logs in
2. AchievementService loads from local storage only
3. Once online, Firebase achievements are merged
4. Pending achievements are synced to Firebase

## Multi-Device Scenario

**Device A → Device B:**

1. User unlocks achievement on Device A
2. Achievement synced to Firebase
3. User logs in on Device B
4. AchievementService initializes
5. Firebase achievements loaded and merged with local
6. Device B now shows the achievement

## Notification Behavior

**First Time Unlock** (shows notification):
```
isNotificationShown: false
→ User sees achievement unlock dialog
→ Dialog dismissed → isNotificationShown: true
```

**Existing Achievement from Firebase** (no notification):
```
isNotificationShown: true
→ Achievement loaded from Firebase
→ No dialog shown (user already saw it on another device)
```

## Error Handling

### Sync Failures
- Achievements stay in sync queue
- Will retry on next `syncToFirebase()` call
- Partial syncs work (if one fails, others continue)

### Offline
- `_syncPendingToFirebase()` detects offline state
- Returns gracefully without throwing
- Syncs resume when online

### Missing User
- If not authenticated, Firebase sync is skipped
- Local sync queue preserved
- Syncs when user logs in

## Testing Scenarios

### ✅ Single Device, Single User
- [ ] Unlock achievement
- [ ] See notification
- [ ] Achievement appears in profile
- [ ] Check Firestore - data saved

### ✅ Multi-Device, Same User
- [ ] Unlock achievement on Device A
- [ ] Log in on Device B
- [ ] Achievement appears without notification
- [ ] User sees correct unlock date

### ✅ Offline Unlock
- [ ] Go offline
- [ ] Unlock achievement
- [ ] See notification
- [ ] Achievement in local storage
- [ ] Come online
- [ ] Achievement syncs to Firebase

### ✅ New Device Login
- [ ] Create achievement on Device A and sync
- [ ] Factory reset Device A
- [ ] Log in on Device A with same account
- [ ] Achievement loads from Firebase
- [ ] User doesn't see duplicate notification

### ✅ Device Switch
- [ ] Unlock 3 achievements on Device A
- [ ] All sync to Firebase
- [ ] Unlock 2 more on Device B
- [ ] Both synced to Firebase
- [ ] Switch back to Device A
- [ ] All 5 achievements visible

## API Methods

```dart
// Initialize (called on app startup/login)
await achievementService.init(userId: currentUser.uid);

// Get achievements
List<Achievement> all = achievementService.getAllAchievements();
List<Achievement> unlocked = achievementService.getUnlockedAchievements();
List<Achievement> locked = achievementService.getLockedAchievements();

// Sync manually (usually automatic)
await achievementService.syncToFirebase();

// Fetch from Firebase (called internally during init)
List<Achievement> firebase = await achievementService.fetchFromFirebase();

// Reset (for testing only)
await achievementService.resetAll();
```

## Performance Notes

- Achievements are fetched once during `init()`
- Subsequent operations use in-memory cache
- Firebase writes are batched in sync queue
- Offline-first approach minimizes network calls

## Future Enhancements

1. **Real-time Sync**: Use Firestore listeners for instant cross-device updates
2. **Selective Sync**: Only sync modified achievements
3. **Compression**: Compress achievement data for bandwidth optimization
4. **Analytics**: Track achievement unlock patterns for game balance
5. **Leaderboards**: Add per-achievement unlock leaderboards
