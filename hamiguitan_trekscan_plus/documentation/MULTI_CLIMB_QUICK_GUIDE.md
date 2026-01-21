# Multi-Climb Feature - Quick Integration Guide

## What Was Added

The multi-climb feature allows users to attempt the trail multiple times, tracking each attempt separately with:
- Individual session management (name, description)
- Automatic time tracking from first station scan
- Station-by-station progress tracking
- Detailed statistics per climb
- Session history with filtering

## Files Created/Modified

### New Files Created:
1. **lib/models/climb_session.dart** - ClimbSession & StationVisit models
2. **lib/services/climb_session_service.dart** - Service to manage climb sessions
3. **lib/dialogs/new_climb_session_dialog.dart** - Dialog to create new sessions
4. **lib/screens/main/climb_session_detail_screen.dart** - Detailed view of a session
5. **lib/screens/main/climb_sessions_list_screen.dart** - History of all sessions
6. **documentation/MULTI_CLIMB_FEATURE.md** - Comprehensive feature documentation

### Modified Files:
1. **lib/screens/main/station_screen.dart**
   - Added imports for new components
   - Added `_activeSession` state variable
   - Modified `_initializeServices()` to init ClimbSessionService
   - Added `_buildActiveSessionBanner()` to show live session stats
   - Added `_createNewSession()` to open creation dialog
   - Added `_formatDuration()` helper method
   - Updated `_buildAppBar()` to show history icon
   - Added FAB for creating new climbs

## Next Steps - Integration Points

### 1. **Connect Scanner with ClimbSession**

In your scanner/QR code handler, add:

```dart
// When a station is scanned successfully
final activeSession = ClimbSessionService.instance.getActiveSession();
if (activeSession != null) {
  await ClimbSessionService.instance.addVisitedStation(
    station, // The StationData that was scanned
    activeSession,
  );
  // Station visit is now tracked in the active session
}
```

### 2. **Add Session Completion Logic**

When user finishes the climb:

```dart
final session = ClimbSessionService.instance.getActiveSession();
if (session != null) {
  await ClimbSessionService.instance.completeSession(session);
  // Navigate to detail screen or show completion dialog
}
```

### 3. **Initialize ClimbSessionService in main.dart**

Add to your main app initialization:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize ClimbSessionService
  if (!ClimbSessionService.isInitialized) {
    await ClimbSessionService.init(userId: currentUserId);
  }
  
  runApp(const MyApp());
}
```

### 4. **Update StationCard Component** (Optional)

If you want to show session-specific visited status:

```dart
// Pass session to StationCard
StationCard(
  imagePath: station.images.first,
  stationName: station.name,
  difficulty: station.difficulty,
  elevation: station.elevation,
  isVisited: _activeSession?.isStationVisited(station.id) ?? false,
)
```

## How It Works

### Creating a Climb
1. User taps FAB "New Climb"
2. Dialog appears asking for name & description
3. Session is created and set as active
4. Active session banner appears

### During a Climb
1. User scans first station → timer starts automatically
2. Each scan adds station to session with timestamp
3. Banner updates in real-time showing:
   - Number of stations visited
   - Elapsed time
   - Session name

### Viewing Statistics
1. Tap active session banner → detailed view
2. OR tap history icon → see all sessions
3. View:
   - Timeline of station visits
   - Duration between stations
   - Total distance & elevation
   - Completion status

## Data Flow

```
User Action → Service Method → Update State → Persist to SharedPreferences
     ↓              ↓                ↓                    ↓
  FAB Click    createSession      setState()        JSON serialization
  Station       addVisited        notifyListeners    SharedPreferences
  Scan          completeSession   UI updates
```

## State Management

The feature uses:
- **Local State**: `_activeSession` in StationScreen
- **Service State**: `_climbSessions` list in ClimbSessionService
- **Persistence**: SharedPreferences (user-scoped keys)
- **Notifications**: ChangeNotifier for reactive updates

## Testing Checklist

- [ ] Create new climb session via FAB
- [ ] Verify active session banner shows
- [ ] Verify history icon navigates to sessions list
- [ ] Check completed sessions tab empty initially
- [ ] Verify session deletion works
- [ ] Test data persistence (close/reopen app)
- [ ] Check multi-user data isolation
- [ ] Verify time formatting displays correctly
- [ ] Test empty states for each screen

## Styling

Uses existing theme colors from `lib/theme/color.dart`:
- `AppColors.primary` - Main actions
- `AppColors.background` - Screen background
- `AppColors.segmentBackground` - Cards
- `AppColors.textSecondary` - Secondary text

All UI components follow your existing design system.

## Troubleshooting

### "ClimbSessionService not initialized" error
→ Make sure to call `ClimbSessionService.init()` before using `.instance`

### Sessions not persisting
→ Check that user ID is properly scoped: `'climb_sessions_{userId}'`

### Active session banner not updating
→ Call `setState(() { _activeSession = result; })` after creating session

### History shows old sessions after app restart
→ Sessions are loaded from SharedPreferences in `_loadSessions()`

## Performance Notes

- All data is stored locally (no network calls)
- Lazy loading of sessions on first access
- Efficient list operations for filtering
- Minimal memory footprint per session

## What's NOT Implemented Yet

- [x] Core session management ✓
- [x] UI and screens ✓
- [x] Data persistence ✓
- [ ] Integration with scanner (Ready for implementation)
- [ ] Session completion dialog
- [ ] Analytics & reporting
- [ ] Photo/media support
- [ ] Advanced statistics

These can be added incrementally as needed!
