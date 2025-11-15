# Achievement System - Setup & Integration Guide

## Overview

This guide walks through the complete achievement system setup, including how achievements are loaded, unlocked, synced, and displayed.

## Files Created/Modified

### New Files
1. **`lib/models/achievement.dart`**
   - Achievement data model with serialization
   - Color and icon mapping for UI

2. **`lib/services/achievement_service.dart`**
   - Main singleton service
   - Handles achievement logic, criteria checking, and Firebase sync
   - **Imports**: cloud_firestore, firebase_auth, connectivity_plus

3. **`lib/services/local_achievement_service.dart`**
   - Local storage service using SharedPreferences
   - Manages sync queue and pending notifications
   - **Imports**: shared_preferences

4. **`lib/components/achievement_notification.dart`**
   - Beautiful notification UI components
   - Two styles: Full dialog and overlay banner
   - Animations and auto-dismiss

### Modified Files
1. **`lib/screens/main/scanner_screen.dart`**
   - Added achievement service initialization
   - Added achievement checking after station visited
   - Shows notification on achievement unlock
   - **New imports**: achievement_service, achievement_notification

2. **`lib/screens/main/profile_screen.dart`**
   - Integrated achievement service
   - Replaced badges section with achievements display
   - Shows unlock dates and stats
   - Added "View All Achievements" dialog

## Initialization Flow

### On App Startup

```dart
// In main.dart or app initialization
AchievementService achievementService = AchievementService();
await achievementService.init();
```

**What happens during init():**
1. LocalAchievementService initialized
2. Achievements loaded from `assets/data/badge.json`
3. Merged with local stored achievements (preserving unlock status)
4. Pending achievements synced to Firebase if online
5. Service ready for use

### In ScannerScreen

```dart
@override
void initState() {
  // ... other initialization
  achievementService = AchievementService();
  await achievementService.init();
}
```

### In ProfileScreen

```dart
@override
void initState() {
  super.initState();
  achievementService = AchievementService();
  // Achievement data loaded on demand when building UI
}
```

## Achievement Unlock Flow

### Step 1: Station QR Scan
User scans QR code at station location

### Step 2: Geofence Verification
```dart
if (station.latitude != null && station.longitude != null) {
  final geofenceResult = await GeofencingService.checkGeofence(...);
  if (!geofenceResult.isWithinGeofence) {
    // Show geofence failure, don't proceed
    return;
  }
}
```

### Step 3: Mark Station Visited
```dart
await stationService.updateStationVisited(code, true);
```

### Step 4: Check Achievement Criteria
```dart
final visitedStations = stationService.getVisitedStations();
final newlyUnlocked = await achievementService.checkAndUnlockAchievements(
  visitedStations.length,
  visitedStations.map((s) => s.id).toList(),
);
```

**Achievement Criteria Checking:**
- Gets all achievements not yet unlocked
- Checks requirement type and value
- Currently supports: `type: 'stations'` (e.g., reach 3 stations)
- Returns first matching achievement or null

### Step 5: Show Notification
```dart
if (newlyUnlocked != null) {
  _showAchievementNotification(newlyUnlocked);
}
```

**Notification Display:**
```dart
void _showAchievementNotification(Achievement achievement) {
  // Mark notification as pending (if offline)
  achievementService.markNotificationAsShown(achievement.id);
  
  // Show dialog
  showDialog(
    context: context,
    builder: (context) => AchievementUnlockNotification(
      achievement: achievement,
      onDismiss: () => Navigator.pop(context),
    ),
  );
}
```

## Offline-First Sync Strategy

### Local Storage Queues

**Achievement Sync Queue** (`achievement_sync_queue`)
```
Purpose: Track achievements needing Firebase sync
Storage: List<String> (achievement IDs)
Trigger: Achievement unlocked while offline
```

**Pending Notifications Queue** (`achievement_pending_notifications`)
```
Purpose: Track achievements needing notification display
Storage: List<String> (achievement IDs)
Trigger: Achievement unlocked, notification not yet shown
```

### Sync Process

#### When Achievement Unlocked

1. **LocalAchievementService.unlockAchievement()**
   ```dart
   await _localService.unlockAchievement(achievement);
   // Sets isUnlocked=true, unlockedAt=now, isNotificationShown=false
   // Adds to sync queue
   // Adds to pending notifications
   ```

2. **Save to Local Storage**
   ```dart
   await _localService.saveAchievement(updatedAchievement);
   // Updates SharedPreferences with new state
   ```

3. **Attempt Firebase Sync**
   ```dart
   await achievementService._syncPendingToFirebase();
   // If online: sync to Firebase, remove from queue
   // If offline: keep in queue for later
   ```

#### When App Online

1. **On Init** - automatic sync:
   ```dart
   await _syncPendingToFirebase();
   ```

2. **Manual Trigger**:
   ```dart
   await achievementService.syncToFirebase();
   ```

3. **Firebase Sync Process**:
   - Check internet connectivity
   - Get current user ID
   - For each achievement in sync queue:
     - Write to `users/{uid}/achievements/{achievementId}`
     - Update `users/{uid}.badges` array
     - Remove from local sync queue
     - Log success/failure

### Notification Dispatch

1. **Pending Notification Stored**:
   ```dart
   await _localService.addToPendingNotifications(achievementId);
   ```

2. **On App Start** - check pending:
   ```dart
   List<Achievement> pending = await achievementService.getPendingNotifications();
   // Show notifications for each
   ```

3. **After Showing**:
   ```dart
   await achievementService.markNotificationAsShown(achievementId);
   // Removes from pending queue
   // Sets isNotificationShown=true in local storage
   ```

## Data Storage Structure

### SharedPreferences Keys

#### `local_achievements`
```json
[
  {
    "id": "station1_gate",
    "name": "Limestone Gate Passer",
    "isUnlocked": true,
    "unlockedAt": "2024-01-15T10:30:00Z",
    "isNotificationShown": true
  },
  ...
]
```

#### `achievement_sync_queue`
```
["station1_gate", "station3_explorer"]
```

#### `achievement_pending_notifications`
```
["station2_mossy"]
```

### Firebase Structure

#### Path: `users/{userId}/achievements/{achievementId}`
```json
{
  "id": "station1_gate",
  "name": "Limestone Gate Passer",
  "description": "Every journey begins with a single brave step...",
  "category": "trail_completion",
  "icon": "footprints",
  "rarity": "common",
  "difficulty": "easy",
  "unlockedAt": "2024-01-15T10:30:00Z",
  "syncedAt": 1705321200000  // Server timestamp
}
```

#### Path: `users/{userId}`
```json
{
  "badges": ["station1_gate", "station2_mossy", "station3_explorer"],
  ...
}
```

## Criteria Logic

### Current Implementation

```dart
bool _checkAchievementCriteria(
  Achievement achievement,
  int stationsVisited,
) {
  final requirement = achievement.requirement;
  final type = requirement['type'] as String?;
  final value = requirement['value'] as int?;

  if (type == null || value == null) return false;

  switch (type) {
    case 'stations':
      // Unlock at specific station count
      return stationsVisited >= value;
    case 'completion':
      // Unlock on trail completion (8 stations)
      return stationsVisited >= 8;
    default:
      return false;
  }
}
```

### Example Achievement Requirements

```json
// Unlock at 1st station
{"type": "stations", "value": 1}

// Unlock at 3rd station  
{"type": "stations", "value": 3}

// Unlock at trail end
{"type": "completion", "value": 8}
```

### Adding New Criteria Types

To add new criteria (e.g., time-based):

1. **Update badge.json**:
   ```json
   {"type": "time_minutes", "value": 120}
   ```

2. **Update criteria logic**:
   ```dart
   case 'time_minutes':
     return elapsedTimeMinutes >= value;
   ```

3. **Pass data to check method**:
   ```dart
   await achievementService.checkAndUnlockAchievements(
     visitedStations.length,
     stationIds,
     elapsedTime: duration.inMinutes,
   );
   ```

## UI Integration

### Profile Screen Display

**Achievement Stats Row**
- Shows "X of Y unlocked"
- Progress percentage
- Color-coded by achievement rarity

**Recent Achievements Cards**
- First 3 unlocked achievements
- Icon matching achievement
- Achievement name
- Unlock date in relative format
- Rarity badge

**View All Button**
- Opens full achievements modal
- Shows all achievements (locked and unlocked)
- Locked achievements grayed out
- Unlock dates for completed ones

### Notification Styles

**Full Dialog** (`AchievementUnlockNotification`)
- Centered modal dialog
- Large icon and achievement name
- Full description
- Auto-dismiss after 5 seconds
- Scale and fade animations

**Banner** (`AchievementUnlockOverlay`)
- Top banner style
- Icon on left, name on right
- Close button
- Auto-dismiss after 4 seconds
- Slide down animation

## Error Handling

### Network Errors
```dart
try {
  await _firestore.collection('users').doc(userId).update(...);
} catch (e) {
  print('Error syncing achievement: $e');
  // Achievement stays in sync queue for retry
}
```

### Storage Errors
```dart
try {
  await prefs.setString(ACHIEVEMENTS_KEY, jsonEncode(jsonList));
} catch (e) {
  print('Error saving achievement: $e');
  rethrow;
}
```

### Initialization Errors
```dart
try {
  await achievementService.init();
} catch (e) {
  print('Error initializing AchievementService: $e');
  // Fall back to empty achievements list
  rethrow;
}
```

## Testing Scenarios

### Test 1: Online Achievement Unlock
1. Device online
2. Scan station QR
3. ✓ Achievement unlocked
4. ✓ Notification shows
5. ✓ Appears in profile
6. ✓ Synced to Firebase

### Test 2: Offline Achievement Unlock
1. Device offline
2. Scan station QR
3. ✓ Achievement unlocked
4. ✓ Notification shows
5. ✓ Appears in profile (local)
6. Turn device online
7. ✓ Auto-synced to Firebase
8. ✓ Appears in Firebase

### Test 3: App Restart with Pending Notification
1. Unlock achievement offline
2. Notification shown
3. Close app without dismissing notification
4. Reopen app
5. ✓ Achievement still shown in profile
6. Check pending notifications queue
7. ✓ Notification re-displayed on next session

### Test 4: Multiple Achievements
1. Scan enough stations to unlock 2+ achievements
2. ✓ First achievement unlocks and shows notification
3. ✓ Second achievement added to queue
4. ✓ Both visible in profile

### Test 5: Firebase Sync Recovery
1. Unlock achievement while offline
2. Turn on airplane mode
3. Turn off airplane mode
4. Check Firebase after sync
5. ✓ Achievement synced successfully

## Debugging Helpers

### Check Local Cache
```dart
List<Achievement> local = await localService.getAchievements();
print('Local achievements: ${local.length}');
for (var a in local) {
  print('${a.name}: ${a.isUnlocked} (${a.unlockedAt})');
}
```

### Check Sync Queue
```dart
List<String> queue = await localService.getSyncQueue();
print('Pending sync: $queue');
```

### Check Pending Notifications
```dart
List<String> pending = await localService.getPendingNotifications();
print('Pending notifications: $pending');
```

### Force Complete Sync
```dart
await achievementService.syncToFirebase();
print('Sync completed');
```

### Check Firebase
```dart
// In Firebase Console → users → {userId} → achievements
// Should see synced achievement documents
```

## Performance Considerations

- Achievements loaded once on init (singleton)
- Local storage queries fast (SharedPreferences)
- Firebase sync batched when possible
- Notifications don't block UI (async)
- Profile display lazy-loads achievement data

## Security Notes

- Firebase rules should allow user to write own achievements
- Achievements synced only from local service (trusted source)
- No client-side validation bypass (criteria checked server-side)
- Achievement timestamps immutable (set at unlock time)

## Troubleshooting Checklist

- [ ] Achievement service initialized before use
- [ ] badge.json file present and valid JSON
- [ ] Icons in badge.json exist in getIconData()
- [ ] Firebase rules allow write to achievements collection
- [ ] SharedPreferences permissions granted
- [ ] Local achievement service initialized before use
- [ ] Geofence check passing before achievement check
- [ ] Station visit recorded before achievement check
- [ ] Notification dismissal calling markNotificationAsShown()
- [ ] Profile screen not caching stale achievement data

