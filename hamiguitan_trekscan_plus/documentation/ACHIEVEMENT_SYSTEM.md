# Achievement System Documentation

## Overview

The achievement system in TrekScanPlus is a comprehensive gamification feature that rewards users for completing stations along the trail. The system includes:

- **Offline-First Architecture**: Achievements are unlocked locally and synced to Firebase when online
- **Persistent Storage**: Uses SharedPreferences for local caching
- **Real-Time Notifications**: Beautiful animated notifications when achievements are unlocked
- **Profile Integration**: Displays all achievements with unlock dates on user profile
- **Automatic Syncing**: Background sync to Firebase when internet connection is restored

## System Architecture

### Core Components

#### 1. **Achievement Data Model** (`lib/models/achievement.dart`)
Represents a single achievement with all metadata:

```dart
class Achievement {
  final String id;
  final String name;
  final String description;
  final String category;
  final String icon;
  final Map<String, dynamic> requirement;
  final String rarity; // common, uncommon, rare, epic, legendary
  final String difficulty; // easy, medium, hard
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final bool isNotificationShown;
}
```

**Key Features:**
- `getColor()`: Returns color based on rarity level
- `getIconData()`: Returns Material icon based on icon name
- `toJson()` / `fromJson()`: Serialization for storage and Firebase

#### 2. **Local Achievement Service** (`lib/services/local_achievement_service.dart`)
Handles all local storage operations using SharedPreferences.

**Key Methods:**
- `saveAchievement()`: Save individual achievement locally
- `saveAchievements()`: Bulk save achievements
- `getAchievements()`: Retrieve all achievements from local storage
- `unlockAchievement()`: Mark achievement as unlocked and queue for sync
- `getSyncQueue()`: Get list of achievements pending Firebase sync
- `getPendingNotifications()`: Get achievements waiting to show notification
- `addToSyncQueue()`: Add achievement ID to sync queue
- `removeFromSyncQueue()`: Remove after successful Firebase sync

**Storage Keys:**
```
achievements_key = 'local_achievements'           // All achievements
sync_queue_key = 'achievement_sync_queue'         // Pending Firebase sync
pending_notifications_key = 'achievement_pending_notifications'  // Pending UI notifications
```

#### 3. **Achievement Service** (`lib/services/achievement_service.dart`)
Main service handling business logic, criteria checking, and Firebase syncing.

**Singleton Pattern**: Uses singleton to ensure single instance across app

**Key Methods:**
- `init()`: Initialize service, load achievements from JSON, merge with local state
- `checkAndUnlockAchievements()`: Check if user qualifies for any achievements
- `syncToFirebase()`: Manually trigger Firebase sync
- `getUnlockedAchievements()`: Get list of unlocked achievements
- `getLockedAchievements()`: Get list of locked achievements
- `getPendingNotifications()`: Get achievements with pending notifications
- `markNotificationAsShown()`: Mark notification as shown

**Achievement Criteria:**
Currently supports:
- `type: 'stations'`: Unlock at specific station count (e.g., unlock at 3 stations)
- `type: 'completion'`: Unlock when all stations visited

**JSON Format in badge.json:**
```json
{
  "id": "station1_gate",
  "name": "Limestone Gate Passer",
  "description": "Every journey begins with a single brave step...",
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

#### 4. **Achievement Notification Components** (`lib/components/achievement_notification.dart`)

Two notification styles:

**AchievementUnlockNotification** (Full Dialog)
- Centered dialog with celebration colors
- Shows achievement details
- Auto-dismisses after 5 seconds
- Elegant animations with scale and fade effects

**AchievementUnlockOverlay** (Top Banner)
- Non-blocking banner style notification
- Slides down from top with icon and brief info
- Auto-dismisses after 4 seconds
- Less intrusive for quick notifications

## Integration Flow

### 1. Scanner Screen Integration

When a QR code is successfully scanned at a station:

```
QR Scan → Geofence Check → Mark Station Visited → Check Achievements
    ↓
checkAndUnlockAchievements(stationsVisited, stationIds)
    ↓
Achievement Criteria Met? → Yes → Unlock Locally → Show Notification
                         ↓ No
                      Continue
```

**Code Example:**
```dart
// In scanner_screen.dart onDetect callback
await stationService.updateStationVisited(code, true);

final visitedStations = stationService.getVisitedStations();
final newlyUnlocked = await achievementService.checkAndUnlockAchievements(
  visitedStations.length,
  visitedStations.map((s) => s.id).toList(),
);

if (newlyUnlocked != null) {
  _showAchievementNotification(newlyUnlocked);
}
```

### 2. Firebase Sync

Automatic sync on initialization and manual sync can be triggered:

```
Unlock Achievement Locally
    ↓
Add to LocalAchievementService sync queue
    ↓
On App Init → Check Internet Connection
    ↓
If Online → Sync Queue to Firebase
    ↓
Success → Remove from sync queue
Fail → Keep in queue for next sync attempt
```

**Firebase Structure:**
```
users/{userId}
  ├── achievements/{achievementId}
  │   ├── id: "station1_gate"
  │   ├── name: "Limestone Gate Passer"
  │   ├── unlockedAt: "2024-01-15T10:30:00Z"
  │   └── syncedAt: server timestamp
  └── badges: ["station1_gate", "station2_mossy", ...]
```

### 3. Offline Support

**Scenario 1: Offline Achievement Unlock**
1. User scans QR at station while offline
2. Achievement unlocked locally + added to sync queue
3. Notification shown immediately
4. Achievement visible in profile (from local cache)
5. When online → Auto-sync to Firebase

**Scenario 2: Online Achievement Unlock**
1. User scans QR at station while online
2. Achievement unlocked locally
3. Immediately synced to Firebase
4. Notification shown
5. Profile updated instantly

## Profile Screen Integration

### Achievement Display
Profile shows:
1. **Achievement Stats**
   - Total unlocked vs. total achievements
   - Completion percentage

2. **Recent Achievements** (First 3)
   - Colorful achievement cards
   - Icon matching rarity
   - Unlock date in relative format ("2 days ago", "today")
   - Rarity badge

3. **View All Dialog**
   - Full list of all achievements
   - Locked achievements grayed out
   - Shows which are unlocked
   - Unlock dates for completed achievements

### Date Formatting
Achievements show relative dates:
- Today
- Yesterday
- 3 days ago
- 2 weeks ago
- MM/DD/YYYY (for older achievements)

## Rarity System

| Rarity | Color | Usage |
|--------|-------|-------|
| Common | Gray (#9E9E9E) | Early achievements |
| Uncommon | Green (#4CAF50) | Mid-trail achievements |
| Rare | Blue (#2196F3) | Later achievements |
| Epic | Purple (#9C27B0) | Hard-to-reach achievements |
| Legendary | Orange (#FF9800) | Challenge/completion achievements |

## Notification Flow

### Step 1: Achievement Unlocked
- Checked against criteria when station visited
- Unlocked in local storage
- Added to pending notifications queue

### Step 2: Show Notification
```dart
_showAchievementNotification(achievement) {
  showDialog(...);  // Shows AchievementUnlockNotification
}
```

### Step 3: Mark as Shown
After user sees notification:
```dart
achievementService.markNotificationAsShown(achievementId);
```
- Removes from pending queue
- Sets `isNotificationShown = true` in local storage
- Prevents duplicate notifications on app restart

## Edge Cases & Error Handling

### 1. No Internet Connection
- Achievements still unlock and show notification
- Synced to Firebase when connection restored
- User sees pending badge until synced

### 2. Firebase Sync Failure
- Achievement stays in sync queue
- Retried on next app launch or sync attempt
- User can see locally (still appears in profile)

### 3. Duplicate Achievements
- Local service checks `isUnlocked` before unlocking again
- Prevents re-triggering notifications

### 4. App Restart While Offline
- Pending notifications queue persists
- Notifications shown on app restart
- Sync queue persists for later syncing

### 5. Missing Achievement Data
- JSON loading failure → empty achievement list
- Firebase sync failure → local data preserved
- Graceful degradation with try-catch blocks

## Configuration & Customization

### Adding New Achievements

1. Add to `assets/data/badge.json`:
```json
{
  "id": "station5_unique_id",
  "name": "Achievement Name",
  "description": "Description of achievement",
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

2. If needed, update criteria logic in `AchievementService._checkAchievementCriteria()`

3. Ensure icon name exists in `Achievement.getIconData()`

### Changing Sync Frequency

Default: On app init and manual sync

To add periodic background sync:
```dart
// In relevant service
Timer.periodic(Duration(minutes: 15), (_) {
  achievementService.syncToFirebase();
});
```

### Custom Notification UI

Replace notification component:
```dart
// Use AchievementUnlockOverlay for banner style
showOverlay(
  AchievementUnlockOverlay(
    achievement: achievement,
    onDismiss: callback,
  ),
);
```

## Testing Checklist

- [ ] Unlock achievement while online → immediately visible in profile + Firebase
- [ ] Unlock achievement offline → visible in profile, syncs when online
- [ ] Restart app offline → pending notifications still show
- [ ] View all achievements → shows locked and unlocked correctly
- [ ] Achievement unlock dates display correctly
- [ ] Multiple achievements unlock → no duplicate notifications
- [ ] Firebase sync recovers from failures
- [ ] Rarity colors display correctly
- [ ] Icon mapping works for all achievement types

## Future Enhancements

1. **Achievement Categories**: Filter by category
2. **Hidden Achievements**: Reveal after unlock
3. **Multi-Step Achievements**: Progress tracking
4. **Achievement Chains**: Unlock one to reveal another
5. **Social Features**: Share achievements
6. **Analytics**: Track achievement unlock rates
7. **Badges Integration**: Link achievements to badges
8. **Leaderboards**: Compare achievement progress with other users

## File Structure

```
lib/
├── models/
│   └── achievement.dart (Achievement data model)
├── services/
│   ├── achievement_service.dart (Main service)
│   └── local_achievement_service.dart (Local storage)
├── components/
│   └── achievement_notification.dart (UI notifications)
└── screens/
    └── main/
        ├── scanner_screen.dart (Achievement unlock trigger)
        └── profile_screen.dart (Display achievements)

assets/
└── data/
    └── badge.json (Achievement definitions)
```

## Troubleshooting

**Problem**: Achievements not syncing to Firebase
- Check internet connection
- Verify Firebase rules allow write access
- Check LocalAchievementService sync queue

**Problem**: Notifications not showing
- Verify pending notifications queue
- Check if already marked as shown
- Restart app to trigger pending notifications

**Problem**: Local achievements not persisting
- Check SharedPreferences permissions
- Verify device storage not full
- Check achievement serialization

**Problem**: Achievement criteria not triggering
- Verify requirement type in badge.json
- Check achievement unlock logic in service
- Ensure station visit count tracking works

