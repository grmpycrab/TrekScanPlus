# Scanner Screen - Quick Reference

## Geofencing Issue - RESOLVED ✅

### What Was Happening
When you scanned a QR code, the app was checking if you were physically close to the station (geofence verification). Since geofencing was **enabled by default**, it was blocking the scan if you weren't within the radius (~20-50 meters).

This showed as a black screen because:
1. Station detected ✅
2. Geofence check started ✅
3. You were outside the geofence radius ❌
4. Geofence failure dialog appeared
5. Return early without navigation

### Solution - Geofencing Toggle
**Geofencing is now OFF by default** for testing and development.

To toggle geofencing:
1. Look at the top-right of the ScannerScreen
2. Find the **location icon** (shows OFF by default in orange 📍)
3. **Tap it** to toggle geofencing ON/OFF
4. Icon changes to:
   - 🟢 **Green location icon** = Geofencing ON
   - 🟠 **Orange location off icon** = Geofencing OFF

### Testing QR Scans

#### Default Mode (Geofencing OFF):
1. Open ScannerScreen
2. Ensure location icon is **orange** (OFF)
3. Scan any QR code
4. Should immediately navigate to station details
5. See station added to climb session

#### With Geofencing ON (for production):
1. Tap location icon until it turns **green**
2. Ensure GPS is enabled on device
3. Ensure location permissions are granted
4. Stand within ~20-50 meters of the actual station
5. Scan the QR code
6. Should navigate to station details

## Debug Logs to Look For

### Successful Scan (Geofencing OFF):
```
📍 Station found: Station 1: UNESCO Marker (56okrkt0pb)
🧗 Current active session: {session_id}
🚀 Creating new climb session...
✅ Climb session created: {timestamp}
✅ Updated climb session with station: Station 1: UNESCO Marker
📱 Navigating to station detail screen...
```

### Geofence Check (When ON):
```
📍 Station found: Station 1: UNESCO Marker (56okrkt0pb)
📍 Checking geofence for Station 1: UNESCO Marker...
✅ User is within geofence
🧗 Current active session: {session_id}
```

### Geofence Failure:
```
📍 Station found: Station 1: UNESCO Marker (56okrkt0pb)
📍 Checking geofence for Station 1: UNESCO Marker...
⚠️ User is outside geofence ({distance}m away)
```

## Recommended Testing Setup

For QR scanning testing:
1. **Keep geofencing OFF** (orange icon) by default
2. Scan QR codes freely
3. Verify climb sessions create automatically
4. Test navigation to station details
5. Enable geofencing (green icon) only when at actual Mt. Hamiguitan

## What Next?

- ✅ Scan QR codes without geofencing blocking
- ✅ Climb sessions auto-create
- ✅ Navigate to station details
- ✅ Offline-first data persists
- 🔄 Firebase syncs in background (when online)

If you still see black screens, check `flutter logs` for error messages and share the output!
