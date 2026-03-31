# Integration Guide: Firebase Station Sync

## Quick Start

### 1. Initialize StationService with User ID
When a user logs in, pass their Firebase UID to StationService:

```dart
// In your login/auth flow
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hamiguitan_trekscan_plus/services/station_service.dart';

final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  final stationService = await StationService.init(userId: user.uid);
  await stationService.loadStations();
  // Stations now include both local and Firebase data
}
```

### 2. Update Stations on QR Scan
When a user scans a QR code, the visited status is automatically synced:

```dart
// In your QR scanner or station detail screen
import 'package:hamiguitan_trekscan_plus/services/station_service.dart';

final stationService = await StationService.init();
await stationService.updateStationVisited(stationId, true);
// ✅ Automatically updates SharedPreferences + Firebase
```

### 3. Load Stations on App Start
Ensure stations are loaded from both sources:

```dart
// In your main screen or splash screen
@override
void initState() {
  super.initState();
  _loadStationData();
}

Future<void> _loadStationData() async {
  final user = FirebaseAuth.instance.currentUser;
  _stationService = await StationService.init(userId: user?.uid);
  await _stationService.loadStations();
  // Merges local data with Firebase
}
```

## Implementation Examples

### Example 1: QR Scanner Integration
```dart
import 'package:hamiguitan_trekscan_plus/services/station_service.dart';

class QRScannerScreen extends StatefulWidget {
  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  late StationService _stationService;

  @override
  void initState() {
    super.initState();
    _initializeStationService();
  }

  Future<void> _initializeStationService() async {
    _stationService = await StationService.init();
    await _stationService.loadStations();
  }

  Future<void> _handleQRCodeScanned(String qrCode) async {
    try {
      // Mark station as visited
      await _stationService.updateStationVisited(qrCode, true);
      
      AppLogger.i('✅ Station marked as visited');
      AppLogger.i('📱 Automatically saved to local storage');
      AppLogger.i('☁️ Automatically synced to Firebase');
      
      // Navigate to station detail
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StationDetailScreen(
              station: _stationService.getStationById(qrCode)!,
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.i('❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Your QR scanner UI
    );
  }
}
```

### Example 2: Home Screen with Real-time Sync
```dart
import 'package:hamiguitan_trekscan_plus/services/firestore_station_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreStationService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<String>>(
        // Listen to real-time updates from other devices
        stream: _firestoreService.getVisitedStationsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final visitedStationIds = snapshot.data ?? [];
          
          return Column(
            children: [
              Text('Visited Stations: ${visitedStationIds.length}'),
              // Show stations
            ],
          );
        },
      ),
    );
  }
}
```

### Example 3: Profile Screen with Stats
```dart
import 'package:hamiguitan_trekscan_plus/services/firestore_station_service.dart';

class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firestoreService = FirestoreStationService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<String>>(
        future: _firestoreService.getVisitedStationIds(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final visitedCount = snapshot.data?.length ?? 0;
          
          return Column(
            children: [
              Text('Total Visited: $visitedCount / 15'),
              Text('Progress: ${((visitedCount / 15) * 100).toStringAsFixed(1)}%'),
              // Show progress bars or badges
            ],
          );
        },
      ),
    );
  }
}
```

### Example 4: Handle Login/Logout
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hamiguitan_trekscan_plus/services/station_service.dart';

class AuthService {
  static Future<void> handleUserLogin(User user) async {
    // Initialize StationService with user ID
    final stationService = await StationService.init(userId: user.uid);
    
    // Load and merge stations from both local and Firebase
    await stationService.loadStations();
    
    AppLogger.i('✅ User logged in: ${user.email}');
    AppLogger.i('📱 Local stations loaded');
    AppLogger.i('☁️ Firebase data merged');
  }

  static Future<void> handleUserLogout() async {
    // Clear local cache but keep Firebase data
    final stationService = await StationService.init();
    
    // Optional: Reset stations on logout
    // await stationService.resetAllStations();
    
    AppLogger.i('✅ User logged out');
    AppLogger.i('📱 Local cache cleared');
  }
}
```

## Firestore Rules Setup

Add these security rules to your Firestore to protect user data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Deny all by default
    match /{document=**} {
      allow read, write: if false;
    }

    // Users collection
    match /users/{userId} {
      // Users can only access their own user document
      allow read, write: if request.auth.uid == userId;
      
      // Allow all operations on subcollections for authorized users
      match /{document=**} {
        allow read, write: if request.auth.uid == userId;
      }
    }
  }
}
```

## Data Persistence Strategy

The app uses a **hybrid approach**:

### SharedPreferences (Local Cache)
- **Speed**: Instant access
- **Storage**: Device only
- **Use**: Offline support, caching
- **TTL**: Indefinite (app data)

### Firestore (Cloud Storage)
- **Speed**: Network dependent
- **Storage**: Cloud backend
- **Use**: Cross-device sync, backup
- **Sync**: Real-time with stream listeners

### Sync Flow
```
User Action (QR Scan)
    ↓
StationService.updateStationVisited()
    ├─ Write to SharedPreferences (instant ✅)
    └─ Sync to Firestore (async 📡)
        ├─ Success: Update in cloud ✅
        └─ Failure: Log warning ⚠️
              (User doesn't notice - offline support works)
```

## Error Handling

The implementation is resilient to failures:

### Offline Scenario
```dart
// Device has no internet
await stationService.updateStationVisited(stationId, true);
// ✅ Updates local storage immediately
// 📡 Firebase sync fails silently
// ✅ Data persists locally
// ✅ Syncs when connection restored
```

### Firebase Unavailable
```dart
// Firebase service is down
await stationService.updateStationVisited(stationId, true);
// ✅ Updates local storage
// 📡 Firebase sync fails with error
// ✅ App continues functioning
// 📝 Error logged for debugging
```

## Testing Checklist

- [ ] User logs in
- [ ] Load stations (local data appears)
- [ ] Scan QR code (station marked visited locally)
- [ ] Check Firestore (station appears in database)
- [ ] Login on another device (visited stations appear)
- [ ] Disconnect internet (app still works)
- [ ] Reconnect internet (data syncs)
- [ ] Reset progress (both local and Firebase cleared)

## Monitoring

### Enable Logging
```dart
// Add to main.dart to see detailed logs
import 'package:flutter/foundation.dart';

void main() {
  // Enable Firestore logging
  if (kDebugMode) {
    AppLogger.i('📱 Starting TrekScanPlus with Firebase Station Sync');
    AppLogger.i('🔍 Debug logging enabled');
  }
  
  runApp(MyApp());
}
```

### Check Logs
```
✅ Station Station 1: UNESCO Marker saved to Firestore
✅ Fetched 3 visited stations from Firestore
🔄 Visited stations stream updated: 4 stations
```

## Troubleshooting

### Issue: Stations Not Syncing to Firebase
**Symptoms**: Local stations update but don't appear in Firestore

**Causes**:
1. User not logged in
2. No internet connection
3. Firestore rules too restrictive
4. Firebase project not configured

**Solution**:
```dart
// Verify user is logged in
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  AppLogger.i('❌ No user logged in');
} else {
  AppLogger.i('✅ Logged in as: ${user.uid}');
}

// Check Firestore connection
final collection = FirebaseFirestore.instance.collection('users');
await collection.doc(user!.uid).get();
```

### Issue: Cross-Device Sync Not Working
**Symptoms**: Same account on Device A and B, but stations don't sync

**Solution**:
1. Verify both devices use same Firebase project
2. Check Firestore rules allow access
3. Ensure network connectivity
4. Check user UID matches

### Issue: Duplicate Stations
**Symptoms**: Stations appear multiple times in list

**Solution**: 
```dart
// The service deduplicates automatically
// If issue persists, clear app cache:
// Settings → Apps → TrekScanPlus → Storage → Clear Cache
```

## Performance Considerations

### Batch Operations
For syncing multiple stations:

```dart
// ❌ Don't do this (slow - multiple writes)
for (var stationId in stationIds) {
  await stationService.updateStationVisited(stationId, true);
}

// ✅ Do this instead (optimized)
final stationService = await StationService.init();
await stationService.loadStations();
// Load all at once, then update individually with caching
```

### Firestore Quotas
- **Free tier**: 20,000 reads/day, 10,000 writes/day
- **Current usage**: ~1 write per station visit
- **Estimate**: 15 stations × 100 users × 1 write = 1,500 writes/day ✅

## Related Files

- Service: `lib/services/firestore_station_service.dart`
- Integration: `lib/services/station_service.dart`
- Documentation: `documentation/FIREBASE_STATION_SYNC.md`
- Security: `firestore.rules`

## Support

For issues or questions:
1. Check the logs (debug mode)
2. Verify Firebase configuration
3. Review this integration guide
4. Check Firestore console
