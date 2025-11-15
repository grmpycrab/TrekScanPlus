# Geofencing Integration Guide

## Overview
The geofencing system ensures users can only check in at stations when they are physically near them. This prevents cheating and ensures data integrity.

## How It Works

### 1. Coordinate Parsing
The system parses DMS (Degrees, Minutes, Seconds) coordinates from stations:
- **Format**: `N:06°44'10.65'' E:126°08'29.99''`
- **Parsing Flow**:
  1. Split coordinates into latitude and longitude parts
  2. Extract direction (N/S/E/W)
  3. Parse degrees, minutes, seconds separately
  4. Convert to decimal degrees: `degrees + (minutes/60) + (seconds/3600)`
  5. Apply sign based on direction (S and W are negative)

**Example**:
- Input: `N:06°44'10.65''` 
- Parsing: 6 + (44/60) + (10.65/3600) = 6.7363...
- Result: 6.7363 (North/positive)

### 2. Location Acquisition
When user scans a QR code:
1. Check location permissions (request if needed)
2. Verify location services are enabled
3. Get current GPS position using `geolocator` package
4. Log location for debugging

### 3. Distance Calculation
Uses Haversine formula to calculate great-circle distance:
- **Inputs**: User lat/lng, Station lat/lng
- **Output**: Distance in meters
- **Formula**: Accounts for Earth's curvature (R = 6,371 km)

### 4. Geofence Check
When scanning a station:
1. Parse station coordinates from JSON
2. Get user's current location
3. Calculate distance between user and station
4. Compare with geofence radius (default: 500m for testing)
5. Allow or deny check-in

## Current Settings

| Setting | Value | Notes |
|---------|-------|-------|
| Geofence Radius | 500 meters | Can be reduced to 100m for production |
| Location Accuracy | Best | Uses GPS + cell towers + WiFi |
| Timeout | 10 seconds | Prevents hanging requests |

## Testing Instructions

### Test Location Coordinates
Use these real station coordinates for testing:

**Station 1: UNESCO Marker**
- Coordinates: `N:06°44'10.65'' E:126°08'29.99''`
- Decimal: 6.7363°N, 126.1417°E

**Station 2: Crossing Stampa**
- Coordinates: `N:06°44'05.54'' E:126°08'34.09''`
- Decimal: 6.7349°N, 126.1428°E

### Manual Testing
To verify the system works:

1. **Enable Location Services**: Ensure device has GPS/location enabled
2. **Grant Permissions**: Allow the app location permission
3. **Navigate to Station**: Travel near one of the test stations
4. **Scan QR Code**: Try scanning the station's QR code
5. **Check Logs**: Monitor the console for:
   ```
   Getting current location...
   Location permission granted
   Location services enabled
   Got position: (6.7363, 126.1417)
   Checking geofence for station at (6.7349, 126.1428) with radius 500 m
   Distance to station: 145.32 m, Within geofence: true
   ```

## Debug Output

The system provides detailed console logs for troubleshooting:

### Success Case
```
Parsing coordinates: N:06°44'10.65'' E:126°08'29.99''
Parsing single coordinate: N:06°44'10.65''
Cleaned coordinate: 06 44 10.65
Parsed coordinate value: 6.7363
Successfully parsed coordinates - Lat: 6.7363, Lng: 126.1417
Getting current location...
Location permission granted
Location services enabled
Got position: (6.7363, 126.1417)
Checking geofence for station at (6.7363, 126.1417) with radius 500 m
Distance to station: 12.45 m, Within geofence: true
```

### Failure Cases
```
# Location permission denied
Location permission denied

# Location services disabled
Location services are disabled

# Invalid coordinates
Invalid coordinates format

# Geofence exceeded
Distance to station: 1200 m, Within geofence: false
```

## Production Adjustments

### Reduce Geofence Radius
For production, change in `geofencing_service.dart`:
```dart
static const double GEOFENCE_RADIUS_METERS = 100; // Changed from 500
```

### Adjust Location Accuracy
For faster response times:
```dart
desiredAccuracy: LocationAccuracy.high, // Changed from LocationAccuracy.best
```

### Error Handling
Consider enabling optional offline mode:
```dart
// Allow check-in at checkpoint stations without geofence check
if (station.isCheckpoint && !geolocator.isLocationServiceEnabled()) {
  // Allow check-in
}
```

## Troubleshooting

### Issue: "Unable to get current location"
- **Cause**: Location permission denied or GPS unavailable
- **Solution**: 
  1. Check app permissions in device settings
  2. Enable location services
  3. Move to area with good GPS signal

### Issue: "Location services are disabled"
- **Cause**: Device location is turned off
- **Solution**: Enable location in device settings

### Issue: Distance shows as very large (> 50km)
- **Cause**: Coordinate parsing error or invalid data
- **Solution**: Check station JSON coordinates format

### Issue: Geofence always fails
- **Current Radius**: 500m (for testing)
- **Solution**: Ensure you are within radius of station

## Integration Points

### Scanner Screen
```dart
// File: lib/screens/main/scanner_screen.dart
final geofenceResult = await GeofencingService.checkGeofence(
  stationLat: station.latitude!,
  stationLng: station.longitude!,
  radiusMeters: GeofencingService.GEOFENCE_RADIUS_METERS,
);

if (!geofenceResult.isWithinGeofence) {
  _showGeofenceFailureDialog(context, station, geofenceResult);
  return;
}
```

### Station Service
```dart
// File: lib/services/station_service.dart
final coords = GeofencingService.parseCoordinates(station.coordinates);
if (coords != null) {
  // Update station with parsed lat/lng
}
```

## Future Enhancements

1. **Background Geofencing**: Use `background_location` package for continuous monitoring
2. **Geofence Zones**: Support custom radius per station
3. **Offline Fallback**: Cache coordinates locally
4. **Map Integration**: Show distance to stations on map
5. **Analytics**: Track average distances at check-in
