# Buffer Day System - Trek Down Day Management

## Overview

The TrekScan Plus app implements a **centralized buffer day system** that automatically blocks the day after each approved booking to prevent scheduling conflicts during the 3-day trek descent period.

## Business Logic

### 3-Day Trek Pattern
- **Day 1-2**: Trek up and exploration
- **Day 3**: Trek down (descent day)
- **Day 4+**: Available for new bookings

### Buffer Rules
- When a booking is approved for date **X**, the system automatically blocks **X+1** as a "trek down day"
- This prevents new bookings on the descent day when trekkers are coming down
- The day **before** (X-1) remains available for new trek starts

### Example
```
June 26 - New booking approved ✅
June 27 - BLOCKED (trek down day) 🚫
June 28 - Available for new bookings ✅
```

## Centralized Firebase Storage

### Why Centralized?
1. **Admin Visibility**: Admins can see all buffer days in the dashboard
2. **Client Consistency**: All users see the same calendar state
3. **Real-time Sync**: Changes appear immediately across all devices
4. **Audit Trail**: Track which trek created each buffer day

### Firestore Structure

```javascript
calendar_config/{YYYY-MM-DD} {
  date: Timestamp,
  isClosed: true,
  maxSlots: 0,
  reason: "Trek down day - Trekkers descending",
  customNote: "Blocked due to approved trek starting on YYYY-MM-DD",
  isTrekDownDay: true,  // Flag to identify buffer days
  originalTrekDate: "YYYY-MM-DD",  // Source trek date
  lastUpdated: Timestamp
}
```

## Automatic Management

### When Booking is Approved
```dart
// In your booking approval logic
final calendarService = CalendarConfigService();
await calendarService.markTrekDownDay(trekDate);
```

### When Booking is Cancelled/Rejected
```dart
// In your booking cancellation logic
final calendarService = CalendarConfigService();
await calendarService.removeTrekDownDay(trekDate);
```

### Sync All Buffer Days
Run periodically to ensure consistency:
```dart
final calendarService = CalendarConfigService();
await calendarService.syncTrekDownDays();
```

## Implementation Files

### Core Service
- `lib/services/calendar_config_service.dart`
  - `markTrekDownDay()` - Create buffer day entry
  - `removeTrekDownDay()` - Remove buffer day entry
  - `syncTrekDownDays()` - Sync all buffer days from approved bookings

### UI Components
- `lib/screens/main/home_screen.dart` - Shows buffer days in home calendar
- `lib/components/event_calendar.dart` - Shows buffer days in calendar overlay
- `lib/screens/main/book_a_climb.dart` - Validates buffer days before booking

## Visual Indicators

### Calendar Display
- **Red background**: Trek down day (buffer day)
- **Tap to see details**: Shows which trek created the buffer
- **Icon**: 🚫 or similar indicator

### Booking Form
When user selects a buffer day:
```
❌ Trek Down Day

There is an approved booking on June 26.
This date is reserved for trekkers descending from their 3-day trek.

Please select a different date.
```

## Admin Dashboard Integration

### View Buffer Days
```javascript
// Query all buffer days
const bufferDays = await db.collection('calendar_config')
  .where('isTrekDownDay', '==', true)
  .orderBy('date')
  .get();
```

### See Source Trek
Each buffer day document includes `originalTrekDate` field:
```javascript
const bufferDay = await db.collection('calendar_config')
  .doc('2025-06-27')
  .get();

console.log('Created by trek on:', bufferDay.data().originalTrekDate);
// Output: "Created by trek on: 2025-06-26"
```

## Maintenance & Sync

### Initial Sync
Run once to populate buffer days for existing bookings:
```bash
# From Flutter app
final calendarService = CalendarConfigService();
await calendarService.syncTrekDownDays();
```

### Periodic Sync (Optional)
Run weekly to ensure consistency:
```dart
// In a scheduled job or admin function
void _weeklySync() async {
  final calendarService = CalendarConfigService();
  await calendarService.syncTrekDownDays();
  AppLogger.i('✅ Buffer days synced');
}
```

## Testing

### Test Scenario 1: New Booking
1. Approve booking for June 26
2. Verify June 27 is marked as closed in Firebase
3. Check calendar UI shows June 27 as "Trek down day"
4. Try booking June 27 - should show error

### Test Scenario 2: Cancellation
1. Cancel/reject booking for June 26
2. Verify June 27 is removed from calendar_config
3. Check calendar UI shows June 27 as available
4. Try booking June 27 - should succeed

### Test Scenario 3: Sync
1. Manually create test booking in Firestore with status='approved'
2. Run `syncTrekDownDays()`
3. Verify buffer day appears in calendar_config
4. Check calendar UI reflects change

## Firestore Rules

Ensure proper security:
```javascript
match /calendar_config/{dateKey} {
  // Public read access
  allow read: if true;
  
  // Admin-only write access
  allow write: if request.auth != null && 
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
  
  // Validate buffer day structure
  allow create, update: if request.resource.data.keys().hasAll(['date', 'isClosed', 'maxSlots', 'reason']) &&
    request.resource.data.maxSlots >= 0 &&
    request.resource.data.maxSlots <= 45;
}
```

## Benefits

### For Users
- ✅ Clear visual indication of unavailable dates
- ✅ Helpful error messages explaining why
- ✅ Consistent experience across all devices

### For Admins
- ✅ See all buffer days in dashboard
- ✅ Trace each buffer to its source trek
- ✅ Override if needed for special cases
- ✅ Automatic management reduces manual work

### For Developers
- ✅ Single source of truth in Firebase
- ✅ Real-time sync across all clients
- ✅ Easy to audit and debug
- ✅ Automatic cleanup when bookings change

## Future Enhancements

1. **Admin Override**: Allow admins to manually remove buffer days
2. **Multi-day Treks**: Support variable trek lengths (2-day, 4-day, etc.)
3. **Buffer Stacking**: Handle multiple treks on consecutive days
4. **Notification**: Alert admin when buffer days are auto-created
5. **Analytics**: Track buffer day usage and conflicts

## Support

For questions or issues:
- Check Firebase Console → Firestore → `calendar_config` collection
- Review booking status in `bookings` collection
- Run sync function to reconcile any discrepancies
- Check app logs for buffer day operations
