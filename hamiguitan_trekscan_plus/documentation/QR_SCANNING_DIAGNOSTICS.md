# QR Scanning & Climb Session Diagnostics

## Issues Fixed

### 1. Black Screen After QR Scan
**Symptoms**: Screen goes black instead of navigating to station details after scanning

**Root Causes Addressed**:
- Navigation errors from unhandled exceptions
- Session update failures causing silent crashes  
- Missing error handling in async operations
- Climb session not being properly initialized

**Fixes Applied**:
✅ Added comprehensive try-catch blocks around QR detection logic
✅ Enhanced error logging for each operation step
✅ Graceful error handling for session creation/update
✅ Safe navigation with error reporting

### 2. Automatic Climb Session Not Creating
**Symptoms**: No climb session created on first station scan, or creation fails silently

**Root Causes Addressed**:
- Service not properly initialized before scan
- createClimbSession() errors not being caught
- Missing null checks
- Undefined methods not being caught

**Fixes Applied**:
✅ Added service initialization check with user feedback
✅ Try-catch block around session creation with error display
✅ Debug logging at each step
✅ Fallback behavior that doesn't block navigation

## Diagnostic Flow

### When You Scan a QR Code:

```
1. Scanner detects barcode
   └─ Log: 📍 Station found: {station.name}

2. Service initialization check
   └─ Log: 🧗 Current active session: {sessionId or 'None'}

3. Create session if needed
   ├─ Log: 🚀 Creating new climb session...
   └─ Log: ✅ Climb session created: {sessionId}

4. Add station to session
   └─ Log: ✅ Updated climb session with station: {station.name}

5. Navigate to details
   ├─ Log: 📱 Navigating to station detail screen...
   └─ Log: ✅ Returned from station detail screen

6. Restart scanner
```

## Debugging Steps

### Step 1: Check Device Logs
```bash
flutter logs
```

Look for these debug messages:
- ❌ CRITICAL ERROR in QR detection
- 🚀 Creating new climb session...
- 📍 Station found:

### Step 2: Enable Console Output
Run the app with verbose logging:
```bash
flutter run -v
```

### Step 3: Test Scan Flow

1. **Ensure Service is Ready**
   - Open ClimbsTab
   - Verify "No climbs yet" message appears (no error)
   - Go to ScannerScreen

2. **Scan First Station**
   - Point camera at QR code
   - Wait for "Verifying location..." (if geofencing enabled)
   - Should see station details screen

3. **Expected Behavior**
   - Climb session created automatically
   - Station marked as visited
   - Navigate to station details without black screen
   - Go back to scanner
   - Scan another station
   - It should use the same active session

### Step 4: Verify Session Creation

After scanning, check ClimbsTab:
```
1. Go to ClimbsTab
2. Should show "1 Ongoing trek session"
3. Tap to open
4. Should show visited stations
```

## Error Messages & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "Navigation error" | StationDetailScreen failed | Check station data is valid |
| "Error creating climb session" | Database/service error | Restart app |
| "Climb service not ready" | Service init timeout | Wait longer or restart |
| "Black screen" | Unhandled exception | Check `flutter logs` for error |
| "Station not found" | Invalid QR code | Ensure code matches station ID |

## Key Debug Logs to Look For

### Success Path:
```
📍 Station found: Station Name (station_id)
🧗 Current active session: {session_id or None}
🚀 Creating new climb session...
✅ Climb session created: {timestamp-based-id}
✅ Updated climb session with station: Station Name
📱 Navigating to station detail screen...
✅ Returned from station detail screen
```

### Error Path:
```
❌ CRITICAL ERROR in QR detection: {error_message}
❌ Error creating climb session: {error_message}
⚠️ Error updating session: {error_message}
❌ Navigation error: {error_message}
```

## Testing Offline Creation

Since climb sessions are offline-first:

1. **Enable Airplane Mode**
2. **Scan a QR code**
3. **Expected**: 
   - Session still creates locally
   - Station still gets added
   - Navigation still works
4. **Verify** in ClimbsTab that session is there
5. **Disable Airplane Mode**
6. **Expected**: Session syncs to Firebase automatically

## Network Issues

### If Firebase Sync Fails
```
⚠️ Background Firebase sync error: {error}
```
This is OK - app continues to work offline

### If Geofence Check Times Out
```
⚠️ Verifying location... (then error dialog)
```
- Ensure location permissions are granted
- Check GPS is enabled on device
- Verify you're within geofence radius

## Performance Checklist

- [ ] First station scan: < 2 seconds
- [ ] Session creation: < 1 second
- [ ] Navigation to details: < 500ms  
- [ ] Black screen: Never (should see details immediately)
- [ ] No silent failures (all errors logged)

## Common Issues & Fixes

### Issue: Always Goes to "Invalid QR code" Even With Valid Code
**Fix**: 
- Verify station ID in QR code matches database
- Clear app cache: `flutter clean && flutter pub get`
- Restart app

### Issue: Session Created But Station Not Added
**Fix**:
- Check if station is already in the session
- Verify `isStationVisited()` logic
- Check SharedPreferences is working

### Issue: Can't See Newly Created Session in ClimbsTab
**Fix**:
- Refresh ClimbsTab (pull down or restart)
- Verify session is being saved to SharedPreferences
- Check `_loadLocalSessions()` in climb_session_service.dart

## Files Modified for Debugging

- **lib/screens/main/scanner_screen.dart**
  - Added comprehensive try-catch blocks
  - Enhanced debug logging
  - Error reporting UI

- **lib/services/climb_session_service.dart**
  - Improved initialization logging
  - Better error messages

## Next Steps if Still Broken

1. Share the full console output from `flutter logs`
2. Check Firebase Firestore console for any sync errors
3. Verify SharedPreferences is accessible:
   ```dart
   final prefs = await SharedPreferences.getInstance();
   debugPrint('SharedPreferences keys: ${prefs.getKeys()}');
   ```

---

**Last Updated**: January 2026  
**Architecture**: Offline-First with Error Handling  
**Status**: Production Ready with Comprehensive Logging
