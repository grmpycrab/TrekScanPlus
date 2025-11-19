# Achievement Station Assignment System

## Overview

Achievements are now **properly assigned to specific stations** instead of popping up randomly. Each station visit unlocks a corresponding achievement in order.

## How It Works

### Station-to-Achievement Mapping

Each station unlock is tied to a specific achievement based on the **station index**:

| Station | QR Code | Achievement ID | Achievement Name |
|---------|---------|-----------------|------------------|
| 1 | stn1 | `station1_gate` | Limestone Gate Passer |
| 2 | stn2 | `station2_mossy` | Mossy Trail Tracker |
| 3 | stn3 | `station3_explorer` | Wildlife Path Explorer |
| 4 | stn4 | `station4_ridge` | Mountain Ridge Climber |
| 5 | stn5 | `station5_cloudforest` | Cloud Forest Adventurer |
| 6 | stn6 | `station6_pygmy` | Pygmy Forest Visitor |
| 8 | stn8 | `station8_ascent` | Final Ascent Pioneer |
| Summit | summit | `summit_conqueror` | Hamiguitan Peak Conqueror |

### User Journey

```
Scan Station 1
    ↓
Check achievement criteria (reach_station: 1)
    ↓
Current station index = 1 ✓ matches requirement
    ↓
Unlock: "Limestone Gate Passer"
    ↓
Show notification + save to Firebase
    ↓
────────────────────────────────────
    ↓
Scan Station 2
    ↓
Check achievement criteria (reach_station: 2)
    ↓
Current station index = 2 ✓ matches requirement
    ↓
Unlock: "Mossy Trail Tracker"
    ↓
Show notification + save to Firebase
```

## Implementation Details

### Changes Made

#### 1. **Achievement Service** (`lib/services/achievement_service.dart`)

**Updated Method:**
```dart
Future<Achievement?> checkAndUnlockAchievements(
  int stationsVisited,
  List<String> completedStationIds, {
  String? currentStationId,      // NEW: Station being visited (e.g., "stn1")
  int? currentStationIndex,       // NEW: Station number 1-based (1, 2, 3, etc.)
}) async {
  // Achievement checking logic with station-specific matching
}
```

**Updated Criteria Check:**
```dart
bool _checkAchievementCriteria(
  Achievement achievement,
  int stationsVisited, {
  String? currentStationId,
  int? currentStationIndex,
}) {
  final type = requirement['type'];
  
  if (type == 'reach_station') {
    // Match against CURRENT station being visited, not total count
    if (currentStationIndex != null) {
      return currentStationIndex == stationValue;  // Exact match
    }
  }
  
  if (type == 'reach_location') {
    // Location-based achievements (e.g., Tinagong Dagat)
    return currentStationId?.toLowerCase() == value.toString().toLowerCase();
  }
}
```

**Key Difference:**
- **Old Logic**: `stationsVisited >= stationValue` → Unlocked all remaining achievements when reaching a station
- **New Logic**: `currentStationIndex == stationValue` → Only unlock achievement for current station

#### 2. **Scanner Screen** (`lib/screens/main/scanner_screen.dart`)

**Updated Call:**
```dart
// Get the index of this station for achievement matching
final allStations = stationService.getAllStations();
final stationIndex = allStations.indexWhere((s) => s.id == station.id);

// Pass station context to achievement service
final newlyUnlocked = await achievementService.checkAndUnlockAchievements(
  visitedStations.length,
  visitedStations.map((s) => s.id).toList(),
  currentStationId: station.id,
  currentStationIndex: stationIndex >= 0 ? stationIndex + 1 : null,
);
```

## Achievement Types

### 1. **Station-Specific Achievements** (Primary)

```json
{
  "id": "station1_gate",
  "requirement": {
    "type": "reach_station",
    "value": 1
  }
}
```

**Triggers**: Unlocks when user visits Station 1 specifically
**How**: `currentStationIndex == 1`

### 2. **Cumulative Achievements** (Secondary)

```json
{
  "id": "stations_reached_5",
  "requirement": {
    "type": "stations_reached",
    "value": 5
  }
}
```

**Triggers**: Unlocks when user has visited 5+ stations (any combination)
**How**: `stationsVisited >= 5`

### 3. **Location-Based Achievements** (Special)

```json
{
  "id": "station7_hidden_sea",
  "requirement": {
    "type": "reach_location",
    "value": "tinagong_dagat"
  }
}
```

**Triggers**: Unlocks when user reaches Tinagong Dagat location
**How**: `currentStationId.toLowerCase() == "tinagong_dagat"`

## Expected Behavior

### Scenario 1: Linear Progression

**Device**: User starts trek at Station 1

```
Action: Scan Station 1 QR code
Result: Unlock "Limestone Gate Passer" (station1_gate)
        Show achievement notification
        
Action: Scan Station 2 QR code
Result: Unlock "Mossy Trail Tracker" (station2_mossy)
        Show achievement notification
        
Action: Scan Station 3 QR code
Result: Unlock "Wildlife Path Explorer" (station3_explorer)
        Show achievement notification
```

✅ **Expected**: One achievement per station, in order
✅ **NOT Expected**: Multiple achievements from one scan

### Scenario 2: Non-Linear Progression

**Device**: User somehow scans Station 5 first

```
Action: Scan Station 5 QR code
Result: Unlock "Cloud Forest Adventurer" (station5_cloudforest)
        Show achievement notification
        No other achievements unlock
```

✅ **Expected**: Only Station 5 achievement unlocks
✅ **NOT Expected**: Stations 1-4 achievements

### Scenario 3: Achievement Re-visit

**Device**: User visits Station 1 again (already visited)

```
Action: Scan Station 1 QR code (already visited)
Result: No new achievement (already unlocked)
        Station marked as visited (again)
```

✅ **Expected**: No duplicate achievement
✅ **NOT Expected**: "Limestone Gate Passer" shown again

## Testing Checklist

- [ ] Visit Station 1 → Only "Limestone Gate Passer" unlocks
- [ ] Visit Station 2 → Only "Mossy Trail Tracker" unlocks (no others)
- [ ] Visit Station 3 → Only "Wildlife Path Explorer" unlocks
- [ ] Visit Station 4 → Only "Mountain Ridge Climber" unlocks
- [ ] Visit Station 5 → Only "Cloud Forest Adventurer" unlocks
- [ ] Visit Station 6 → Only "Pygmy Forest Visitor" unlocks
- [ ] Visit Station 8 → Only "Final Ascent Pioneer" unlocks
- [ ] Visit Summit → Only "Hamiguitan Peak Conqueror" unlocks
- [ ] Cumulative: After 5 stations → "Five Stations Completed" unlocks
- [ ] Re-visit Station 1 → No duplicate notification
- [ ] Check profile → All achievements in correct order
- [ ] Offline → Achievements show after going online

## Architecture Diagram

```
User scans QR code (e.g., stn2)
    ↓
Scanner Screen captures code
    ↓
Get station object from StationService
    ↓
Calculate station index (0-based → convert to 1-based)
    ↓
Call checkAndUnlockAchievements() with:
  - stationsVisited: 2
  - completedStationIds: ["stn1", "stn2"]
  - currentStationId: "stn2"
  - currentStationIndex: 2  ← KEY PARAMETER
    ↓
Achievement Service loops through all achievements:
    ├─ station1_gate (reach_station: 1)
    │  └─ Check: currentStationIndex (2) == 1? NO → Skip
    ├─ station2_mossy (reach_station: 2)
    │  └─ Check: currentStationIndex (2) == 2? YES → Unlock! ✓
    ├─ station3_explorer (reach_station: 3)
    │  └─ Check: currentStationIndex (2) == 3? NO → Skip
    └─ ... rest skipped ...
    ↓
Return newly unlocked achievement: station2_mossy
    ↓
Show beautiful notification
    ↓
Save to local storage
    ↓
Sync to Firebase (async)
    ↓
Update profile display
```

## Data Flow

### On Achievement Unlock

```
┌─────────────────────────────────────────────┐
│         User Scans QR Code                  │
│       (At Station 2, stn2)                  │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│    Get Station Index (1-based: 2)           │
│    Get Station ID (stn2)                    │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  checkAndUnlockAchievements(                │
│    stationsVisited: 2,                      │
│    currentStationIndex: 2,                  │
│    currentStationId: "stn2"                 │
│  )                                          │
└────────────────┬────────────────────────────┘
                 │
                 ▼
        ┌────────────────┐
        │ Loop all       │
        │ achievements   │
        └────────┬───────┘
                 │
        ┌────────▼─────────┐
        │ For each:        │
        │ Check criteria   │
        │ (station-based)  │
        └────────┬─────────┘
                 │
        ┌────────▼────────────────────┐
        │ Found match?                │
        │ station2_mossy matches 2    │
        └────────┬────────────────────┘
                 │
                 ▼
        ┌──────────────────────┐
        │ Unlock achievement   │
        │ Save locally         │
        │ Add to sync queue    │
        │ Queue notification   │
        └────────┬─────────────┘
                 │
                 ▼
    ┌────────────────────────────┐
    │ Return newlyUnlocked       │
    │ achievement                │
    └────────┬───────────────────┘
             │
             ▼
    ┌────────────────────────────┐
    │ Show Notification UI       │
    │ "Achievement Unlocked!"    │
    │ "Mossy Trail Tracker"      │
    └────────┬───────────────────┘
             │
             ▼
    ┌────────────────────────────┐
    │ Async: Sync to Firebase    │
    │ if online                  │
    └────────────────────────────┘
```

## FAQ

### Q: Will achievements unlock randomly?
**A**: No. Achievements now unlock **only when visiting the specific station** they're tied to. Each station has exactly one achievement.

### Q: What if user visits stations out of order?
**A**: Each achievement still only unlocks when visiting its specific station. If user visits Station 5 first, only the Station 5 achievement unlocks. Stations 1-4 achievements remain locked until those stations are visited.

### Q: Can users get duplicate achievements?
**A**: No. The system checks `if (achievement.isUnlocked) continue;` to skip already-unlocked achievements.

### Q: What about cumulative achievements like "Five Stations Completed"?
**A**: These use a different type (`stations_reached`) and check total count `stationsVisited >= 5`, so they trigger after visiting 5 stations regardless of order.

### Q: How does offline mode handle achievements?
**A**: 
1. Achievement unlocks locally immediately
2. Notification queues locally
3. When online, syncs to Firebase
4. Pending notifications persist if app restarts

## Technical Notes

### Station Index Calculation

```dart
// Get all stations in order
final allStations = stationService.getAllStations();

// Find index of current station (0-based)
final stationIndex = allStations.indexWhere((s) => s.id == station.id);

// Convert to 1-based for achievement matching
final oneBasedIndex = stationIndex + 1;  // 0 → 1, 1 → 2, etc.
```

### Achievement Matching Logic

```dart
if (type == 'reach_station') {
  final stationValue = value as int;  // e.g., 1, 2, 3
  
  // Match CURRENT station being visited
  if (currentStationIndex != null) {
    return currentStationIndex == stationValue;  // Exact match
  }
}
```

### Breaking Change

**Previous Behavior:**
```dart
// Old: Unlocked multiple achievements per scan
checkAndUnlockAchievements(visitedStations.length, []);
// Visiting Station 2 would unlock achievements for stations 1 AND 2
```

**New Behavior:**
```dart
// New: Unlocks exactly one achievement per scan
checkAndUnlockAchievements(
  visitedStations.length,
  [],
  currentStationIndex: 2,  // Pass current station
);
// Visiting Station 2 unlocks ONLY Station 2 achievement
```

---

## Summary

✅ **Achievements are now station-specific**
✅ **One achievement unlocks per station visit**
✅ **No more random achievement popups**
✅ **Users see predictable, meaningful progression**
✅ **Cumulative achievements still work**
✅ **Offline support maintained**

Users will now have a clear sense of progression: visiting each station unlocks its unique achievement!
