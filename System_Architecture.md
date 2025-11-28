# Mt. Hamiguitan TrekScan+ System Architecture

## Overview

Mt. Hamiguitan TrekScan+ employs a **Mobile-Based Client-Server Cloud Architecture** that combines mobile application functionality with cloud-based backend services. The system is designed to support offline-first operations for trekkers in remote areas while maintaining real-time synchronization when connectivity is available. This architecture leverages Firebase's comprehensive cloud platform for authentication, data storage, and serverless computing, ensuring scalability, security, and reliability.

---

## Architecture Type

**Mobile-Based Client-Server Cloud Architecture**

The system architecture consists of three primary layers:
1. **Client Layer** - Flutter mobile application (iOS/Android)
2. **Cloud Services Layer** - Firebase backend services
3. **Data Layer** - Firestore NoSQL database and Cloud Storage

This architecture enables:
- **Cross-platform deployment** (single codebase for iOS and Android)
- **Offline-first functionality** (local data persistence with automatic sync)
- **Scalable cloud infrastructure** (auto-scaling based on demand)
- **Real-time data synchronization** (instant updates across devices)
- **Secure authentication** (Google Sign-In with Firebase Auth)

---

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                  CLIENT LAYER                                       │
│                          (Mobile Application - Flutter)                             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │                         PRESENTATION LAYER (UI)                              │  │
│  ├──────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                              │  │
│  │  Home Screen  │  Station Screen  │  Scanner  │  Booking  │  Profile/Settings│  │
│  │  • Dashboard  │  • Station List  │  • QR Scan│  • Calendar│  • Achievements │  │
│  │  • Calendar   │  • Station Info  │  • Camera │  • Upload  │  • Social       │  │
│  │  • Quicklinks │  • Progress      │  • Verify │  • Status  │  • Certificates │  │
│  │                                                                              │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                         ↕                                           │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │                         APPLICATION LOGIC LAYER                              │  │
│  ├──────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                              │  │
│  │  ┌─────────────────────┐  ┌─────────────────────┐  ┌────────────────────┐  │  │
│  │  │   Core Services     │  │  Feature Services   │  │  Utility Services  │  │  │
│  │  ├─────────────────────┤  ├─────────────────────┤  ├────────────────────┤  │  │
│  │  │ • AuthService       │  │ • BookingService    │  │ • ConnectivitySvc  │  │  │
│  │  │ • UserService       │  │ • StationService    │  │ • GeofencingService│  │  │
│  │  │ • FirestoreService  │  │ • AchievementSvc    │  │ • PermissionSvc    │  │  │
│  │  │ • StorageService    │  │ • SocialSharingS    │  │ • NotificationSvc  │  │  │
│  │  │ • FCMService        │  │ • CertificateService│  │ • CalendarConfigS  │  │  │
│  │  │                     │  │ • PresenceService   │  │ • EmailService     │  │  │
│  │  └─────────────────────┘  └─────────────────────┘  └────────────────────┘  │  │
│  │                                                                              │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                         ↕                                           │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │                         LOCAL DATA LAYER (Offline)                           │  │
│  ├──────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                              │  │
│  │  • SQLite Database (Visited Stations, Trek Data)                            │  │
│  │  • SharedPreferences (Achievements, User Preferences, Sync Queue)           │  │
│  │  • Cached Images & Offline Maps                                             │  │
│  │  • Firestore Offline Persistence (Automatic Caching)                        │  │
│  │                                                                              │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                         ↕
                                    INTERNET
                                         ↕
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              CLOUD SERVICES LAYER                                   │
│                              (Firebase Platform)                                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────────┐    │
│  │ Firebase Auth       │  │ Cloud Firestore     │  │ Firebase Storage        │    │
│  ├─────────────────────┤  ├─────────────────────┤  ├─────────────────────────┤    │
│  │ • Google Sign-In    │  │ • users/            │  │ • Profile Images        │    │
│  │ • Biometric Auth    │  │ • bookings/         │  │ • Booking Documents     │    │
│  │ • Session Mgmt      │  │ • posts/            │  │ • Post Photos           │    │
│  │ • Token Refresh     │  │ • calendar_config/  │  │ • E-Certificates (PDF)  │    │
│  │ • User Claims       │  │ • system_settings/  │  │ • Station Images        │    │
│  │ • Security Rules    │  │ • Subcollections    │  │ • Cached Assets         │    │
│  │                     │  │ • Real-time Sync    │  │ • Access Control        │    │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────────┘    │
│                                                                                     │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────────┐    │
│  │ Cloud Functions     │  │ Firebase Messaging  │  │ Firebase Analytics      │    │
│  ├─────────────────────┤  ├─────────────────────┤  ├─────────────────────────┤    │
│  │ • Booking Approval  │  │ • Push Notifications│  │ • User Behavior         │    │
│  │ • Auto Notifications│  │ • FCM Tokens        │  │ • Screen Views          │    │
│  │ • Certificate Gen   │  │ • Topic Messaging   │  │ • Event Tracking        │    │
│  │ • Email Triggers    │  │ • Background Sync   │  │ • Achievement Stats     │    │
│  │ • Scheduled Tasks   │  │ • Device Mgmt       │  │ • Booking Patterns      │    │
│  │ • Data Validation   │  │                     │  │ • Error Monitoring      │    │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────────┘    │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                         ↕
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                 DATA LAYER                                          │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │                     Firestore Database (NoSQL)                               │  │
│  ├──────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                              │  │
│  │  Top-Level Collections:           User Subcollections:                      │  │
│  │  ├─ users/                         ├─ /notifications/                       │  │
│  │  ├─ bookings/                      ├─ /visitedStations/                     │  │
│  │  ├─ posts/                         ├─ /achievements/                        │  │
│  │  ├─ calendar_config/               ├─ /certificates/                        │  │
│  │  └─ system_settings/               └─ /bookmarks/                           │  │
│  │                                                                              │  │
│  │  Post Subcollections:              Relationships:                           │  │
│  │  ├─ /comments/                     • 1:N (users → bookings)                 │  │
│  │  │   ├─ /replies/                  • 1:N (users → posts)                    │  │
│  │  │   │   └─ /likes/                • M:N (users ↔ users - followers)        │  │
│  │  │   └─ /likes/                    • 1:N (posts → comments → replies)       │  │
│  │  └─ /likes/                        • N:1 (bookings → calendar_config)       │  │
│  │                                                                              │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │                     Firebase Cloud Storage (Blob Storage)                    │  │
│  ├──────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                              │  │
│  │  Organized by Type:                Security:                                │  │
│  │  ├─ /users/{uid}/profile/          • Path-based rules                       │  │
│  │  ├─ /users/{uid}/bookings/         • Size limits (10MB)                     │  │
│  │  ├─ /posts/{postId}/images/        • File type validation                   │  │
│  │  ├─ /certificates/{userId}/        • User ownership                         │  │
│  │  └─ /stations/images/              • Public read for assets                 │  │
│  │                                                                              │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                         ↕
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         EXTERNAL SERVICES & APIs                                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────────┐    │
│  │ Google Maps API     │  │ Google Sign-In      │  │ Device Hardware         │    │
│  ├─────────────────────┤  ├─────────────────────┤  ├─────────────────────────┤    │
│  │ • Offline Maps      │  │ • OAuth 2.0         │  │ • Camera (QR Scanner)   │    │
│  │ • GPS Navigation    │  │ • User Profiles     │  │ • GPS Receiver          │    │
│  │ • Elevation Data    │  │ • ID Tokens         │  │ • Biometric Sensors     │    │
│  │ • Route Planning    │  │ • Account Linking   │  │ • Network Adapter       │    │
│  │ • Geolocation       │  │                     │  │ • Local Storage         │    │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────────┘    │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Architecture Components

### 1. Client Layer (Mobile Application)

#### 1.1 Presentation Layer (UI)
**Technology:** Flutter (Dart)

**Components:**
- **Home Screen**: Dashboard with calendar, quick access, and statistics
- **Station Screen**: List of 7 eco-stations with detailed information
- **Scanner Screen**: QR code scanning with geofence validation
- **Booking Screen**: Trek reservation with calendar and document upload
- **Settings/Profile Screen**: User profile, achievements, social features, certificates

**Responsibilities:**
- Render responsive UI components
- Handle user interactions and gestures
- Display notifications and dialogs
- Navigate between screens
- Manage UI state (loading, error, success)

**Key Features:**
- Material Design 3 components
- Responsive layout for different screen sizes
- Dark/light theme support (future)
- Accessibility features
- Smooth animations and transitions

---

#### 1.2 Application Logic Layer (Business Logic)

**Core Services:**

1. **FirebaseAuthService**
   - User authentication (Google Sign-In, biometric)
   - Session management
   - Token refresh
   - User state listeners

2. **UserService**
   - User profile CRUD operations
   - Follow/unfollow functionality
   - Badge management
   - User statistics tracking

3. **FirestoreStationService**
   - Station data synchronization
   - Visited stations tracking
   - Progress calculation

4. **StorageService**
   - File upload/download
   - Image compression
   - URL generation

5. **FCMService**
   - Push notification handling
   - Token registration
   - Background message processing

**Feature Services:**

1. **BookingService**
   - Booking creation and validation
   - Document upload
   - Status tracking
   - Duplicate prevention
   - Buffer day enforcement

2. **StationService**
   - Load station metadata from JSON
   - Geofence validation
   - Station visit marking
   - Progress tracking

3. **AchievementService**
   - Achievement criteria checking
   - Local unlock logic
   - Firebase synchronization
   - Notification queue management

4. **SocialSharingService**
   - Post creation/deletion
   - Comment/reply management
   - Like/unlike functionality
   - Privacy control

5. **ECertificateService**
   - Certificate eligibility checking
   - PDF generation
   - Verification code generation
   - Email delivery

6. **CalendarConfigService**
   - Date availability checking
   - Capacity validation
   - Buffer day calculation
   - Closed date management

**Utility Services:**

1. **ConnectivityService**
   - Network status monitoring
   - Auto-reconnect handling
   - Sync queue processing

2. **GeofencingService**
   - Location-based validation
   - Radius checking
   - GPS accuracy verification

3. **PermissionService**
   - Camera permission
   - Location permission
   - Storage permission
   - Notification permission

4. **NotificationService**
   - Local notification scheduling
   - In-app notification display
   - Action handling

**Data Flow Pattern:**
```
UI → Service → Firebase API → Firestore/Storage
                     ↓
                 Local Cache (Offline)
                     ↓
                 Sync Queue → Firebase (When Online)
```

---

#### 1.3 Local Data Layer (Offline Support)

**Technologies:**
- SQLite (via sqflite package)
- SharedPreferences
- Firestore Offline Persistence
- File System (path_provider)

**Stored Data:**

1. **SQLite Database**
   - Visited stations with timestamps
   - Trek session data
   - Offline station metadata

2. **SharedPreferences**
   - Achievement unlock status
   - Sync queue (pending Firebase updates)
   - User preferences
   - Last sync timestamps

3. **Firestore Offline Cache**
   - User profile
   - Bookings
   - Posts (recent feed)
   - Notifications

4. **File System Cache**
   - Offline maps
   - Station images
   - Profile photos
   - Booking documents (temporary)

**Sync Strategy:**
```
Offline Action → Local Storage → Sync Queue
                                      ↓
                              Network Available?
                                      ↓
                                   YES → Upload to Firebase
                                      ↓
                                Update Local State
```

---

### 2. Cloud Services Layer (Firebase Platform)

#### 2.1 Firebase Authentication
**Purpose:** Secure user authentication and authorization

**Features:**
- Google Sign-In integration
- Custom claims for admin roles
- Session persistence
- Token-based security
- Biometric authentication support

**Authentication Flow:**
```
User → Google Sign-In → Firebase Auth → Token Generation → User Profile Creation
                                              ↓
                                        Firestore User Doc
```

**Security:**
- HTTPS-only communication
- Token expiration and refresh
- Email verification
- Password complexity (if email/password enabled)

---

#### 2.2 Cloud Firestore (Database)
**Type:** NoSQL Document Database

**Structure:**
- **Collections:** Top-level entities (users, bookings, posts)
- **Documents:** Individual records with unique IDs
- **Subcollections:** Nested hierarchical data

**Features:**
- Real-time data synchronization
- Offline persistence
- Complex queries with indexes
- Compound indexes for multi-field queries
- Security rules enforcement
- Automatic scaling

**Key Collections:**
1. `users/` - User profiles and social data
2. `bookings/` - Trek reservations
3. `posts/` - Social media content
4. `calendar_config/` - Date-specific settings
5. `system_settings/` - Global configuration

**Security Rules:**
- Role-based access control (RBAC)
- Field-level validation
- Owner-only write access
- Public read for certain data
- Admin-only system settings

**Indexes:**
```
bookings: userId + trekDate
posts: userId + createdAt (DESC)
comments: postId + createdAt
achievements: userId + unlockedAt (DESC)
```

---

#### 2.3 Firebase Cloud Storage
**Purpose:** Binary file storage (images, PDFs, documents)

**Organization:**
```
/users/{userId}/
    /profile/           → Profile photos
    /bookings/          → Booking verification documents
/posts/{postId}/
    /images/            → Post media (max 4 per post)
/certificates/{userId}/
    /{certId}.pdf       → Generated e-certificates
/stations/
    /images/            → Station educational content
```

**Features:**
- Resumable uploads
- Download URLs with expiration
- File metadata storage
- Size limits (10MB per file)
- Image compression before upload

**Security Rules:**
- Path-based access control
- File size validation
- MIME type checking
- User ownership verification

---

#### 2.4 Cloud Functions (Serverless)
**Technology:** Node.js with Firebase Functions

**Implemented Functions:**

1. **onBookingCreate**
   - Trigger: New booking document created
   - Action: Send notification to admins
   - Validation: Check capacity limits

2. **onBookingStatusChange**
   - Trigger: Booking status updated
   - Action: Notify user of approval/rejection
   - Email: Send confirmation email

3. **generateCertificate**
   - Trigger: HTTP callable function
   - Action: Generate PDF certificate
   - Storage: Upload to Cloud Storage
   - Email: Send certificate to user

4. **scheduledCleanup**
   - Trigger: Scheduled (daily)
   - Action: Remove old notifications
   - Maintenance: Clean expired tokens

**Benefits:**
- Auto-scaling based on demand
- Pay-per-execution pricing
- No server management
- Integrated with Firebase ecosystem

---

#### 2.5 Firebase Cloud Messaging (FCM)
**Purpose:** Push notifications to mobile devices

**Features:**
- Topic-based messaging
- User-specific notifications
- Background/foreground handling
- Data payloads with notifications
- Token management

**Notification Types:**
1. Booking status updates
2. Achievement unlocks
3. Social interactions (likes, comments, follows)
4. Admin announcements
5. System maintenance alerts

**Implementation:**
- FCM tokens stored in Firestore
- Background handler for silent updates
- Local notification display
- Action buttons (accept/reject follow requests)

---

#### 2.6 Firebase Analytics
**Purpose:** Track user behavior and app performance

**Tracked Events:**
- Screen views
- Button clicks
- Station scans
- Achievement unlocks
- Booking completions
- Social interactions

**Metrics:**
- Daily/Monthly Active Users (DAU/MAU)
- Session duration
- Retention rates
- Feature usage
- Error rates

---

### 3. Data Layer

#### 3.1 Database Schema (Firestore)
See **database_erd.md** for complete ERD documentation.

**Key Design Principles:**
- Denormalization for read optimization
- Subcollections for hierarchical data
- Counter fields for aggregation
- Timestamp fields for audit trails
- Indexes for complex queries

**Data Integrity:**
- Firestore security rules validation
- Client-side validation before submission
- Cloud Functions for server-side validation
- Atomic batch operations
- Transaction support for critical updates

---

#### 3.2 Cloud Storage Structure
**Organization by Entity Type**

```
cloud-storage-bucket/
├── users/
│   └── {userId}/
│       ├── profile/
│       │   └── avatar.jpg
│       └── bookings/
│           └── {bookingId}/
│               ├── payment_receipt.pdf
│               └── id_verification.jpg
├── posts/
│   └── {postId}/
│       └── images/
│           ├── image_1.jpg
│           ├── image_2.jpg
│           ├── image_3.jpg
│           └── image_4.jpg
├── certificates/
│   └── {userId}/
│       └── {certificateId}.pdf
└── stations/
    └── images/
        ├── station1_banner.jpg
        ├── station2_mossy.jpg
        └── ...
```

**Access Control:**
- Users can only write to their own directories
- Public read for station assets
- Authenticated read for other users' profiles
- Owner-only read for certificates and bookings

---

### 4. External Services & APIs

#### 4.1 Google Maps API
**Purpose:** Offline navigation and geolocation

**Usage:**
- Display offline maps for trail navigation
- Track user location during trek
- Calculate elevation gain
- Measure distances between stations
- Route planning

**Configuration:**
- API key stored in `.env` file
- Offline map tiles cached locally
- GPS accuracy threshold: 50 meters

---

#### 4.2 Google Sign-In API
**Purpose:** OAuth authentication

**Flow:**
```
User clicks "Sign in with Google"
    ↓
Google OAuth consent screen
    ↓
User approves
    ↓
Google returns ID token
    ↓
Firebase Auth verifies token
    ↓
Create/update user in Firestore
    ↓
Navigate to home screen
```

---

#### 4.3 Device Hardware APIs
**Accessed via Flutter Plugins:**

1. **Camera** (mobile_scanner)
   - QR code scanning
   - Auto-focus and flash control
   - Real-time barcode detection

2. **GPS** (geolocator)
   - Location tracking
   - Distance calculation
   - Geofence validation

3. **Biometric Sensors** (local_auth - future)
   - Fingerprint authentication
   - Face ID (iOS)
   - Security enhancement

4. **Network** (connectivity_plus)
   - Connection status
   - Network type (WiFi, cellular, none)
   - Connectivity change listeners

---

## Data Flow & Communication

### 1. Authentication Flow
```
┌──────────┐         ┌──────────────┐         ┌─────────────┐         ┌───────────┐
│  User    │────────>│  Google      │────────>│  Firebase   │────────>│ Firestore │
│  Login   │         │  OAuth       │         │  Auth       │         │  /users   │
└──────────┘         └──────────────┘         └─────────────┘         └───────────┘
     │                      │                        │                      │
     │   1. Click Sign In   │                        │                      │
     ├─────────────────────>│                        │                      │
     │                      │ 2. Show Consent        │                      │
     │<─────────────────────┤                        │                      │
     │                      │                        │                      │
     │   3. Approve         │                        │                      │
     ├─────────────────────>│                        │                      │
     │                      │ 4. Return ID Token     │                      │
     │<─────────────────────┤                        │                      │
     │                      │                        │                      │
     │   5. Send Token      │                        │                      │
     ├──────────────────────┼───────────────────────>│                      │
     │                      │                        │ 6. Verify Token      │
     │                      │                        │ 7. Create User       │
     │                      │                        ├─────────────────────>│
     │                      │                        │                      │
     │   8. Auth Success    │                        │                      │
     │<─────────────────────┼────────────────────────┤                      │
     │                      │                        │                      │
```

---

### 2. Booking Creation Flow
```
┌──────────┐    ┌─────────────┐    ┌──────────┐    ┌───────────┐    ┌──────────┐
│  User    │───>│  Booking    │───>│  Storage │───>│ Firestore │───>│ Cloud    │
│  UI      │    │  Service    │    │  Upload  │    │  /bookings│    │ Function │
└──────────┘    └─────────────┘    └──────────┘    └───────────┘    └──────────┘
     │                 │                 │                │                │
     │ 1. Select Date  │                 │                │                │
     ├────────────────>│                 │                │                │
     │                 │ 2. Check Buffer │                │                │
     │                 │    & Capacity   │                │                │
     │                 ├────────────────────────────────>│                │
     │                 │                 │                │                │
     │ 3. Upload Docs  │                 │                │                │
     ├────────────────>│                 │                │                │
     │                 │ 4. Upload Files │                │                │
     │                 ├────────────────>│                │                │
     │                 │                 │ 5. Return URLs │                │
     │                 │<────────────────┤                │                │
     │                 │                 │                │                │
     │                 │ 6. Create Booking                │                │
     │                 ├────────────────────────────────>│                │
     │                 │                 │                │ 7. Trigger     │
     │                 │                 │                ├───────────────>│
     │                 │                 │                │ 8. Notify Admin│
     │                 │                 │                │                │
     │ 9. Confirmation │                 │                │                │
     │<────────────────┤                 │                │                │
```

---

### 3. Station Scan & Achievement Unlock Flow
```
┌──────────┐    ┌─────────────┐    ┌──────────────┐    ┌────────────────┐    ┌──────────┐
│  Scanner │───>│  Geofence   │───>│   Station    │───>│  Achievement   │───>│ Firestore│
│  Screen  │    │  Service    │    │   Service    │    │  Service       │    │  Sync    │
└──────────┘    └─────────────┘    └──────────────┘    └────────────────┘    └──────────┘
     │                 │                   │                    │                   │
     │ 1. Scan QR      │                   │                    │                   │
     ├────────────────>│                   │                    │                   │
     │                 │ 2. Get GPS        │                    │                   │
     │                 │ 3. Validate       │                    │                   │
     │                 │    Location       │                    │                   │
     │                 ├──────────────────>│                    │                   │
     │                 │                   │ 4. Mark Visited    │                   │
     │                 │                   │    (Local + Cloud) │                   │
     │                 │                   ├───────────────────>│                   │
     │                 │                   │                    │ 5. Check Criteria │
     │                 │                   │                    │ 6. Unlock Local   │
     │                 │                   │                    │ 7. Queue Sync     │
     │                 │                   │                    ├──────────────────>│
     │                 │                   │                    │                   │
     │                 │                   │ 8. Show Achievement│                   │
     │<────────────────┴───────────────────┴────────────────────┤                   │
     │                 │                   │                    │ 9. Sync Online    │
     │                 │                   │                    │<──────────────────┤
```

---

### 4. Offline-to-Online Sync Flow
```
┌──────────────┐         ┌──────────────┐         ┌─────────────┐
│  Local       │────────>│ Connectivity │────────>│  Firebase   │
│  Storage     │         │  Service     │         │  Sync       │
└──────────────┘         └──────────────┘         └─────────────┘
     │                          │                        │
     │  Offline Actions:        │                        │
     │  - Scan stations         │                        │
     │  - Unlock achievements   │                        │
     │  - Create posts          │                        │
     │  ↓                       │                        │
     │  Queue in Local DB       │                        │
     │                          │                        │
     │                          │ Network Detected       │
     │                          ├───────────────────────>│
     │                          │                        │
     │  Read Sync Queue         │                        │
     ├─────────────────────────>│                        │
     │                          │ Process Queue          │
     │                          ├───────────────────────>│
     │                          │   • Upload Stations    │
     │                          │   • Sync Achievements  │
     │                          │   • Upload Posts       │
     │                          │                        │
     │                          │ Sync Complete          │
     │  Clear Queue             │<───────────────────────┤
     │<─────────────────────────┤                        │
```

---

## Component Responsibilities

### Client Layer Responsibilities
1. **Presentation Layer**
   - Render user interface
   - Handle user input
   - Display data from services
   - Navigate between screens
   - Show loading states and errors

2. **Application Logic Layer**
   - Business logic implementation
   - Data validation
   - API calls to Firebase
   - State management
   - Error handling
   - Offline queue management

3. **Local Data Layer**
   - Cache frequently accessed data
   - Store data for offline use
   - Manage sync queue
   - Persist user preferences

---

### Cloud Services Layer Responsibilities
1. **Firebase Auth**
   - User authentication
   - Token management
   - Session persistence
   - Security enforcement

2. **Cloud Firestore**
   - Data persistence
   - Real-time synchronization
   - Query processing
   - Security rules enforcement
   - Indexing and optimization

3. **Cloud Storage**
   - File storage
   - URL generation
   - Access control
   - Metadata management

4. **Cloud Functions**
   - Server-side logic
   - Automated tasks
   - Email notifications
   - Data validation
   - Background processing

5. **FCM**
   - Push notification delivery
   - Token management
   - Message routing

6. **Analytics**
   - Event tracking
   - Usage metrics
   - Performance monitoring

---

### Data Layer Responsibilities
1. **Firestore Database**
   - Store structured data
   - Maintain relationships
   - Enforce data integrity
   - Enable complex queries
   - Real-time updates

2. **Cloud Storage**
   - Store binary files
   - Generate download URLs
   - Manage file lifecycle
   - Control access

---

## Architecture Benefits

### 1. Efficiency
- **Offline-First Design**: Users can interact with the app without internet connectivity
- **Local Caching**: Reduces network calls and improves response time
- **Lazy Loading**: Load data only when needed
- **Image Compression**: Reduce bandwidth usage
- **Firestore Indexes**: Optimized query performance

### 2. Scalability
- **Auto-Scaling Cloud Services**: Firebase automatically scales based on demand
- **NoSQL Database**: Horizontal scaling for large datasets
- **CDN Distribution**: Firebase Storage uses global CDN
- **Serverless Functions**: Scale per-request without server management
- **Concurrent Users**: Support thousands of simultaneous users

### 3. Data Security
- **Firebase Security Rules**: Enforced at database and storage level
- **HTTPS Communication**: All data encrypted in transit
- **Token-Based Auth**: Secure, time-limited access tokens
- **Role-Based Access Control**: Users can only access their own data
- **Data Encryption**: Firestore data encrypted at rest
- **Geofencing**: Location verification prevents QR code spoofing
- **Input Validation**: Client and server-side validation

### 4. Maintainability
- **Service-Oriented Architecture**: Clear separation of concerns
- **Modular Design**: Independent services can be updated separately
- **Code Reusability**: Shared services across features
- **Documentation**: Comprehensive code comments and docs
- **Error Logging**: Firebase Crashlytics for error tracking

### 5. Reliability
- **99.95% Uptime SLA**: Firebase infrastructure reliability
- **Automatic Backups**: Firestore automatic daily backups
- **Data Redundancy**: Multi-region replication
- **Graceful Degradation**: Offline mode when network unavailable
- **Retry Logic**: Auto-retry failed operations

### 6. User Experience
- **Real-Time Updates**: Instant synchronization across devices
- **Offline Capability**: Full functionality without internet
- **Fast Loading**: Cached data and optimized queries
- **Push Notifications**: Timely updates and engagement
- **Cross-Platform**: Single codebase for iOS and Android

---

## Technology Stack Summary

| **Layer** | **Component** | **Technology** | **Purpose** |
|-----------|---------------|----------------|-------------|
| **Client** | Mobile App | Flutter (Dart) | Cross-platform UI |
| | Local Database | SQLite | Offline data persistence |
| | Preferences | SharedPreferences | Settings and sync queue |
| | QR Scanner | mobile_scanner | Station verification |
| | Location | geolocator | GPS and geofencing |
| | Permissions | permission_handler | Runtime permissions |
| **Cloud** | Authentication | Firebase Auth | User login/security |
| | Database | Cloud Firestore | NoSQL database |
| | File Storage | Firebase Storage | Binary files |
| | Backend Logic | Cloud Functions | Serverless computing |
| | Messaging | FCM | Push notifications |
| | Analytics | Firebase Analytics | User behavior tracking |
| **External** | Maps | Google Maps API | Offline navigation |
| | OAuth | Google Sign-In | Authentication |
| | Email | Mailer | Certificate delivery |

---

## Deployment Architecture

### Mobile Application Distribution
- **Android**: Google Play Store
- **iOS**: Apple App Store
- **Testing**: Firebase App Distribution for beta testing

### Backend Deployment
- **Firebase Project**: Production environment
- **Cloud Functions**: Deployed via Firebase CLI
- **Security Rules**: Firestore and Storage rules deployed separately
- **Indexes**: Automatically generated from firestore.indexes.json

### CI/CD Pipeline (Future)
```
GitHub Repository
    ↓
GitHub Actions
    ├─ Run Tests
    ├─ Build APK/IPA
    ├─ Deploy Cloud Functions
    └─ Deploy to App Distribution
```

---

## Performance Optimization Strategies

1. **Database Optimization**
   - Compound indexes for multi-field queries
   - Denormalization for read-heavy operations
   - Pagination for large datasets
   - Limit query results (10-20 per page)

2. **Network Optimization**
   - Image compression before upload
   - Lazy loading of images
   - Batch operations when possible
   - Cache-first strategy with Firestore

3. **Client-Side Optimization**
   - Widget caching (Flutter)
   - Efficient state management
   - Debouncing search inputs
   - Virtualized lists for long scrolls

4. **Storage Optimization**
   - Delete old cached files
   - Compress images to 1MB max
   - Use Firebase Storage URLs with cache control

---

## Security Measures

### 1. Authentication Security
- Google Sign-In with OAuth 2.0
- Token expiration and refresh
- Secure token storage
- Biometric authentication (future)

### 2. Data Security
- Firestore security rules
- Storage security rules
- HTTPS-only communication
- Input sanitization
- SQL injection prevention (NoSQL)

### 3. Application Security
- Code obfuscation (release builds)
- Certificate pinning (future)
- Geofencing for QR validation
- Rate limiting on Cloud Functions

### 4. Privacy
- GDPR compliance (data deletion)
- Privacy policy enforcement
- User consent for data collection
- Minimal data collection principle

---

## Monitoring & Maintenance

### 1. Error Tracking
- Firebase Crashlytics for crash reports
- Custom error logging
- Cloud Functions error alerts

### 2. Performance Monitoring
- Firebase Performance Monitoring
- Query performance metrics
- Network request tracking
- Screen rendering time

### 3. Analytics
- User engagement metrics
- Feature adoption rates
- Conversion funnels
- Retention analysis

### 4. Maintenance Tasks
- Database cleanup (old notifications)
- Storage cleanup (expired files)
- Token refresh
- Index optimization
- Security rule updates

---

## Conclusion

The Mt. Hamiguitan TrekScan+ system architecture is designed as a **mobile-based client-server cloud architecture** that prioritizes **offline-first functionality**, **scalability**, and **security**. By leveraging Firebase's comprehensive cloud platform, the system ensures:

1. **Efficiency**: Fast response times through local caching and optimized queries
2. **Scalability**: Auto-scaling cloud services handle growing user base
3. **Data Security**: Multi-layered security from authentication to storage
4. **Reliability**: 99.95% uptime with automatic backups and redundancy
5. **User Experience**: Seamless offline/online transitions with real-time updates

The architecture supports all core features—booking management, station tracking, achievement gamification, social sharing, and e-certificate generation—while maintaining clean separation of concerns, modularity, and maintainability. This design ensures the application can grow and adapt to future requirements while providing a robust, secure, and engaging experience for trekkers exploring the Mt. Hamiguitan Range Wildlife Sanctuary.
