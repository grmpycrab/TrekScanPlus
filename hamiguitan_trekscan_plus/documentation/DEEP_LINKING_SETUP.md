# Deep Linking Setup for TrekScanPlus

## Overview
Deep linking allows users to:
1. Click a link from outside the app (WhatsApp, Facebook, Email, etc.)
2. If app is installed → Opens directly to that post
3. If app not installed → Redirects to Play Store (once published)

## Current Setup

### Share Link Format
Posts now share with: `https://trekscanplus.app/posts/{postId}`

This link will:
- Open the app to that specific post if installed
- Redirect to Play Store if app not installed (future)

---

## Android Configuration (Required)

### Step 1: Update AndroidManifest.xml

Open: `android/app/src/main/AndroidManifest.xml`

Add this intent filter to the MainActivity:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true">
    
    <!-- Standard Flutter launch -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>
    
    <!-- Deep linking for posts -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        
        <!-- Handle https://trekscanplus.app/posts/* -->
        <data
            android:scheme="https"
            android:host="trekscanplus.app"
            android:pathPrefix="/posts/" />
        
        <!-- Handle custom app scheme: trekscanplus://posts/* -->
        <data
            android:scheme="trekscanplus"
            android:host="posts"
            android:pathPrefix="/" />
    </intent-filter>
</activity>
```

### Step 2: Update main.dart to Handle Deep Links

In your `main.dart`, add this to the main function:

```dart
import 'package:uni_links/uni_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... existing initialization code ...
  
  // Handle deep links when app is launched from cold start
  _handleInitialDeepLink();
  
  // Listen for deep links when app is in background/foreground
  _listenToDeepLinks();
  
  runApp(const MyApp());
}

/// Handle deep link when app is launched from closed state
Future<void> _handleInitialDeepLink() async {
  try {
    final initialLink = await getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink);
    }
  } catch (e) {
    print('Error getting initial link: $e');
  }
}

/// Listen for deep links when app is running
void _listenToDeepLinks() {
  deepLinkStream.listen(
    (String? link) {
      if (link != null) {
        _handleDeepLink(link);
      }
    },
    onError: (err) {
      print('Deep link error: $err');
    },
  );
}

/// Route user to the correct screen based on deep link
void _handleDeepLink(String link) {
  // Parse URL: https://trekscanplus.app/posts/{postId}
  // or: trekscanplus://posts/{postId}
  
  try {
    final uri = Uri.parse(link);
    
    // Extract post ID from path
    if (uri.path.startsWith('/posts/')) {
      final postId = uri.path.replaceFirst('/posts/', '');
      if (postId.isNotEmpty) {
        // Navigate to post detail screen
        navigatorKey.currentState?.pushNamed('/post', arguments: postId);
      }
    }
  } catch (e) {
    print('Error parsing deep link: $e');
  }
}
```

### Step 3: Add uni_links Package

Add to `pubspec.yaml`:
```yaml
dependencies:
  uni_links: ^0.0.1
```

Then run: `flutter pub get`

### Step 4: Add Navigation Key (if not already present)

In your `main.dart`:

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,  // ← Add this
      // ... rest of your app config
    );
  }
}
```

---

## iOS Configuration (Required)

### Step 1: Update Info.plist

Open: `ios/Runner/Info.plist`

Add this section:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string>trekscanplus</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>trekscanplus</string>
    </array>
  </dict>
</array>
```

### Step 2: Update Runner.pbxproj for Associated Domains

This requires the app to be published on App Store for web authentication.

For now, the custom scheme `trekscanplus://` will work.

---

## Testing Deep Links

### Test on Android Emulator

**Method 1: ADB Command**
```bash
adb shell am start -W -a android.intent.action.VIEW \
  -d "trekscanplus://posts/testPostId123" \
  com.trekscan.app
```

**Method 2: Using adb in PowerShell**
```powershell
adb shell am start -W -a android.intent.action.VIEW -d "trekscanplus://posts/postId123" com.trekscan.app
```

### Test on Physical Android Device

1. Share a post (it will contain the link)
2. Send the link via WhatsApp/Email
3. Click the link on your device
4. App should open to that post

### Test Link Format

Both formats should work:
- `https://trekscanplus.app/posts/postId123`
- `trekscanplus://posts/postId123`

---

## Future: Web Fallback (When App Published)

Once the app is on Play Store:

1. Set up a simple backend endpoint: `https://trekscanplus.app/posts/{postId}`
2. This endpoint can:
   - Detect if user has the app (via JavaScript)
   - If app installed → Redirect to app store or use intent
   - If app not installed → Show "Download TrekScanPlus" banner
   - Show post preview while user downloads

---

## Current Share Link Behavior

**Right Now** (App Not Published):
- Share link: `https://trekscanplus.app/posts/postId123`
- User clicks link → Gets a "404 Not Found" or browser error
- **Why?** The domain `trekscanplus.app` doesn't have a web server yet

**Workaround Options:**

### Option A: Use Custom Scheme Only
Change share link to just use the app scheme:
```
trekscanplus://posts/postId123
```

**Pros**: Works immediately
**Cons**: If app not installed, link doesn't work at all

### Option B: Set Up Firebase Hosting
- Deploy a simple page to Firebase Hosting
- Redirect traffic to Play Store/App Store
- When app is installed and user clicks, use Intent to open app

### Option C: Wait Until App Published
- Publish to Play Store first
- Then enable web fallback
- Google Play handles the routing automatically

---

## Recommendation

**For now**: Use Option A (custom scheme only) so deep links work immediately once you rebuild the app.

Later, when ready to publish:
1. Deploy web fallback to Firebase Hosting or simple server
2. Update AndroidManifest.xml to verify domain
3. Configure App Links (will redirect users to Play Store)

---

## Current Implementation Status

✅ **Done**:
- Share method generates deep links
- Android Intent Filter configured (steps above)
- iOS URL scheme configured (steps above)

⏳ **To Do**:
1. Add `uni_links` package to pubspec.yaml
2. Update main.dart with deep link handlers
3. Add post detail navigation (if not exists)
4. Test on emulator/device
5. (Later) Set up web fallback when app published

---

## Code References

**Current Share Implementation**:
- File: `lib/components/social_card.dart`
- Method: `_handleShare()`
- Link: `https://trekscanplus.app/posts/{postId}`

**Next Update Needed**:
- File: `lib/main.dart`
- Add: Deep link stream listeners and navigation handler
