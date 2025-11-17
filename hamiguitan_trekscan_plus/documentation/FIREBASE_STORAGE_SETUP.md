# Firebase Cloud Storage Setup Guide

## ✅ Current Status

Your Firebase Storage is **already configured** and ready to use:
- **Storage Bucket**: `trekscanplus.firebasestorage.app`
- **Package**: `firebase_storage: ^11.3.0` ✅ (already in pubspec.yaml)
- **Billing**: ✅ Enabled

## Step 1: Deploy Storage Rules to Firebase

Your storage rules have been created in `storage.rules`. Now deploy them to Firebase:

### Option A: Using Firebase Console (Easiest)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **trekscanplus**
3. Navigate to: **Storage** → **Rules** tab
4. Copy the entire content from `storage.rules` file in your project
5. Paste it into the Firebase Console rules editor
6. Click **Publish**

### Option B: Using Firebase CLI (Recommended for Teams)

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not already done)
cd hamiguitan_trekscan_plus
firebase init

# Deploy storage rules
firebase deploy --only storage
```

## Step 2: Storage Structure

Your storage will be organized like this:

```
trekscanplus.firebasestorage.app
├── bookings/
│   ├── {bookingId}/
│   │   └── attachments/
│   │       ├── 1731852000000_12345_document.pdf
│   │       ├── 1731852000000_54321_photo.jpg
│   │       └── 1731852000000_99999_image.png
│
├── profile-images/
│   ├── {userId}/
│   │   └── profile.jpg
│
└── stations/
    ├── hamiguitan/
    │   ├── station1.jpg
    │   └── station2.jpg
```

## Step 3: How BookingService Already Uses Storage

Your `BookingService` is **already configured** to use Firebase Storage! Here's how it works:

### Current Implementation (booking_service.dart):

```dart
// Storage reference - automatically uses your configured bucket
final _storage = FirebaseStorage.instance;

// Upload files with automatic progress tracking
Future<Attachment> uploadAttachment(
  String bookingId,
  PlatformFile file, {
  void Function(int, int)? onProgress,
}) async {
  // Generates unique filename with timestamp
  final rand = Random().nextInt(100000);
  final name = '${DateTime.now().millisecondsSinceEpoch}_$rand_${file.name}';
  
  // Stores in: bookings/{bookingId}/attachments/{filename}
  final path = 'bookings/$bookingId/attachments/$name';
  final ref = _storage.ref(path);
  
  // Upload with progress tracking
  UploadTask uploadTask;
  if (file.path != null) {
    uploadTask = ref.putFile(File(file.path!));
  } else if (file.bytes != null) {
    uploadTask = ref.putData(file.bytes!);
  }
  
  // Track progress
  if (onProgress != null) {
    uploadTask.snapshotEvents.listen((s) {
      onProgress(s.bytesTransferred, s.totalBytes);
    });
  }
  
  // Get download URL
  final snapshot = await uploadTask.whenComplete(() {});
  final url = await snapshot.ref.getDownloadURL();
  
  // Save metadata to Firestore
  await _firestore.collection('bookings').doc(bookingId).update({
    'attachments': FieldValue.arrayUnion([meta.toMap()]),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  
  return meta;
}
```

## Step 4: Storage Security Rules Explained

### Bookings Attachments

```plaintext
match /bookings/{bookingId}/attachments/{allFiles=**}
```

**Rules:**
- ✅ **Create (Upload)**: Any authenticated user can upload files
- ✅ **Read (Download)**: Only the booking owner or admins can read files
- ✅ **Delete**: Only the booking owner or admins can delete files

**Why?**: Prevents unauthorized users from accessing other users' booking documents

### Profile Images

```plaintext
match /profile-images/{userId}/{allFiles=**}
```

**Rules:**
- ✅ **Create/Write**: Only the user can upload their own profile image
- ✅ **Read**: Anyone can view profile images (public)
- ✅ **Delete**: Only the user can delete their own profile image

### Station Images (Admin Only)

```plaintext
match /stations/{stationId}/{allFiles=**}
```

**Rules:**
- ✅ Only admins can upload, read, or manage station images

## Step 5: Testing Storage in the App

### The booking form already has file upload!

When user creates a booking:

1. **File Selection**: User taps "Upload Docx, PDF, or Image" button
2. **File Picker Opens**: Selects files (docx, pdf, jpg, jpeg, png)
3. **Review**: Shows files before submission
4. **Upload Progress**: Shows upload status while uploading
5. **Storage**: Files saved to `bookings/{bookingId}/attachments/`
6. **Firestore**: Metadata saved with download URL

### Testing Steps:

1. Open app and go to **Book a Climb**
2. Tap **+ button** to create new booking
3. Fill in the form:
   - Contact number
   - Affiliation
   - Number of porters
   - Date
4. **Upload Documents**: Tap "Upload Docx, PDF, or Image"
5. Select a file from your device
6. Tap **Proceed** to submit
7. Watch the upload progress bar
8. Check Firebase Console → Storage to see uploaded files

## Step 6: View Uploaded Files in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **trekscanplus**
3. Navigate to: **Storage**
4. You'll see folders:
   - `bookings/` → Your uploaded booking files
   - `profile-images/` → User profile pictures
   - `stations/` → Station photos (admin only)

## Step 7: File Size & Type Restrictions (Optional)

Your current implementation accepts:
- **File Types**: docx, pdf, jpg, jpeg, png
- **Max Concurrent Uploads**: 3-5 files at a time
- **No explicit file size limit** in client (handled by Firebase: default 25MB per file)

### To add file size validation:

```dart
// Add to booking_service.dart
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

Future<Attachment> uploadAttachment(
  String bookingId,
  PlatformFile file, {
  void Function(int, int)? onProgress,
}) async {
  // Validate file size
  if (file.size > MAX_FILE_SIZE) {
    throw Exception('File size exceeds 10MB limit');
  }
  
  // ... rest of upload code
}
```

## Step 8: Download/View Uploaded Files

The booking metadata stores `downloadURL` which allows:

1. **View in App**: Display files in booking details
2. **Download**: Users can download their own booking files
3. **Share**: Admin can share booking files with trek authorities

Example code to display:

```dart
// In BookingModel
final List<Attachment> attachments;

// In UI
ListTile(
  title: Text(attachment.fileName),
  subtitle: Text('${(attachment.size / 1024 / 1024).toStringAsFixed(2)} MB'),
  onTap: () => launchUrl(Uri.parse(attachment.downloadURL)),
)
```

## Troubleshooting

### Issue: "Permission denied" when uploading

**Solution**: Make sure rules are deployed. Check:
1. Firebase Console → Storage → Rules
2. Verify rules match `storage.rules` file
3. User must be authenticated

### Issue: Files uploaded but not appearing in console

**Solution**: 
1. Wait 5-10 seconds for indexing
2. Refresh Firebase Console
3. Check Network tab in browser dev tools

### Issue: File size too large

**Solution**: Firebase allows up to 25MB per file. For larger files:
1. Implement chunked upload
2. Or notify user about size limits

## Best Practices

✅ **Security**
- Always authenticate before uploading
- Use user-scoped paths (`bookings/{bookingId}/`)
- Validate file types on client and server
- Don't make sensitive files publicly readable

✅ **Performance**
- Upload files in background
- Show progress bar for large files
- Compress images before upload
- Use CDN for frequently accessed files

✅ **Storage Cost**
- Delete old/cancelled booking attachments periodically
- Set up automatic cleanup for files older than 1 year
- Monitor storage usage in Firebase Console

✅ **Backup**
- Download backups of important files periodically
- Keep copies in multiple regions (if needed)
- Monitor for data loss events

## Next Steps

1. ✅ **Deploy Storage Rules**
   - Copy rules to Firebase Console
   - Click Publish

2. ✅ **Test File Upload**
   - Create a booking
   - Upload a file
   - Check Firebase Console → Storage

3. ✅ **Monitor Usage**
   - Firebase Console → Storage → Usage
   - Check for quota limits

4. ✅ **Optimize (Optional)**
   - Add file size validation
   - Compress images
   - Implement cleanup jobs

## Reference

- [Firebase Storage Documentation](https://firebase.google.com/docs/storage)
- [Firebase Storage Security Rules](https://firebase.google.com/docs/storage/security)
- [Flutter Firebase Storage](https://pub.dev/packages/firebase_storage)

---

**Your storage is ready!** 🚀 All you need to do is deploy the security rules to Firebase Console.
