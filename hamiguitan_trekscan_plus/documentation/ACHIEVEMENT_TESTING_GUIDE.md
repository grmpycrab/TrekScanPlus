# Achievement Station Assignment - Testing Guide

## Quick Test Procedure

### Pre-Test Setup
1. Clear app data: Settings → Apps → TrekScanPlus → Clear Data
2. Login with test account
3. Open Scanner screen
4. Have access to QR codes for stations 1-8

---

## Test Scenarios

### Test 1: Station 1 (First Achievement)

**Steps:**
1. Scan QR code for Station 1 (stn1)
2. Geofence verification passes (or skip if disabled)
3. Observe notification

**Expected Result:**
- ✅ "Achievement Unlocked!" notification appears
- ✅ Achievement name: "Limestone Gate Passer"
- ✅ Achievement icon: footprints
- ✅ Rarity: Common (gray)
- ✅ NO other achievements appear

**Verify:**
- Open Profile → Achievements → Should show "1 of 20 unlocked"
- "Limestone Gate Passer" appears with today's unlock date
- No other achievements marked as unlocked

---

### Test 2: Station 2 (Second Achievement)

**Steps:**
1. From Station Detail screen, go back to Scanner
2. Scan QR code for Station 2 (stn2)
3. Geofence verification passes
4. Observe notification

**Expected Result:**
- ✅ "Achievement Unlocked!" notification appears
- ✅ Achievement name: "Mossy Trail Tracker"
- ✅ Achievement icon: compass
- ✅ Rarity: Common (gray)
- ✅ NO Station 1 notification re-appears
- ✅ Only NEW Station 2 achievement shows

**Verify:**
- Open Profile → Achievements → Should show "2 of 20 unlocked"
- Both "Limestone Gate Passer" and "Mossy Trail Tracker" appear
- Correct unlock dates for each

---

### Test 3: Station 3 (Third Achievement)

**Steps:**
1. Scan QR code for Station 3 (stn3)
2. Verify notification

**Expected Result:**
- ✅ Achievement name: "Wildlife Path Explorer"
- ✅ Rarity: Uncommon (green)
- ✅ NO previous achievements re-unlock

**Verify:**
- Profile shows "3 of 20 unlocked"

---

### Test 4: Non-Linear Progression (Skip Stations)

**Steps:**
1. Don't scan Stations 4-7
2. Go directly to Station 8
3. Scan QR code for Station 8 (stn8)

**Expected Result:**
- ✅ Achievement name: "Final Ascent Pioneer"
- ✅ ONLY this achievement unlocks
- ✅ Stations 4, 5, 6, 7 achievements remain locked

**Verify:**
- Profile shows Stations 1-3 and Station 8 as unlocked
- Stations 4-7 still show as locked

---

### Test 5: Duplicate Scan (Re-visit Station)

**Steps:**
1. Go back to Station 1
2. Scan Station 1 QR code again

**Expected Result:**
- ✅ NO achievement notification appears
- ✅ Station marked as visited again (no error)
- ✅ NO duplicate achievement in profile

**Verify:**
- Profile still shows "Limestone Gate Passer" once
- No duplicate unlock date entry

---

### Test 6: Cumulative Achievement (Five Stations)

**Steps:**
1. Ensure you've scanned Stations 1, 2, 3, 8, and Summit (any 5)
2. Take a screenshot of achievements

**Expected Result:**
- ✅ "Five Stations Completed" achievement unlocks
- ✅ Shows as Uncommon (green)
- ✅ Appears after 5th station scan

**Verify:**
- Profile shows this achievement unlocked
- Achievement count reflects 6+ unlocked

---

### Test 7: Offline Mode Test

**Steps:**
1. Turn off WiFi and disable mobile data
2. Scan a new station (e.g., Station 4)
3. Verify notification shows
4. Re-enable internet

**Expected Result:**
- ✅ Achievement unlocks locally
- ✅ Notification shows immediately (offline)
- ✅ Achievement appears in profile
- ✅ No crash or error
- ✅ When online: Syncs to Firebase automatically

**Verify:**
- Profile shows achievement even while offline
- After reconnecting, Firebase Firestore has achievement

---

### Test 8: App Restart with Pending Achievements

**Steps:**
1. Offline: Scan new station (e.g., Station 5)
2. Achievement unlocks
3. FORCE CLOSE app (Settings → Apps → Force Stop)
4. Turn off WiFi
5. Restart app
6. Go to Scanner/Profile

**Expected Result:**
- ✅ Achievement notification still pending
- ✅ Shows notification on app restart
- ✅ User can see achievement in profile
- ✅ When WiFi re-enabled: Syncs successfully

**Verify:**
- Notification appears when app reopens
- Profile shows achievement

---

### Test 9: Profile Display

**Steps:**
1. After completing Tests 1-3
2. Open Profile screen
3. Scroll to Achievements section

**Expected Result:**
- ✅ Shows "3 of 20 unlocked (15%)"
- ✅ First 3 unlocked achievements visible:
  - Limestone Gate Passer
  - Mossy Trail Tracker
  - Wildlife Path Explorer
- ✅ Each shows correct unlock date
- ✅ Rarity badges show correct colors
- ✅ Icons display correctly

**Verify:**
- Tap "View all 20 achievements"
- Locked achievements show grayed out
- Descriptions visible for locked ones

---

### Test 10: Firebase Sync Verification

**Steps:**
1. Unlock achievements while online
2. Go to Firebase Console
3. Navigate to Firestore
4. Check: `users/{userId}/visitedStations/`

**Expected Result:**
- ✅ Each visited station appears in subcollection
- ✅ Correct data structure:
  ```json
  {
    "stationId": "stn1",
    "stationName": "Limestone Gate",
    "isVisited": true,
    "visitedAt": "2024-11-19T...",
    "lastUpdated": "2024-11-19T..."
  }
  ```
- ✅ Timestamps are server-side (not device time)

**Verify:**
- Multiple devices with same account see all stations

---

## Common Issues & Fixes

### Issue: Achievement doesn't appear after scan

**Possible Causes:**
1. Achievement already unlocked (check profile)
2. Offline and pending notification exists (restart app)
3. Geofence failed (check geofence settings)

**Fixes:**
1. Clear app data and retry
2. Check console logs for errors
3. Disable geofencing temporarily

---

### Issue: Multiple achievements appear for one scan

**This should NOT happen with new code.**

**If it does:**
1. Clear app data
2. Rebuild app: `flutter clean && flutter pub get && flutter run`
3. Test again

---

### Issue: Duplicate achievements in profile

**This should NOT happen.**

**If it does:**
1. One per station rule is broken
2. Check app version is latest
3. File bug report with details

---

## Performance Checklist

- [ ] Achievement check completes in < 100ms
- [ ] Notification animates smoothly
- [ ] No freezing when scanning
- [ ] Profile loads quickly with achievements
- [ ] Firebase sync doesn't block UI
- [ ] Offline detection works instantly

---

## Sign-Off

**Tested by:** _________________ **Date:** _______

**Build version:** _______

**Devices tested:**
- [ ] Android emulator
- [ ] Android device (model: ____________)
- [ ] Both online and offline
- [ ] After app restart
- [ ] After user logout/login

**Test Results:**
- [ ] All 10 tests passed
- [ ] No crashes observed
- [ ] Performance acceptable
- [ ] Ready for release

**Issues Found:**
(List any issues to fix before release)

---

## Automation Test Cases

### Unit Test: Achievement Matching

```dart
test('Station 1 achievement should match currentStationIndex 1', () {
  final achievement = Achievement(
    id: 'station1_gate',
    requirement: {'type': 'reach_station', 'value': 1},
  );
  
  final matches = _checkAchievementCriteria(
    achievement,
    1,
    currentStationIndex: 1,
  );
  
  expect(matches, true);
});
```

### Widget Test: Notification Display

```dart
testWidgets('Achievement notification shows correct details', (tester) async {
  final achievement = Achievement(
    id: 'station1_gate',
    name: 'Limestone Gate Passer',
  );
  
  await tester.pumpWidget(AchievementUnlockOverlay(
    achievement: achievement,
  ));
  
  expect(find.text('Limestone Gate Passer'), findsOneWidget);
  expect(find.byIcon(Icons.directions_walk), findsOneWidget);
});
```

---

## Regression Testing

After any future changes to achievement system:

1. Run all 10 manual tests
2. Check no regressions in:
   - Achievement unlock logic
   - Notification display
   - Firebase sync
   - Profile display
   - Offline behavior

---

**Status**: Ready for testing ✅
