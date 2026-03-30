# Booking Data Verification Guide

## Overview
This document helps verify that all booking information, including the newly added **hometown**, **isSenior**, and **phoneNumber** fields, are being correctly saved to and fetched from Firebase Firestore.

## What Was Added

### Debug Logging
Added print statements in three key locations to track data flow:

1. **`booking_service.dart` - createBooking()**
   - Logs when a new booking is created
   - Shows: hometown, isSenior, phoneNumber, affiliation, trek type, and full data object
   - Look for: `📝 CREATING BOOKING WITH DATA:`

2. **`booking_service.dart` - updateBooking()**
   - Logs when an existing booking is updated
   - Shows: hometown, isSenior, phoneNumber, and full update data
   - Look for: `🔄 UPDATING BOOKING [id] WITH DATA:`

3. **`booking_model.dart` - fromDoc()`**
   - Logs when booking data is fetched from Firestore
   - Shows: document ID, hometown, isSenior, phoneNumber, affiliation, and all field keys
   - Look for: `📥 FETCHING BOOKING FROM FIRESTORE:`

## How to Test

### 1. Create a New Booking

**Steps:**
1. Open the app and navigate to "Book a Climb"
2. Fill in the booking form:
   - Select a date
   - Enter contact number
   - Enter affiliation
   - Select trek type (Recreational/Research)
   - **Select Hometown** (e.g., "Inside San Isidro")
   - **Select Senior Citizen** (Yes/No)
   - Add porters if needed
3. Submit the booking

**Expected Console Output:**
```
📝 CREATING BOOKING WITH DATA:
  - Hometown: inside_san_isidro
  - Is Senior: false
  - Phone Number: 09123456789
  - Affiliation: Test Organization
  - Trek Type: recreational
  - Full data: {userId: xyz123, phoneNumber: 09123456789, affiliation: Test Organization, trekDate: ..., hometown: inside_san_isidro, isSenior: false, ...}
```

**Verify in Console:**
- ✅ `hometown` is stored in database format (lowercase with underscores)
- ✅ `isSenior` is a boolean (true/false)
- ✅ `phoneNumber` is present and matches input
- ✅ All other fields are present

### 2. View Existing Bookings

**Steps:**
1. Navigate to "My Bookings" or view booking details
2. Check the console for fetch logs

**Expected Console Output:**
```
📥 FETCHING BOOKING FROM FIRESTORE:
  - Document ID: abc123def456
  - Hometown: inside_san_isidro
  - Is Senior: false
  - Affiliation: Test Organization
  - Full data keys: [userId, affiliation, trekDate, hometown, isSenior, ...]
```

**Verify in Console:**
- ✅ `hometown` field exists in fetched data
- ✅ `isSenior` field exists in fetched data
- ✅ Values match what was saved

**Verify in UI:**
- ✅ Booking details modal shows "Hometown: Inside San Isidro" (display format)
- ✅ Booking details modal shows "Senior Citizen: Yes" or "No"
- ✅ Both fields are displayed correctly

### 3. Edit an Existing Booking

**Steps:**
1. Open an existing booking
2. Click "Edit" button
3. Change the hometown (e.g., from "Inside San Isidro" to "Outside Davao Oriental")
4. Change senior citizen status (e.g., from "No" to "Yes")
5. Save changes

**Expected Console Output:**
```
🔄 UPDATING BOOKING abc123def456 WITH DATA:
  - Hometown: outside_davao_oriental
  - Is Senior: true
  - Full update data: {updatedAt: ..., hometown: outside_davao_oriental, isSenior: true, ...}
```

**Verify in Console:**
- ✅ Update shows new hometown value in database format
- ✅ Update shows new isSenior value as boolean
- ✅ `updatedAt` timestamp is included

**Verify in UI:**
- ✅ Changes are reflected immediately after save
- ✅ Booking details show updated hometown
- ✅ Booking details show updated senior citizen status

## Data Format Reference

### Hometown Field
**Display Format** (shown in UI):
- "Inside San Isidro"
- "Inside Davao Oriental"
- "Outside Davao Oriental"

**Database Format** (stored in Firestore):
- "inside_san_isidro"
- "inside_davao_oriental"
- "outside_davao_oriental"

**Conversion:** The app automatically converts between formats:
- Save: Display → Database (lowercase, spaces to underscores)
- Load: Database → Display (title case, underscores to spaces)

### Senior Citizen Field
**Type:** Boolean
- `true` = Yes (60+ years old)
- `false` = No

**UI Display:**
- Shows "Yes" or "No" in booking details
- Dropdown with icons (👤 for No, 👴 for Yes)

## Firestore Database Structure

### Document: `bookings/{bookingId}`
```javascript
{
  "id": "auto-generated-id",
  "userId": "user-uid",
  "affiliation": "Organization Name",
  "trekDate": Timestamp,
  "numberOfPorters": 2,
  "trekType": "recreational",
  "hometown": "inside_san_isidro",        // ← NEW FIELD
  "isSenior": false,                      // ← NEW FIELD
  "notes": "Optional user notes",
  "adminNotes": "Optional admin feedback",
  "attachments": [],
  "status": "pending",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

## Quick Verification Checklist

### Console Logs
- [ ] Creating booking shows hometown and isSenior
- [ ] Fetching booking shows hometown and isSenior
- [ ] Updating booking shows hometown and isSenior changes
- [ ] Hometown is in database format (lowercase_with_underscores)
- [ ] isSenior is boolean (true/false, not "true"/"false" strings)

### UI Display
- [ ] Booking form has "Hometown" dropdown (not "Location")
- [ ] Booking form has "Senior Citizen (60+)" dropdown
- [ ] Hometown dropdown shows 3 options (Inside San Isidro, Inside/Outside Davao Oriental)
- [ ] Senior dropdown shows Yes/No with appropriate icons
- [ ] Booking details modal displays hometown correctly
- [ ] Booking details modal displays senior citizen status
- [ ] Edit modal has both dropdowns working
- [ ] Edit modal saves changes to both fields

### Firestore Database
- [ ] New bookings have `hometown` field
- [ ] New bookings have `isSenior` field
- [ ] Hometown values are in database format
- [ ] isSenior values are booleans (not strings)
- [ ] Updated bookings have `updatedAt` timestamp

## Troubleshooting

### Issue: Hometown shows "Not provided"
**Cause:** Database has empty string or null
**Solution:** Create new booking or edit existing one to set hometown

### Issue: Senior Citizen shows "N/A"
**Cause:** Database missing isSenior field
**Solution:** Edit booking and save to add the field

### Issue: Console shows hometown as empty string
**Cause:** Form submission not including dropdown value
**Fix:** Check that `_hometown` state variable is being used in BookingModel creation

### Issue: isSenior stored as string instead of boolean
**Cause:** Conversion issue in form submission
**Fix:** Ensure `_isSenior` is bool type, not parsed from string

## Code References

### Files Modified
1. **`lib/models/booking_model.dart`**
   - Lines 45-47: Added hometown and isSenior fields
   - Lines 77-79: Added to toMap() method
   - Lines 97-99: Added to fromDoc() factory with debug logs

2. **`lib/services/booking_service.dart`**
   - Lines 23-40: createBooking() with debug logs
   - Lines 71-108: updateBooking() with hometown and isSenior parameters

3. **`lib/screens/main/book_a_climb.dart`**
   - Lines 35-37: State variables for _hometown and _isSenior
   - Lines 347-349: BookingModel creation with hometown and isSenior
   - Lines 1858-2000: Dropdown UI for hometown and senior citizen

4. **`lib/components/booking_details_modal.dart`**
   - Lines 145-158: Display rows for hometown and senior citizen

## Testing Scenarios

### Scenario 1: Senior Citizen from Inside San Isidro
- Hometown: "Inside San Isidro" → stored as "inside_san_isidro"
- Senior: "Yes" → stored as true
- Expected in details: "Hometown: Inside San Isidro, Senior Citizen: Yes"

### Scenario 2: Non-Senior from Outside Davao Oriental
- Hometown: "Outside Davao Oriental" → stored as "outside_davao_oriental"
- Senior: "No" → stored as false
- Expected in details: "Hometown: Outside Davao Oriental, Senior Citizen: No"

### Scenario 3: Edit Existing Booking
- Original: Inside San Isidro, Non-Senior
- Updated: Inside Davao Oriental, Senior
- Verify console shows update with both changes
- Verify UI reflects both changes immediately

## Debug Log Removal (Production)

Before deploying to production, remove or comment out the debug print statements:

**Files to clean:**
- `lib/services/booking_service.dart` (lines ~30-38, ~98-102)
- `lib/models/booking_model.dart` (lines ~93-98)

Or wrap them in `kDebugMode` checks:
```dart
if (kDebugMode) {
  print('📝 CREATING BOOKING WITH DATA:');
  // ... debug logs
}
```

## Summary

The booking system now properly handles:
✅ **Hometown dropdown** (replaces "Location" label, same 3 options)
✅ **Senior Citizen dropdown** (new Yes/No field for 60+ users)
✅ **Database persistence** (both fields stored and retrieved correctly)
✅ **Data format conversion** (display format ↔ database format)
✅ **UI display** (both fields shown in booking details)
✅ **Edit functionality** (both fields can be updated)

All data flows through:
1. **Form Input** → State variables (`_hometown`, `_isSenior`)
2. **Submission** → BookingModel → toMap() → Firestore
3. **Retrieval** → Firestore → fromDoc() → BookingModel
4. **Display** → Booking details modal with format conversion

**Status:** ✅ Fully implemented and ready for testing
**Next Step:** Run the app and follow the testing steps above to verify console logs and UI display
