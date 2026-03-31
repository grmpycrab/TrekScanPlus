# Achievement System - Quick Reference

## How It Works

### User Journey
1. **Scan QR Code** → Station marked as visited
2. **Achievement Check** → System checks if achievement criteria met
3. **Unlock Achievement** → If criteria met, achievement unlocked locally
4. **Show Notification** → Beautiful dialog shows achievement unlocked
5. **Sync to Firebase** → If online, synced to Firebase; if offline, queued for later
6. **Show in Profile** → User sees achievement in profile with unlock date

### Key Files Created

| File | Purpose | Key Features |
|------|---------|--------------|
| `lib/models/achievement.dart` | Achievement data model | Color/icon mapping, serialization |
| `lib/services/achievement_service.dart` | Main business logic | Singleton, criteria checking, Firebase sync |
| `lib/services/local_achievement_service.dart` | Local storage | SharedPreferences, sync queue management |
| `lib/components/achievement_notification.dart` | Notification UI | Dialog and overlay styles, animations |
| `ACHIEVEMENT_SYSTEM.md` | Full documentation | Complete reference guide |

### Integration Points

**1. Scanner Screen** (`scanner_screen.dart`)
```dart
// After marking station as visited
final newlyUnlocked = await achievementService.checkAndUnlockAchievements(
  visitedStations.length,
  visitedStations.map((s) => s.id).toList(),
);

if (newlyUnlocked != null) {
  _showAchievementNotification(newlyUnlocked);
}
```

**2. Profile Screen** (`profile_screen.dart`)
```dart
// Display achievements with unlock dates and stats
final unlockedAchievements = achievementService.getUnlockedAchievements();
final totalAchievements = achievementService.getTotalCount();
// Shows cards with achievement info
```

## Offline-First Architecture

### What Happens Offline
- ✅ Achievements unlock
- ✅ Notifications show
- ✅ Data saved locally
- ⏳ Firebase sync queued
- ⏳ Syncs when online

### What Happens Online
- ✅ Achievements unlock
- ✅ Notifications show
- ✅ Immediate Firebase sync
- ✅ Data visible everywhere

## Achievement Data Structure

### In badge.json
```json
{
  "id": "station1_gate",
  "name": "Limestone Gate Passer",
  "description": "By reaching Station 1...",
  "category": "trail_completion",
  "icon": "footprints",
  "requirement": {
    "type": "stations",
    "value": 1
  },
  "rarity": "common",
  "difficulty": "easy"
}
```

### In Firebase
```
users/{userId}/achievements/{achievementId}
  - id, name, description, category, icon, rarity, difficulty
  - unlockedAt: timestamp
  - syncedAt: server timestamp
```

### In Local Storage (SharedPreferences)
```
'local_achievements' → JSON array of all achievements with unlock status
'achievement_sync_queue' → List of achievement IDs pending Firebase sync
'achievement_pending_notifications' → List of achievement IDs with pending notifications
```

## Rarity Levels & Colors

```
Common     → Gray    (#9E9E9E)   → Early in trail
Uncommon   → Green   (#4CAF50)   → Mid trail
Rare       → Blue    (#2196F3)   → Later stages
Epic       → Purple  (#9C27B0)   → Hard to get
Legendary  → Orange  (#FF9800)   → Final/challenge
```

## How to Add New Achievements

### Step 1: Add to badge.json
```json
{
  "id": "unique_id",
  "name": "Achievement Name",
  "description": "Description",
  "category": "trail_completion",
  "icon": "iconName",
  "requirement": {
    "type": "stations",
    "value": 5
  },
  "rarity": "rare",
  "difficulty": "hard"
}
```

### Step 2: Add icon to Achievement.getIconData()
```dart
case 'yourIconName':
  return Icons.your_icon;
```

### Step 3: Update criteria logic if needed
In `AchievementService._checkAchievementCriteria()`, add custom logic if needed

## API Reference

### AchievementService (Singleton)

```dart
// Initialize
await achievementService.init();

// Check and unlock
Achievement? newUnlocked = await achievementService
  .checkAndUnlockAchievements(stationCount, stationIds);

// Get achievements
List<Achievement> all = achievementService.getAllAchievements();
List<Achievement> unlocked = achievementService.getUnlockedAchievements();
List<Achievement> locked = achievementService.getLockedAchievements();

// Notifications
List<Achievement> pending = await achievementService.getPendingNotifications();
await achievementService.markNotificationAsShown(achievementId);

// Stats
int unlockedCount = achievementService.getUnlockedCount();
int totalCount = achievementService.getTotalCount();

// Manual sync
await achievementService.syncToFirebase();

// Reset (dev only)
await achievementService.resetAll();
```

### LocalAchievementService

```dart
// Initialize
LocalAchievementService localService = await LocalAchievementService.init();

// Save
await localService.saveAchievement(achievement);
await localService.saveAchievements([achievement1, achievement2]);

// Get
List<Achievement> achievements = await localService.getAchievements();
Achievement? achievement = await localService.getAchievementById(id);

// Unlock
await localService.unlockAchievement(achievement);

// Sync queue
List<String> queue = await localService.getSyncQueue();
await localService.addToSyncQueue(achievementId);
await localService.removeFromSyncQueue(achievementId);

// Notifications
List<String> pending = await localService.getPendingNotifications();
await localService.addToPendingNotifications(achievementId);
await localService.removeFromPendingNotifications(achievementId);
```

### Achievement Model

```dart
// Properties
achievement.id                    // Unique identifier
achievement.name                  // Display name
achievement.description          // Full description
achievement.category             // Category type
achievement.icon                 // Icon reference
achievement.requirement          // {type, value}
achievement.rarity               // common/uncommon/rare/epic/legendary
achievement.difficulty           // easy/medium/hard
achievement.isUnlocked          // Whether unlocked
achievement.unlockedAt          // When unlocked (DateTime)
achievement.isNotificationShown // Whether notification shown

// Methods
achievement.getColor()           // Returns color for rarity
achievement.getIconData()        // Returns IconData for icon
achievement.toJson()             // Serialize to JSON
achievement.copyWith(...)        // Create copy with changes
```

## Notification Usage

### Show Full Dialog
```dart
showDialog(
  context: context,
  builder: (context) => AchievementUnlockNotification(
    achievement: achievement,
    onDismiss: () => Navigator.pop(context),
  ),
);
```

### Show Banner (Overlay)
```dart
showDialog(
  context: context,
  builder: (context) => AchievementUnlockOverlay(
    achievement: achievement,
    displayDuration: Duration(seconds: 4),
    onDismiss: () => Navigator.pop(context),
  ),
);
```

## Profile Display

### What Users See
1. **Achievement Stats**: "3 of 8 unlocked (37.5%)"
2. **Recent Achievements**: First 3 with unlock dates
3. **View All Button**: Opens modal with complete list
4. **Locked Achievements**: Shown grayed out with description
5. **Unlock Dates**: Relative format ("2 days ago", "today", etc.)

## Common Scenarios

### Scenario 1: Online Achievement
```
Scan QR → Geofence ✓ → Mark Visited → Check Criteria ✓
  → Unlock → Local Save → Firebase Sync ✓ → Show Notification
```

### Scenario 2: Offline Achievement
```
Scan QR → Geofence ✓ → Mark Visited → Check Criteria ✓
  → Unlock → Local Save → Sync Queue → Show Notification
                              ↓
                    (When Online)
                              ↓
                      Firebase Sync ✓
```

### Scenario 3: App Restart
```
App Starts → Load Achievements → Check Pending Notifications
  → Show Any Pending → Mark as Shown → Sync Queue ✓
```

## Debugging Tips

### Check Sync Queue
```dart
List<String> queue = await localService.getSyncQueue();
AppLogger.i('Pending sync: $queue');
```

### Check Pending Notifications
```dart
List<String> pending = await localService.getPendingNotifications();
AppLogger.i('Pending notifications: $pending');
```

### Check Achievement Status
```dart
Achievement? achievement = achievementService.getAchievementById('id');
AppLogger.i('Unlocked: ${achievement?.isUnlocked}');
AppLogger.i('Notification shown: ${achievement?.isNotificationShown}');
AppLogger.i('Unlocked at: ${achievement?.unlockedAt}');
```

### Force Sync
```dart
await achievementService.syncToFirebase();
```

### Reset All (Dev Only)
```dart
await achievementService.resetAll();
```

## Known Limitations & Future Work

### Current Limitations
- Single achievement per scan (first matching)
- Achievement criteria: stations only (not time-based, difficulty, etc.)
- No progress tracking for multi-step achievements
- No achievement chains or hierarchies

### Planned Features
- Hidden achievements (reveal on unlock)
- Multi-step achievements with progress
- Achievement chains
- Social sharing
- Leaderboards
- Achievement categories filtering
- Background sync service

## Support & Troubleshooting

### Not Seeing Achievements in Profile?
1. Check `achievementService.init()` was called
2. Verify badge.json loaded correctly
3. Check achievements are in local storage
4. Restart app

### Achievements Not Syncing?
1. Check internet connection
2. Verify Firebase rules allow write
3. Check console logs for errors
4. Check sync queue with debug method

### Notifications Not Showing?
1. Verify pending notifications queue
2. Check if already marked as shown
3. Restart app to trigger pending
4. Check notification logic in scanner_screen

