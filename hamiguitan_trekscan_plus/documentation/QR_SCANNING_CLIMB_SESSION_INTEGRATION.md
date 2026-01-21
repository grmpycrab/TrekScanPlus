# QR Scanning & ClimbSession Integration

## Overview
Implemented automatic station tracking in ClimbSession when QR codes are scanned. When a user scans a station's QR code, that station is now added to the active climb session.

## Architecture

### Data Flow
```
User Scans QR Code
    ↓
Scanner detects code
    ↓
Lookup station in StationService
    ↓
Mark station as visited (StationService.updateStationVisited)
    ↓
Get active ClimbSession
    ↓
Add station to ClimbSession.visitedStations ← NEW
    ↓
Update ClimbSession in ClimbSessionService ← NEW
    ↓
Check achievements
    ↓
Show achievement notification (if any)
    ↓
Navigate to StationDetailScreen
```

## Implementation Details

### File: `lib/screens/main/scanner_screen.dart`

#### Added Import
```dart
import '../../services/climb_session_service.dart';
```

#### Code Integration (in onDetect callback, after `updateStationVisited`)
```dart
// Add station to active climb session if one exists
final climbSessionService = ClimbSessionService.instance;
final activeSession = climbSessionService.getActiveSession();
if (activeSession != null && !activeSession.isStationVisited(station.id)) {
  activeSession.addVisitedStation(station);
  await climbSessionService.updateSession(activeSession);
}
```

#### How It Works
1. **Get Active Session**: Retrieves the current active climb session (status == 'ongoing')
2. **Check If Already Visited**: Uses `isStationVisited()` to prevent duplicate entries
3. **Add Station**: Calls `addVisitedStation()` which creates a `StationVisit` record with:
   - Station ID and name
   - Scan timestamp
   - Elevation
   - Distance from previous station
4. **Persist**: Saves the updated session via `updateSession()`

### Data Persistence

The scanned station is stored in two places:

1. **StationService** (local visited stations list)
   - Used for marking stations as "visited" globally
   - Prevents re-scanning same station

2. **ClimbSession** (climb-specific stations)
   - Tracks stations visited *during this specific climb*
   - Records exact scan time and sequence
   - Used for climb progress and statistics

### Station Visit Record

When a station is added to a climb, a `StationVisit` is created with:

```dart
class StationVisit {
  final String stationId;           // e.g., "stn2"
  final String stationName;         // e.g., "Mossy Trail"
  final DateTime scannedAt;         // Exact scan time
  final int elevation;              // Station elevation
  final double? distanceFromPrevious; // km from previous station
}
```

## Key Features

### ✅ Multi-Climb Support
- Each active climb session tracks its own visited stations
- Users can have multiple concurrent climb sessions
- Prevents cross-climb contamination

### ✅ Deduplication
```dart
if (!activeSession.isStationVisited(station.id)) {
  // Only add if not already in this climb
  activeSession.addVisitedStation(station);
}
```

### ✅ Time Tracking
- Records exact scan timestamp for each station
- Enables duration calculations between stations
- Supports session statistics

### ✅ Optional Session Handling
```dart
if (activeSession != null) {
  // Only process if there's an active climb
  // Scanning without active session still works (StationService)
}
```

## ClimbSession Statistics

After scanning stations, the ClimbSession can calculate:

```dart
// Get elapsed time since climb started
Duration? elapsed = session.getElapsedDuration();

// Get visit sequence and timing
List<StationVisit> stations = session.visitedStations;

// Check progress
double progress = session.getProgressPercentage(totalStations);

// Calculate total distance
session.completeClimb(); // Calculates totalDistance from all visits
```

## Integration with Other Systems

### 1. Achievements
When a station is scanned:
- Achievement service checks criteria (e.g., "visited station X")
- Works independently of ClimbSession (uses StationService count)
- No changes needed to achievement system

### 2. Firebase Sync (Future)
When Firebase integration is added, ClimbSession operations should sync to:
```
POST /users/{userId}/climbs/{climbId}/stations ← new station visit
PUT /users/{userId}/climbs/{climbId} ← update climb with new station count
```

### 3. Geofencing
Geofence check happens before any station recording:
- User must be within radius to scan
- Both StationService AND ClimbSession only receive valid scans

## Testing

### Scenario 1: Normal Climb Session
```
1. Create climb session: "Summit Quest"
2. Scan Station 1 → Added to session
3. Scan Station 2 → Added to session
4. Scan Station 5 → Added to session (skipping 3, 4)
✓ session.visitedStations = [stn1, stn2, stn5]
```

### Scenario 2: Duplicate Scan Prevention
```
1. Climb session exists
2. Scan Station 3 → Added
3. Scan Station 3 again → Ignored (already in session)
✓ session.visitedStations.length = 1 (no duplicate)
```

### Scenario 3: No Active Session
```
1. No climb session created
2. Scan Station 1
✓ Station marked as visited in StationService
✓ ClimbSession not affected (activeSession == null)
✓ Station still appears in StationDetailScreen
```

## Edge Cases Handled

| Scenario | Behavior |
|----------|----------|
| Scan while no climb active | Station marked globally, skips ClimbSession |
| Scan already-visited station in same climb | Ignored (deduplication) |
| Scan already-visited station in different climb | Added (same station can appear in different climbs) |
| Geofence verification fails | Station not added to either system |
| ClimbSession deleted after scan | Station still in StationService |

## Related Components

- **ClimbSession Model**: Stores and manages visited stations
- **StationService**: Global station visit tracking
- **ClimbSessionService**: CRUD operations on climb sessions
- **ScannerScreen**: Initiates station scanning
- **AchievementService**: Notified of scans (independent)

## Future Enhancements

1. **Firebase Integration**: Sync ClimbSession to Firestore subcollection
2. **Station Duration**: Calculate time spent at each station
3. **Route Optimization**: Suggest optimal station visit order
4. **Offline Queue**: Queue scans when offline, sync when online
5. **Station Photos**: Capture and attach photos during scan

---

**Last Updated**: January 21, 2026
**Status**: ✅ Implemented and Integrated
