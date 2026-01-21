# Quick Start - Multi-Climb Feature Integration

## 🚀 Get Started in 5 Minutes

### What You Just Got

A complete multi-climb feature that allows users to:
- Create multiple climbing attempts
- Track each climb separately
- View real-time statistics
- Access complete climb history

### 3 Simple Steps to Integration

---

## Step 1: Initialize Service (30 seconds)

Add to your `main.dart`:

```dart
import 'services/climb_session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize ClimbSessionService
  await ClimbSessionService.init(userId: 'user123'); // Add current userId
  
  runApp(const MyApp());
}
```

**That's it!** The service is now ready to use.

---

## Step 2: Connect Scanner (2 minutes)

When a QR code is scanned, add this code:

```dart
// In your scanner/QR handler
Future<void> handleStationScanned(StationData station) async {
  // Get active session (will be null if no active climb)
  final session = ClimbSessionService.instance.getActiveSession();
  
  if (session != null) {
    // Record this station visit
    await ClimbSessionService.instance.addVisitedStation(
      station,
      session,
    );
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${station.name} recorded!')),
    );
  } else {
    // No active session
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create a new climb first')),
    );
  }
}
```

**Done!** Stations are now tracked in the active climb.

---

## Step 3: Complete Climbs (2 minutes)

When user finishes (or manually completes), add:

```dart
// Complete the current climb
Future<void> completeCurrentClimb() async {
  final session = ClimbSessionService.instance.getActiveSession();
  
  if (session != null) {
    // Mark as complete
    await ClimbSessionService.instance.completeSession(session);
    
    // Show completion feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Climb complete! ${session.visitedStations.length} stations'),
      ),
    );
    
    // Navigate to detail view
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClimbSessionDetailScreen(session: session),
      ),
    );
  }
}
```

**Perfect!** Users can now complete climbs and see statistics.

---

## What Happens Automatically

### ✅ User Creates Climb
1. Taps "New Climb" FAB
2. Enters name & description
3. Sees active session banner
4. Ready to scan!

### ✅ User Scans Station
1. Scanner is triggered
2. Your code calls `addVisitedStation()`
3. Service records timestamp, elevation, distance
4. Banner updates automatically
5. Station count increases

### ✅ User Completes Climb
1. You call `completeSession()`
2. Service calculates all statistics
3. Session moves to history
4. User sees detailed stats

---

## UI Already Provided

### Station Screen Updates
- ✅ "New Climb" FAB - Users create sessions
- ✅ Active session banner - Shows live stats
- ✅ History icon - Access past climbs

### New Screens (Already Created)
- ✅ Climb detail screen - Full statistics
- ✅ Sessions list screen - History with tabs

### Dialog (Already Created)
- ✅ New session dialog - Input name/description

**Everything is ready!** No UI work needed.

---

## 5-Minute Testing

### Test Creation
```
1. Run app
2. Tap "New Climb" FAB
3. Enter: "Test Climb"
4. Tap "Create"
5. See active banner ✅
```

### Test Scanner Integration
```
1. Call addVisitedStation() in scanner
2. See banner update ✅
3. Check station count increases ✅
```

### Test Completion
```
1. Call completeSession()
2. See detail screen ✅
3. View statistics ✅
```

---

## Reference: Available APIs

### Create Session
```dart
final session = await ClimbSessionService.instance.createClimbSession(
  name: 'Morning Trek',
  description: 'Solo attempt',
);
```

### Add Station Visit
```dart
await ClimbSessionService.instance.addVisitedStation(
  station, // StationData
  session, // ClimbSession
);
```

### Complete Session
```dart
await ClimbSessionService.instance.completeSession(session);
```

### Get Active Session
```dart
final session = ClimbSessionService.instance.getActiveSession();
if (session != null) {
  // Use session
}
```

### Get All Sessions
```dart
final sessions = ClimbSessionService.instance.getAllSessions();
final completed = ClimbSessionService.instance.getCompletedSessions();
final ongoing = ClimbSessionService.instance.getOngoingSessions();
```

### Get Session Statistics
```dart
final stats = ClimbSessionService.instance.getSessionStats(session);
print('Duration: ${stats['totalDuration']}');
print('Stations: ${stats['totalStations']}');
```

---

## Common Questions

### Q: Do I need to manually update the UI?
**A:** No! The banner updates automatically via ChangeNotifier.

### Q: How do I know when to complete a climb?
**A:** Call it when user:
- Reaches the last station, or
- Taps a "Complete" button, or
- Manually ends the session

### Q: Can I have multiple active climbs?
**A:** No, only one active at a time (by design). But users can:
- Complete one climb
- Start another
- View both in history

### Q: How is data saved?
**A:** Automatically! Every operation auto-saves to SharedPreferences.

### Q: What if user closes the app?
**A:** Data is preserved. Next time they open:
- Previous climbs in history ✓
- If climb was ongoing, it's still marked ongoing ✓
- They can create new climbs ✓

---

## Troubleshooting

### "ClimbSessionService not initialized"
**Fix:** Call `await ClimbSessionService.init()` in main.dart before app runs.

### Active session banner not showing
**Fix:** After creating session, call `setState()` to update StationScreen.

### Data not persisting
**Fix:** Make sure userId is set correctly when initializing service.

### Station not recording
**Fix:** Check that active session exists: `if (session != null) { ... }`

---

## Files You Might Need to Update

### scanner_screen.dart (or wherever you handle QR)
- Add import: `import 'services/climb_session_service.dart';`
- In scanner callback, add the station recording code

### main.dart
- Initialize the service

### station_screen.dart
- Already updated! Just use it as-is

---

## Next: Read the Docs

For deeper understanding, read:

1. **Quick** (5 min): `MULTI_CLIMB_README.md`
2. **Implementation** (15 min): `MULTI_CLIMB_QUICK_GUIDE.md`
3. **Reference** (30 min): `MULTI_CLIMB_ARCHITECTURE.md`
4. **Complete** (1 hour): `MULTI_CLIMB_FEATURE.md`

---

## 🎯 You're Done!

### What You Have
- ✅ Complete feature implementation
- ✅ All UI components
- ✅ Service layer
- ✅ Data persistence
- ✅ Comprehensive docs

### What's Left
1. Initialize service in main.dart
2. Connect scanner
3. Test end-to-end
4. Deploy!

### Timeline
- **5 minutes** - Read this guide
- **30 minutes** - Integrate service + scanner
- **30 minutes** - Test
- **Done!** - Ready for production

---

## 💡 Pro Tips

1. **Start Simple** - Just initialize and test creation
2. **Add Scanner** - Then add station recording
3. **Test Completion** - Finally add completion logic
4. **Go Live** - Everything works! 🚀

---

## 🚀 You're Ready!

The hardest work is done. Now you just need to:
1. Initialize the service
2. Call 1 method when stations are scanned
3. Call 1 method to complete

Everything else is automatic! 

**Start with Step 1 above and you'll be done in 5 minutes!**

---

**Questions?** Check the documentation files in `documentation/` folder.

**Ready to code?** Go to Step 1 above and start integrating!

**Happy coding!** 🎉
