# Centralized Calendar Configuration Guide

## Overview

The TrekScan Plus calendar system now uses **centralized Firebase-based configuration**, allowing administrators to dynamically control booking availability, slot limits, and date closures without requiring app updates.

## Architecture

### Firestore Collections

#### 1. `system_settings/calendar`
Global calendar defaults and system-wide settings.

**Document Structure:**
```json
{
  "defaultMaxSlots": 30,
  "criticalThreshold": 5,
  "allowWeekendBookings": true,
  "advanceBookingDays": 1825,
  "lastUpdated": "2025-11-24T10:30:00Z"
}
```

**Fields:**
- `defaultMaxSlots` (number): Default maximum slots per day (30, can be increased up to 45)
- `criticalThreshold` (number): Show warning when slots remaining ≤ this number (e.g., 5)
- `allowWeekendBookings` (bool): Whether weekend bookings are allowed
- `advanceBookingDays` (number): How far in advance users can book (1825 days = 5 years)
- `lastUpdated` (timestamp): Last update timestamp

#### 2. `calendar_config/{YYYY-MM-DD}`
Date-specific overrides for special dates.

**Document ID Format:** `YYYY-MM-DD` (e.g., `2025-12-25`)

**Document Structure:**
```json
{
  "date": "2025-12-25T00:00:00Z",
  "isClosed": true,
  "maxSlots": 0,
  "reason": "Christmas Holiday",
  "customNote": "Park closed for holiday observance",
  "lastUpdated": "2025-11-24T10:30:00Z"
}
```

**Fields:**
- `date` (timestamp): The date this configuration applies to
- `isClosed` (bool): Whether the date is closed for bookings
- `maxSlots` (number): Custom slot limit for this date (0 if closed)
- `reason` (string): Reason for closure or custom limit
- `customNote` (string, optional): Additional admin notes
- `lastUpdated` (timestamp): Last update timestamp

---

## CalendarConfigService API

### Get System Settings
```dart
final calendarService = CalendarConfigService();
final systemSettings = await calendarService.getSystemSettings();

final defaultMaxSlots = systemSettings['defaultMaxSlots'] as int; // 30
final criticalThreshold = systemSettings['criticalThreshold'] as int; // 5
```

**Caching:** System settings are cached for 5 minutes to reduce Firestore reads.

### Get Date Configuration
```dart
final dateConfig = await calendarService.getDateConfig(DateTime(2025, 12, 25));

AppLogger.i(dateConfig.isClosed); // true
AppLogger.i(dateConfig.maxSlots); // 0
AppLogger.i(dateConfig.reason); // "Christmas Holiday"
```

**Returns:** `DateConfig` object with merged configuration (date-specific + system defaults)

### Get Date Range Configuration
```dart
final startDate = DateTime(2025, 12, 1);
final endDate = DateTime(2025, 12, 31);
final configs = await calendarService.getDateRangeConfig(startDate, endDate);

// configs is Map<String, DateConfig>
// Keys are date strings like "2025-12-25"
final xmasConfig = configs['2025-12-25'];
```

**Use Case:** Efficiently fetch configuration for entire month in calendar displays.

---

## Admin Operations

### Close a Date
```dart
await calendarService.closeDate(
  DateTime(2025, 12, 25),
  reason: 'Christmas Holiday',
  customNote: 'Park closed for holiday observance',
);
```

**Effect:** Sets `isClosed: true` and `maxSlots: 0`. Users cannot book this date.

### Open a Closed Date
```dart
await calendarService.openDate(DateTime(2025, 12, 25));
```

**Effect:** Removes date-specific configuration, reverting to system defaults.

### Set Custom Max Slots
```dart
await calendarService.setDateMaxSlots(
  DateTime(2025, 12, 31),
  maxSlots: 50,
  reason: 'New Year Special Event',
);
```

**Effect:** Increases slot limit to 50 for New Year's Eve.

### Update System Settings
```dart
await calendarService.updateSystemSettings({
  'defaultMaxSlots': 35, // Increase default from 30 to 35
  'criticalThreshold': 10, // Increase warning threshold
});
```

**Effect:** Updates global defaults. Existing date-specific configs are not affected.

---

## Real-Time Streams

### Watch System Settings
```dart
calendarService.watchSystemSettings().listen((settings) {
  AppLogger.i('Max slots updated to: ${settings['defaultMaxSlots']}');
});
```

**Use Case:** Admin dashboard live updates when settings change.

### Watch Date Configuration
```dart
calendarService.watchDateConfig(DateTime(2025, 12, 25)).listen((config) {
  AppLogger.i('Date closed: ${config.isClosed}');
});
```

**Use Case:** Real-time calendar updates when admin modifies dates.

---

## Integration Examples

### Booking Validation
```dart
// In book_a_climb.dart
Future<Map<String, dynamic>> _checkDateAvailability(DateTime date, int portersNeeded) async {
  final calendarService = CalendarConfigService();
  final dateConfig = await calendarService.getDateConfig(date);

  // Check if date is closed
  if (dateConfig.isClosed) {
    return {
      'available': false,
      'isClosed': true,
      'closureReason': dateConfig.reason,
    };
  }

  // Get max slots for this date
  final maxSlots = dateConfig.maxSlots;
  
  // Count approved bookings...
  // Check availability...
}
```

### Calendar Display
```dart
// In home_screen.dart
void _subscribeBookingsForMonth(DateTime month) {
  // ... get bookings snapshot ...
  
  final calendarService = CalendarConfigService();
  final systemSettings = await calendarService.getSystemSettings();
  final dateConfigs = await calendarService.getDateRangeConfig(firstDay, lastDay);
  
  setState(() {
    _trekDays = List.generate(daysInMonth, (index) {
      final date = DateTime(month.year, month.month, index + 1);
      final key = '${date.year}-${date.month}-${date.day}';
      final config = dateConfigs[key];
      
      return TrekDay.fromBookingData(
        date: date,
        bookedSlots: bookedSlots,
        maxSlots: config?.maxSlots ?? systemSettings['defaultMaxSlots'],
        criticalThreshold: systemSettings['criticalThreshold'],
        isClosed: config?.isClosed ?? false,
        closureReason: config?.reason,
      );
    });
  });
}
```

---

## Firestore Security Rules

### Public Read, Admin Write
```javascript
// system_settings collection
match /system_settings/{settingId} {
  allow read: if true; // Anyone can read
  allow write: if request.auth.token.admin == true; // Admin only
}

// calendar_config collection
match /calendar_config/{dateKey} {
  allow read: if true; // Anyone can read
  allow create, update, delete: if request.auth.token.admin == true; // Admin only
  
  // Validate data structure
  allow create, update: if 
    request.resource.data.keys().hasAll(['date', 'isClosed', 'maxSlots']) &&
    request.resource.data.isClosed is bool &&
    request.resource.data.maxSlots is int &&
    request.resource.data.maxSlots >= 0 &&
    request.resource.data.maxSlots <= 100;
}
```

---

## Admin Dashboard Integration

### Required Features

1. **Calendar View**
   - Display month calendar with color-coded availability
   - Show current slot counts per day
   - Highlight closed dates

2. **Date Management**
   - Click date to open configuration dialog
   - Close/open date toggle
   - Set custom max slots (slider or input)
   - Add closure reason and notes

3. **System Settings**
   - Edit default max slots
   - Edit critical threshold
   - Edit advance booking days

4. **Real-Time Updates**
   - Subscribe to calendar config streams
   - Auto-refresh when changes occur
   - Show last updated timestamp

### Example Admin UI Flow

```
User clicks date (Dec 25, 2025)
  ↓
Dialog opens showing:
  - Current status: Open / Closed
  - Max slots: [input field, default 30]
  - Reason: [text field]
  - Custom note: [text area]
  ↓
User clicks "Close Date"
  ↓
System calls: closeDate(date, reason, note)
  ↓
Firestore updates calendar_config/2025-12-25
  ↓
All app users see updated calendar (real-time)
```

---

## Business Logic

### Slot Calculation
- Each booking occupies: `1 person + numberOfPorters` slots
- Example: Booking with 3 porters = 4 slots

### Status Determination
```dart
TrekDayStatus getStatus(int booked, int maxSlots, int criticalThreshold, bool isClosed) {
  if (isClosed) return TrekDayStatus.closed;
  if (booked >= maxSlots) return TrekDayStatus.full;
  if (maxSlots - booked <= criticalThreshold) return TrekDayStatus.critical;
  return TrekDayStatus.available;
}
```

### Booking Approval Logic
- **Pending bookings** do NOT count toward slot limits
- **Only approved bookings** reserve slots
- Admin must approve booking before it counts

---

## Common Use Cases

### 1. Close Date for Maintenance
```dart
await calendarService.closeDate(
  DateTime(2025, 11, 30),
  reason: 'Trail Maintenance',
  customNote: 'Reforestation work in progress',
);
```

### 2. Increase Slots for Special Event
```dart
await calendarService.setDateMaxSlots(
  DateTime(2025, 12, 31),
  maxSlots: 45,
  reason: 'New Year Special',
);
```

### 3. Temporarily Reduce Capacity
```dart
await calendarService.setDateMaxSlots(
  DateTime(2025, 12, 15),
  maxSlots: 15,
  reason: 'Conservation Period',
);
```

### 4. Revert to Default
```dart
await calendarService.openDate(DateTime(2025, 12, 31));
// Removes date-specific config, uses defaultMaxSlots: 30
```

---

## Testing

### Manual Testing Steps

1. **Create System Settings:**
   ```
   Firestore Console → system_settings → Create document "calendar"
   {
     "defaultMaxSlots": 30,
     "criticalThreshold": 5,
     "allowWeekendBookings": true,
     "advanceBookingDays": 90
   }
   ```

2. **Close a Date:**
   ```
   Firestore Console → calendar_config → Create document "2025-11-26"
   {
     "date": Timestamp(2025-11-26 00:00:00),
     "isClosed": true,
     "maxSlots": 0,
     "reason": "Testing date closure"
   }
   ```

3. **Try Booking Closed Date:**
   - App should show "Date Closed" error
   - Display closure reason

4. **Set Custom Limit:**
   ```
   calendar_config → Create document "2025-11-27"
   {
     "date": Timestamp(2025-11-27 00:00:00),
     "isClosed": false,
     "maxSlots": 10,
     "reason": "Reduced capacity test"
   }
   ```

5. **Verify Calendar Display:**
   - Home screen calendar should reflect custom limits
   - Event calendar should show correct availability

---

## Migration from Hardcoded Values

### Before (Hardcoded)
```dart
const maxSlots = 30; // Cannot be changed without app update
```

### After (Centralized)
```dart
final dateConfig = await calendarService.getDateConfig(date);
final maxSlots = dateConfig.maxSlots; // Admin can change anytime
```

### Benefits
✅ No app updates required for calendar changes  
✅ Instant updates across all users  
✅ Admin dashboard control  
✅ Date-specific customization  
✅ Emergency closures without app deployment  

---

## Future Enhancements

- **Recurring Closures:** Weekly maintenance windows
- **Bulk Operations:** Close entire date range
- **Booking Windows:** Open slots at specific times
- **Dynamic Pricing:** Different slots for different user types
- **Weather Integration:** Auto-close dates based on weather forecasts
- **Analytics Dashboard:** Track slot utilization trends

---

## Support

For admin dashboard implementation or calendar configuration issues:
1. Check Firestore security rules
2. Verify admin claims: `request.auth.token.admin == true`
3. Test with Firebase Emulator Suite first
4. Monitor Firestore usage to avoid excessive reads

---

**Last Updated:** November 24, 2025  
**Version:** 1.0.0
