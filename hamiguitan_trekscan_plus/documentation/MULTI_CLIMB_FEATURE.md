# Multi-Climb Feature Documentation

## Overview

The Multi-Climb feature allows users to perform multiple climbing attempts/sessions on the Hamiguitan mountain trek. Each session is completely independent, allowing users to track their progress, timing, and statistics for each individual climb attempt.

## Key Features

### 1. **Create New Climb Sessions**
- Users can start a new climb session using the FAB ("New Climb" button) in the Station Screen
- Each session requires:
  - **Name**: e.g., "Morning Trek 2025", "Solo Challenge"
  - **Description**: Optional notes about the climb (optional)

### 2. **Active Session Tracking**
- While a climb is ongoing, a banner appears at the top showing:
  - Climb name with active indicator
  - Number of stations visited
  - Current elapsed time
  - Quick access to detailed statistics

### 3. **Automatic Climb Start**
- The climb timer starts automatically when the user scans the first station
- Timer continues running as the user visits more stations
- Users can abandon or complete sessions at any time

### 4. **Station Tracking Per Session**
- Each station visit is recorded with:
  - Station ID and name
  - Scan timestamp
  - Elevation data
  - Distance from previous station
  
### 5. **Automatic Statistics Calculation**
- **Total Duration**: Time from first station scan to completion
- **Stations Visited**: Count of unique stations visited
- **Total Distance**: Sum of distances between stations
- **Average Elevation**: Average elevation of visited stations
- **Time per Station**: Duration spent between each station

### 6. **Climb History**
- Access via the history icon (⏱️) in the app bar
- Two tabs:
  - **Ongoing**: Active climb sessions in progress
  - **Completed**: Finished climb attempts with final statistics

### 7. **Detailed Session View**
- Click any session from history or the active session banner to view:
  - Timeline of visited stations with timestamps
  - Detailed statistics dashboard
  - Duration breakdown per station
  - Distance and elevation information
  - Session metadata (created, started, completed times)

## User Flow

```
Station Screen
    ↓
[FAB: New Climb] → Create Session Dialog
    ↓
Enter Name & Description
    ↓
Session Created & Active
    ↓
[Active Session Banner] - Shows live statistics
    ↓
Scan Stations → Auto-start tracking
    ↓
View Details [Banner Click] → Detailed Session Screen
    ↓
Complete/Abandon Session
    ↓
[History Icon] → View All Sessions
```

## Models

### ClimbSession
Located in `lib/models/climb_session.dart`

```dart
class ClimbSession {
  String id;              // Unique session identifier
  String name;            // User-provided name
  String description;     // User-provided description
  DateTime createdAt;     // When session was created
  DateTime? startedAt;    // When first station was scanned
  DateTime? completedAt;  // When session was completed
  String status;          // 'ongoing', 'completed', 'abandoned'
  List<StationVisit> visitedStations;  // All stations visited
  Duration? totalDuration;
  double? totalDistance;
}
```

### StationVisit
Located in `lib/models/climb_session.dart`

```dart
class StationVisit {
  String stationId;
  String stationName;
  DateTime scannedAt;
  int elevation;
  double? distanceFromPrevious;  // in km
}
```

## Services

### ClimbSessionService
Located in `lib/services/climb_session_service.dart`

#### Key Methods:

- `createClimbSession(name, description)` - Create new session
- `addVisitedStation(station, session)` - Record station visit
- `completeSession(session)` - Mark session as complete
- `abandonSession(session)` - Mark session as abandoned
- `getAllSessions()` - Get all sessions
- `getOngoingSessions()` - Get only active sessions
- `getCompletedSessions()` - Get only finished sessions
- `getActiveSession()` - Get current active session
- `deleteSession(id)` - Remove a session
- `getSessionStats(session)` - Calculate statistics

## UI Components

### NewClimbSessionDialog
- Location: `lib/dialogs/new_climb_session_dialog.dart`
- Handles session creation with validation
- Returns created session to caller

### ClimbSessionDetailScreen
- Location: `lib/screens/main/climb_session_detail_screen.dart`
- Displays comprehensive session information
- Shows statistics cards, timeline, and metadata
- Allows navigation from active session or history

### ClimbSessionsListScreen
- Location: `lib/screens/main/climb_sessions_list_screen.dart`
- Tab-based view (Ongoing/Completed)
- Quick stats preview per session
- Tap to view detailed statistics

### StationScreen Updates
- Active session banner with live stats
- History icon to access all sessions
- FAB to create new climb sessions

## Data Storage

All climb session data is persisted using SharedPreferences:
- Storage Key: `climb_sessions_{userId}` (user-scoped)
- Format: JSON serialization
- Automatic save on every change

## Integration with Scanner

When a user scans a QR code:
1. Station is marked as visited in the active session
2. `ClimbSession.startClimb()` is called (if not started)
3. Station visit is recorded with timestamp
4. Active session banner updates automatically
5. User can continue scanning or view session details

## Integration with StationService

The new feature works alongside existing StationService:
- `StationService`: Tracks global visited/unvisited stations (for all-time tracking)
- `ClimbSessionService`: Tracks per-session visits (for individual climb attempts)

This allows users to:
- View their all-time visited stations on the main tabs
- Also track individual session attempts separately

## Future Enhancements

Possible features to add:
1. **Pause/Resume Sessions** - Pause timer during breaks
2. **Notifications** - Alert when completing milestone stations
3. **Achievements** - Special badges for fastest climbs, most frequent climber, etc.
4. **Social Sharing** - Share climb results with friends
5. **Export Data** - Download climb data as PDF/CSV
6. **Live Map Tracking** - Show position on trail map during climb
7. **Photo Checkpoints** - Require photo at specific stations
8. **Climb Challenges** - Time-based or speed challenges
9. **Leaderboard** - Compare times with other climbers
10. **Weather Integration** - Record conditions during climb

## Technical Notes

- Uses singleton pattern for service management
- ChangeNotifier for reactive updates
- Asynchronous initialization with proper error handling
- User-scoped data storage for multi-user support
- Serializable models for persistence
- Comprehensive timestamp tracking for analytics

## Integration Checklist

- [x] Create ClimbSession model
- [x] Create StationVisit model
- [x] Create ClimbSessionService
- [x] Create NewClimbSessionDialog
- [x] Create ClimbSessionDetailScreen
- [x] Create ClimbSessionsListScreen
- [x] Update StationScreen with active session banner
- [x] Add history navigation
- [x] Add FAB for new sessions
- [ ] Integrate scanner with session tracking
- [ ] Add session completion flow
- [ ] Add analytics/reporting (future)
