# Firebase Storage Rules Deployment - Quick Reference

## 🚀 TL;DR - Deploy in 2 Minutes

### Method 1: Firebase Console (Easiest - No CLI Needed)

1. Open: https://console.firebase.google.com/
2. Select project: **trekscanplus**
3. Go to: **Storage** → **Rules** tab
4. Open file: `hamiguitan_trekscan_plus/storage.rules` in your text editor
5. Copy the entire content
6. Paste into Firebase Console rules editor
7. Click **Publish** (blue button, top right)
8. ✅ Done!

### Method 2: Firebase CLI (1 Command)

```bash
cd hamiguitan_trekscan_plus
firebase deploy --only storage
```

---

## Current Security Rules Summary

| Path | Create | Read | Write | Delete | Who |
|------|--------|------|-------|--------|-----|
| `bookings/{id}/attachments/*` | ✅ Auth | ✅ Owner/Admin | ❌ | ✅ Owner/Admin | Booking owners |
| `profile-images/{uid}/*` | ✅ Self | ✅ Public | ✅ Self | ✅ Self | Users |
| `stations/{id}/*` | ✅ Admin | ✅ Admin | ✅ Admin | ✅ Admin | Admins only |
| Everything else | ❌ | ❌ | ❌ | ❌ | Denied |

---

## File Upload Flow (Already Working!)

```
User Action                 → Code Location              → Storage Path
────────────────────────────────────────────────────────────────
Click "Upload Files"        → book_a_climb.dart:430      Pick files
Select from device          → FilePicker.platform        User's device
Show in review dialog       → _showReviewDialog()        In-memory
Click "Proceed"             → BookingService             Upload to Firebase
Progress bar shows          → uploadAttachment()         Uploading...
File saved with metadata    → bookings/{id}/attachments/ ✅ Done!
```

---

## Storage Bucket Details

- **Project ID**: `trekscanplus`
- **Bucket Name**: `trekscanplus.firebasestorage.app`
- **Region**: Default (auto-assigned)
- **Tier**: Standard (with billing enabled)

---

## File Size Limits

- **Single File**: Up to 25 MB (default)
- **Total Bucket**: Unlimited (with billing)
- **Concurrent Uploads**: 10 per user

---

## Folder Structure After Deployment

```
🗂️ Storage
├── 📁 bookings/
│   ├── 📁 booking_001/
│   │   └── 📁 attachments/
│   │       ├── 📄 1731852000000_12345_contract.pdf
│   │       ├── 🖼️ 1731852000000_54321_receipt.jpg
│   │       └── 🖼️ 1731852000000_99999_id_card.png
│   ├── 📁 booking_002/
│   │   └── 📁 attachments/
│   │       └── 📄 1731852001000_11111_booking.docx
│
├── 📁 profile-images/
│   ├── 📁 user_abc123/
│   │   └── 🖼️ profile.jpg
│   ├── 📁 user_def456/
│   │   └── 🖼️ profile.jpg
│
└── 📁 stations/
    ├── 📁 hamiguitan/
    │   ├── 🖼️ overview.jpg
    │   ├── 🖼️ entrance.jpg
    │   └── 🖼️ peak.jpg
```

---

## Verify Rules Are Deployed

1. Firebase Console → Storage → Rules tab
2. You should see rules starting with `rules_version = '2';`
3. If you see placeholder rules, copy & paste from `storage.rules`

---

## Test Upload Workflow

1. App: **Book a Climb** tab
2. Tap **+ (Add)** button
3. Fill form with dummy data
4. Tap **Upload Docx, PDF, or Image**
5. Select a small test file
6. Tap **Proceed**
7. Firebase Console → Storage: You should see your file!

---

## Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| "Permission denied" | Rules not deployed | Deploy to Firebase Console |
| Upload hangs | Auth not ready | Ensure user logged in |
| File not visible | Caching | Refresh Firebase Console (F5) |
| Can't find file | Wrong path | Check `bookings/{id}/attachments/` folder |

---

## Next: Enable in Your Build

Your booking code already uses storage! No changes needed. Just deploy the rules and test:

```bash
cd hamiguitan_trekscan_plus
flutter run
# Navigate to: Book a Climb → Create Booking → Upload Files
```

---

**Questions?** Check `FIREBASE_STORAGE_SETUP.md` for detailed guide.
