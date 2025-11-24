# Centralized Calendar Configuration - Quick Reference

## 🚀 Getting Started (5 Minutes)

### Step 1: Initialize Firebase Configuration
```bash
node scripts/init_calendar_config.js
```

This creates:
- ✅ System defaults: `defaultMaxSlots: 30`, `criticalThreshold: 5`
- ✅ Example closed dates and custom limits

### Step 2: Verify in Firebase Console
Navigate to: **Firestore → system_settings → calendar**

You should see:
```json
{
  "defaultMaxSlots": 30,
  "criticalThreshold": 5,
  "allowWeekendBookings": true,
  "advanceBookingDays": 1825
}
```

### Step 3: Test in App
1. Open TrekScan Plus
2. Navigate to **Home Screen** → View calendar
3. Navigate to **Book a Climb** → Select a date
4. System now uses Firebase configuration!

---

## 🎯 Common Admin Tasks

### Close a Date (Firestore Console)

**Collection:** `calendar_config`  
**Document ID:** `2025-12-25` (YYYY-MM-DD format)

```json
{
  "date": "2025-12-25T00:00:00Z",
  "isClosed": true,
  "maxSlots": 0,
  "reason": "Christmas Holiday",
  "customNote": "Park closed for holiday observance"
}
```

**Result:** Users cannot book this date. App shows "Date Closed: Christmas Holiday"

---

### Set Custom Slot Limit

**Collection:** `calendar_config`  
**Document ID:** `2025-12-31`

```json
{
  "date": "2025-12-31T00:00:00Z",
  "isClosed": false,
  "maxSlots": 45,
  "reason": "New Year Special Event - Increased Capacity"
}
```

**Result:** This date allows 50 bookings instead of default 30

---

### Revert to Default (Remove Custom Config)

**Action:** Delete the document from `calendar_config` collection

**Result:** Date uses system default (30 slots)

---

### Update System Defaults

**Collection:** `system_settings`  
**Document:** `calendar`

```json
{
  "defaultMaxSlots": 35,  // Changed from 30
  "criticalThreshold": 10  // Changed from 5
}
```

**Result:** All dates without custom config now use 35 slots

---

## 📱 How It Works in the App

### Home Screen Calendar
- Shows color-coded availability:
  - 🟢 Green: Available slots
  - 🟡 Orange: Critical (few slots left)
  - 🔴 Red: Full
  - ⚫ Grey: Closed
- Displays: `15/30 slots` (booked/total)
- Updates in real-time when admin changes config

### Book a Climb Screen
- Validates date before allowing booking
- Shows error if date is closed with reason
- Shows error if date is full with slot count
- Shows warning if slots critical (≤ threshold)

### Event Calendar Overlay
- Same color coding as home screen
- Click date to see slot count
- Closed dates clearly marked

---

## 🔑 Key Concepts

### Slot Calculation
```
Slots used = 1 (requester) + numberOfPorters
```

Example:
- 1 person, 0 porters = 1 slot
- 1 person, 3 porters = 4 slots

### Only Approved Bookings Count
- **Pending** bookings: Don't count toward limit
- **Approved** bookings: Count toward limit
- **Declined/Cancelled**: Don't count

### Configuration Priority
1. Date-specific config (`calendar_config/{date}`)
2. System defaults (`system_settings/calendar`)
3. Hardcoded fallback (30 slots)

---

## 📊 Firestore Collections

### `system_settings/calendar`
**Purpose:** Global defaults for all dates  
**Read by:** Anyone  
**Write by:** Admin only

### `calendar_config/{YYYY-MM-DD}`
**Purpose:** Date-specific overrides  
**Read by:** Anyone  
**Write by:** Admin only  
**Optional:** Only create for dates needing custom config

---

## 💡 Use Cases

### Emergency Closure
```javascript
// In Firestore Console, create document: calendar_config/2025-11-27
{
  "date": "2025-11-27T00:00:00Z",
  "isClosed": true,
  "maxSlots": 0,
  "reason": "Emergency: Typhoon Warning"
}
```
**Effect:** Instant closure, all users see it immediately

### Special Event
```javascript
// Increase capacity for celebration (max 45)
{
  "date": "2025-12-31T00:00:00Z",
  "isClosed": false,
  "maxSlots": 45,
  "reason": "New Year Countdown Event"
}
```

### Conservation Period
```javascript
// Reduce capacity for reforestation
{
  "date": "2025-06-15T00:00:00Z",
  "isClosed": false,
  "maxSlots": 15,
  "reason": "Conservation Period - Reduced Capacity"
}
```

---

## 🛠️ Admin Dashboard (Future)

Once you build the admin dashboard UI, admins can:

### Visual Calendar Interface
- Click any date to configure
- Toggle close/open
- Adjust max slots with slider
- Add closure reason
- See real-time slot counts

### System Settings Panel
- Edit default max slots
- Edit critical threshold
- Edit advance booking days
- View last updated timestamp

### Quick Actions
- Bulk close date range
- Copy config to multiple dates
- View booking analytics
- Export calendar configuration

---

## 🧪 Testing

### Test Closed Date
1. Create document: `calendar_config/2025-11-26`
2. Set `isClosed: true`
3. Open app → Try to book Nov 26
4. Should see: "Date Closed" error

### Test Custom Limit
1. Create document: `calendar_config/2025-11-27`
2. Set `maxSlots: 10`
3. Create 10 approved test bookings
4. Try to book 11th booking
5. Should see: "Date Fully Booked" error

### Test Real-Time Updates
1. Open app on Device A
2. Close a date in Firestore Console
3. Calendar on Device A updates automatically
4. No refresh needed!

---

## 🔒 Security

### Firestore Rules
- ✅ Anyone can **read** calendar config (for availability checks)
- ✅ Only admins can **write** calendar config
- ✅ Data validation ensures correct structure
- ✅ Max slots capped at 100 (safety limit)

### Admin Claims
Ensure admin users have custom claim:
```javascript
// In Firebase Console → Authentication
{
  "admin": true
}
```

Or via script:
```javascript
await admin.auth().setCustomUserClaims(uid, { admin: true });
```

---

## 📚 Full Documentation

- **Complete Guide:** `documentation/CALENDAR_CONFIG_GUIDE.md`
- **Implementation Summary:** `documentation/CALENDAR_CONFIG_SUMMARY.md`
- **Scripts README:** `scripts/README.md`

---

## ⚡ Quick Commands

```bash
# Initialize calendar config
node scripts/init_calendar_config.js

# Create test bookings
node scripts/add_test_bookings.js

# Clean up test data
node scripts/delete_test_bookings.js
```

---

## 🐛 Troubleshooting

**Q: Calendar still shows 20 or 30 hardcoded?**  
A: Run `init_calendar_config.js` to create Firestore documents

**Q: Changes not reflecting in app?**  
A: Pull to refresh, or restart app. Check Firestore Console to verify data.

**Q: Error: "Permission denied"**  
A: Deploy updated `firestore.rules` to Firebase

**Q: Closed date still allowing bookings?**  
A: Ensure `isClosed: true` and deploy latest app code

---

**Last Updated:** November 24, 2025  
**Status:** ✅ Production Ready
