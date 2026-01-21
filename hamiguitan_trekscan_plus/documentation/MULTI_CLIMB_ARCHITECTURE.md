# Multi-Climb Feature Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     STATION SCREEN                              │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ AppBar (with History Icon)                                 │ │
│  │ [History] ─────────────────────────────────────────┐      │ │
│  └────────────────────────────────────────────────────┼──────┘ │
│  ┌────────────────────────────────────────────────────┼──────┐ │
│  │ Active Session Banner (if session active)          │      │ │
│  │ [Name] Stations: N | Duration: HH:MM:SS           │      │ │
│  │                                                    │      │ │
│  │         ┌─────────────────────────────────────┐    │      │ │
│  │         │ OnTap → Detail Screen               │    │      │ │
│  │         └─────────────────────────────────────┘    │      │ │
│  └────────────────────────────────────────────────────┼──────┘ │
│  ┌────────────────────────────────────────────────────┼──────┐ │
│  │ Tabs: Visited | Not Visited                        │      │ │
│  │                                                    │      │ │
│  │ [Station List]                                    │      │ │
│  │                                                    │      │ │
│  │ OnTap → Check if active session                   │      │ │
│  │        → Add to session if yes                    │      │ │
│  │        → Update banner                           │      │ │
│  │                                                    │      │ │
│  └────────────────────────────────────────────────────┼──────┘ │
│                                                       │         │
│  ┌────────────────────────────────────────────────────┼──────┐ │
│  │ FAB: New Climb                                     │      │ │
│  │                                                    │      │ │
│  │      ┌──────────────────────────────────────┐     │      │ │
│  │      │ OnPress → Dialog                     │     │      │ │
│  │      └──────────────────────────────────────┘     │      │ │
│  └────────────────────────────────────────────────────┼──────┘ │
│                                                       │         │
└──────────────────────────────────────────────────────┼─────────┘
                                                       │
        ┌──────────────────────────────────────────────┴──────┐
        │                                                      │
        ▼                                                      ▼
┌──────────────────────────────┐     ┌──────────────────────────────┐
│  NEW CLIMB SESSION DIALOG     │     │  CLIMB SESSIONS LIST SCREEN  │
│                              │     │                              │
│ Name: [________]             │     │ Tabs:                        │
│ Description: [_____]         │     │ ├─ Ongoing                  │
│                              │     │ └─ Completed                │
│ [Cancel] [Create]            │     │                              │
│      │        │              │     │ Session Cards:              │
│      │        └──────┐       │     │ ┌──────────────────────┐    │
│      │               │       │     │ │ Name                 │    │
│      │               │       │     │ │ ○ Stations | ⏱ Dur  │    │
│      └───────────────┼───────┼─────┼→│ [OnTap → Details]    │    │
│              │       │       │     │ └──────────────────────┘    │
│              │       │       │     │                              │
│              │       │       │     │ Status: ONGOING/COMPLETED   │
│              ▼       ▼       │     │                              │
│        Service Create        │     └──────────────────────────────┘
│        _climbSessions.add()  │
│        _activeSession = ...  │
│        prefs.save()          │
│              │               │
│              │               │
│              └─────┬─────────┘
│                    │
└────────────────────┴──────────────────────────────────────────────┐
                                                                    │
                                                                    │
        ┌───────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────┐
│    CLIMB SESSION DETAIL SCREEN                           │
│                                                          │
│ Header:                                                  │
│ ┌────────────────────────────────────────────────────┐  │
│ │ Name          [ONGOING/COMPLETED]                  │  │
│ │ Description                                        │  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ Statistics Grid:                                         │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                   │
│ │ ⏱    │ │ 📍   │ │ 🏔   │ │ 📊   │                   │
│ │ 2h   │ │ 5    │ │ 12   │ │ 1200 │                   │
│ │ Dur  │ │ Stat │ │ km   │ │ m    │                   │
│ └──────┘ └──────┘ └──────┘ └──────┘                   │
│                                                          │
│ Timeline:                                                │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ ① Station A           14:30                         │ │
│ │    Elevation: 800m                                  │ │
│ │    Distance: 2.5 km                                │ │
│ │                                                     │ │
│ │ ② Station B           15:45                         │ │
│ │    Duration to next: 1h 15m                        │ │
│ │    Elevation: 950m                                 │ │
│ │    Distance: 3.2 km                                │ │
│ │                                                     │ │
│ │ ③ Station C           17:00                         │ │
│ │    ...                                              │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
│ Info Box:                                                │
│ ├─ Created: 21/1/2025 14:30                            │
│ ├─ Started: 21/1/2025 14:30                            │
│ └─ Completed: 21/1/2025 17:00                          │
└──────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
USER INTERACTION
       │
       ▼
┌──────────────────────┐
│ Tap FAB: New Climb   │
└──────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ NewClimbSessionDialog                │
│ • Get name & description from user   │
│ • Validate input                     │
└──────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ ClimbSessionService.createSession()  │
│ • Create ClimbSession object         │
│ • Add to _climbSessions list         │
│ • Set as _activeSession              │
│ • Save to SharedPreferences          │
└──────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ StationScreen State Update           │
│ • setState() → _activeSession        │
│ • Rebuild UI with banner             │
└──────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ User Scans Station                   │
└──────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ Scanner Handler                      │
│ 1. Get active session                │
│ 2. If not started, startClimb()     │
│ 3. Add station to session            │
│ 4. Save to SharedPreferences         │
└──────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ UI Updates (Real-time)               │
│ • Active session banner refreshes    │
│ • Station count updates              │
│ • Timer/duration updates             │
└──────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ User Views Details                   │
│ (Tap banner or history)              │
└──────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ ClimbSessionDetailScreen             │
│ • Load session data                  │
│ • Calculate statistics               │
│ • Display timeline & stats           │
└──────────────────────────────────────┘
```

## Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   CLIMB SESSION SERVICE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ SINGLETON INSTANCE                                              │
│ └─ static _instance: ClimbSessionService                        │
│                                                                 │
│ STATE VARIABLES                                                 │
│ ├─ _climbSessions: List<ClimbSession>  [All sessions]          │
│ ├─ _activeSession: ClimbSession?       [Current active]        │
│ ├─ _currentUserId: String?             [User scoping]          │
│ └─ prefs: SharedPreferences            [Persistence]           │
│                                                                 │
│ PUBLIC API                                                      │
│ ├─ init(userId?)                       [Initialize]            │
│ ├─ createClimbSession(name, desc)      [New session]           │
│ ├─ addVisitedStation(station, session) [Track visit]           │
│ ├─ completeSession(session)            [Mark complete]         │
│ ├─ abandonSession(session)             [Mark abandoned]        │
│ ├─ getActiveSession()                  [Get current]           │
│ ├─ getAllSessions()                    [All sessions]          │
│ ├─ getOngoingSessions()                [Filter ongoing]        │
│ ├─ getCompletedSessions()              [Filter completed]      │
│ ├─ getSessionById(id)                  [Lookup]                │
│ ├─ deleteSession(id)                   [Remove]                │
│ ├─ updateSession(session)              [Update]                │
│ └─ getSessionStats(session)            [Calculate stats]       │
│                                                                 │
│ INTERNAL METHODS                                                │
│ ├─ _loadSessions()                     [Load from prefs]       │
│ ├─ _saveSessions()                     [Save to prefs]         │
│ ├─ _userClimbSessionsKey               [User-scoped key]       │
│ └─ setCurrentUser(userId)              [Update user]           │
│                                                                 │
│ NOTIFICATIONS                                                   │
│ └─ notifyListeners()                   [ChangeNotifier]        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Model Structure

```
ClimbSession
├── id: String                    [Unique identifier]
├── name: String                  [User-provided name]
├── description: String           [User-provided description]
├── createdAt: DateTime           [When session created]
├── startedAt: DateTime?          [When first station scanned]
├── completedAt: DateTime?        [When session finished]
├── status: String                [ongoing|completed|abandoned]
├── visitedStations: List<StationVisit>  [All visits]
│   └── StationVisit
│       ├── stationId: String
│       ├── stationName: String
│       ├── scannedAt: DateTime
│       ├── elevation: int
│       └── distanceFromPrevious: double?
├── totalDuration: Duration?      [Calculated on complete]
└── totalDistance: double?        [Calculated on complete]

Methods:
├── startClimb()                  [Mark as started]
├── addVisitedStation(station)    [Record visit]
├── completeClimb()               [Mark as complete]
├── isStationVisited(id)          [Check if visited]
├── getElapsedDuration()          [Time so far]
├── getProgressPercentage()       [% complete]
├── formatDuration(duration)      [Pretty print]
├── toMap() / fromMap()           [Serialization]
└── ...
```

## User Flows

### Flow 1: Create New Climb

```
START
  │
  ├─ User taps FAB "New Climb"
  │
  ├─ Dialog appears
  │  └─ User enters: Name + Description
  │
  ├─ User taps "Create"
  │
  ├─ ClimbSessionService.createClimbSession()
  │  ├─ Create new ClimbSession object
  │  ├─ Generate unique ID
  │  ├─ Add to _climbSessions
  │  ├─ Set as _activeSession
  │  ├─ Save to SharedPreferences
  │  └─ Return created session
  │
  ├─ Dialog closes, returns session
  │
  ├─ StationScreen updates
  │  ├─ setState() with new _activeSession
  │  ├─ Active banner appears
  │  └─ FAB changes appearance (visual feedback)
  │
  └─ END
```

### Flow 2: Scan Station During Active Climb

```
START
  │
  ├─ User scans QR code
  │
  ├─ Scanner identifies station
  │
  ├─ Handler checks: Is there active session?
  │  └─ YES: Continue with Flow
  │
  ├─ Get active session from service
  │
  ├─ Check: Has session started?
  │  └─ NO: Call session.startClimb() → starts timer
  │
  ├─ Call addVisitedStation(station, session)
  │  ├─ Create StationVisit object
  │  ├─ Set scannedAt = NOW
  │  ├─ Add to session.visitedStations
  │  └─ Save to SharedPreferences
  │
  ├─ UI updates (listeners notified)
  │  ├─ Active banner refreshes
  │  ├─ Station count increases
  │  ├─ Duration updates
  │  └─ Smooth animation
  │
  └─ END
```

### Flow 3: Complete Climb

```
START
  │
  ├─ User reaches final station or taps "Complete"
  │
  ├─ Call completeSession(session)
  │  ├─ Set completedAt = NOW
  │  ├─ Set status = 'completed'
  │  ├─ Calculate totalDuration
  │  ├─ Calculate totalDistance
  │  ├─ Clear _activeSession
  │  └─ Save to SharedPreferences
  │
  ├─ Optional: Show completion screen
  │  ├─ Display stats
  │  ├─ Show achievements
  │  └─ Offer sharing
  │
  ├─ Redirect to history or station screen
  │
  ├─ Active banner disappears
  │
  └─ END
```

## Persistence Strategy

```
SharedPreferences
│
├─ Key: "climb_sessions_{userId}"
│  └─ Value: JSON Array of ClimbSession objects
│     [
│       {
│         "id": "1705829400000",
│         "name": "Morning Trek 2025",
│         "description": "Solo attempt",
│         "createdAt": "2025-01-21T14:30:00",
│         "startedAt": "2025-01-21T14:30:00",
│         "completedAt": "2025-01-21T17:00:00",
│         "status": "completed",
│         "visitedStations": [
│           {
│             "stationId": "1",
│             "stationName": "Station A",
│             "scannedAt": "2025-01-21T14:30:00",
│             "elevation": 800,
│             "distanceFromPrevious": null
│           },
│           ...
│         ],
│         "totalDuration": 9000,  [seconds]
│         "totalDistance": 8.7
│       },
│       ...
│     ]
│
└─ Auto-saved on every operation (create, add, complete, etc.)
```

## Error Handling

```
Operation Flow:
│
├─ Initialization Error
│  └─ ClimbSessionService not initialized
│     → Caught: Check isInitialized before .instance
│     → Fix: Call init() in main.dart
│
├─ Validation Error
│  └─ Name is empty in dialog
│     → Caught: TextField validation
│     → Fix: Show SnackBar, prevent creation
│
├─ Persistence Error
│  └─ SharedPreferences save fails
│     → Caught: Try-catch in _saveSessions()
│     → Fix: Log error, notify user
│
├─ Data Corruption
│  └─ Invalid JSON in SharedPreferences
│     → Caught: Try-catch in _loadSessions()
│     → Fix: Clear and reset, restore from backup
│
└─ User Error
   └─ Abandon session accidentally
      → Caught: Confirmation dialog
      → Fix: Allow undo via history
```

## Performance Considerations

1. **Memory**: Climb sessions loaded once at init
2. **Storage**: JSON serialization is efficient
3. **UI**: Minimal rebuilds with setState scoping
4. **Network**: All local (no API calls)
5. **Scalability**: Works well with 100+ sessions

## Future Architecture Enhancements

- Add Firestore sync for cloud backup
- Implement offline-first sync
- Add image/media storage
- Implement analytics pipeline
- Add leaderboard infrastructure
