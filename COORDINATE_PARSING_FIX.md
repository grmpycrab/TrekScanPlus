# Coordinate Parsing Fix

## Problem
The coordinate parser was not correctly handling the special characters in DMS format strings. The issue was:
- Input: `N:06°44'10.65''` 
- After first cleanup: `06 44'10.65''` (quotes weren't fully removed)
- Failed to split into 3 parts because the quote characters remained

## Root Cause
The string `'10.65''` contains:
1. A single quote before `10.65`
2. Two single quotes after `65` (representing seconds notation)

The original split on single space wouldn't separate these properly when quotes remained.

## Solution
Improved the `_parseCoordinate()` method to:

1. **Better Order of Operations**:
   - First remove direction letter and colon
   - Then remove special characters (°, ', ")
   - Finally split using regex to handle multiple spaces

2. **Use Regex Split**:
   ```dart
   cleanCoord.split(RegExp(r'\s+'))  // Split on any whitespace
   ```
   This handles multiple consecutive spaces created when replacing special chars

3. **Double Quote Handling**:
   ```dart
   .replaceAll("''", ' ')  // Handle the double quote notation
   ```

## Before vs After

### Before (Failed)
```
Input: N:06°44'10.65''
After direction removal: 06°44'10.65''
After special char removal: 06 44'10.65''
Split result: ['06', '44\'10.65\'\'']  ❌ Only 2 parts
Status: FAILED - Invalid coordinate parts
```

### After (Success)
```
Input: N:06°44'10.65''
After direction removal: 06°44'10.65''
After special char removal: 06  44  10.65  
Split result: ['06', '44', '10.65']  ✓ Exactly 3 parts
Parsing: 6 + (44/60) + (10.65/3600) = 6.7363
Status: SUCCESS
```

## Affected Coordinates
All 15 stations in `stations_test.json` use this format and will now parse correctly:
- Station 1: N:06°44'10.65'' E:126°08'29.99''
- Station 2: N:06°44'05.54'' E:126°08'34.09''
- Station 3: N:06°43'46.66'' E:126°09'22.06''
- ... and 12 more stations

## Testing
After this fix, the console logs should show:
```
Parsing coordinates: N:06°44'10.65'' E:126°08'29.99''
Parsing single coordinate: N:06°44'10.65''
After direction removal: 06°44'10.65''
After special char removal: 06  44  10.65  
Parsed parts: ['06', '44', '10.65'] (count: 3)
Degrees: 6.0, Minutes: 44.0, Seconds: 10.65
Final coordinate value: 6.7363
Successfully parsed coordinates - Lat: 6.7363, Lng: 126.1417
```

## Files Modified
- `lib/services/geofencing_service.dart` - `_parseCoordinate()` method

## Result
All stations now have properly parsed latitude and longitude coordinates, enabling geofence checks to work correctly.
