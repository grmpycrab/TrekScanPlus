# Mt. Hamiguitan TrekScan+ Conceptual Framework

## Overview
This conceptual framework illustrates the Input-Process-Output (IPO) model for the Mt. Hamiguitan TrekScan+ mobile application. The framework demonstrates how the system transforms user requirements, environmental data, and technological resources into a comprehensive ecotourism management solution that enhances trekker experiences while supporting conservation efforts at the Mt. Hamiguitan Range Wildlife Sanctuary.

---

## INPUT

### 👤 User Inputs

#### Trekker Information
- **Personal Data**: Full name, email, birthdate, gender
- **Authentication**: Google Sign-In credentials, biometric verification
- **Profile Media**: Profile photos, uploaded trek photos
- **Booking Documents**: Payment receipts, reservation confirmations
- **Trek Date**: Selected trekking date and group size

#### Trek Activity Data
- **QR Code Scans**: Station QR codes at designated eco-stations
- **Location Data**: GPS coordinates for navigation and geofencing
- **User Interactions**: Task completions, quiz responses, feedback
- **Social Content**: Photos, journal entries, experience sharing

### 🗄️ System Data

#### Static Data Resources
- **Station Database** (`assets/data/stations_test.json`)
  - 7 designated stations with metadata
  - GPS coordinates (latitude/longitude)
  - Educational content (flora, fauna, warnings)
  - Difficulty levels and elevation data
  - Next station information and distances

- **Achievement System** (`assets/data/badge.json`)
  - Achievement definitions with criteria
  - Rarity levels (Common, Uncommon, Rare, Epic, Legendary)
  - Categories: Trail completion, milestones, exploration, learning, community
  - Requirement types: Station-based, completion-based

#### Dynamic Data (Firebase)
- **User Profiles**: Account information, preferences, statistics
- **Bookings**: Reservation records, trek dates, verification status
- **Achievements**: Unlocked badges, progress tracking, timestamps
- **Social Data**: Posts, followers, following relationships
- **Notifications**: System alerts, booking updates, achievement unlocks

### 🌐 External Inputs

#### Third-Party Services
- **Google Maps API**: Offline navigation, elevation tracking
- **Firebase Services**: 
  - Authentication (Google Sign-In)
  - Firestore (Database)
  - Cloud Storage (Media files)
  - Cloud Functions (Backend logic)
  - Analytics
- **Device Hardware**: Camera (QR scanner), GPS, biometric sensors

#### Environmental Context
- **Mt. Hamiguitan Trail System**: 7 eco-stations along trekking routes
- **Conservation Requirements**: UNESCO World Heritage Site guidelines
- **Tourism Policies**: DOT and DENR regulations
- **Network Conditions**: Limited/no connectivity in remote areas

---

## PROCESS

### 🔐 Phase 1: User Authentication & Profile Management

#### Authentication Flow
```
1. Google Sign-In / Biometric Login
   ↓
2. Firebase Authentication validates credentials
   ↓
3. Retrieve/Create user profile in Firestore
   ↓
4. Load user-specific data (bookings, achievements, social)
   ↓
5. Initialize local storage for offline capability
```

**Services Involved:**
- `firebase_auth_service.dart`: Handles authentication
- `user_service.dart`: Manages user profiles
- `presence_service.dart`: Tracks online/offline status

### 📅 Phase 2: Booking & Pre-Trek Verification

#### Booking Creation Process
```
1. User selects trek date via calendar
   ↓
2. CalendarConfigService validates:
   - Buffer days (3-day advance booking minimum)
   - Daily capacity limits
   - Existing bookings on same date
   ↓
3. User uploads verification documents
   ↓
4. File upload to Firebase Storage
   ↓
5. BookingService creates booking record
   ↓
6. NotificationService sends confirmation
   ↓
7. Admin receives booking for approval
```

**Services Involved:**
- `booking_service.dart`: Manages booking lifecycle
- `calendar_config_service.dart`: Validates dates and capacity
- `notification_service.dart`: Sends alerts
- Firebase Storage: Stores documents

**Data Validation:**
- Duplicate booking check per user per date
- Buffer day enforcement (minimum 3 days in advance)
- Maximum capacity validation
- Document format verification

### 🚶 Phase 3: Trek Navigation & Station Interaction

#### Station Scanning & Verification Process
```
1. Trekker initiates QR scan
   ↓
2. Mobile Scanner captures QR code data
   ↓
3. GeofencingService validates location
   ↓
4. StationService verifies station ID
   ↓
5. Mark station as visited (local + Firebase)
   ↓
6. Achievement check triggered
   ↓
7. Display educational content
   ↓
8. Update trek progress
```

**Services Involved:**
- `geofencing_service.dart`: Location-based validation
- `station_service.dart`: Station data management
- `firestore_station_service.dart`: Syncs visited stations
- Mobile Scanner: QR code detection

**Geofencing Logic:**
- Radius-based validation (prevents remote scanning)
- GPS coordinate matching with station database
- Offline geofence validation capability

### 🏆 Phase 4: Achievement & Gamification

#### Achievement Unlock Process
```
1. Station marked as visited
   ↓
2. AchievementService.checkAndUnlockAchievements()
   ↓
3. Criteria evaluation:
   - Station count thresholds
   - Completion milestones
   - Special conditions
   ↓
4. If criteria met:
   a. Unlock achievement locally (SharedPreferences)
   b. Add to Firebase sync queue
   c. Add to pending notifications
   ↓
5. Display notification (dialog/banner)
   ↓
6. Sync to Firebase when online
   ↓
7. Update profile statistics
```

**Services Involved:**
- `achievement_service.dart`: Core achievement logic
- `local_achievement_service.dart`: Offline persistence
- `AchievementUnlockNotification`: UI components

**Offline-First Design:**
- Local unlock with SharedPreferences
- Sync queue for pending Firebase updates
- Notification queue survives app restarts
- Automatic sync when connectivity restored

### 📱 Phase 5: Social Sharing & Community

#### Social Interaction Process
```
1. User creates post with media
   ↓
2. Upload to Firebase Storage
   ↓
3. SocialSharingService creates post record
   ↓
4. Update user's post count
   ↓
5. Notify followers (if public)
   ↓
6. Display in social feed
```

**Services Involved:**
- `social_sharing_service.dart`: Post management
- Firebase Storage: Media hosting
- `notification_service.dart`: Social notifications

### 📜 Phase 6: Certificate Generation

#### E-Certificate Creation Process
```
1. Verify trek completion:
   - Minimum required stations visited
   - Booking status confirmed
   ↓
2. ECertificateService generates certificate
   ↓
3. CertificatePdfService creates PDF
   ↓
4. Store in Firebase Storage
   ↓
5. CertificateEmailService sends copy
   ↓
6. User can download/share
```

**Services Involved:**
- `e_certificate_service.dart`: Certificate logic
- `certificate_pdf_service.dart`: PDF generation
- `certificate_email_service.dart`: Email delivery

### 🔄 Phase 7: Data Synchronization & Offline Support

#### Sync Strategy
```
Online Mode:
- Real-time Firestore sync
- Immediate Firebase updates
- Live notifications

Offline Mode:
- Local SQLite database
- SharedPreferences for achievements
- Queue pending operations
- Offline maps pre-downloaded

Reconnection:
- Auto-detect connectivity (ConnectivityService)
- Process sync queue
- Upload pending data
- Download updates
```

**Services Involved:**
- `connectivity_service.dart`: Network monitoring
- SQLite: Local database
- SharedPreferences: Achievement persistence
- Firebase offline persistence

---

## OUTPUT

### 📱 Mobile Application Features

#### For Trekkers

**1. Navigation & Guidance**
- Offline GPS navigation with elevation tracking
- Real-time position on trail map
- Distance and progress indicators
- Difficulty level warnings

**2. Educational Experience**
- 7 location-verified eco-stations
- Interactive QR code content
- Flora and fauna information
- Conservation awareness materials
- Safety warnings and guidelines

**3. Achievement System**
- 15+ unlockable achievements
- 5 rarity tiers (Common to Legendary)
- Progress tracking and statistics
- Beautiful notification dialogs
- Profile achievement showcase

**4. Booking Management**
- Calendar-based booking interface
- Document upload for verification
- Booking status tracking
- Buffer day enforcement (3-day minimum)
- Capacity limit validation

**5. Social Features**
- Photo and story sharing
- Follower/following system
- Trek journal entries
- Community engagement
- Privacy controls

**6. E-Certificate**
- Automated certificate generation
- Personalized completion certificates
- PDF download capability
- Email delivery
- Social sharing

**7. User Profile**
- Personal information management
- Achievement statistics
- Booking history
- Social metrics (followers, posts)
- Settings and preferences

### 🖥️ Web Admin Dashboard

#### Administrative Tools

**1. Booking Management**
- View all booking requests
- Approve/reject reservations
- Verify uploaded documents
- Manage trek capacity
- Calendar configuration

**2. User Management**
- Monitor trekker accounts
- View user statistics
- Manage permissions
- Handle support requests

**3. Analytics & Reporting**
- Trek participation metrics
- Station visit analytics
- Achievement unlock rates
- Popular dates/seasons
- User engagement statistics

**4. Real-Time Monitoring**
- Active trekker sessions
- QR scan logs
- System health status
- Firebase usage metrics

### 📊 System Outputs

#### Data Products

**1. User Data**
- Verified user profiles with authentication history
- Complete trek history with timestamps
- Achievement progress records
- Social interaction metrics
- Booking transaction logs

**2. Analytics Data**
- Station visit frequency
- Peak trekking periods
- User retention rates
- Achievement unlock patterns
- Popular eco-stations

**3. Conservation Metrics**
- Total trekkers served
- Educational content engagement
- Environmental awareness impact
- Sustainable tourism indicators

#### Technical Deliverables

**1. Mobile Application**
- Flutter-based cross-platform app (Android/iOS)
- Offline-first architecture
- SQLite local database
- Firebase cloud integration
- Google Maps integration

**2. Backend Infrastructure**
- Firebase Authentication system
- Firestore NoSQL database
- Cloud Storage for media
- Cloud Functions for logic
- Firebase Analytics

**3. Documentation**
- User guides and tutorials
- API documentation
- System architecture diagrams
- Achievement setup guides
- Troubleshooting resources

---

## SYSTEM ARCHITECTURE DIAGRAM

```
┌─────────────────────────────────────────────────────────────┐
│                        INPUT LAYER                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Trekker → [Mobile App]                                    │
│             ↓                                               │
│  ├─ Authentication (Google/Biometric)                      │
│  ├─ Booking Documents                                      │
│  ├─ QR Code Scans                                          │
│  ├─ GPS Location                                           │
│  └─ Social Content                                         │
│                                                             │
│  Station Data ← [assets/data/stations_test.json]           │
│  Achievements ← [assets/data/badge.json]                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      PROCESS LAYER                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────┐          │
│  │        MOBILE APP SERVICES                   │          │
│  ├──────────────────────────────────────────────┤          │
│  │                                              │          │
│  │  Authentication & User Management            │          │
│  │  ├─ firebase_auth_service                   │          │
│  │  ├─ user_service                            │          │
│  │  └─ presence_service                        │          │
│  │                                              │          │
│  │  Booking & Calendar System                   │          │
│  │  ├─ booking_service                         │          │
│  │  ├─ calendar_config_service                 │          │
│  │  └─ notification_service                    │          │
│  │                                              │          │
│  │  Trek Navigation & Stations                  │          │
│  │  ├─ station_service                         │          │
│  │  ├─ firestore_station_service               │          │
│  │  ├─ geofencing_service                      │          │
│  │  └─ Mobile Scanner                          │          │
│  │                                              │          │
│  │  Achievement & Gamification                  │          │
│  │  ├─ achievement_service                     │          │
│  │  ├─ local_achievement_service               │          │
│  │  └─ SharedPreferences                       │          │
│  │                                              │          │
│  │  Social & Community                          │          │
│  │  ├─ social_sharing_service                  │          │
│  │  └─ Firebase Storage                        │          │
│  │                                              │          │
│  │  Certificate Generation                      │          │
│  │  ├─ e_certificate_service                   │          │
│  │  ├─ certificate_pdf_service                 │          │
│  │  └─ certificate_email_service               │          │
│  │                                              │          │
│  │  Offline & Connectivity                      │          │
│  │  ├─ connectivity_service                    │          │
│  │  ├─ SQLite Database                         │          │
│  │  └─ Sync Queue Manager                      │          │
│  │                                              │          │
│  └──────────────────────────────────────────────┘          │
│                         ↕                                   │
│  ┌──────────────────────────────────────────────┐          │
│  │         FIREBASE BACKEND                     │          │
│  ├──────────────────────────────────────────────┤          │
│  │                                              │          │
│  │  → Authentication: User login/security       │          │
│  │  → Firestore: NoSQL database                │          │
│  │  → Cloud Storage: Media/documents            │          │
│  │  → Cloud Functions: Server logic             │          │
│  │  → Analytics: Usage tracking                 │          │
│  │  → FCM: Push notifications                   │          │
│  │                                              │          │
│  └──────────────────────────────────────────────┘          │
│                         ↕                                   │
│  ┌──────────────────────────────────────────────┐          │
│  │       EXTERNAL SERVICES                      │          │
│  ├──────────────────────────────────────────────┤          │
│  │                                              │          │
│  │  → Google Maps API (Navigation)              │          │
│  │  → Google Sign-In (OAuth)                    │          │
│  │  → Device GPS & Camera                       │          │
│  │                                              │          │
│  └──────────────────────────────────────────────┘          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       OUTPUT LAYER                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  FOR TREKKERS:                                             │
│  ├─ ✓ Offline GPS navigation                              │
│  ├─ ✓ Educational eco-station content                     │
│  ├─ ✓ Unlocked achievements & badges                      │
│  ├─ ✓ Verified booking confirmations                      │
│  ├─ ✓ Digital completion certificates                     │
│  ├─ ✓ Social sharing capabilities                         │
│  └─ ✓ Trek progress tracking                              │
│                                                             │
│  FOR ADMINISTRATORS:                                        │
│  ├─ ✓ Booking approval system                             │
│  ├─ ✓ User management dashboard                           │
│  ├─ ✓ Analytics & usage reports                           │
│  ├─ ✓ Real-time activity monitoring                       │
│  └─ ✓ System health metrics                               │
│                                                             │
│  DATA OUTPUTS:                                             │
│  ├─ User profiles & trek histories                        │
│  ├─ Station visit analytics                               │
│  ├─ Achievement statistics                                │
│  ├─ Conservation impact metrics                           │
│  └─ Tourism pattern insights                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## KEY WORKFLOWS

### Workflow 1: Complete Trek Journey
```
[Register/Login] → [Book Trek Date] → [Upload Documents] 
      ↓
[Admin Approval] → [Download Offline Maps] → [Start Trek]
      ↓
[Scan Station 1] → [Geofence Validate] → [View Content] → [Unlock Achievement]
      ↓
[Scan Station 2-7] → [Complete Trek] → [Generate Certificate]
      ↓
[Share Experience] → [View Profile Stats] → [Plan Next Trek]
```

### Workflow 2: Achievement Unlock Flow
```
[Scan QR Code] → [Verify Location] → [Mark Station Visited]
      ↓
[Check Achievement Criteria] → [Criteria Met?]
      ↓ YES                            ↓ NO
[Unlock Locally]              [Continue Trek]
      ↓
[Add to Sync Queue] → [Show Notification]
      ↓
[Sync to Firebase when online] → [Update Profile]
```

### Workflow 3: Offline-to-Online Sync
```
[Offline Actions]
├─ Station scans saved locally
├─ Achievements unlocked in SharedPreferences  
├─ Photos cached locally
└─ Operations queued
      ↓
[Connectivity Restored]
      ↓
[Sync Queue Processes]
├─ Upload station visits to Firestore
├─ Sync achievements to user.badges
├─ Upload cached media to Storage
└─ Download new notifications
      ↓
[Local & Cloud Synchronized]
```

---

## TECHNOLOGY STACK MAPPING

| **Component**          | **Technology**              | **Purpose**                          |
|------------------------|----------------------------|--------------------------------------|
| Mobile Framework       | Flutter + Dart             | Cross-platform development           |
| Local Database         | SQLite                     | Offline data storage                 |
| Achievement Storage    | SharedPreferences          | Lightweight offline persistence      |
| Backend                | Firebase Suite             | Authentication, database, storage    |
| Maps & Navigation      | Google Maps API            | GPS navigation & elevation           |
| QR Scanning            | Mobile Scanner             | Station verification                 |
| Authentication         | Firebase Auth + Google     | Secure user login                    |
| Cloud Database         | Firestore (NoSQL)          | Real-time synchronized data          |
| File Storage           | Firebase Cloud Storage     | Media and documents                  |
| Push Notifications     | Firebase Cloud Messaging   | User alerts                          |
| Analytics              | Firebase Analytics         | Usage tracking                       |
| Admin Dashboard        | React.js + Node.js         | Web-based management                 |
| Version Control        | GitHub                     | Code management                      |

---

## ALIGNMENT WITH PROJECT OBJECTIVES

### Primary Objectives Achieved

1. **Enhanced Trekker Experience**
   - Input: GPS data, station scans, user preferences
   - Process: Navigation service, geofencing, achievement system
   - Output: Seamless offline navigation, gamified learning

2. **Conservation Education**
   - Input: Educational content (flora, fauna, warnings)
   - Process: QR-triggered content delivery at stations
   - Output: Increased environmental awareness

3. **Efficient Booking Management**
   - Input: Trek dates, payment documents, user information
   - Process: Validation, buffer day check, capacity management
   - Output: Streamlined pre-trek verification

4. **Data-Driven Decision Making**
   - Input: User interactions, station visits, booking patterns
   - Process: Firebase analytics, aggregation
   - Output: Administrative insights, tourism optimization

5. **Sustainable Tourism Support**
   - Input: Capacity limits, UNESCO guidelines, DENR policies
   - Process: Automated enforcement through calendar config
   - Output: Controlled visitor flow, protected ecosystem

---

## CONCLUSION

The Mt. Hamiguitan TrekScan+ conceptual framework demonstrates a comprehensive Input-Process-Output flow that transforms raw trekker data, environmental information, and technological infrastructure into a robust ecotourism management system. By leveraging Firebase cloud services, offline-first architecture, and gamification principles, the system addresses the limitations of the original TrekScanApp while supporting the conservation goals of the Mt. Hamiguitan Range Wildlife Sanctuary, a UNESCO World Heritage Site.

The framework ensures that every input—from user authentication to QR code scans—is processed through well-defined services and workflows, ultimately producing meaningful outputs that enhance both the trekker experience and administrative oversight.