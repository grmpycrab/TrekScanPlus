# Firebase Setup Guide for TrekScanPlus

This guide walks you through setting up Firebase for your Flutter app.

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `trekscanplus`
4. Follow the setup wizard and enable Google Analytics if desired

## Step 2: Install Firebase CLI

```powershell
# Install Firebase CLI globally
npm install -g firebase-tools

# Verify installation
firebase --version

# Login to Firebase
firebase login
```

## Step 3: Configure Firebase for Your Project

Navigate to your Flutter project and run:

```powershell
cd c:\Users\Admin\Desktop\TrekScanPlus\hamiguitan_trekscan_plus

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (this will guide you through iOS and Android setup)
flutterfire configure
```

This command will:
- Ask you to select your Firebase project
- Generate `firebase_options.dart` automatically with your credentials
- Configure Android and iOS configurations

## Step 4: Android Setup (Automatic via flutterfire configure)

The `flutterfire configure` command will automatically:
1. Download `google-services.json`
2. Add it to `android/app/`
3. Configure Android build files

**If you need to do it manually:**

1. In [Firebase Console](https://console.firebase.google.com/):
   - Go to your project settings
   - Click "Add app" → Android
   - Package name: `com.example.hamiguitan_trekscan_plus`
   - Download `google-services.json`
   - Place it in `android/app/` folder

2. Update `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        // Add this line
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

3. Update `android/app/build.gradle`:
```gradle
// Add at the end of file
apply plugin: 'com.google.gms.google-services'
```

## Step 5: iOS Setup (Automatic via flutterfire configure)

The `flutterfire configure` command will automatically handle iOS setup.

**If you need to do it manually:**

1. In [Firebase Console](https://console.firebase.google.com/):
   - Go to your project settings
   - Click "Add app" → iOS
   - Bundle ID: `com.example.hamiguitan_trekscan_plus`
   - Download `GoogleService-Info.plist`

2. Open Xcode:
```bash
open ios/Runner.xcworkspace
```

3. Drag `GoogleService-Info.plist` into the Runner project (make sure it's added to Runner target)

## Step 6: Enable Firebase Authentication

1. In [Firebase Console](https://console.firebase.google.com/):
   - Go to your project
   - Click "Authentication" in the left menu
   - Click "Get started"
   - Enable "Email/Password" provider
   - Optionally enable "Google" provider

## Step 7: Get Packages

```powershell
flutter pub get
```

## Step 8: Update firebase_options.dart (If needed)

If `flutterfire configure` didn't generate the file correctly, update `lib/firebase_options.dart` with your Firebase credentials from the Firebase Console.

## Step 9: Run Your App

```powershell
flutter run
```

## Testing

1. **Login Screen**: Try to sign up with a test email and password
2. **Error Handling**: Test with invalid credentials to see error messages
3. **Navigation**: After successful login, you should be redirected to MainScreen

## Firebase Security Rules

Once your app is working, set up Firestore security rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      // For development only - replace with proper rules
      allow read, write: if request.auth != null;
    }
  }
}
```

## Common Issues

### Issue: `google-services.json` not found
**Solution**: Run `flutterfire configure` or download it manually from Firebase Console

### Issue: Pod install fails on iOS
**Solution**: 
```bash
cd ios
rm -rf Pods
rm Podfile.lock
pod install
cd ..
```

### Issue: BuildGradle error on Android
**Solution**: Make sure `com.google.gms:google-services` plugin is added to both `build.gradle` files

### Issue: Firebase not initializing
**Solution**: Ensure `Firebase.initializeApp()` is called in `main()` before `runApp()`

## Next Steps

1. Set up Firestore database for storing user data
2. Configure Firebase Storage for images
3. Set up Firebase Cloud Messaging for notifications
4. Implement Google Sign-In authentication
5. Add password reset functionality

## Useful Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Overview](https://firebase.flutter.dev/docs/overview)
- [Firebase Auth for Flutter](https://firebase.flutter.dev/docs/auth/overview)
