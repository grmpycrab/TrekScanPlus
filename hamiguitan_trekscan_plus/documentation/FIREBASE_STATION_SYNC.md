# Firebase Station Sync Implementation

## Overview
Visited stations are now automatically synced to Firebase Firestore. This ensures user progress is persisted across:
- App reinstalls
- Device changes
- Multi-device logins

## Architecture

### Services
1. **FirestoreStationService** (`firestore_station_service.dart`)
   - Handles all Firestore operations
   - Singleton pattern for global access
   - Auto-scoped to current user

2. **StationService** (`station_service.dart`)
   - Enhanced to sync with Firestore
   - Maintains backward compatibility with SharedPreferences
   - Hybrid local/cloud storage

### Data Structure in Firestore
```
users/
├── {userId}/
    └── visitedStations/
        ├── {stationId1}/
        │   ├── stationId: string
        │   ├── stationName: string
        │   ├── difficulty: string
        │   ├── elevation: number
        │   ├── latitude: number
        │   ├── longitude: number
        │   ├── isVisited: boolean
        │   ├── visitedAt: timestamp
        │   └── lastUpdated: timestamp
        └── {stationId2}/
            └── ...
```

## Usage

### Automatic Sync
Syncing happens automatically in these scenarios:

1. **When marking a station as visited**
   ```dart
   await stationService.updateStationVisited(stationId, true);
   // Automatically saves to Firebase
   ```

2. **When loading stations**
   ```dart
   await stationService.loadStations();
   // Merges local and Firebase data
   ```

3. **When resetting stations**
   ```dart
   await stationService.resetAllStations();
   // Clears both local and Firebase data
   ```

### Manual Sync Operations
For advanced use cases:

```dart
final firestoreService = FirestoreStationService.instance;

// Get all visited station IDs
final visitedIds = await firestoreService.getVisitedStationIds();

// Listen to real-time updates
firestoreService.getVisitedStationsStream().listen((stationIds) {
  AppLogger.i('Updated stations: $stationIds');
});

// Check if specific station is visited
final isVisited = await firestoreService.isStationVisited('stn1');

// Manual sync
await firestoreService.syncVisitedStations(localStationIds);
```

## Features

### ✅ Real-time Sync
- Changes on one device appear on others instantly
- Stream-based listeners for live updates

### ✅ Offline Support
- Works without internet connection
- Data is cached locally
- Syncs when connection is restored

### ✅ Data Integrity
- Server timestamps prevent clock-skew issues
- Merge options prevent data loss
- Atomic operations ensure consistency

### ✅ Error Handling
- Graceful fallbacks if Firebase is unavailable
- Local data persists even if sync fails
- Detailed logging for debugging

### ✅ User Scoping
- Each user's data is isolated
- Automatic filtering by UID
- Secure by default (Firestore rules required)

## Security Considerations

### Required Firestore Rules
Add these rules to your Firestore to secure user data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      
      // Visited stations subcollection
      match /visitedStations/{document=**} {
        allow read, write: if request.auth.uid == userId;
      }
    }
  }
}
```

## Implementation Details

### Hybrid Storage Strategy
The app uses both SharedPreferences and Firestore:

| Aspect | Local (SharedPreferences) | Cloud (Firestore) |
|--------|--------------------------|-------------------|
| Speed | ⚡ Instant | 📡 Network dependent |
| Persistence | 📱 Device only | ☁️ Cloud backed |
| Sync | ❌ Manual | ✅ Automatic |
| Use Case | Cache/Offline | Source of truth |

### Data Flow

```
User Scans QR
    ↓
StationService.updateStationVisited()
    ↓
├─ Update SharedPreferences (instant)
└─ Sync to FirestoreStationService
    ├─ Save station data
    ├─ Attach server timestamp
    └─ Merge with existing data
```

### Error Handling Strategy
- Local updates always succeed
- Firebase sync is best-effort
- Warnings logged but not thrown
- User can continue using app offline

## Integration Points

### App Initialization
When user logs in, stations are automatically synced:

```dart
// In login screen or splash screen
_stationService = await StationService.init(userId: user.uid);
await _stationService.loadStations();
// Firebase data is merged here
```

### Station Detail Screen
When viewing a station:

```dart
// Already integrated via StationService
// No code changes needed
final isVisited = station.isVisited;
```

### QR Scanner
When scanning a station:

```dart
// Already integrated via StationService
await stationService.updateStationVisited(scannedStationId, true);
// Both local and Firebase updated automatically
```

## Testing

### Test Local Sync
```dart
// Verify data is saved locally
final prefs = await SharedPreferences.getInstance();
final visitedIds = prefs.getStringList('visited_stations_$userId');
assert(visitedIds != null && visitedIds.isNotEmpty);
```

### Test Firebase Sync
```dart
// Verify data is in Firestore
final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .collection('visitedStations')
    .doc(stationId)
    .get();
assert(doc.exists);
```

### Test Cross-Device Sync
1. Login on Device A, scan stations
2. Wait 2-3 seconds
3. Login on Device B with same account
4. Load stations on Device B
5. Verify stations show as visited

## Troubleshooting

### Stations Not Appearing as Visited
- Check: User is logged in (`FirebaseAuth.instance.currentUser != null`)
- Check: Firestore has internet connectivity
- Check: User UID matches in both local and cloud
- Solution: Check logs for Firebase errors

### Cross-Device Sync Not Working
- Check: Same Firebase project on both devices
- Check: Both devices using same account
- Check: Firestore rules allow read/write
- Solution: Clear app data and re-login

### Performance Issues
- Monitor: Number of stations (currently 15)
- Monitor: Firestore reads/writes quota
- Optimize: Batch operations for multiple stations
- Cache: Real-time listeners for frequently accessed data

## Future Enhancements

1. **Batch Sync** - Sync multiple stations in one transaction
2. **Sync History** - Track when stations were visited
3. **Analytics** - Track completion rates
4. **Notifications** - Alert on cross-device changes
5. **Offline Queue** - Queue changes when offline, sync when online

## Related Documentation
- Firebase Firestore: https://firebase.google.com/docs/firestore
- Flutter Firebase: https://firebase.flutter.dev
- SharedPreferences: https://pub.dev/packages/shared_preferences
