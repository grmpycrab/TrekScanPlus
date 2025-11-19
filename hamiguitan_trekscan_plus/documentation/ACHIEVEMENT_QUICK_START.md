# Achievement Station Assignment - Quick Reference

## What Changed?

### Before ❌
- Achievements unlocked randomly
- Multiple achievements from one scan
- No clear station-to-achievement mapping
- Confusing user experience

### After ✅
- Each station has ONE achievement
- Achievement unlocks only when visiting that station
- Clear, predictable progression
- Professional user experience

---

## Station-Achievement Map

```
Scan Stn1 → "Limestone Gate Passer" (Common)
Scan Stn2 → "Mossy Trail Tracker" (Common)
Scan Stn3 → "Wildlife Path Explorer" (Uncommon)
Scan Stn4 → "Mountain Ridge Climber" (Uncommon)
Scan Stn5 → "Cloud Forest Adventurer" (Uncommon)
Scan Stn6 → "Pygmy Forest Visitor" (Rare)
Scan Stn8 → "Final Ascent Pioneer" (Rare)
Scan Summit → "Hamiguitan Peak Conqueror" (Epic)
```

---

## Implementation Details

### Files Changed

**`lib/services/achievement_service.dart`**
- Method: `checkAndUnlockAchievements()`
  - Added: `currentStationIndex` parameter (1-based)
  - Added: `currentStationId` parameter
- Method: `_checkAchievementCriteria()`
  - Old logic: `stationsVisited >= value` ❌
  - New logic: `currentStationIndex == value` ✅

**`lib/screens/main/scanner_screen.dart`**
- Calculate station index before achievement check
- Pass `currentStationIndex` to achievement service

---

## How It Works

```
Scan Station → Get Index → Check Achievements → Match Current Station → Unlock
   ↓              ↓               ↓                    ↓               ↓
 "stn2"      index = 1        Loop all        "Is this Station 2?" → YES
                             achievements         Check passes
                             (20 total)          Unlock achievement
                                               Show notification
```

---

## Key Logic

### Old Code ❌
```dart
if (_checkAchievementCriteria(achievement, stationsVisited)) {
  unlock();
}

// _checkAchievementCriteria:
case 'reach_station':
  return stationsVisited >= stationValue;  // 3 stations = unlock all 3 achievements!
```

### New Code ✅
```dart
if (_checkAchievementCriteria(
  achievement,
  stationsVisited,
  currentStationIndex: 2,  // KEY: Pass current station
)) {
  unlock();
}

// _checkAchievementCriteria:
case 'reach_station':
  if (currentStationIndex != null) {
    return currentStationIndex == stationValue;  // Only this station's achievement
  }
```

---

## Testing Checklist

- [ ] Visit Stn1 → Only Station 1 achievement unlocks
- [ ] Visit Stn2 → Only Station 2 achievement unlocks
- [ ] Visit Stn3 → Only Station 3 achievement unlocks
- [ ] Re-visit Stn1 → No duplicate achievement
- [ ] After 5 stations → "Five Stations Completed" unlocks
- [ ] Offline → Achievements sync when online
- [ ] Profile → Shows all unlocked achievements

---

## Expected Behavior

| Action | Expected Result |
|--------|-----------------|
| Scan Station 1 | "Limestone Gate Passer" unlocks |
| Scan Station 2 | "Mossy Trail Tracker" unlocks (NOT Station 1 again) |
| Scan Station 1 again | No new achievement |
| Scan 5 different stations | "Five Stations Completed" also unlocks |
| Go offline, scan, go online | Achievement persists and syncs |

---

## Common Questions

**Q: Will Station 1 achievement pop up again?**
A: No. Once unlocked, it stays in profile with today's date.

**Q: What if I visit stations out of order?**
A: Each achievement still unlocks for its specific station. Visit Stn5 first? Only Stn5 achievement unlocks.

**Q: Can I get the same achievement twice?**
A: No. The system prevents duplicate unlocks.

**Q: How do cumulative achievements work?**
A: Separately. They track total visits, not individual stations.

**Q: Does offline mode work?**
A: Yes. Achievements unlock locally, sync when online.

---

## Files to Review

**Understanding the System:**
1. `ACHIEVEMENT_STATION_ASSIGNMENT.md` - Full technical details
2. `ACHIEVEMENT_TESTING_GUIDE.md` - 10 test scenarios

**Testing:**
1. Run: `flutter pub get`
2. Build: `flutter run`
3. Follow testing guide for 10 scenarios

**Before Release:**
1. Complete all 10 tests
2. Verify Firebase sync
3. Test offline/online
4. Sign off on testing document

---

## Quick Deployment Steps

```bash
# 1. Get latest dependencies
flutter pub get

# 2. Clean build
flutter clean

# 3. Build APK
flutter build apk

# 4. Install on device
flutter install

# 5. Test using ACHIEVEMENT_TESTING_GUIDE.md
# Run tests 1-10

# 6. Verify Firebase
# Check Firestore console for synced achievements

# 7. Release when ready!
```

---

## Summary

✅ Achievements now tied to specific stations
✅ One achievement per station
✅ No random unlocks
✅ Clear progression
✅ Professional UX
✅ Offline support
✅ Firebase sync
✅ Backward compatible

**Status**: Ready for Testing 🚀

---

## Questions?

Refer to:
- System design: `ACHIEVEMENT_STATION_ASSIGNMENT.md`
- Testing: `ACHIEVEMENT_TESTING_GUIDE.md`
- History: `ACHIEVEMENT_SYSTEM_IMPLEMENTATION_COMPLETE.md`
- Architecture: `ACHIEVEMENT_SYSTEM_ARCHITECTURE.md`
