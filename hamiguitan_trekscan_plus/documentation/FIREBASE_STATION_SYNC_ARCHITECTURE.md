# Firebase Station Sync - Visual Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        TREKSCANPLUS APP                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              UI Screens & Components                     │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  • Home Screen (display progress)                        │  │
│  │  • QR Scanner (mark visited)                            │  │
│  │  • Station Detail (show info)                           │  │
│  │  • Profile (show stats)                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            ↕                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │        StationService (Sync Orchestrator)               │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  • loadStations()                                        │  │
│  │  • updateStationVisited()                                │  │
│  │  • resetAllStations()                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                    ↙              ↘                              │
│                   /                \                             │
│                  /                  \                            │
│         ┌──────────────┐      ┌──────────────────────────┐      │
│         │ SharedPrefs  │      │ FirestoreStationService │      │
│         ├──────────────┤      ├──────────────────────────┤      │
│         │ (Local Cache)│      │ (Cloud Sync Manager)    │      │
│         └──────────────┘      └──────────────────────────┘      │
│             ↓                         ↓                          │
│         ┌──────────────┐      ┌──────────────────────────┐      │
│         │  Device     │◄────►│   Firebase              │      │
│         │  Storage    │      │   Firestore            │      │
│         │             │      │   + Auth               │      │
│         └──────────────┘      └──────────────────────────┘      │
│                                        ↓                         │
│                                   ☁️ CLOUD                       │
│                                        ↓                         │
│                           ┌────────────────────────┐             │
│                           │  users/{userId}       │             │
│                           │  ├─ name              │             │
│                           │  ├─ email             │             │
│                           │  └─ visitedStations   │             │
│                           │     ├─ stn1           │             │
│                           │     ├─ stn2           │             │
│                           │     └─ stn3           │             │
│                           └────────────────────────┘             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

### When User Scans QR Code:

```
┌─────────────────┐
│  QR Code Scan   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│ StationService.updateStationVisited(stationId, true)   │
└────────┬────────────────────────────────────────────────┘
         │
         │ (Immediate ✅)
         ▼
┌─────────────────────────────────────────────────────────┐
│ 1. Update SharedPreferences                             │
│    visited_stations_userId = [stn1, stn2]             │
└────────┬────────────────────────────────────────────────┘
         │ (Async, Best-effort 📡)
         ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Call FirestoreStationService.saveVisitedStation()   │
│    └─ Add to /users/{userId}/visitedStations/{stnId}  │
└────────┬────────────────────────────────────────────────┘
         │ (Network dependent ⏱️)
         ▼
    ┌────────────────────────┐
    │ Success  │  Failure    │
    └────┬─────┴────┬────────┘
         │          │
         │ (✅)     │ (⚠️ Logged, app continues)
         ▼          ▼
    Firestore    Local Only
    ☁️ Cloud      📱 Device
```

## Multi-Device Sync Diagram

```
DEVICE A                    FIREBASE               DEVICE B
┌────────────────┐         ☁️ CLOUD              ┌────────────────┐
│   User@A       │         Cloud DB              │   User@B       │
│  stn1 ✓        │        ┌────────┐             │   No data      │
└────┬───────────┘        │users   │             └────┬───────────┘
     │                    │{uid}   │                   │
     │  Scan stn2         │visited │                   │
     ▼                    │Stations│                   │
   Mark                   └───┬────┘                   ▼
  stn2 ✓                      │                   App Starts
     │                        │
     │  Save to local         │
     ▼  + Firebase            │
   ┌─────────────┐            │
   │ stn1 ✓      │            │
   │ stn2 ✓      │  Sync      │  Get from
   └─────┬───────┘  Upload    │  Firebase
         │         ────────►  │
         │                    ▼
         │               ┌──────────────┐
         │               │ stn1 ✓       │
         │               │ stn2 ✓       │
         │               └──────────────┘
         │                  ✅ Synced!
         │
       Real-time listener
        (via stream)
         │
         ├─ stn1 (already known)
         ├─ stn2 (already known)
         └─ [awaiting Device B action]
```

## State Transitions Diagram

```
START
  │
  ├─ Not Logged In
  │   ├─ Local: ❌ Can't save
  │   └─ Firebase: ❌ Can't sync
  │
  └─ Logged In
      ├─ Online 🟢
      │   ├─ Local: ✅ Save instant
      │   └─ Firebase: ✅ Sync instant
      │
      └─ Offline 🔴
          ├─ Local: ✅ Save instant
          └─ Firebase: ⏳ Queue
              │
              └─ Connection Restored 🟢
                  └─ Sync queued data
```

## Error Handling Flow

```
User Action
  │
  ▼
UpdateStationVisited()
  │
  ├──────────────────────────────────────────────────┐
  │                                                  │
  ▼ (Local - Always succeeds)                        ▼ (Firebase - Best-effort)
┌────────────────┐                        ┌──────────────────────────┐
│ Update Local   │                        │ Try Firebase Sync        │
│ Store ✅       │                        └────┬─────────────────────┘
└────────────────┘                             │
  │                                     ┌──────┴──────────┐
  │                              Success │               │ Failure
  │                                ✅    │              ⚠️
  │                                 │    │               │
  │                                 ▼    ▼               │
  │                            Data in   Log error       │
  │                            Cloud ☁️  Continue app   │
  │                                                      │
  └──────────────────────────────┬─────────────────────┘
                                 │
                       ✅ Result: User can continue
                           (Offline support maintained)
```

## Firebase Data Structure Diagram

```
Firebase Firestore
├── users (collection)
│   ├── {userId1}
│   │   ├── email: "user1@example.com"
│   │   ├── name: "User One"
│   │   ├── visitedStations (subcollection)
│   │   │   ├── stn1
│   │   │   │   ├── stationId: "stn1"
│   │   │   │   ├── stationName: "Station 1: UNESCO Marker"
│   │   │   │   ├── difficulty: "Easy"
│   │   │   │   ├── elevation: 1200
│   │   │   │   ├── latitude: 6.7362917
│   │   │   │   ├── longitude: 126.1416639
│   │   │   │   ├── isVisited: true
│   │   │   │   ├── visitedAt: timestamp
│   │   │   │   └── lastUpdated: timestamp
│   │   │   ├── stn2
│   │   │   │   ├── stationId: "stn2"
│   │   │   │   ├── stationName: "Station 2: ..."
│   │   │   │   └── ...
│   │   │   └── stn3
│   │   │       └── ...
│   │   └── (other user fields)
│   └── {userId2}
│       ├── email: "user2@example.com"
│       ├── visitedStations
│       │   ├── stn1
│       │   ├── stn5
│       │   └── stn10
│       └── ...
└── (other collections)
```

## Sync Timeline

```
DEVICE A                                    FIREBASE                                    DEVICE B
   │                                           │                                           │
   │  (12:00:00) Scan QR "stn1"               │                                           │
   │─────────────────────────────────────────►│                                           │
   ├─ Store local instantly                   │                                           │
   │  ✅ (12:00:00.001)                       │                                           │
   │                                          │                                           │
   │                                   (12:00:00.5)
   │                                   Upload to Cloud
   │                                          │
   │                                   (12:00:01) 
   │                                   Stored in DB
   │                                   ✅ stn1 exists
   │                                          │
   │                                          │  (12:00:02) Real-time listener
   │                                          │  triggers on Device B
   │                                          │
   │                                          ├──────────────────────────►│
   │                                          │  StreamSnapshot: [stn1]   │
   │                                          │                          ├─ Load
   │                                          │                          │ ✅
   │                                          │                          │
   │                                          │                          │ (12:00:02)
   │                                          │                          │ Device B
   │                                          │                          │ updates UI
   │◄─────────────────────────────────────────┴──────────────────────────┤
   │
   TOTAL LATENCY: ~2 seconds (network dependent)
```

## Offline Scenario

```
Device Goes Offline
       │
       ▼
  ┌─────────────────────────────────┐
  │ User Scans QR Code: stn1        │
  └────┬────────────────────────────┘
       │
       ├─ SaveToLocal() ✅
       │  └─ SharedPreferences updated instantly
       │
       └─ SaveToFirebase() ⏳
          └─ OFFLINE! Can't reach cloud
             └─ Log: "⚠️ Firestore sync failed (offline)"
                └─ App continues normally!

  [Later... Internet Restored]
       │
       ├─ App detects connectivity ✅
       │
       └─ Retry sync
          └─ Upload stn1 to Firebase
             └─ Success ✅
             └─ Now synced with cloud
                └─ Other devices see update
```

## Class Dependency Diagram

```
StationDetailScreen
    │
    ├─ StationService
    │   │
    │   ├─ SharedPreferences (local cache)
    │   │
    │   └─ FirestoreStationService (cloud sync)
    │       │
    │       ├─ FirebaseFirestore
    │       │   └─ Cloud Database
    │       │
    │       └─ FirebaseAuth
    │           └─ User Authentication
    │
    └─ StationData (model)
        └─ Serialization/Deserialization
```

## Key Components Interaction

```
┌─────────────────────────────────────────────────────────────┐
│  User Interface Layer                                       │
│  ├─ HomeScreen (shows progress)                            │
│  ├─ QRScannerScreen (marks visited)                        │
│  ├─ StationDetailScreen (shows info)                       │
│  └─ ProfileScreen (shows stats)                            │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│  Service Layer (Business Logic)                            │
│  ├─ StationService                                         │
│  │   ├─ loadStations()      ┐ User-scoped                 │
│  │   ├─ updateVisited()     │ operations                  │
│  │   ├─ resetAll()          ┘                             │
│  │                                                         │
│  └─ FirestoreStationService                                │
│      ├─ saveVisitedStation()   ┐                          │
│      ├─ removeVisitedStation() │ Firebase                 │
│      ├─ getVisitedIds()        │ operations               │
│      ├─ getStream()            ┘                          │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│  Data Storage Layer                                        │
│  ├─ SharedPreferences (local)                             │
│  │   └─ visited_stations_{userId}                        │
│  │                                                        │
│  └─ Firebase Firestore (cloud)                            │
│      └─ users/{userId}/visitedStations                   │
└─────────────────────────────────────────────────────────────┘
```

## Summary Flow

```
App Start
  │
  ├─ User Not Logged In? ────────────► Show Login
  │
  └─ User Logged In? ──┐
                        │
                        ▼
                 Initialize Services
                  (with userId)
                        │
                        ▼
                 Load Stations
                 ├─ From Local
                 └─ From Firebase
                 (Merged)
                        │
                        ▼
                 Show Home Screen
                 (with visited count)
                        │
                        ├─ Scan QR? ─┐
                        │            │
                        │            ▼
                        │     Mark as Visited
                        │     ├─ Local ✅
                        │     └─ Firebase 📡
                        │            │
                        │            ▼
                        │     Other Devices
                        │     See Update
                        │     (via stream)
                        │
                        └─ Logout? ────────► Clear Local
                                            (Cloud persists)
```

---

This architecture ensures:
✅ **Fast Local Access** - SharedPreferences is instant
✅ **Cloud Persistence** - Firestore is reliable
✅ **Cross-Device Sync** - Real-time listeners
✅ **Offline Support** - Works without internet
✅ **Error Resilient** - Graceful degradation
