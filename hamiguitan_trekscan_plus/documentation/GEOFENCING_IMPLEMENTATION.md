# Geofencing Implementation for Trek Scan Plus

## Overview

The geofencing feature ensures that users can only verify QR code scans when they are physically present at the station location. This adds an authenticity layer to prevent users from scanning QR codes remotely.

## How It Works

### 1. **Location Permission & Access**
- The app requests location permissions when the user opens the Scanner screen
- Uses the `geolocator` package to access GPS coordinates
- Supports both "While in Use" and "Always" permission levels

### 2. **Coordinate Parsing**
- Station coordinates are stored in the format: `"N:06°44'10.65'' E:126°08'29.99''"`
- The `GeofencingService` parses these strings into decimal latitude/longitude values
- Example: `06°44'10.65''` → `6.736295°`

### 3. **Distance Calculation**
- Uses the **Haversine formula** to calculate the great-circle distance between user and station
- Returns distance in meters for accuracy
- Formula accounts for Earth's curvature

### 4. **Geofence Validation**
- Default geofence radius: **100 meters**
- When a QR code is scanned:
  1. Check if station has coordinates
  2. Get user's current GPS location
  3. Calculate distance to station
  4. If distance ≤ 100m → Allow scan
  5. If distance > 100m → Show error dialog with distance info

### 5. **User Feedback**
- If user is outside geofence:
  - Dialog shows actual distance to station
  - Shows required distance (100m)
  - Explains the geofence requirement
  - User can dismiss and try moving closer

## File Structure

### New Files Created:
1. **`lib/services/geofencing_service.dart`**
   - Core geofencing logic
   - Distance calculation methods
   - Coordinate parsing utilities
   - Permission handling

### Modified Files:
1. **`pubspec.yaml`**
   - Added: `geolocator: ^9.0.2` package

2. **`lib/models/station_data.dart`**
   - Added: `latitude` and `longitude` fields
   - Updated: Constructor, fromJson(), toJson() methods

3. **`lib/services/station_service.dart`**
   - Enhanced: loadStations() to parse coordinates when loading
   - Creates StationData objects with latitude/longitude populated

4. **`lib/screens/main/scanner_screen.dart`**
   - Enhanced: onDetect callback to check geofence before allowing scan
   - Added: _showGeofenceFailureDialog() for user feedback
   - Integrated: GeofencingService.checkGeofence() call

## Key Components

### GeofencingService Methods

```dart
// Check if user is within geofence
static Future<GeofenceCheckResult> checkGeofence({
  required double stationLat,
  required double stationLng,
  required double radiusMeters,
})

// Get current user location
static Future<Position?> getCurrentLocation()

// Calculate distance between two points
static double calculateDistance({
  required double userLat,
  required double userLng,
  required double stationLat,
  required double stationLng,
})

// Parse coordinates from string format
static Map<String, double>? parseCoordinates(String coordinates)

// Request location permissions
static Future<bool> requestLocationPermission()

// Check if location services enabled
static Future<bool> isLocationServiceEnabled()

// Format distance for display
static String formatDistance(double meters)
```

### GeofenceCheckResult Class

```dart
class GeofenceCheckResult {
  final bool isWithinGeofence;        // Is user within geofence?
  final double? distanceMeters;       // Distance to station
  final double? userLat;              // User's latitude
  final double? userLng;              // User's longitude
  final String? errorMessage;         // Error if any
}
```

## Configuration

### Adjustable Geofence Radius
To change the geofence radius, modify the constant in `geofencing_service.dart`:

```dart
static const double GEOFENCE_RADIUS_METERS = 100; // Change this value
```

Recommended values:
- **50m**: Very strict, requires exact station location
- **100m** (default): Good balance between accuracy and usability
- **200m**: More lenient, useful for larger station areas
- **500m**: Very lenient, for testing purposes

## Permissions Required

The app needs these permissions in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

And in `Info.plist` for iOS:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Trek Scan Plus needs your location to verify QR code scans at station locations</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Trek Scan Plus needs your location to verify QR code scans at station locations</string>
```

## Error Handling

The system gracefully handles:
- **Location permission denied**: Shows permission request dialog
- **GPS disabled**: Shows location services disabled message
- **GPS timeout**: 10-second timeout with fallback error message
- **Invalid coordinates**: Skips geofence check, allows scan
- **No GPS signal**: Shows error and allows retry

## Testing

### Testing Without GPS (Simulator)

1. **Android Emulator**:
   - Open Extended Controls
   - Go to "Location" tab
   - Set test coordinates to a Mt. Hamiguitan station

2. **iOS Simulator**:
   - Xcode → Debug → Simulate Location → Choose a saved location

### Test Cases

1. **Valid Scan (Within Geofence)**
   - Simulate location at station coordinates ± 50m
   - Scan QR → Should proceed to detail view

2. **Invalid Scan (Outside Geofence)**
   - Simulate location 500m away from station
   - Scan QR → Should show error dialog

3. **Missing Coordinates**
   - Station without lat/lng → Should allow scan (fallback)

4. **Permission Denied**
   - Deny location permission → Should show request dialog

## Data Flow

```
QR Code Scanned
    ↓
Get Station Data
    ↓
Check if Station Has Coordinates?
    ├─ NO → Allow scan (proceed to detail)
    └─ YES ↓
    Request User Location
    ↓
    Calculate Distance (Haversine)
    ↓
    Distance ≤ 100m?
    ├─ YES → Mark visited & show detail view
    └─ NO → Show geofence error dialog
    ↓
    User sees actual distance
    & required distance
```

## Performance Considerations

- **Battery Impact**: GPS queries consume battery. Configured with 10-second timeout to minimize drain
- **Network Independent**: Geofencing uses only GPS, not internet-dependent
- **Caching**: User location is fetched fresh for each scan (not cached)
- **Distance Calculation**: Haversine formula is mathematically optimized

## Security Benefits

1. **Prevents Remote Scanning**: Users must be physically present at station
2. **Tamper-Proof Records**: Scan location data can be audited
3. **Badge Authenticity**: Achievements require real-world presence
4. **Data Integrity**: Reduces fraudulent QR scan records in Firestore

## Future Enhancements

1. **Variable Geofence Zones**
   - Different radius per station type
   - Larger radius for outdoor areas, smaller for enclosed

2. **Geofence Entry Logging**
   - Record when user enters/exits geofence
   - Track dwell time at stations

3. **Offline Geofencing**
   - Cache station coordinates locally
   - Check geofence without internet

4. **Heatmaps**
   - Visualize user distribution at stations
   - Analytics dashboard

5. **Real-time Geofence Monitoring**
   - Background geofence notifications
   - Alert when user enters station area

## Troubleshooting

### GPS Not Working
- Ensure location services enabled
- Check app has location permissions
- Verify GPS is returning valid coordinates

### Distance Always Shows 0
- Ensure station coordinates parsed correctly
- Check `AppLogger.i()` statements in debug console

### Geofence Check Hangs
- 10-second timeout implemented
- Check GPS signal strength
- Try enabling location services

### Coordinate Parsing Fails
- Verify coordinate format: `"N:06°44'10.65'' E:126°08'29.99''"`
- Check for special character encoding issues

## References

- [Geolocator Package](https://pub.dev/packages/geolocator)
- [Haversine Formula](https://en.wikipedia.org/wiki/Haversine_formula)
- [Flutter Permissions](https://flutter.dev/docs/development/plugins-and-packages/permissions)
