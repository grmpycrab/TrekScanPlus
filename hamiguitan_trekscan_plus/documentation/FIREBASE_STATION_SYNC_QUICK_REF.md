# Firebase Station Sync - Quick Reference

## 🚀 Quick Start (5 Minutes)

### 1. Deploy Firestore Rules
```bash
# In terminal
firebase deploy --only firestore:rules
```

Add to `firestore.rules`:
```javascript
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
  match /visitedStations/{document=**} {
    allow read, write: if request.auth.uid == userId;
  }
}
```

### 2. Initialize with User ID
```dart
// When user logs in
final user = FirebaseAuth.instance.currentUser;
final stationService = await StationService.init(userId: user?.uid);
await stationService.loadStations();
```

### 3. Done!
Stations now sync automatically:
```dart
// Mark as visited (auto-syncs)
await stationService.updateStationVisited(stationId, true);

// Get visited (from cloud)
final ids = await FirestoreStationService.instance.getVisitedStationIds();

// Listen to updates (real-time from other devices)
FirestoreStationService.instance.getVisitedStationsStream().listen((ids) {
  print('Visited: $ids');
});
```

---

## 📚 API Reference

### StationService
```dart
// Load stations (merges local + Firebase)
await stationService.loadStations();

// Mark visited (auto-syncs to Firebase)
await stationService.updateStationVisited(stationId, isVisited);

// Get all visited
List<StationData> visited = stationService.getVisitedStations();

// Get unvisited
List<StationData> unvisited = stationService.getUnvisitedStations();

// Reset all (clears both local + Firebase)
await stationService.resetAllStations();
```

### FirestoreStationService
```dart
// Save a station
await FirestoreStationService.instance.saveVisitedStation(station);

// Remove a station
await FirestoreStationService.instance.removeVisitedStation(stationId);

// Get all visited IDs (one-time)
final ids = await FirestoreStationService.instance.getVisitedStationIds();

// Listen to changes (real-time)
FirestoreStationService.instance.getVisitedStationsStream().listen((ids) {
  // Called when:
  // - This device marks a station visited
  // - Another device marks a station visited
  // - This device receives Firebase update
});

// Check if visited
final isVisited = await FirestoreStationService.instance.isStationVisited(id);

// Manual sync
await FirestoreStationService.instance.syncVisitedStations(localIds);

// Clear all
await FirestoreStationService.instance.resetAllVisitedStations();
```

---

## 🎯 Common Scenarios

### Scenario 1: User Logs In
```dart
@override
void initState() {
  super.initState();
  _loadData();
}

Future<void> _loadData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    _stationService = await StationService.init(userId: user.uid);
    await _stationService.loadStations();
    // ✅ Local + Firebase data merged
    setState(() => _isLoading = false);
  }
}
```

### Scenario 2: QR Code Scanned
```dart
Future<void> _handleQRScanned(String qrCode) async {
  try {
    await _stationService.updateStationVisited(qrCode, true);
    // ✅ Saved locally
    // ✅ Syncing to Firebase
    print('Station marked as visited!');
  } catch (e) {
    print('Error: $e');
  }
}
```

### Scenario 3: Show Real-time Progress
```dart
@override
Widget build(BuildContext context) {
  return StreamBuilder<List<String>>(
    stream: FirestoreStationService.instance.getVisitedStationsStream(),
    builder: (context, snapshot) {
      final count = snapshot.data?.length ?? 0;
      return Text('Visited: $count / 15');
    },
  );
}
```

### Scenario 4: Multi-Device Sync
```dart
// Device A
await stationService.updateStationVisited('stn1', true);

// Device B (automatic)
// Sees update immediately via stream listener
FirestoreStationService.instance.getVisitedStationsStream().listen((ids) {
  if (ids.contains('stn1')) {
    print('🔄 Device A marked stn1 as visited!');
  }
});
```

---

## ⚙️ Configuration

### Pass User ID on Init
```dart
// ✅ Correct
final service = await StationService.init(userId: user.uid);

// ❌ Won't sync to Firebase
final service = await StationService.init();
```

### Firestore Rules Must Be Set
```javascript
// ✅ Allows user to access their data
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}

// ❌ Denies all access
match /users/{userId} {
  allow read, write: if false;
}
```

### Must Be Logged In
```dart
// ✅ Syncs to Firebase
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  await stationService.updateStationVisited(id, true);
}

// ⚠️ Doesn't sync (no user)
await stationService.updateStationVisited(id, true);
```

---

## 🔍 Debugging

### Check if User is Logged In
```dart
final user = FirebaseAuth.instance.currentUser;
print('Logged in: ${user != null}');
print('UID: ${user?.uid}');
```

### Check Local Data
```dart
final prefs = await SharedPreferences.getInstance();
final local = prefs.getStringList('visited_stations_$uid');
print('Local: $local');
```

### Check Firebase Data
```
Console → Firestore → users → {userId} → visitedStations
```

### Enable Debug Logging
```dart
// Add to main.dart
if (kDebugMode) {
  print('🔍 Debug logging enabled');
}
```

### Common Errors
```
❌ Error: No user logged in
   → Login user before calling functions

❌ Error: Permission denied
   → Check Firestore rules are deployed

❌ Error: Network error
   → Check internet connection

❌ Stations not syncing
   → Check user UID is passed to StationService.init()
```

---

## 📊 Monitoring

### Track Firebase Writes
```dart
// Monitor in Firestore console
Console → Usage → Write Operations

Each station sync = 1 write
15 stations × 100 users = 1,500 writes/day ✅
```

### Check Real-time Updates
```dart
// Open Firestore in console and watch
Console → Firestore → users → {userId} → visitedStations
```

---

## 🚨 Common Issues

| Issue | Solution |
|-------|----------|
| Stations not appearing in Firestore | Pass userId to `StationService.init()` |
| Cross-device sync not working | Wait 5 seconds, check same account on both devices |
| Getting permission errors | Deploy Firestore rules: `firebase deploy --only firestore:rules` |
| App crashes on station update | Wrap in try-catch, check user is logged in |
| Offline stations not syncing | Call `loadStations()` again when back online |

---

## 🔗 Related Files

- Service: `lib/services/firestore_station_service.dart`
- Integration: `lib/services/station_service.dart`
- Rules: `firestore.rules`
- Docs: `documentation/FIREBASE_STATION_SYNC*.md`

---

## 💡 Pro Tips

1. **Always pass userId to StationService.init()**
   ```dart
   final service = await StationService.init(
     userId: FirebaseAuth.instance.currentUser?.uid
   );
   ```

2. **Use stream for real-time updates**
   ```dart
   // ❌ Polling (wasteful)
   Timer.periodic(Duration(seconds: 1), (_) {
     getVisitedStations();
   });

   // ✅ Stream (efficient)
   FirestoreStationService.instance.getVisitedStationsStream().listen((_) {});
   ```

3. **Handle errors gracefully**
   ```dart
   try {
     await stationService.updateStationVisited(id, true);
   } catch (e) {
     // Logged but app continues (offline support)
     print('Sync failed: $e');
   }
   ```

4. **Test cross-device on same account**
   ```dart
   // Device A & B
   firebase login
   # Use same email on both
   ```

---

## 📞 Need Help?

1. Check debug logs: `flutter run | grep -i firebase`
2. Read full docs: `documentation/FIREBASE_STATION_SYNC.md`
3. Check Firestore console: `https://console.firebase.google.com`
4. Review code: `lib/services/firestore_station_service.dart`
