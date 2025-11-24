# Scripts Directory

This folder contains utility scripts for the TrekScan Plus application.

## 📁 Available Scripts

### 🧪 Test Booking Scripts

Scripts to test the 30-booking limit for Mt. Hamiguitan.

#### 1. `add_test_bookings.js` (Node.js - Recommended)
Firebase Admin script that creates 30 test bookings for a specific date.

#### 2. `add_test_bookings.dart` (Flutter)
Flutter script that creates test bookings using the app's context.

#### 3. `delete_test_bookings.js` (Node.js)
Cleanup script to remove all test bookings.

### 📅 Calendar Configuration Script (NEW!)

#### 4. `init_calendar_config.js` (Node.js)
Initializes the centralized calendar configuration in Firestore.

**Features:**
- Creates system settings document with defaults
- Sets up example date configurations
- Demonstrates closing dates, custom limits
- Helper functions for manual calendar management

**Usage:**
```bash
node scripts/init_calendar_config.js
```

**See also:** `documentation/CALENDAR_CONFIG_GUIDE.md`

---

## Overview

Mt. Hamiguitan has a **maximum of 30 slots per day**. The booking system calculates slots as:
```
Slots = 1 (requester) + number of porters
```

These scripts help you create test data to verify the booking limit functionality.

## 📁 Scripts

### 1. `add_test_bookings.js` (Node.js - Recommended)
Firebase Admin script that creates 30 test bookings for a specific date.

**Advantages:**
- ✅ No authentication required
- ✅ Batch writes (faster)
- ✅ Works from command line
- ✅ Easy to configure

### 2. `add_test_bookings.dart` (Flutter)
Flutter script that creates test bookings using the app's context.

**Advantages:**
- ✅ Uses existing Firebase configuration
- ✅ Runs with current user's authentication
- ✅ No additional setup needed

### 3. `delete_test_bookings.js` (Node.js)
Cleanup script to remove all test bookings.

---

## 🚀 Quick Start (Node.js Method - Recommended)

### Step 1: Setup

1. **Install Firebase Admin SDK**
   ```bash
   npm install firebase-admin
   ```

2. **Get Service Account Key**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your project: **trekscanplus**
   - Click the ⚙️ icon → **Project Settings**
   - Go to **Service Accounts** tab
   - Click **Generate New Private Key**
   - Save the file as `serviceAccountKey.json` in the `scripts` folder

### Step 2: Configure

Open `add_test_bookings.js` and update:

```javascript
// Target date for test bookings
const TARGET_DATE = new Date('2025-11-30'); // Change this date

// Number of bookings to create
const NUMBER_OF_BOOKINGS = 30;

// User ID (get from Firebase Auth Users)
const TEST_USER_ID = 'your-user-id-here'; // ⚠️ IMPORTANT: Update this!
```

**How to get User ID:**
- Firebase Console → Authentication → Users → Copy UID

### Step 3: Run

```bash
cd hamiguitan_trekscan_plus
node scripts/add_test_bookings.js
```

### Step 4: Test

1. Open the app
2. Navigate to **Book a Climb** or **Home Screen**
3. Check the calendar for your target date
4. Verify that:
   - Date shows as 🔴 FULL (30/30 slots)
   - Booking is prevented or shows warning

### Step 5: Cleanup

```bash
node scripts/delete_test_bookings.js
```

---

## 🎯 Alternative: Flutter Method

If you prefer to use the Flutter script:

### Step 1: Ensure you're logged in

Run the app and log in with your account.

### Step 2: Configure

Open `add_test_bookings.dart` and update:

```dart
// The date you want to test (format: YYYY-MM-DD)
final targetDate = DateTime(2025, 11, 30); // Update this

// Number of bookings to create
const numberOfBookings = 30;

// Number of porters per booking
const portersPerBooking = 0;
```

### Step 3: Run

```bash
cd hamiguitan_trekscan_plus
flutter run -t scripts/add_test_bookings.dart
```

⚠️ **Note:** This method requires you to be logged in first.

---

## 📊 Booking Limit Logic

The system uses this calculation:

```dart
// Each booking uses slots based on:
int slotsUsed = 1 + numberOfPorters;

// Example:
// 1 person, 0 porters = 1 slot
// 1 person, 2 porters = 3 slots
```

Date status indicators:
- 🟢 **Available**: < 25 slots used
- 🟡 **Critical**: 25-29 slots used
- 🔴 **Full**: ≥ 30 slots used

---

## 🧪 Testing Scenarios

### Scenario 1: Exactly 30 bookings
```javascript
const NUMBER_OF_BOOKINGS = 30;
const PORTERS_PER_BOOKING = 0;
// Result: 30 slots used (FULL)
```

### Scenario 2: 15 bookings with 1 porter each
```javascript
const NUMBER_OF_BOOKINGS = 15;
const PORTERS_PER_BOOKING = 1;
// Result: 30 slots used (FULL)
```

### Scenario 3: Critical status
```javascript
const NUMBER_OF_BOOKINGS = 27;
const PORTERS_PER_BOOKING = 0;
// Result: 27 slots used (CRITICAL)
```

---

## 🔍 Verification

### Check in Firebase Console

1. Go to **Firestore Database**
2. Open `bookings` collection
3. Filter by `trekDate` = your target date
4. Count documents and calculate:
   ```
   Total Slots = Σ(1 + numberOfPorters for each booking)
   ```

### Check in App

1. **Home Screen**
   - Calendar should show date as FULL/CRITICAL
   - Tap the date to see slot count

2. **Book a Climb**
   - Try to select the full date
   - System should prevent or warn

---

## 🗑️ Cleanup

### Method 1: Using Script
```bash
node scripts/delete_test_bookings.js
```

### Method 2: Firebase Console
1. Go to Firestore Database
2. Open `bookings` collection
3. Filter where `notes` contains "Test booking"
4. Select all → Delete

### Method 3: Manual
Delete individual test booking documents in Firebase Console.

---

## ⚠️ Important Notes

1. **Test bookings are marked as `approved`** to count towards the limit
2. **Use a test date in the future** to avoid conflicts
3. **Clean up after testing** to maintain accurate data
4. **Update `TEST_USER_ID`** with a real user ID from your Firebase Auth

---

## 🐛 Troubleshooting

### Error: "Cannot find module 'firebase-admin'"
```bash
npm install firebase-admin
```

### Error: "Service account key not found"
Make sure `serviceAccountKey.json` is in the `scripts` folder.

### Error: "No user is currently logged in" (Flutter script)
Log in to the app first, then run the script.

### Bookings created but not showing in app
- Restart the app
- Pull to refresh on Home screen
- Check Firebase Console to verify data

---

## 📝 Example Output

```
🚀 Starting test booking creation script...

📅 Target Date: 2025-11-30
📊 Bookings to create: 30
👷 Porters per booking: 0
💺 Slots per booking: 1

⚠️  This will create 30 test bookings.
Press Ctrl+C to cancel, or wait 3 seconds to continue...

📝 Creating bookings...

✅ Prepared 5/30 bookings...
✅ Prepared 10/30 bookings...
✅ Prepared 15/30 bookings...
✅ Prepared 20/30 bookings...
✅ Prepared 25/30 bookings...
✅ Prepared 30/30 bookings...

⏳ Committing batch write...

✨ Completed!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Results:
   ✅ Successful: 30
   ❌ Failed: 0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📈 Current Status for 2025-11-30:
   📋 Total bookings: 30
   💺 Slots used: 30 / 30
   🔴 Date is FULL (≥30 slots)

💡 Next Steps:
1. Open the app and navigate to Book a Climb
2. Try to book on 2025-11-30
3. Verify that the system prevents booking if slots are full

🗑️  To clean up test data:
   Run: node scripts/delete_test_bookings.js
```

---

## 📚 Related Documentation

- [Booking System Documentation](../documentation/ADMIN_WEB_DASHBOARD_GUIDE.md)
- [Firebase Setup Guide](../documentation/FIREBASE_SETUP.md)
- [BookingService Implementation](../lib/services/booking_service.dart)
