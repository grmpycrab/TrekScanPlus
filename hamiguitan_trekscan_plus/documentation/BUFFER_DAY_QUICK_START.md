# Buffer Day System - Quick Start Guide

## What Changed?

Buffer days (trek down days) are now **centralized in Firebase** instead of being calculated locally in each UI component.

### Before (Old System)
- ❌ Each screen calculated buffer days independently
- ❌ No admin visibility
- ❌ Clients might see different states
- ❌ No persistence or audit trail

### After (New System)
- ✅ Buffer days stored in `calendar_config` collection
- ✅ Admins can see all buffer days in dashboard
- ✅ All clients see the same state (real-time sync)
- ✅ Full audit trail (which trek created each buffer)

## Quick Setup (5 minutes)

### Step 1: Run Initial Sync
```bash
cd scripts
node sync_buffer_days.js
```

This will:
- Read all approved bookings
- Create buffer day entries in `calendar_config`
- Show summary of buffer days created

### Step 2: Add to Booking Approval Logic

When you approve a booking, add this code:

```dart
import 'package:hamiguitan_trekscan_plus/services/calendar_config_service.dart';

// After approving booking
Future<void> approveBooking(String bookingId, DateTime trekDate) async {
  // ... your existing approval logic ...
  
  await FirebaseFirestore.instance
      .collection('bookings')
      .doc(bookingId)
      .update({'status': 'approved'});
  
  // ✨ NEW: Mark buffer day in calendar
  final calendarService = CalendarConfigService();
  await calendarService.markTrekDownDay(trekDate);
  
  AppLogger.i('✅ Booking approved and buffer day created');
}
```

### Step 3: Add to Booking Cancellation Logic

When you cancel/reject a booking:

```dart
// After canceling/rejecting booking
Future<void> cancelBooking(String bookingId, DateTime trekDate) async {
  // ... your existing cancellation logic ...
  
  await FirebaseFirestore.instance
      .collection('bookings')
      .doc(bookingId)
      .update({'status': 'cancelled'});
  
  // ✨ NEW: Remove buffer day from calendar
  final calendarService = CalendarConfigService();
  await calendarService.removeTrekDownDay(trekDate);
  
  AppLogger.i('✅ Booking cancelled and buffer day removed');
}
```

## How It Works

### Automatic Buffer Day Creation

When booking on **June 26** is approved:
1. Booking status → `approved`
2. System creates calendar entry for **June 27**:
```javascript
calendar_config/2025-06-27 {
  isClosed: true,
  maxSlots: 0,
  reason: "Trek down day - Trekkers descending",
  customNote: "Blocked due to approved trek starting on 2025-06-26",
  isTrekDownDay: true,
  originalTrekDate: "2025-06-26"
}
```
3. All users instantly see June 27 as blocked

### Visual Display

**In Calendar:**
- June 26: Shows as booked (green/orange/red based on capacity)
- June 27: Shows as closed (red) with reason "Trek down day"

**In Booking Form:**
If user tries to book June 27:
```
❌ Trek Down Day

There is an approved booking on 2025-06-26.
This date is reserved for trekkers descending from their 3-day trek.

Please select a different date.
```

## Admin Dashboard Integration

### View All Buffer Days

```javascript
// Get all trek down days
const bufferDays = await db.collection('calendar_config')
  .where('isTrekDownDay', '==', true)
  .orderBy('date')
  .get();

bufferDays.forEach(doc => {
  const data = doc.data();
  console.log(`${doc.id} - Created by trek on ${data.originalTrekDate}`);
});
```

### Check Specific Date

```javascript
const date = '2025-06-27';
const config = await db.collection('calendar_config').doc(date).get();

if (config.exists && config.data().isTrekDownDay) {
  console.log('This is a trek down day');
  console.log('Original trek:', config.data().originalTrekDate);
}
```

## Maintenance

### Weekly Sync (Recommended)

Add to your cron jobs or scheduled tasks:
```bash
# Every Sunday at 2 AM
0 2 * * 0 cd /path/to/scripts && node sync_buffer_days.js
```

Or run manually when needed:
```bash
cd scripts
node sync_buffer_days.js
```

### Manual Override (Admin Only)

If you need to manually remove a buffer day:
```javascript
// Remove specific buffer day
await db.collection('calendar_config').doc('2025-06-27').delete();
console.log('✅ Buffer day removed');
```

## Testing

### Test 1: Create Buffer Day
1. Create test booking for tomorrow
2. Approve it
3. Check Firestore → `calendar_config` → should see entry for day after
4. Open app calendar → day after should be red/closed
5. Try booking day after → should show error

### Test 2: Remove Buffer Day
1. Cancel the test booking
2. Check Firestore → `calendar_config` → entry should be deleted
3. Open app calendar → day after should be available
4. Try booking day after → should succeed

### Test 3: Sync Script
1. Create manual booking in Firestore with `status: 'approved'`
2. Run `node sync_buffer_days.js`
3. Check that buffer day appears in calendar_config
4. Verify calendar UI shows it

## Troubleshooting

### Buffer days not showing?
```bash
# Run sync to fix
cd scripts
node sync_buffer_days.js
```

### Old buffer days still there?
Sync script will clean them up:
```bash
node sync_buffer_days.js
# Output will show "Removed X outdated buffer days"
```

### Calendar shows different dates than Firebase?
Clear app cache and restart:
```dart
final calendarService = CalendarConfigService();
// Cache is automatically invalidated on updates
```

## Next Steps

1. ✅ Run `sync_buffer_days.js` to initialize
2. ✅ Add `markTrekDownDay()` to booking approval
3. ✅ Add `removeTrekDownDay()` to booking cancellation
4. ✅ Test with real bookings
5. ✅ Set up weekly sync cron job
6. ✅ Update admin dashboard to show buffer days

## Support Files

- **Documentation**: `BUFFER_DAY_SYSTEM.md` (full details)
- **Sync Script**: `scripts/sync_buffer_days.js`
- **Service Class**: `lib/services/calendar_config_service.dart`
- **Firestore Rules**: `firestore.rules`

---

**Need help?** Check the full documentation in `BUFFER_DAY_SYSTEM.md` or examine the service code in `calendar_config_service.dart`.
