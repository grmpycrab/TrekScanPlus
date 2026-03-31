# Quick Start: Testing Booking Limits

This guide will help you quickly test if the app allows booking when there are already 30 bookings for a date.

## 🎯 Goal

Test if the booking system correctly prevents bookings when 30 slots are already filled.

---

## ⚡ Fastest Method (5 minutes)

### 1. Install Dependencies

```bash
cd hamiguitan_trekscan_plus\scripts
npm install
```

### 2. Get Service Account Key

1. Go to: https://console.firebase.google.com
2. Select: **trekscanplus** project
3. Click: ⚙️ → **Project Settings** → **Service Accounts**
4. Click: **Generate New Private Key**
5. Save as: `serviceAccountKey.json` in `scripts` folder

### 3. Get Your User ID

1. Firebase Console → **Authentication** → **Users**
2. Copy your **User UID** (something like `abc123xyz...`)

### 4. Configure the Script

Open `scripts\add_test_bookings.js` and change:

```javascript
// Line 22: Set your target date
const TARGET_DATE = new Date('2025-12-01'); // Tomorrow or any future date

// Line 30: Paste your User ID
const TEST_USER_ID = 'paste-your-uid-here'; // ⚠️ IMPORTANT!
```

### 5. Run the Script

```bash
npm run add-bookings
```

You should see:
```
🚀 Starting test booking creation script...
📅 Target Date: 2025-12-01
📊 Bookings to create: 30
...
✨ Completed!
📈 Current Status for 2025-12-01:
   📋 Total bookings: 30
   💺 Slots used: 30 / 30
   🔴 Date is FULL (≥30 slots)
```

### 6. Test in the App

1. Open TrekScan+ app
2. Go to **Home** screen
3. Look at the calendar for your date
   - Should show **30/30** or **FULL** indicator
4. Go to **Book a Climb**
5. Try to select that date
   - Should prevent booking or show warning

### 7. Cleanup

```bash
npm run delete-bookings
```

---

## 🔍 What to Verify

###   Expected Behavior

1. **Home Screen Calendar**
   - Date shows red/full indicator
   - Date shows "30/30 slots"
   
2. **Book a Climb Screen**
   - Date is disabled/grayed out, OR
   - Selecting date shows "No slots available", OR
   - Form validation prevents submission

3. **Firebase Console**
   - 30 booking documents exist for the date
   - Each has `status: 'approved'`
   - Total slots = 30 (sum of 1 + porters for all bookings)

### ❌ Bug Indicators

- App allows booking despite 30 slots used
- Calendar shows available slots incorrectly
- Booking submission succeeds when it shouldn't

---

## 🎨 Alternative: Test with Different Scenarios

### Scenario 1: Critical Status (27 slots)

```javascript
const NUMBER_OF_BOOKINGS = 27;
const PORTERS_PER_BOOKING = 0;
```

Expected: Yellow/warning indicator, booking still allowed.

### Scenario 2: 31st Booking Test

1. Create 30 bookings
2. Try to create 31st booking in app
3. Expected: System prevents it

### Scenario 3: Bookings with Porters

```javascript
const NUMBER_OF_BOOKINGS = 15;
const PORTERS_PER_BOOKING = 1; // 15 × 2 slots = 30 slots
```

---

## 🐛 Troubleshooting

### "Cannot find module 'firebase-admin'"
```bash
cd scripts
npm install
```

### "Service account key not found"
Make sure `serviceAccountKey.json` exists in the `scripts` folder.

### "Error: Invalid user ID"
1. Go to Firebase Console → Authentication
2. Copy a valid User UID
3. Update `TEST_USER_ID` in the script

### Bookings not showing in app
1. Pull to refresh
2. Restart the app
3. Check Firebase Console → Firestore → bookings

---

## 📞 Support

If you encounter issues:

1. Check Firebase Console to verify bookings were created
2. Check app logs for errors
3. Verify date calculations (timezone issues)
4. Ensure booking status is 'approved' (only approved bookings count)

---

## ✨ Summary

**Fastest Path:**
1. `npm install` (1 min)
2. Get service account key (2 min)
3. Update config (1 min)
4. `npm run add-bookings` (30 sec)
5. Test in app (1 min)
6. `npm run delete-bookings` (30 sec)

**Total Time: ~5 minutes**
