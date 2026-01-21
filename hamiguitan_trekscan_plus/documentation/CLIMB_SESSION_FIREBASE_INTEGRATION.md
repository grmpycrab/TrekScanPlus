# Firebase Integration for ClimbSessionService

## Overview
Integrated Firebase Firestore persistence for climb sessions while maintaining backward compatibility with SharedPreferences for offline support.

## Architecture

### Hybrid Data Storage
```
┌─────────────────────────────────────────────┐
│      ClimbSessionService                    │
├─────────────────────────────────────────────┤
│  • Orchestrates all climb session ops       │
│  • Manages local + cloud sync               │
│  • Maintains active session state           │
└────────────────┬────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
┌──────────────┐    ┌─────────────────────────┐
│SharedPrefs   │    │ Firebase Firestore      │
├──────────────┤    ├─────────────────────────┤
│Local Cache   │    │Cloud Persistence       │
│Offline Supp. │    │Cross-device Sync       │
│(Instant)     │    │Real-time Updates       │
└──────────────┘    └─────────────────────────┘
     ↑ Read/Write          ↑ Sync (async)
     │                     │
     └─────────────────────┘
```

## Firebase Data Structure

**Firestore Path**: `/users/{userId}/climbs/{climbId}`

```javascript
{
  "id": "1705900234567",
  "name": "Trek Session - 2026-01-22 14:57:14",
  "description": "Auto-created when scanning Station X",
  "trekType": "regular_trek",
  "createdAt": "2026-01-22T14:57:14.567Z",
  "trekStartDate": "2026-01-22T00:00:00.000Z",
  "trekEndDate": null,
  "startedAt": "2026-01-22T15:10:30.123Z",
  "completedAt": null,
  "status": "ongoing",
  "visitedStations": [
    {
      "stationId": "stn1",
      "stationName": "Base Camp",
      "scannedAt": "2026-01-22T15:10:30.123Z",
      "elevation": 100,
      "distanceFromPrevious": null
    },
    {
      "stationId": "stn2",
      "stationName": "Mossy Trail",
      "scannedAt": "2026-01-22T15:25:45.456Z",
      "elevation": 250,
      "distanceFromPrevious": 2.5
    }
  ],
  "totalDuration": null,
  "totalDistance": null
}
```

## Features Implemented

### ✅ 1. Automatic Local-First Sync
```dart
// Creates locally (instant) + syncs to Firebase (async)
final session = await climbSessionService.createClimbSession(
  name: 'My Trek',
  description: 'January Summit Attempt',
  trekType: 'regular_trek',
);

// User sees session immediately
// Firebase syncs in background
```

### ✅ 2. Offline Support
- App works completely offline with SharedPreferences
- Firebase sync happens when connection is available
- No data loss if Firebase temporarily unavailable

### ✅ 3. Cross-Device Sync
```dart
// Real-time stream of climb sessions
climbSessionService.getClimbSessionsStream().listen((sessions) {
  // Updates when other devices modify climbs
  // Useful for multi-device tracking
});
```

### ✅ 4. Full CRUD Operations
| Operation | Local | Firebase | Description |
|-----------|-------|----------|-------------|
| Create | ✅ Instant | ✅ Async | Auto-synced on create |
| Read | ✅ Fast | ✅ On-demand | Loads from local cache first |
| Update | ✅ Instant | ✅ Async | All updates auto-synced |
| Delete | ✅ Instant | ✅ Async | Deletion synced to cloud |

### ✅ 5. Session Merging
When user logs in:
1. Local sessions loaded from SharedPreferences (instant)
2. Firebase sessions fetched in parallel
3. Firebase data takes precedence (source of truth)
4. Local cache updated with merged data

### ✅ 6. User Scoping
- Each user's climbs stored in their own collection: `/users/{userId}/climbs`
- Automatic filtering by current user UID
- No cross-user data contamination

## Integration Points

### 1. App Initialization
```dart
// In login screen after successful authentication
final user = FirebaseAuth.instance.currentUser;
final climbService = await ClimbSessionService.init(userId: user.uid);

// Loads local cache instantly + syncs with Firebase
// User's old climbs automatically merged from cloud
```

### 2. QR Scanner (Already Integrated)
```dart
// In scanner_screen.dart
var activeSession = climbSessionService.getActiveSession();

// If no session exists, one is auto-created
if (activeSession == null) {
  activeSession = await climbSessionService.createClimbSession(...);
}

// Station is added locally (instant) + Firebase syncs async
activeSession.addVisitedStation(station);
await climbSessionService.updateSession(activeSession);
```

### 3. Station Screen (Already Integrated)
```dart
// Display all climb sessions
final allSessions = climbSessionService.getAllSessions();

// Edit/delete operations auto-sync
await climbSessionService.updateSession(editedSession);
await climbSessionService.deleteSession(sessionId);
```

## Firebase Security Rules

Add these rules to `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      
      match /climbs/{document=**} {
        allow read, write: if request.auth.uid == userId;
      }
    }
  }
}
```

**Deploy:**
```bash
firebase deploy --only firestore:rules
```

## API Reference

### Core Methods

```dart
// Create new climb session (auto-syncs)
Future<ClimbSession> createClimbSession({
  required String name,
  required String description,
  required String trekType,
  DateTime? trekStartDate,
  DateTime? trekEndDate,
})

// Update session (auto-syncs)
Future<void> updateSession(ClimbSession session)

// Delete session (auto-syncs)
Future<void> deleteSession(String sessionId)

// Get active session (most recent ongoing)
ClimbSession? getActiveSession()

// Get all sessions (includes completed + ongoing)
List<ClimbSession> getAllSessions()

// Only completed sessions
List<ClimbSession> getCompletedSessions()

// Only ongoing sessions
List<ClimbSession> getOngoingSessions()
```

### Firebase Sync Methods

```dart
// Real-time stream of all user's climb sessions
Stream<List<ClimbSession>> getClimbSessionsStream()

// Internal: Sync to Firebase
Future<void> _syncSessionToFirebase(
  ClimbSession session, {
  bool isNew = false,
})
```

## Performance Considerations

### Local Cache Benefits
- **Speed**: SharedPreferences access is instant
- **Offline**: Works completely without internet
- **Reduced Quota**: Firebase only syncs on operations
- **Bandwidth**: Uses minimal data

### Firestore Quotas (Free Tier)
- Read capacity: 20,000/day
- Write capacity: 10,000/day
- Estimated usage: ~1 write per climb session update
- For 100 users with 5 active climbs: 500 writes/day ✅

### Network Usage
- Per climb sync: ~2KB (includes all visited stations)
- Acceptable for mobile networks ✅

## Offline-First Workflow

```
User Action (Create Climb)
    ↓
✅ Saved to SharedPreferences (instant)
    ↓
User sees changes immediately
    ↓
📡 Sync triggered to Firebase (background)
    ├─ Success: Stored in cloud ✅
    └─ Failure: App works offline, retry on next sync ⚠️
    ↓
User can continue using app
```

## Migration Path

### For Existing Users
1. User logs in → ClimbSessionService.init(userId: user.uid)
2. Local sessions loaded from SharedPreferences
3. Firebase sessions fetched + merged
4. User sees all their old climbs
5. New climbs auto-sync to Firebase

### No Data Loss
- Old local data preserved
- Migrated transparently to Firestore
- Can switch devices anytime
- Cross-device access works immediately

## Troubleshooting

### Issue: Climbs Not Syncing to Firebase
**Cause**: User not logged in

**Solution**:
```dart
// Verify user is authenticated
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  await ClimbSessionService.init(userId: user.uid);
}
```

### Issue: No Offline Support
**Cause**: Trying to access climbs without initializing service

**Solution**:
```dart
// Initialize service on app startup (with or without user)
await ClimbSessionService.init(userId: firebaseUser?.uid);
```

### Issue: Climbs Don't Appear on New Device
**Cause**: User not logged in or wrong user

**Solution**:
1. Verify same Firebase account logged in
2. Check Firestore rules allow access
3. Force sync: Re-initialize service with user UID

## Related Files

- **Service**: `lib/services/climb_session_service.dart`
- **Model**: `lib/models/climb_session.dart`
- **Integration**: `lib/screens/main/scanner_screen.dart`, `lib/screens/main/station_screen.dart`
- **Rules**: `firestore.rules`
- **Documentation**: This file

## Next Steps

1. ✅ Deploy Firestore rules
2. ✅ Initialize service with user UID on login
3. ✅ Test offline functionality
4. ✅ Test cross-device sync
5. ✅ Monitor Firestore quota usage
6. Consider: Real-time collaboration features (multiple users on same climb)

---

**Last Updated**: January 22, 2026
**Status**: ✅ Implemented and Ready for Production
