# TrekScan+ Codebase — 7-Phase Refactoring Analysis

> **Status**: Analysis only. No code has been changed.  
> **Scope**: Full `lib/` directory, Flutter 3.41.9 / Dart 3.11.5, Firebase backend.  
> **Date**: Written after complete codebase audit (file-size scan, Firebase coupling scan, setState frequency scan, static analysis).

---

## PHASE 1 — GLOBAL UNDERSTANDING

### 1.1 Architecture Diagram (text)

```
┌─────────────────────────────────────────────────────────────────────┐
│  main()                                                             │
│    └─ AppInit.initialize()                                          │
│         ├─ dotenv.load()                                            │
│         ├─ ThemeService.initialize()                                │
│         ├─ Firebase.initializeApp()                                 │
│         ├─ FirebaseAppCheck.activate()                              │
│         └─ FirebaseFirestore.settings (100 MB cache, persistence)   │
│                                                                     │
│    └─ AppProviders (MultiProvider)                                  │
│         ├─ ChangeNotifierProvider<ThemeService>                     │
│         └─ ChangeNotifierProvider<AuthViewModel>                    │
│                                                                     │
│    └─ AppShell (MaterialApp)                                        │
│         ├─ Consumer<ThemeService> → ThemeData                       │
│         ├─ navigatorKey (global)                                    │
│         └─ NotificationBannerOverlay                                │
│              └─ MyApp                                               │
│                   ├─ SplashScreen (1200 ms delay)                   │
│                   └─ AuthGate                                       │
│                        └─ Consumer<AuthViewModel>                   │
│                             ├─ loading   → LoadingIndicator         │
│                             ├─ unauth    → LoginScreen              │
│                             ├─ unverified→ EmailVerificationScreen  │
│                             └─ authed   → MainScreen                │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────────── MainScreen ─────────────────────────────────┐
│  BottomNavigationBar                                                │
│  ├─ [0] HomeScreen          → HomeViewModel (manual listener)       │
│  ├─ [1] StationScreen       → StationService.instance (manual)      │
│  ├─ [2] ScannerScreen       → (raw StatefulWidget, no ViewModel)    │
│  ├─ [3] BookAClimbScreenRefactored → BookingProvider (ChangeNotifier)│
│  └─ [4] SettingsScreen      → navigation-only shell                 │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 State Management Layers

```
┌────────────────────────────────────────────────────────────┐
│  LAYER              HOW IT IS EXPOSED         PATTERN      │
├────────────────────────────────────────────────────────────┤
│  ThemeService       Provider tree             ChangeNotifier│
│  AuthViewModel      Provider tree             ChangeNotifier│
│  BookingProvider    Provider.of (local scope) ChangeNotifier│
│  HomeViewModel      manual addListener        ChangeNotifier│
│  SocialFeedViewModel manual addListener       ChangeNotifier│
│  CommentsViewModel  manual addListener        ChangeNotifier│
│  CreatePostViewModel manual addListener       ChangeNotifier│
│  PostViewModel      manual addListener        ChangeNotifier│
│  ClimbSessionService singleton + manual       ChangeNotifier│
│  StationService     singleton + manual        ChangeNotifier│
│  AchievementService singleton                 plain class   │
│  BookingService     singleton                 plain class   │
│  UserService        singleton                 plain class   │
│  FeedPaginationSvc  singleton                 plain class   │
│  NotificationHandler static methods          (no state)     │
└────────────────────────────────────────────────────────────┘
```

### 1.3 Data Flow (per feature)

**Authentication:**

```
FirebaseAuth → FirebaseAuthService → AuthViewModel (stream)
  → AuthGate (Consumer) → routes to correct screen
```

**Home / Social Feed:**

```
Firestore → FeedPaginationService → SocialFeedViewModel
  → HomeViewModel → HomeSocialFeed widget
```

**Booking:**

```
User action → BookingProvider (business logic + Firestore)
  → BookAClimbScreenRefactored (Consumer)
  ← BookingService (Firestore CRUD, singleton)
```

**Scanner (QR):**

```
Camera → MobileScanner widget → ScannerScreen._onDetect()
  → GeofencingService (static) → AchievementService → Firestore
  All inside one StatefulWidget — no ViewModel
```

**Notifications:**

```
FCM → FCMService → NotificationHandler (static)
  → NotificationManager (GlobalKey overlay)
  → NotificationBannerOverlay widget

Firestore CRUD → notification_services.NotificationService
  → NotificationScreen (StreamBuilder)
```

### 1.4 Startup Sequence

```
1. main() calls AppInit.initialize()
2. AppInit runs ThemeService + dotenv in parallel, then Firebase
3. MultiProvider wraps MyApp → ThemeService + AuthViewModel created
4. SplashScreen shown for 1200 ms
5. AuthGate renders based on AuthViewModel.status
6. First time status == authenticated → onServicesInitNeeded fires
7. AppStartupController.initialize():
   a. ClimbSessionService.init()
   b. BookingService.initialize()
   c. NotificationHandler.initialize() (FCM)
   d. NotificationService (FCM) permission request
   e. Permission check (location, camera)
8. MainScreen renders with 5 tabs
9. MainScreen.initState() starts AchievementService + OnboardingService
   (⚠ this should be in step 7, not here)
```

---

## PHASE 2 — PROBLEM DETECTION

### Issue 1 — Dead God Class File (`book_a_climb.dart`, 2612 lines) — SEVERITY: HIGH

**WHERE:** `lib/screens/main/book_a_climb.dart`

**WHY it is a problem:**  
This file defines `BookAClimbScreen` (original god class) with 2612 lines, 24 `setState` calls, 13 direct `FirebaseFirestore.instance` / `FirebaseAuth.instance` calls. **Nothing imports it.** It is dead code. The active booking screen is `features/booking/screens/book_a_climb_screen.dart` (class `BookAClimbScreenRefactored`). The dead file consumes cognitive load, confuses new contributors, and may accidentally be reactivated.

**FIX:** Delete `lib/screens/main/book_a_climb.dart`. Verify zero imports first.

---

### Issue 2 — Duplicate `NotificationService` Class — SEVERITY: HIGH

**WHERE:**

- `lib/services/notification_service.dart` → `class NotificationService` (FCM + local push)
- `lib/services/notification_services.dart` → `class NotificationService` (Firestore CRUD for in-app notifications)

**WHY it is a problem:**  
Two files define the same class name. Any screen that imports both (or accidentally imports the wrong one) will get a compile ambiguity. The classes have different responsibilities, different constructors, and different APIs. The subtle difference in filename (`service` vs `services`) is a maintenance trap.

**FIX:** Rename `notification_services.dart` class to `InAppNotificationService` (or `FirestoreNotificationService`) and update the 4 known consumers.

---

### Issue 3 — `LoginScreen` Bypasses `AuthGate` — SEVERITY: HIGH

**WHERE:** `lib/screens/auth/login_screen.dart` (11 `setState` calls, ~444 lines)

**WHY it is a problem:**  
After a successful login, `LoginScreen` manually navigates to `MainScreen` via `Navigator.pushReplacement`. This completely bypasses `AuthGate` and `AuthViewModel`. If authentication state ever changes (e.g., email becomes unverified, token refresh fails), `AuthGate` will be unaware. The routing logic is duplicated: once in `AuthGate` and once in `LoginScreen._login()`. This also means `LoginScreen` manually checks `user.emailVerified` and manually routes to `EmailVerificationScreen`, duplicating `AuthGate`'s exact logic.

**FIX:** After `FirebaseAuthService.logIn()` succeeds, do nothing — `AuthViewModel` will emit a new status, which `AuthGate` (always in the widget tree) will react to automatically.

---

### Issue 4 — `SettingsScreen` Logout Bypasses Provider System — SEVERITY: MEDIUM

**WHERE:** `lib/screens/main/settings_screen.dart`

**WHY it is a problem:**  
The logout handler calls `FirebaseAuthService.instance.signOut()` then pushes `LoginScreen` manually. `AuthViewModel` never receives the sign-out signal in time, so the Provider tree's `AuthStatus` is temporarily out of sync. The `onLogout` callback wired in `AuthGate` (which resets services) is not triggered by this path.

**FIX:** The logout handler should call `AuthViewModel.signOut()` (which is already defined) and let `AuthGate` navigate automatically based on the resulting `AuthStatus.unauthenticated`.

---

### Issue 5 — Firestore Calls Inside UI-Layer Files — SEVERITY: MEDIUM

**WHERE:**  
| File | Count | Layer |
|---|---|---|
| `screens/main/book_a_climb.dart` | 15 | Screen (dead) |
| `features/booking/providers/booking_provider.dart` | 8 | Provider |
| `screens/settings/security_screen.dart` | 4 | Screen |
| `features/booking/screens/book_a_climb_screen.dart` | 4 | Screen |
| `screens/settings/account_settings.dart` | 3 | Screen |
| `components/event_calendar.dart` | 3 | Component |
| `screens/settings/archived_bookings_screen.dart` | 2 | Screen |
| `screens/main/main_screen.dart` | 1 | Screen |

**WHY it is a problem:**  
Firestore calls in screens and components violate the repository pattern. They:

- Make unit testing impossible without Firebase emulators
- Couple UI lifecycle to network calls
- Spread error-handling logic across the widget tree

`event_calendar.dart` is particularly bad: it opens a `StreamSubscription<QuerySnapshot>` inside a simple UI calendar component, giving the component a live network dependency.

**FIX:** Route all Firestore calls through service/repository classes. `BookingProvider` should delegate to `BookingService`. `EventCalendar` should accept pre-fetched data via constructor (already partially done — it accepts `trekDays` — but it also independently subscribes to Firestore for booking counts).

---

### Issue 6 — `PresenceService` Has a Duplicate Auth Subscription — SEVERITY: MEDIUM

**WHERE:** `lib/services/presence_service.dart`

**WHY it is a problem:**  
`PresenceService` opens its own `FirebaseAuth.instance.authStateChanges()` subscription independently of `AuthViewModel`. When the user logs out, both `AuthViewModel`'s stream and `PresenceService`'s stream fire. This creates a race condition: `PresenceService` may attempt to write "online: false" to Firestore after the session has been cleaned up. It also makes it impossible to guarantee ordering of logout side effects.

**FIX:** Drive `PresenceService` from the `onLogout` / `onLogin` callbacks already wired in `AuthGate` and `AppStartupController`, instead of subscribing to auth state independently.

---

### Issue 7 — `MainScreen` Initializes Services In `initState` — SEVERITY: MEDIUM

**WHERE:** `lib/screens/main/main_screen.dart` → `_MainScreenState.initState()`

**WHY it is a problem:**  
`MainScreen._initializeServicesAsync()` initializes `AchievementService` and `OnboardingService`. This puts service initialization logic inside a tab-navigation widget. If `MainScreen` is ever rebuilt (e.g., from deep-link or hot restart), `initState` reruns. It also means service startup is split across two locations: `AppStartupController` (step 7 in startup sequence) and `MainScreen.initState` (step 9), which makes the startup sequence hard to reason about.

**FIX:** Move `AchievementService` and `OnboardingService` initialization into `AppStartupController.initialize()`.

---

### Issue 8 — `features/scanner/` and `features/stations/` Are Empty — SEVERITY: LOW

**WHERE:** `lib/features/scanner/` and `lib/features/stations/`

**WHY it is a problem:**  
These folders exist as stubs from the feature-based architecture migration but contain no files. The actual screens (`scanner_screen.dart`, `station_screen.dart`, `station_detail_screen.dart`) remain in `lib/screens/main/` as large StatefulWidgets. This is inconsistent with the fully migrated `social/` and partially migrated `booking/` features.

`scanner_screen.dart` (~628 lines, 10 `setState` calls) has all QR scan logic, geofencing, achievement unlocking, and camera permission handling in one class.  
`station_screen.dart` (~806 lines, 6 `setState` calls) has station listing, filtering, and `ClimbSessionService` integration mixed together.

---

### Issue 9 — `profile_screen.dart` Is a 1606-line God Class — SEVERITY: MEDIUM

**WHERE:** `lib/screens/main/profile_screen.dart`

**WHY it is a problem:**  
`profile_screen.dart` (1606 lines, 6 `setState` calls) directly calls `SocialSharingService`, `AchievementService`, `UserService`, `ECertificateService`, and `StationService`. It hosts multiple `StreamBuilder` widgets (follow streams, post streams), builds an achievements tab, a climb history tab, a stats tab, and a settings/edit section — all in one `StatefulWidget`. It also manages profile image upload with `ImagePicker`, which includes async file I/O mixed into the widget lifecycle.

This is the largest active screen in the codebase. No ViewModel exists for it.

---

### Issue 10 — Color System Has 5 Parallel Color Namespaces — SEVERITY: LOW

**WHERE:** `lib/theme/new_color.dart`, `lib/theme/color.dart`

**WHY it is a problem:**  
The codebase defines:

- `AppColors` (new-theme light)
- `AppColorsDark` (new-theme dark)
- `SharedColors` (shared between themes)
- `OriginalColors` (legacy light)
- `OriginalColorsDark` (legacy dark)
- `AppColorsLegacy` (wrapper class in `color.dart`)

The `color.dart` file is a re-export wrapper that also defines `AppColorsLegacy`. Files across the codebase import either `color.dart` or `new_color.dart` inconsistently. The `ThemeService.themeType` enum (`original` vs `new_theme`) drives which set is active, but this branching is done manually at each call site — there is no central color resolver.

This means every widget that needs a semantic color (e.g., "background", "primary") must write a conditional branch against `ThemeService.themeType`, rather than receiving a resolved token.

---

## PHASE 3 — ARCHITECTURE PROPOSAL

### 3.1 Target Folder Structure

```
lib/
  main.dart                        ← entry point only
  firebase_options.dart

  config/
    app_init.dart
    app_router.dart

  core/
    app_startup_controller.dart
    deep_link_handler.dart
    notification_handler.dart
    providers/
      app_providers.dart
    services/
      analytics_service.dart
    viewmodels/
      auth_view_model.dart
    widgets/
      app_shell.dart
      auth_gate.dart

  features/
    auth/                          ← NEW: move login/signup/verify screens here
      screens/
        login_screen.dart
        signup_screen.dart
        email_verification_screen.dart
        forgot_password_screen.dart
        additional_information.dart

    home/                          ← DONE ✓
      viewmodels/home_view_model.dart
      widgets/
      screens/home_screen.dart

    booking/                       ← PARTIALLY DONE
      models/
      repositories/                ← NEW: extract Firestore from BookingProvider
        booking_repository.dart
      providers/
        booking_provider.dart      ← slim to form state only
      screens/
        book_a_climb_screen.dart
      services/
      widgets/

    scanner/                       ← EMPTY → migrate ScannerScreen here
      viewmodels/
        scanner_view_model.dart
      screens/
        scanner_screen.dart

    stations/                      ← EMPTY → migrate StationScreen here
      repositories/
        station_repository.dart
      viewmodels/
        station_view_model.dart
        station_detail_view_model.dart
      screens/
        station_screen.dart
        station_detail_screen.dart

    profile/                       ← NEW
      repositories/
        profile_repository.dart
      viewmodels/
        profile_view_model.dart
      screens/
        profile_screen.dart
      widgets/

    social/                        ← DONE ✓

    settings/                      ← NEW
      viewmodels/
        settings_view_model.dart
      screens/
        settings_screen.dart
        account_settings.dart
        security_screen.dart
        notification_settings.dart
        archived_bookings_screen.dart
        appearance_settings.dart
        badges_screen.dart
        about_screen.dart
        help_and_support_screen.dart

    notifications/                 ← NEW
      repositories/
        notification_repository.dart   ← extract from notification_services.dart
      viewmodels/
        notifications_view_model.dart
      screens/
        notification_screen.dart

  components/                      ← keep shared UI widgets only
    bottom_navigation.dart
    banner_slideshow.dart
    connectivity_banner.dart
    notification_banner.dart
    profile_avatar_with_status.dart
    app_dialogue_handler.dart
    event_calendar.dart            ← remove Firestore from here
    station_review_widgets.dart

  models/                          ← shared/cross-feature models only
    user_model.dart
    notification_model.dart
    calendar_model.dart
    station_data.dart

  services/                        ← infrastructure services (no Firestore UI coupling)
    firebase_auth_service.dart
    user_service.dart
    theme_service.dart
    app_theme_builder.dart
    presence_service.dart
    achievement_service.dart
    climb_session_service.dart
    calendar_config_service.dart
    station_service.dart           ← rename/consolidate with firestore_station_service.dart
    notification_service.dart      ← FCM only (rename the Firestore one)
    feed_pagination_service.dart
    geofencing_service.dart
    e_certificate_service.dart
    social_sharing_service.dart    ← (already a shim)
    onboarding_service.dart
    connectivity_service.dart
    permission_service.dart

  theme/
    color.dart                     ← keep as single source of truth
    app_theme_builder.dart

  utils/
    app_logger.dart
    image_cache_manager.dart
    station_image_path.dart
    status_helpers.dart
```

### 3.2 Layer Rules

```
UI (Screens / Widgets)
  ├─ MAY depend on: ViewModel, Models, Theme, Utils
  ├─ MAY NOT depend on: Firestore, FirebaseAuth, SharedPreferences
  └─ COMMUNICATES via: ViewModel methods and notifyListeners()

ViewModel (ChangeNotifier)
  ├─ MAY depend on: Repository, Service, Model
  ├─ MAY NOT depend on: BuildContext (except via callbacks), Widget
  └─ COMMUNICATES via: notifyListeners(), exposed getters

Repository
  ├─ MAY depend on: FirebaseFirestore, FirebaseAuth, FirebaseStorage
  ├─ MAY NOT depend on: Widget, BuildContext, ChangeNotifier
  └─ RETURNS: typed Model objects or Streams

Service (Infrastructure)
  ├─ MAY depend on: Firebase, SharedPreferences, Platform APIs
  ├─ MAY NOT depend on: Widget, BuildContext
  └─ SCOPE: singleton or injected, no UI knowledge
```

### 3.3 ViewModel Exposure Pattern (no Riverpod)

For ViewModels that are **tab-scoped** (not global):

```dart
// In StatefulWidget
late final MyViewModel _vm;

@override
void initState() {
  super.initState();
  _vm = MyViewModel();
  _vm.addListener(_onVmChanged);
  _vm.initialize();
}

@override
void dispose() {
  _vm.removeListener(_onVmChanged);
  _vm.dispose();
  super.dispose();
}

void _onVmChanged() => setState(() {});
```

For ViewModels that are **app-scoped** (e.g., AuthViewModel, ThemeService): use `ChangeNotifierProvider` in `AppProviders`.

---

## PHASE 4 — REFACTOR PLAN (CRITICAL)

**Principle**: Every step is independently deployable. Each step follows the same pattern:

1. Create ViewModel/Repository in `features/<name>/`
2. Move screen to `features/<name>/screens/`
3. Add re-export shim at old path for zero-import-breakage
4. Run `dart analyze` — must be clean
5. Test on device

---

### Step 0 — Safe Cleanup (1 day)

**0A.** Delete `lib/screens/main/book_a_climb.dart` (2612-line dead file — confirmed zero imports).

**0B.** Rename `class NotificationService` in `notification_services.dart` to `InAppNotificationService`. Update the 3 consumers:

- `screens/main/notification_screen.dart`
- Any other file importing `notification_services.dart`
  Add a re-export shim if needed for backward compat.

**0C.** Move `AchievementService` and `OnboardingService` initialization from `MainScreen.initState()` into `AppStartupController.initialize()`.

---

### Step 1 — Auth Feature Folder (1 day)

**Goal**: Move auth screens under `features/auth/screens/` and fix `LoginScreen`'s bypass of `AuthGate`.

1. Create `lib/features/auth/screens/` directory.
2. Move these screens verbatim:
   - `login_screen.dart`
   - `signup_screen.dart`
   - `email_verification_screen.dart`
   - `forgot_password_screen.dart`
   - `additional_information.dart`
3. Add re-export shims at old paths (`lib/screens/auth/`).
4. In `login_screen.dart`: After `FirebaseAuthService.instance.logIn()` succeeds, remove the manual `Navigator.pushReplacement` and email-verification check. The `AuthViewModel` stream will automatically trigger `AuthGate` to route correctly.
5. In `settings_screen.dart`: Change `_handleLogout()` to call `context.read<AuthViewModel>().signOut()` and remove the manual `Navigator.pushReplacement`.
6. Run `dart analyze`.

---

### Step 2 — Scanner Feature (2 days)

**Goal**: Extract `ScannerScreen` business logic into a `ScannerViewModel`.

1. Create `lib/features/scanner/viewmodels/scanner_view_model.dart`:
   - Holds: `scanResult`, `isScanning`, `permissionDenied`, `isGeofenceValid`
   - Methods: `initialize()`, `onDetect(BarcodeCapture)`, `dispose()`
   - Calls: `GeofencingService`, `AchievementService`
   - NO `BuildContext` stored. Dialog callbacks injected via constructor.

2. Create `lib/features/scanner/screens/scanner_screen.dart`:
   - Thin StatefulWidget using `ScannerViewModel` via manual listener pattern
   - Handles camera permission UI only

3. Add re-export shim at `lib/screens/main/scanner_screen.dart`.

4. Run `dart analyze`.

---

### Step 3 — Stations Feature (2 days)

**Goal**: Extract station listing and station detail logic into ViewModels.

1. Create `lib/features/stations/viewmodels/station_view_model.dart`:
   - Holds: `List<StationData> stations`, `isLoading`, `error`
   - Calls: `StationService.instance`
   - Removes manual `addListener`/`removeListener` from `StationScreen`

2. Create `lib/features/stations/viewmodels/station_detail_view_model.dart`:
   - Holds state from `station_detail_screen.dart` (~1338 lines)
   - Primarily: `stationData`, `visitStatus`, `reviews`, `trailMapVisible`

3. Move screens:
   - `station_screen.dart` → `features/stations/screens/`
   - `station_detail_screen.dart` → `features/stations/screens/`

4. Add re-export shims at old paths.

5. Consolidate `StationService` + `FirestoreStationService` → single `StationService` that delegates to internal Firestore helper (or a `StationRepository`).

---

### Step 4 — Booking Repository Extraction (1 day)

**Goal**: Remove direct Firestore calls from `BookingProvider`.

1. Create `lib/features/booking/repositories/booking_repository.dart`:
   - Extracts all `FirebaseFirestore.instance.collection(...)` calls from `booking_provider.dart`
   - Methods: `saveDraft()`, `submitBooking()`, `getBookings()`, `deleteBooking()`
   - Returns typed `BookingModel` objects

2. Update `BookingProvider` to call `BookingRepository` instead of Firestore directly.

3. Move `FirebaseAuth.instance.currentUser` calls in `book_a_climb_screen.dart` to `BookingProvider`.

4. Run `dart analyze`.

---

### Step 5 — Profile Feature (3 days)

**Goal**: Extract `ProfileScreen` (1606 lines) into a ViewModel + smaller widgets.

1. Create `lib/features/profile/repositories/profile_repository.dart`:
   - Extracts `UserService` + `SocialSharingService` calls into one place
   - Methods: `getProfile(uid)`, `updateProfile()`, `getFollowers()`, `getPosts()`

2. Create `lib/features/profile/viewmodels/profile_view_model.dart`:
   - Holds: `UserModel? profile`, `List<SocialPost> posts`, `List<Achievement> achievements`, `isFollowing`, `isLoading`
   - NO `BuildContext` stored

3. Extract widgets from `ProfileScreen`:
   - `lib/features/profile/widgets/profile_header.dart`
   - `lib/features/profile/widgets/profile_stats.dart`
   - `lib/features/profile/widgets/profile_tab_bar.dart`
   - `lib/features/profile/widgets/achievements_tab.dart`
   - `lib/features/profile/widgets/posts_grid.dart`

4. Move `profile_screen.dart` → `features/profile/screens/`.

5. Add re-export shim at `lib/screens/main/profile_screen.dart`.

---

### Step 6 — Notifications Feature (1 day)

**Goal**: Rename duplicate class, create a proper notifications ViewModel.

1. (Already done in Step 0B) Rename `NotificationService` → `InAppNotificationService`.

2. Create `lib/features/notifications/viewmodels/notifications_view_model.dart`:
   - Holds: `List<NotificationModel> notifications`, `isLoading`, `selectedIds`
   - Uses `InAppNotificationService` for Firestore ops

3. Move `notification_screen.dart` → `features/notifications/screens/`.

4. Add re-export shim.

---

### Step 7 — Settings Feature (1 day)

**Goal**: Extract common settings ViewModel, remove Firestore from settings screens.

1. Create `lib/features/settings/viewmodels/settings_view_model.dart`:
   - Holds logout logic (delegates to `AuthViewModel`)
   - Navigation helpers

2. Extract Firestore calls from `security_screen.dart` → `UserService`/`FirebaseAuthService`.

3. Move all settings screens under `features/settings/screens/`.

4. Add re-export shims.

---

### Step 8 — EventCalendar Firestore Decoupling (0.5 day)

**Goal**: Make `EventCalendar` a pure UI widget.

1. Remove `StreamSubscription<QuerySnapshot>` from `event_calendar.dart`.
2. The booking count data that it fetches should come from `HomeViewModel` or whichever screen hosts the calendar.
3. `EventCalendar` should only accept `trekDays` (already a parameter) — no network access inside the widget.

---

### Step 9 — PresenceService Decoupling (0.5 day)

**Goal**: Remove PresenceService's independent auth subscription.

1. Remove `FirebaseAuth.instance.authStateChanges()` subscription from `PresenceService`.
2. Add `PresenceService.setOnline(uid)` and `PresenceService.setOffline()` methods.
3. Call `setOnline` from `AppStartupController.initialize()`.
4. Call `setOffline` from the `onLogout` callback in `AuthGate`.

---

## PHASE 5 — PRIORITIZATION

### Critical (fix before new features)

| #   | Task                                                  | Risk if skipped                                                       |
| --- | ----------------------------------------------------- | --------------------------------------------------------------------- |
| 1   | Delete dead `book_a_climb.dart` (2612 lines)          | Confuses all future contributors                                      |
| 2   | Fix `NotificationService` class name collision        | Compile ambiguity when both are imported                              |
| 3   | Fix `LoginScreen` bypassing `AuthGate`                | Auth routing bugs on edge cases (token refresh, verification)         |
| 4   | Fix `SettingsScreen` logout bypassing `AuthViewModel` | onLogout cleanup (ClimbSession, PresenceService) never runs on logout |

### Important (next sprint)

| #   | Task                                                                    | Benefit                                                 |
| --- | ----------------------------------------------------------------------- | ------------------------------------------------------- |
| 5   | Scanner ViewModel (Step 2)                                              | 628-line screen → testable logic                        |
| 6   | Move service init from `MainScreen` to `AppStartupController` (Step 0C) | Single authoritative startup sequence                   |
| 7   | Booking repository (Step 4)                                             | Removes 8 direct Firestore calls from `BookingProvider` |
| 8   | EventCalendar Firestore decoupling (Step 8)                             | Removes network from a passive UI component             |
| 9   | PresenceService auth subscription cleanup (Step 9)                      | Eliminates race condition on logout                     |

### Optional (future polish)

| #   | Task                                      | Benefit                           |
| --- | ----------------------------------------- | --------------------------------- |
| 10  | Profile ViewModel (Step 5)                | Splits 1606-line God class        |
| 11  | Stations ViewModel (Step 3)               | Testable station logic            |
| 12  | Notifications feature folder (Step 6)     | Clean architecture consistency    |
| 13  | Settings feature folder (Step 7)          | Architecture consistency          |
| 14  | Color system consolidation (Phase 7)      | DX improvement, no runtime impact |
| 15  | `AchievementService` dual-factory cleanup | Easier instantiation              |

---

## PHASE 6 — CODE QUALITY

### 6.1 Naming

| Problem                                                          | Location                   | Fix                                                        |
| ---------------------------------------------------------------- | -------------------------- | ---------------------------------------------------------- |
| `BookAClimbScreenRefactored` as class name                       | `book_a_climb_screen.dart` | Rename to `BookAClimbScreen` (after deleting dead file)    |
| `notification_service.dart` vs `notification_services.dart`      | `services/`                | Rename Firestore one to `in_app_notification_service.dart` |
| `FirestoreStationService` + `StationService` (same concept)      | `services/`                | Merge into single `StationService`                         |
| `social_sharing_service.dart` is a re-export shim, not a service | `services/`                | Delete; update the 2 files that import it directly         |

### 6.2 File Splitting Candidates

| File                         | Lines | Split into                                                     |
| ---------------------------- | ----- | -------------------------------------------------------------- |
| `profile_screen.dart`        | 1606  | profile_view_model + 5 sub-widgets + thin screen               |
| `book_a_climb_screen.dart`   | 1368  | already has 10 extracted widgets; move Firestore to repository |
| `station_detail_screen.dart` | 1338  | station_detail_view_model + tab widgets                        |
| `social_card.dart`           | 805   | header, body, actions, media sub-widgets                       |
| `comment_thread.dart`        | 581   | collapse 7 `setState` calls into a ViewModel                   |
| `do_and_dont.dart`           | 742   | Split tabs into separate stateless widgets                     |
| `trail_map.dart`             | 704   | Extract map controls and map view into separate widgets        |

### 6.3 Reusable Components to Extract

1. **LoadingIndicator** — inline `CircularProgressIndicator` appears in >10 screens. Create `components/loading_indicator.dart`.
2. **ErrorRetryWidget** — inline error + retry button pattern repeated in at least 8 screens.
3. **EmptyStateWidget** — empty list state (icon + message + optional action) repeated in social feed, bookings, notifications.
4. **ConfirmationDialog** — multiple screens show their own `AlertDialog` for destructive actions. Consolidate in `app_dialogue_handler.dart`.

### 6.4 State Management Improvements

1. **`ClimbSessionService`** is a `ChangeNotifier` singleton that is NOT in the Provider tree. All screens manually add/remove listeners to it. Either:
   - Add it to the Provider tree in `AppProviders` (if app-wide scope is needed), OR
   - Convert it to a plain service if no UI needs to reactively rebuild from it

2. **`FeedPaginationService`** is a singleton with mutable cursor state (`_lastPublicPostDocument`). If the user navigates away and back, the cursor is stale. Consider making it non-singleton (instantiated by `SocialFeedViewModel`) or adding a `reset()` method called on ViewModel disposal.

3. **`AchievementService`** has two factory constructors:
   ```dart
   AchievementService()          // uses singleton
   AchievementService.forUser(uid)  // creates new instance
   ```
   This makes it unclear which instance has valid state. Consolidate to a single pattern.

### 6.5 Performance

1. **`profile_screen.dart`** has multiple `StreamBuilder` widgets reading Firestore in parallel. Each rebuild of the parent rebuilds all streams. Hoist to ViewModel `initState` + `notifyListeners`.

2. **`station_detail_screen.dart`** (~1338 lines) has several `setState` calls for tab switching that rebuild the entire screen. Convert tab state to an `IndexedStack` or cached tab pattern.

3. **`social_card.dart`** (805 lines) builds multiple conditional sub-trees on every rebuild. Extract each section as a `const` widget or use `RepaintBoundary` for the heavy media sections.

4. **`components/banner_slideshow.dart`** — verify `PageController` is disposed properly (common leak in slideshow widgets).

---

## PHASE 7 — THEME & STATE SYSTEM REVIEW

### 7.1 Current Theme Architecture

```
ThemeService (ChangeNotifier, singleton in Provider tree)
  ├─ themeType: ThemeType { original, new_theme }
  ├─ appThemeMode: AppThemeMode { light, dark }
  └─ persists to SharedPreferences

AppThemeBuilder
  └─ buildTheme(ThemeType, AppThemeMode) → ThemeData

Color namespaces (new_color.dart):
  ├─ AppColors (new_theme + light)
  ├─ AppColorsDark (new_theme + dark)
  ├─ SharedColors (shared between themes)
  ├─ OriginalColors (original + light)
  └─ OriginalColorsDark (original + dark)

color.dart (re-export + legacy wrapper):
  ├─ re-exports new_color.dart
  └─ defines AppColorsLegacy (backward compat alias class)
```

### 7.2 Problems

**Problem A — No semantic color token system.**  
Widgets reference `AppColors.background` or `OriginalColors.background` directly. When the theme switches, every widget that hardcodes a color class must be updated. There is no single "background" token that resolves to the correct color based on active theme.

**Problem B — Manual branching in widgets.**  
Several widgets do:

```dart
final bg = ThemeService.instance.themeType == ThemeType.new_theme
    ? AppColors.background
    : OriginalColors.background;
```

This pattern is spread across many files and will scale poorly as theme variants grow.

**Problem C — `AppColorsLegacy` class in `color.dart`.**  
`color.dart` defines `AppColorsLegacy` as a static field wrapper pointing to `OriginalColors`. This exists for backward compatibility but is technically a dead layer on top of another layer.

**Problem D — Dark mode is implemented twice.**  
`AppColorsDark` and `OriginalColorsDark` define separate dark color sets for each theme type. `AppThemeBuilder` must handle 4 combinations (2 types × 2 modes). This works but scales to 8 combinations if a 3rd theme type is added.

### 7.3 Recommended Theme Fix (no breaking changes)

**Phase A — Add a color resolver extension:**

```dart
// lib/theme/app_color_resolver.dart
extension AppColorResolver on ThemeService {
  Color get background => themeType == ThemeType.new_theme
      ? (isDark ? AppColorsDark.background : AppColors.background)
      : (isDark ? OriginalColorsDark.background : OriginalColors.background);

  Color get primary => themeType == ThemeType.new_theme
      ? (isDark ? AppColorsDark.primary : AppColors.primary)
      : (isDark ? OriginalColorsDark.primary : OriginalColors.primary);
  // ... one line per semantic token
}
```

Then widgets use:

```dart
final theme = context.read<ThemeService>();
final bg = theme.background; // resolved automatically
```

**Phase B — Consolidate `color.dart`:**  
Remove `AppColorsLegacy` from `color.dart` once all usages are updated. Make `color.dart` export only `new_color.dart` and the resolver.

**Phase C — Long-term (optional):** Consider making `ThemeData.colorScheme` the single source of truth by populating it fully in `AppThemeBuilder`. Then widgets use `Theme.of(context).colorScheme.surface` instead of custom color classes.

### 7.4 Provider System Review

**Current state:**  
Only `ThemeService` and `AuthViewModel` are in the Provider tree. All other ViewModels use manual `addListener`/`removeListener`.

**Assessment:**  
This is a valid and consistent pattern for the project's current scale. The manual listener pattern works well for screen-scoped ViewModels where the ViewModel lifecycle matches the `StatefulWidget` lifecycle.

**Gaps to fix:**

1. `ClimbSessionService` is a `ChangeNotifier` but not in the Provider tree. Screens call `ClimbSessionService.instance` + manually add listeners. This works but is inconsistent with the rest of the architecture. If it needs to be globally reactive (notify multiple screens), add it to `AppProviders`. If it is only used in `StationScreen` and `HomeScreen`, leave it as a singleton and document the pattern.

2. `BookingProvider` is a `ChangeNotifier` used with `Provider.of(context)` locally (inside `BookAClimbScreenRefactored` via `ChangeNotifierProvider` at the top of the build tree). This is correct usage of the scoped provider pattern and should be kept as-is.

3. **No Riverpod needed** for the current scale. The existing pattern (global Provider tree for app-level state, manual listeners for screen-level ViewModels) is adequate. Riverpod would be the right next step only if the app adds >10 global providers or needs compile-time dependency injection guarantees.

---

## Appendix — Key File Reference

| File                                                  | Lines     | Status                                   |
| ----------------------------------------------------- | --------- | ---------------------------------------- |
| `screens/main/book_a_climb.dart`                      | 2612      | DEAD — delete                            |
| `screens/main/profile_screen.dart`                    | 1606      | Active God class                         |
| `features/booking/screens/book_a_climb_screen.dart`   | 1368      | Active, needs repository                 |
| `screens/main/station_detail_screen.dart`             | 1338      | Active, needs ViewModel                  |
| `screens/main/station_screen.dart`                    | 806       | Active, needs ViewModel                  |
| `features/social/widgets/social_card.dart`            | 805       | Active, could be split                   |
| `features/social/repositories/social_repository.dart` | 795       | Clean repository — keep                  |
| `features/booking/providers/booking_provider.dart`    | 682       | Needs repository extraction              |
| `screens/main/scanner_screen.dart`                    | 628       | Needs ViewModel                          |
| `services/notification_service.dart`                  | ~300      | FCM (keep, rename companion)             |
| `services/notification_services.dart`                 | ~200      | Rename class to InAppNotificationService |
| `features/social/`                                    | ~20 files | FULLY REFACTORED ✓                       |
| `features/home/`                                      | ~5 files  | REFACTORED ✓                             |
| `features/scanner/`                                   | 0 files   | EMPTY STUB                               |
| `features/stations/`                                  | 0 files   | EMPTY STUB                               |
