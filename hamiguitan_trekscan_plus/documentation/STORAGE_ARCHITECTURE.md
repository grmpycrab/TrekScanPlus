# Firebase Storage Architecture for TrekScan+

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      TrekScan+ App                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  User Interaction (Book a Climb Screen)                          │
│  ├── Fill booking form                                           │
│  ├── Upload Files (PDF, Images, Docx)                           │
│  └── Submit Booking                                              │
│                                                                   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
    ┌─────────┐       ┌──────────┐      ┌────────────┐
    │Firebase │       │Firestore │      │Firebase    │
    │Auth     │       │Bookings  │      │Storage     │
    │         │       │          │      │            │
    │ Verify  │       │ Save     │      │ Save Files │
    │ User    │       │Metadata  │      │            │
    └────┬────┘       └────┬─────┘      └────┬───────┘
         │                 │                  │
         └─────────────────┼──────────────────┘
                           │
                ┌──────────▼──────────┐
                │ Booking Created:    │
                │ ✅ User verified    │
                │ ✅ Metadata saved   │
                │ ✅ Files stored     │
                └─────────────────────┘
```

## Detailed Data Flow

### 1. File Upload Process

```
BookAClimbScreen
       │
       ├─ User taps "Upload Files"
       │
       ▼
FilePicker Dialog
       │
       ├─ User selects files (PDF, JPG, PNG, Docx)
       │
       ▼
_showReviewDialog()
       │
       ├─ Show file preview
       │ ├─ File name
       │ ├─ Upload progress indicator
       │ └─ Status message
       │
       ▼
User clicks "Proceed"
       │
       ▼
BookingService.uploadAttachment()
       │
       ├─ Generate unique filename:
       │  └─ {timestamp}_{randomNum}_{originalName}
       │
       ├─ Create Firebase Storage reference:
       │  └─ bookings/{bookingId}/attachments/{filename}
       │
       ├─ Check file source (path or bytes)
       │
       ├─ Create upload task
       │  └─ Listen to upload progress
       │
       ├─ Upload to Cloud Storage
       │  │
       │  ├─ Bytes transferred: 0% → 100%
       │  │  (UI progress bar updates)
       │  │
       │  └─ Get download URL
       │
       ▼
Save Attachment Metadata
       │
       ├─ Storage path
       ├─ Download URL
       ├─ File name
       ├─ MIME type
       ├─ File size
       └─ Upload timestamp
       │
       ▼
Update Firestore Booking
       │
       └─ Add to attachments array
           └─ Metadata saved with booking

Firestore:
└─ bookings/{bookingId}
   └─ attachments: [
        {
          storagePath: "bookings/book_123/attachments/1731852000_12345_doc.pdf",
          downloadURL: "https://firebasestorage.googleapis.com/v0/b/...",
          fileName: "document.pdf",
          mimeType: "application/pdf",
          size: 2048576,
          uploadedAt: Timestamp
        }
      ]

Storage:
└─ bookings/
   └─ book_123/
      └─ attachments/
         └─ 1731852000_12345_doc.pdf (actual file)
```

### 2. Multi-File Upload

```
User selects 3 files
│
├─ File 1: contract.pdf (2 MB)
├─ File 2: receipt.jpg (500 KB)
└─ File 3: id_card.png (800 KB)

Sequential Upload:
│
├─ Contract (0% → 100%)
│  └─ Saved to Storage & Firestore
│
├─ Receipt (0% → 100%)
│  └─ Saved to Storage & Firestore
│
└─ ID Card (0% → 100%)
   └─ Saved to Storage & Firestore

Result:
└─ Booking contains all 3 files
   with download URLs for each
```

## Storage Rules & Access Control

```
                    Firebase Storage Rules
                    
┌─────────────────────────────────────────────────────────┐
│                   Bookings Attachments                   │
│  Path: bookings/{bookingId}/attachments/{filename}      │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  Allow Upload       ← Authenticated users               │
│  Allow Download     ← Booking owner + Admins            │
│  Allow Delete       ← Booking owner + Admins            │
│  Deny Everything    ← All other users                   │
│                                                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│               Profile Images                             │
│  Path: profile-images/{userId}/{filename}               │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  Allow Upload       ← User themselves only              │
│  Allow Download     ← Everyone (public)                 │
│  Allow Delete       ← User themselves only              │
│  Deny Edit          ← No modifications allowed          │
│                                                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│             Station Images (Admin Only)                  │
│  Path: stations/{stationId}/{filename}                  │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  Allow Upload       ← Admins only                       │
│  Allow Download     ← Admins only                       │
│  Allow Delete       ← Admins only                       │
│  Deny Everyone      ← All other users                   │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## User Roles & Permissions

```
Regular User
│
├─ Can upload to: bookings/{myBookingId}/attachments/
│                 profile-images/{myUserId}/
│
├─ Can read: Their own booking files
│            All public profile images
│
└─ Cannot access: Other users' bookings
                  Station images

Admin User
│
├─ Can upload to: bookings/*/attachments/
│                 profile-images/*/
│                 stations/*/
│
├─ Can read: All bookings
│            All profile images
│            All station images
│
├─ Can delete: Any file anywhere
│
└─ Super access: Manage all uploads
                 Set policies
                 Delete old files
```

## Integration with BookingService

```
BookingService (lib/services/booking_service.dart)
│
├─ createBooking(booking)
│  └─ Creates Firestore document
│
├─ uploadAttachment(bookingId, file)
│  │
│  ├─ Generate unique filename
│  ├─ Create storage reference
│  ├─ Upload file bytes to Storage
│  ├─ Get download URL
│  └─ Save metadata to Firestore
│
├─ createBookingWithAttachments(booking, files)
│  │
│  ├─ Create booking first
│  ├─ Upload each file sequentially
│  └─ Return booking with all metadata
│
└─ streamBookingsForUser(uid)
   └─ Stream of user's bookings
      (includes attachment metadata)
```

## Storage Quota & Costs

```
Firebase Storage Pricing (with Billing Enabled)
│
├─ Storage: $0.18 per GB per month
│
├─ Download: $0.12 per GB per month
│
├─ Upload: FREE
│
├─ API calls: Included in free tier
│  (First 50,000 calls/day free)
│
└─ Example Usage:
   ├─ 100 bookings × 3 files × 2 MB = 600 MB
   │  └─ Cost: $0.11/month for storage
   │
   ├─ Each file downloaded once
   │  └─ Cost: $0.07/month for downloads
   │
   └─ Total: ~$0.18/month for 100 bookings
```

## Error Handling

```
Upload Process
│
├─ Try: Upload file
│  │
│  ├─ On Success:
│  │  └─ Save metadata to Firestore ✅
│  │
│  └─ On Failure:
│     ├─ If auth error: Notify user to login
│     ├─ If network: Retry automatically
│     ├─ If size error: Show size limit message
│     └─ If quota error: Contact support message
│
└─ Status: Saved locally if upload fails
   (Can retry later)
```

## Monitoring & Debugging

```
Firebase Console
│
├─ Storage tab
│  │
│  ├─ View uploaded files
│  │  └─ bookings/{id}/attachments/...
│  │
│  ├─ Check file size
│  │
│  ├─ View last modified date
│  │
│  └─ Download files for backup
│
├─ Rules tab
│  │
│  ├─ View current rules
│  │
│  ├─ Test rules with "Play" button
│  │
│  ├─ Check syntax
│  │
│  └─ View deployment history
│
└─ Usage tab
   │
   ├─ Total storage used
   │
   ├─ Download stats
   │
   └─ Billing information
```

## Deployment Checklist

```
✅ Storage bucket created: trekscanplus.firebasestorage.app
✅ firebase_storage package installed: v11.3.0
✅ BookingService implemented: booking_service.dart
✅ Upload UI implemented: book_a_climb.dart
✅ Storage rules created: storage.rules

TODO:
□ Deploy storage.rules to Firebase Console
□ Test file upload with sample booking
□ Verify files appear in Storage console
□ Check Firestore metadata is saved
□ Monitor first month billing

Then:
✅ Production ready!
```

---

**Next Step:** Deploy `storage.rules` to Firebase Console (see STORAGE_RULES_QUICK_DEPLOY.md)
