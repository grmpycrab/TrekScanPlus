# Permission System Implementation

## Overview
TrekScan+ now implements a comprehensive permission system that requests user consent before accessing device features. This ensures transparency and compliance with privacy standards.

## Permissions Requested

### 1. **Notification Permission** 📱
- **Purpose**: Send push notifications for booking updates, social interactions, achievements, etc.
- **When**: Requested after user login
- **Customizable**: Users can enable/disable specific notification types in settings

### 2. **Storage Permission** 💾
- **Purpose**: Save certificates, trek photos, and cache data
- **When**: Requested after login and when saving certificates
- **Android 13+**: Uses scoped storage (READ_MEDIA_IMAGES, READ_MEDIA_VIDEO)
- **Android <13**: Uses READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE

### 3. **Camera Permission** 📷
- **Purpose**: Scan QR codes at trek stations
- **When**: Requested when opening scanner screen
- **Already Implemented**: In scanner_screen.dart

### 4. **Location Permission** 📍
- **Purpose**: Verify user is at trek station (geofencing)
- **When**: Requested when using geofencing features
- **Already Implemented**: In geofencing_service.dart

## Permission Flow

### Initial Setup (After Login)
```dart
// In main.dart
FirebaseAuthService.instance.authStateChanges.listen((user) {
  if (user != null) {
    // Request permissions after login
    PermissionService.instance.requestInitialPermissions(context);
  }
});
```

### Permission Service Features

#### 1. **Request with Explanation**
```dart
// Shows dialog explaining why permission is needed
await PermissionService.instance.requestNotificationPermission(context);
await PermissionService.instance.requestStoragePermission(context);
```

#### 2. **Track Permission Requests**
```dart
// Prevents showing same permission dialog multiple times
await PermissionService.instance.hasRequestedNotificationPermission();
await PermissionService.instance.hasRequestedStoragePermission();
```

#### 3. **Handle Permanent Denial**
```dart
// If user permanently denies, show dialog to open settings
if (status.isPermanentlyDenied) {
  _showOpenSettingsDialog(context, 'notification');
}
```

## User Experience

### Permission Request Dialog
1. **Icon & Title**: Visual representation of permission type
2. **Detailed Explanation**: Lists all features that use this permission
3. **Two Options**:
   - "Not Now" - Skip for now (can enable later in settings)
   - "Allow" - Grant permission

### Notification Settings Integration

#### System Permission Warning
If notification permission is not granted at system level:
- **Orange warning banner** appears at top of notification settings
- **"Open Settings" button** to easily grant permission
- Automatically rechecks when user returns from settings

#### Master Toggle Behavior
- **Enabling notifications** when system permission is denied → Automatically requests permission
- **Permission granted** → Toggle enables successfully
- **Permission denied** → Toggle stays off, shows explanation

### Storage Permission Flow
When downloading certificate:
1. Check if storage permission is granted
2. If not granted → Show explanation dialog
3. User allows → Save certificate to Downloads
4. User denies → Show orange snackbar explaining permission is needed

## Android Manifest Permissions

```xml
<!-- Notification permissions (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Storage permissions for saving certificates and photos -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" 
                 android:maxSdkVersion="32" />

<!-- Photo/Media permissions for Android 13+ -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />

<!-- Camera permission for QR scanning -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Location permissions for geofencing -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Internet for Firebase and API calls -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

## Files Modified/Created

### Created
- `lib/services/permission_service.dart` - Central permission management
- `documentation/PERMISSION_SYSTEM.md` - This documentation

### Modified
- `lib/main.dart` - Request permissions after login
- `lib/screens/settings/notification_settings.dart` - Permission warning banner & system check
- `lib/screens/main/profile_screen.dart` - Request storage permission before saving certificate
- `android/app/src/main/AndroidManifest.xml` - Added permission declarations

## Privacy Compliance

✅ **Transparency**: Users are informed about what data is accessed and why
✅ **Consent**: Permissions are only granted with explicit user approval
✅ **Control**: Users can revoke permissions at any time in settings
✅ **Minimal Access**: Only request permissions when features are actually used
✅ **Graceful Degradation**: App functions without permissions (with limited features)

## Testing Checklist

- [ ] Notification permission requested after login
- [ ] Storage permission requested before saving certificate
- [ ] Camera permission requested when opening scanner
- [ ] Location permission requested for geofencing
- [ ] Permission dialogs show correct explanations
- [ ] "Not Now" option works and doesn't show dialog again
- [ ] "Allow" option grants permission successfully
- [ ] Permanent denial shows "Open Settings" dialog
- [ ] Notification settings show warning when system permission denied
- [ ] Master toggle requests permission when enabling
- [ ] Certificate save shows error when storage permission denied
- [ ] All permissions visible in Android Settings → Apps → TrekScan+ → Permissions

## Best Practices Implemented

1. **Just-in-Time Requests**: Permissions requested when needed, not all at once
2. **Clear Explanations**: Users understand why each permission is necessary
3. **Graceful Fallbacks**: App doesn't crash if permissions are denied
4. **Easy Access to Settings**: Direct links to system settings when needed
5. **State Persistence**: Tracks which permissions have been requested
6. **User Control**: Settings UI to manage notification preferences

## Future Enhancements

- [ ] Add permission status indicators in main settings screen
- [ ] Implement notification permission prompt reminder after X days
- [ ] Add analytics to track permission grant/denial rates
- [ ] Create in-app tutorial explaining permission benefits
- [ ] Add "Why do you need this?" expandable sections in dialogs
