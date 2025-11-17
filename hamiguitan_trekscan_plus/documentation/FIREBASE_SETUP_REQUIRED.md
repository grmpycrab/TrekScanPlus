# 🔴 Firebase Setup Required - 3 Critical Issues

Your app is failing because Firebase needs 2 things:
1. Composite index for booking queries
2. Verified user authentication

---

## Issue #1: Missing Composite Index (BLOCKING) 🔴

**Error:**
```
The query requires an index on: bookings (userId, createdAt)
```

**Fix: Auto-Create Index (30 seconds)**

Firebase provided you an auto-create link in the error. Click it or do this manually:

1. Open: https://console.firebase.google.com/v1/r/project/trekscanplus/firestore/indexes?create_composite=Ck1wcm9qZWN0cy90cmVrc2NhbnBsdXMvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2Jvb2tpbmdzL2luZGV4ZXMvXxABGgoKBnVzZXJJZBABGg0KCWNyZWF0ZWRBdBACGgwKCF9fbmFtZV9fEAI
   - Or manually:
   - Firebase Console → Firestore → Indexes → Create composite index
   - **Collection:** bookings
   - **Fields:**
     - userId (Ascending) ✓
     - createdAt (Descending) ✓
   - Click: **Create Index**

2. **Wait 1-2 minutes** for index to build (you'll see a loading spinner)

3. Once done, you'll see: ✅ **Status: Enabled**

---

## Issue #2: Firestore Permission Denied ❌

**Error:**
```
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions}
```

**Root Cause:**
The query is trying to read bookings BEFORE the composite index exists. Once you create the index, this will be resolved.

**What to verify after creating index:**
1. Go to Firebase Console → Firestore
2. Try to view a booking document manually
3. Should be readable if you're logged in as the booking owner

---

## Issue #3: Storage Channel Connection Error 🔴

**Error:**
```
PlatformException(channel-error, Unable to establish connection on channel)
```

**Root Cause:** 
This happens when Firebase Storage is not properly initialized or rules are blocking the upload.

**Fix:**
1. Make sure you've deployed the updated `storage.rules` (from previous step)
2. Verify in Firebase Console → Storage → Rules tab:
   - Should show your complete rules
   - Click **Publish** again if not applied

3. Restart the app:
   - Stop flutter run (Ctrl+C)
   - Run: `flutter clean` (in terminal)
   - Run: `flutter pub get`
   - Run: `flutter run`

---

## Quick Checklist ✓

- [ ] **Step 1:** Create composite index for bookings (userId, createdAt)
- [ ] **Step 2:** Wait for index to show "Enabled" status
- [ ] **Step 3:** Verify storage.rules are published
- [ ] **Step 4:** Flutter clean & restart app
- [ ] **Step 5:** Test upload again

---

## What Happens After

```
BEFORE (❌)                    AFTER (✅)
─────────────────────         ────────────────────
❌ Permission denied          ✅ Can query bookings
❌ No index                    ✅ Index enabled
❌ Storage channel error       ✅ Can upload files
❌ Upload fails                ✅ Upload succeeds
```

---

## Step-by-Step: Create Index

### Via Auto-Link (Easiest)
1. Copy this link (Firebase provided it in the error):
   ```
   https://console.firebase.google.com/v1/r/project/trekscanplus/firestore/indexes?create_composite=Ck1wcm9qZWN0cy90cmVrc2NhbnBsdXMvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2Jvb2tpbmdzL2luZGV4ZXMvXxABGgoKBnVzZXJJZBABGg0KCWNyZWF0ZWRBdBACGgwKCF9fbmFtZV9fEAI
   ```
2. Paste in browser
3. Click **Create Index** button
4. Wait for green checkmark

### Via Manual (If link doesn't work)
1. Go to: https://console.firebase.google.com
2. Select: **trekscanplus** project
3. Left menu: **Firestore Database**
4. Tab: **Indexes**
5. Button: **Create index**
6. Fill:
   - Collection ID: `bookings`
   - Field 1: `userId` → Ascending ✓
   - Field 2: `createdAt` → Descending ✓
7. Click: **Create Index**
8. Status changes to: ⏳ Building → ✅ Enabled

---

## After Index is Ready

Once you see **✅ Enabled** status:

1. **Stop the app:** `Ctrl+C` in terminal
2. **Clean:** Run `flutter clean`
3. **Reinstall:** Run `flutter pub get`
4. **Restart:** Run `flutter run`
5. **Test:** Navigate to Book a Climb
6. **Upload:** Select a file and test

---

## Expected Result

After all steps:
- ✅ Book a Climb screen loads (no permission errors)
- ✅ File picker works
- ✅ Upload completes in 5-10 seconds
- ✅ Progress bar shows 100%
- ✅ Booking appears in list with attachment metadata

---

## Troubleshooting

### Index still shows "Building" after 5 minutes
- This is normal for first-time index creation
- Wait up to 10 minutes
- Refresh the page if needed

### Still get "Permission denied" after index creation
- Make sure you're logged in as authenticated user
- Check Firestore rules are correct (they should be)
- Try logging out and back in

### Storage upload still fails
- Verify storage.rules are published
- Check rules in Firebase Console → Storage → Rules tab
- See that your updated rules appear there
- Click Publish again if needed

### Index won't create
- Try creating manually instead of auto-link
- Make sure fields are in correct order:
  1. userId (Ascending)
  2. createdAt (Descending)

---

## What Each Fix Does

| Fix | Does What | Why Needed |
|-----|-----------|-----------|
| Composite Index | Enables complex queries on bookings | Without it, `where userId == X order by createdAt` fails |
| Redeploy storage.rules | Allows authenticated users to upload | Upload channel can't connect without proper rules |
| Flutter clean | Clears cache and rebuilds Firebase bindings | Ensures app uses updated configuration |

---

**Ready? Start with the composite index!** ✨
