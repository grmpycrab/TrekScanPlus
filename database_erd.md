# Mt. Hamiguitan TrekScan+ Database ERD

## Overview
This Entity-Relationship Diagram (ERD) illustrates the database structure for the Mt. Hamiguitan TrekScan+ application using Firebase Firestore (NoSQL database). The diagram shows all collections, their attributes, data types, relationships, and cardinality.

---

## Database Type
**Firebase Firestore** - NoSQL Cloud Database
- Document-oriented database
- Hierarchical structure with collections and documents
- Supports subcollections for nested data
- Real-time synchronization capabilities
- Offline persistence support

---

## Collections & Entities

### 1. USERS Collection
**Path:** `/users/{userId}`

**Purpose:** Stores user profile information, authentication data, and social metrics

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **userId (PK)** | String | Required, Unique | Firebase Auth UID |
| firstName | String | Optional | User's first name |
| lastName | String | Optional | User's last name |
| email | String | Required, Unique | User's email address |
| birthDate | String | Required | Date of birth (YYYY-MM-DD) |
| gender | String | Required | Gender identity |
| profileImage | String | Optional | Firebase Storage URL |
| badges | Array\<String\> | Default: [] | Array of unlocked achievement IDs |
| followingCount | Number | Default: 0 | Count of users being followed |
| followersCount | Number | Default: 0 | Count of followers |
| postsCount | Number | Default: 0 | Total posts created |
| pendingFollowRequests | Array\<String\> | Default: [] | Array of user IDs who sent follow requests |
| sentFollowRequests | Array\<String\> | Default: [] | Array of user IDs to whom follow requests were sent |

**Relationships:**
- 1:N with BOOKINGS (one user has many bookings)
- 1:N with POSTS (one user creates many posts)
- 1:N with COMMENTS (one user writes many comments)
- 1:N with REPLIES (one user writes many replies)
- M:N with USERS (followers/following - self-referential)
- 1:N with NOTIFICATIONS (one user receives many notifications)
- 1:N with VISITED_STATIONS (one user visits many stations)
- 1:N with ACHIEVEMENTS (one user unlocks many achievements)
- 1:N with CERTIFICATES (one user earns many certificates)
- 1:N with BOOKMARKS (one user bookmarks many posts)

---

### 2. BOOKINGS Collection
**Path:** `/bookings/{bookingId}`

**Purpose:** Group booking container for multiple trek participants. Represents one booking session containing one or more members.

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **bookingId (PK)** | String | Auto-generated | Firestore document ID |
| **userId (FK)** | String | Required | Reference to authenticated user (primary contact/booker only) |
| bookingType | String | Required | Trek category selected by booker |
| affiliation | String | Required | Organization/school affiliation |
| trekDate | Timestamp | Required | Scheduled trek date |
| hometown | String | Optional | Primary contact's hometown/city |
| notes | String | Optional | Special requests/notes |
| adminNotes | String | Optional | Admin comments on booking |
| primaryContact | Object | Required | Auto-filled from USERS collection |
| totalMembers | Number | Auto-calculated | Total participants in this booking (from members subcollection) |
| status | String | Default: "pending" | "pending", "approved", "declined", "cancelled" |
| createdAt | Timestamp | Auto-generated | Booking creation timestamp |
| updatedAt | Timestamp | Auto-updated | Last modification timestamp |

**bookingType Values:**
- "special_trekking" - Special trekking category
- "benchmarking_trek" - Benchmarking trek
- "research_trek" - Research trek
- "regular_trek" - Regular recreational trek

**primaryContact Object Structure:**
```json
{
  "userId": "String - Firebase Auth UID",
  "firstName": "String - User's first name",
  "lastName": "String - User's last name",
  "email": "String - User's email",
  "phoneNumber": "String - User's phone",
  "birthDate": "String - YYYY-MM-DD format",
  "gender": "String - User's gender"
}
```

**Relationships:**
- N:1 with USERS (many bookings belong to one authenticated user)
- 1:N with MEMBERS (one booking contains many members - subcollection)
- 1:1 with CALENDAR_CONFIG (booking date references calendar config)

---

### 2.1 MEMBERS Subcollection (New)
**Path:** `/bookings/{bookingId}/members/{memberId}`

**Purpose:** Stores individual participant information for a booking. Each person in the group (including the primary contact) has their own member record. All data entered by the authenticated user.

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **memberId (PK)** | String | Auto-generated | Firestore document ID |
| **bookingId (FK)** | String | Required | Reference to parent booking |
| **userId (FK)** | String or null | Optional | Firebase Auth UID if member has account; null for non-account members |
| lastName | String | Required | Member's last name |
| firstName | String | Required | Member's first name |
| middleName | String | Optional | Member's middle name |
| suffix | String | Optional | Name suffix (e.g., "Jr.", "Sr.") |
| gender | String | Required | "male", "female", or "other" |
| birthDate | String | Required | Date of birth (YYYY-MM-DD format) |
| contactNumber | String | Required | Member's contact phone number |
| facebookAccount | String | Optional | Member's Facebook account/URL |
| nationality | String | Required | Member's nationality |
| homeAddress | String | Required | Member's home address |
| category | String | Required | Participant category |
| isPrimaryContact | Boolean | Default: false | true if member is the booking creator |
| hasAccount | Boolean | Default: false | true if member has Firebase account; false if added as guest |
| fileRequirements | Object | Required | Dynamic category-specific file requirements |
| attachments | Array\<Attachment\> | Default: [] | Category-specific uploaded documents |
| memberStatus | String | Default: "pending" | "pending", "incomplete", "complete", "verified", "rejected" |
| createdAt | Timestamp | Auto-generated | Member record creation timestamp |
| updatedAt | Timestamp | Auto-updated | Last modification timestamp |

**category Values:**
- "student" - Student participant
- "senior_citizen" - Senior citizen (60+ years old)
- "davao_oriental_resident" - Davao Oriental resident
- "ocfdo" - OCFDO member
- "outside_davao_oriental" - Outside Davao Oriental resident
- "children_8_15" - Children aged 8-15 years
- "mfsm" - MFSM member

**fileRequirements Object Structure:**
```json
{
  "requiredFiles": [
    "Array of required file type identifiers based on selected category"
  ]
}
```

**Attachment Object Structure:**
```json
{
  "storagePath": "String - Firebase Storage path",
  "downloadURL": "String - Public download URL",
  "fileName": "String - Original file name",
  "mimeType": "String - File MIME type",
  "size": "Number - File size in bytes",
  "uploadedAt": "Timestamp - Upload timestamp",
  "uploadedBy": "String - User ID of uploader (always primary contact)"
}
```

**Relationships:**
- N:1 with BOOKINGS (many members belong to one booking)
- N:1 with USERS (member references user if hasAccount=true)

### 3. POSTS Collection
**Path:** `/posts/{postId}`

**Purpose:** Social media posts shared by trekkers

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **postId (PK)** | String | Auto-generated | Firestore document ID |
| **userId (FK)** | String | Required | Reference to users collection |
| userName | String | Required | Display name of post author |
| userPhotoUrl | String | Optional | Author's profile photo URL |
| userRole | String | Optional | User's role/title (e.g., "Trekker") |
| caption | String | Required | Post caption/description |
| imageUrls | Array\<String\> | Max: 4 | Array of image URLs (Firebase Storage) |
| privacy | String | Default: "public" | "public", "followers", "private" |
| likesCount | Number | Default: 0 | Total likes count |
| commentsCount | Number | Default: 0 | Total comments count |
| sharesCount | Number | Default: 0 | Total shares count |
| isBookmarked | Boolean | Default: false | Bookmark status |
| createdAt | Timestamp | Auto-generated | Post creation timestamp |
| updatedAt | Timestamp | Auto-updated | Last modification timestamp |

**Relationships:**
- N:1 with USERS (many posts belong to one user)
- 1:N with COMMENTS (one post has many comments)
- 1:N with LIKES (one post has many likes)
- 1:N with BOOKMARKS (one post can be bookmarked by many users)

---

### 4. COMMENTS Subcollection
**Path:** `/posts/{postId}/comments/{commentId}`

**Purpose:** User comments on social posts

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **commentId (PK)** | String | Auto-generated | Firestore document ID |
| **postId (FK)** | String | Required | Reference to parent post |
| **userId (FK)** | String | Required | Reference to users collection |
| userName | String | Required | Display name of commenter |
| userPhotoUrl | String | Optional | Commenter's profile photo URL |
| text | String | Required | Comment text content |
| likesCount | Number | Default: 0 | Total likes on comment |
| repliesCount | Number | Default: 0 | Total replies to comment |
| createdAt | Timestamp | Auto-generated | Comment creation timestamp |

**Relationships:**
- N:1 with POSTS (many comments belong to one post)
- N:1 with USERS (many comments written by one user)
- 1:N with REPLIES (one comment has many replies)
- 1:N with LIKES (one comment has many likes)

---

### 5. REPLIES Subcollection
**Path:** `/posts/{postId}/comments/{commentId}/replies/{replyId}`

**Purpose:** Nested replies to comments

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **replyId (PK)** | String | Auto-generated | Firestore document ID |
| **postId (FK)** | String | Required | Reference to parent post |
| **commentId (FK)** | String | Required | Reference to parent comment |
| **userId (FK)** | String | Required | Reference to users collection |
| userName | String | Required | Display name of replier |
| userPhotoUrl | String | Optional | Replier's profile photo URL |
| text | String | Required | Reply text content |
| likesCount | Number | Default: 0 | Total likes on reply |
| createdAt | Timestamp | Auto-generated | Reply creation timestamp |

**Relationships:**
- N:1 with COMMENTS (many replies belong to one comment)
- N:1 with USERS (many replies written by one user)
- 1:N with LIKES (one reply has many likes)

---

### 6. LIKES Subcollections
**Paths:** 
- `/posts/{postId}/likes/{likeId}`
- `/posts/{postId}/comments/{commentId}/likes/{likeId}`
- `/posts/{postId}/comments/{commentId}/replies/{replyId}/likes/{likeId}`

**Purpose:** Track likes on posts, comments, and replies

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **likeId (PK)** | String | userId | User ID (serves as document ID) |
| **userId (FK)** | String | Required | Reference to users collection |
| createdAt | Timestamp | Auto-generated | Like timestamp |

**Relationships:**
- N:1 with POSTS/COMMENTS/REPLIES (many likes on one item)
- N:1 with USERS (many likes by one user)

---

### 7. NOTIFICATIONS Subcollection
**Path:** `/users/{userId}/notifications/{notificationId}`

**Purpose:** User-specific notifications for bookings, achievements, social interactions

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **notificationId (PK)** | String | Auto-generated | Firestore document ID |
| **userId (FK)** | String | Required | Reference to parent user |
| title | String | Required | Notification title |
| message | String | Required | Notification message |
| type | String | Required | "success", "warning", "info", "alert" |
| timestamp | Timestamp | Auto-generated | Notification creation time |
| isRead | Boolean | Default: false | Read status |
| actionType | String | Optional | "post", "booking", "achievement", "follow_request" |
| actionData | String | Optional | Related entity ID (postId, bookingId, etc.) |
| showActionButtons | Boolean | Default: false | Display action buttons flag |
| followRequestId | String | Optional | User ID for follow requests |

**Relationships:**
- N:1 with USERS (many notifications belong to one user)

---

### 8. VISITED_STATIONS Subcollection
**Path:** `/users/{userId}/visitedStations/{stationId}`

**Purpose:** Track which stations a user has visited during treks

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **stationId (PK)** | String | Required | Station identifier (matches QR code) |
| **userId (FK)** | String | Required | Reference to parent user |
| stationName | String | Required | Name of the station |
| visitedAt | Timestamp | Auto-generated | Visit timestamp |
| latitude | Number | Optional | GPS latitude at scan |
| longitude | Number | Optional | GPS longitude at scan |
| isGeofenced | Boolean | Default: true | Location verified flag |

**Relationships:**
- N:1 with USERS (many station visits by one user)
- N:1 with STATIONS (reference to static station data)

---

### 9. ACHIEVEMENTS Subcollection
**Path:** `/users/{userId}/achievements/{achievementId}`

**Purpose:** Store user-specific achievement unlock data (synced from local)

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **achievementId (PK)** | String | Required | Achievement identifier |
| **userId (FK)** | String | Required | Reference to parent user |
| id | String | Required | Achievement ID (from badge.json) |
| name | String | Required | Achievement name |
| description | String | Required | Achievement description |
| category | String | Required | Achievement category |
| icon | String | Required | Icon identifier |
| requirement | Object | Required | Unlock criteria definition |
| rarity | String | Required | "common", "uncommon", "rare", "epic", "legendary" |
| difficulty | String | Required | "easy", "medium", "hard" |
| isUnlocked | Boolean | Default: true | Unlock status (always true in this collection) |
| unlockedAt | Timestamp | Required | Unlock timestamp |
| isNotificationShown | Boolean | Default: false | Notification display status |

**Relationships:**
- N:1 with USERS (many achievements unlocked by one user)
- Reference to static achievement data in `assets/data/badge.json`

---

### 10. CERTIFICATES Subcollection
**Path:** `/users/{userId}/certificates/{certificateId}`

**Purpose:** E-certificates earned by trekkers upon completion

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **certificateId (PK)** | String | Auto-generated | Firestore document ID |
| **userId (FK)** | String | Required | Reference to parent user |
| trekkerName | String | Required | Full name of trekker |
| certificateType | String | Required | "camp3", "fullTrek", "peakConqueror" |
| dateEarned | Timestamp | Required | Certificate issue date |
| stationsVisited | Number | Required | Total stations completed |
| totalDistance | Number | Required | Total distance trekked (km) |
| totalTimeMinutes | Number | Required | Total trek duration (minutes) |
| trekStartDate | Timestamp | Optional | Trek start timestamp |
| trekEndDate | Timestamp | Optional | Trek end timestamp |
| isVerified | Boolean | Default: true | Verification status |
| verificationCode | String | Required, Unique | Unique verification code |
| createdAt | Timestamp | Auto-generated | Certificate creation timestamp |
| lastUpdated | Timestamp | Auto-updated | Last modification timestamp |

**Certificate Types:**
- **camp3**: Reached Station 8 (Camp 3)
- **fullTrek**: Visited all stations
- **peakConqueror**: Reached Station 14 (Peak)

**Relationships:**
- N:1 with USERS (many certificates earned by one user)

---

### 11. BOOKMARKS Subcollection
**Path:** `/users/{userId}/bookmarks/{bookmarkId}`

**Purpose:** User's saved/bookmarked posts

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **bookmarkId (PK)** | String | postId | Post ID (serves as document ID) |
| **userId (FK)** | String | Required | Reference to parent user |
| **postId (FK)** | String | Required | Reference to posts collection |
| createdAt | Timestamp | Auto-generated | Bookmark timestamp |

**Relationships:**
- N:1 with USERS (many bookmarks belong to one user)
- N:1 with POSTS (many bookmarks reference one post)

---

### 12. FILE_REQUIREMENTS Reference Document (New)
**Path:** `/system_settings/file_requirements`

**Purpose:** Global configuration defining category-specific file requirements for member verification. Updated by admins, read by app for dynamic form rendering.

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| student | Object | Required | Requirements for student participants |
| senior_citizen | Object | Required | Requirements for senior citizens |
| davao_oriental_resident | Object | Required | Requirements for Davao Oriental residents |
| ocfdo | Object | Required | Requirements for OCFDO members |
| outside_davao_oriental | Object | Required | Requirements for outside residents |
| children_8_15 | Object | Required | Requirements for children (8-15 years) |
| mfsm | Object | Required | Requirements for MFSM members |
| lastUpdated | Timestamp | Auto-updated | Last modification timestamp |

**Category Object Structure:**
```json
{
  "files": [
    "Array of required file type identifiers (e.g., 'school_id', 'birth_certificate')"
  ],
  "description": "String - Human-readable description"
}
```

**Example Structure:**
```json
{
  "student": {
    "files": ["school_id", "school_clearance", "birth_certificate", "valid_id"],
    "description": "Requirements for student participants"
  },
  "senior_citizen": {
    "files": ["senior_id", "birth_certificate", "valid_id", "medical_clearance"],
    "description": "Requirements for senior citizens"
  },
  "davao_oriental_resident": {
    "files": ["proof_of_residency", "valid_id", "birth_certificate"],
    "description": "Requirements for Davao Oriental residents"
  },
  "ocfdo": {
    "files": ["ocfdo_certificate", "valid_id", "birth_certificate"],
    "description": "Requirements for OCFDO members"
  },
  "outside_davao_oriental": {
    "files": ["valid_id", "birth_certificate", "proof_of_travel"],
    "description": "Requirements for outside residents"
  },
  "children_8_15": {
    "files": ["birth_certificate", "parental_consent", "medical_clearance", "school_id"],
    "description": "Requirements for children (8-15 years)"
  },
  "mfsm": {
    "files": ["mfsm_certificate", "valid_id", "birth_certificate"],
    "description": "Requirements for MFSM members"
  }
}
```

**Access Control:**
- Read: Public (used by app for form rendering)
- Write: Admin only

---

### 13. SYSTEM_SETTINGS Collection
**Path:** `/system_settings/{settingId}`

**Purpose:** Global system configuration settings

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **settingId (PK)** | String | Required | Setting identifier |
| bufferDays | Number | Default: 3 | Minimum days required before trek date |
| maxDailyCapacity | Number | Default: 30 | Maximum bookings per day |
| isSystemActive | Boolean | Default: true | System operational status |
| lastUpdated | Timestamp | Auto-updated | Last modification timestamp |

**Access Control:**
- Read: Public
- Write: Admin only

---

### 14. CALENDAR_CONFIG Collection
**Path:** `/calendar_config/{dateKey}`

**Purpose:** Date-specific booking configuration (capacity, closures)

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **dateKey (PK)** | String | Required | Date in YYYY-MM-DD format |
| date | Timestamp | Required | Actual date timestamp |
| isClosed | Boolean | Default: false | Date availability status |
| maxSlots | Number | Range: 0-45 | Maximum bookings for this date |
| currentBookings | Number | Default: 0 | Current booking count |
| lastUpdated | Timestamp | Auto-updated | Last modification timestamp |
| notes | String | Optional | Admin notes for the date |

**Constraints:**
- maxSlots must be between 0-45
- Normal max: 30, special events up to 45

**Access Control:**
- Read: Public
- Write: Admin only

**Relationships:**
- 1:N with BOOKINGS (one date config referenced by many bookings)

---

### 15. CLIMBS Subcollection (New)
**Path:** `/users/{userId}/climbs/{climbId}`

**Purpose:** Track individual trek/climb sessions. Users can have multiple climbs over time. Each climb is a separate trek instance with its own station visits and duration tracking.

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **climbId (PK)** | String | Auto-generated | Firestore document ID |
| **userId (FK)** | String | Required | Reference to parent user |
| climbName | String | Optional | User-given name for this climb (e.g., "January 2026 Summit Attempt") |
| description | String | Optional | User notes/details about this climb (e.g., "Weather was great, many photo ops") |
| trekType | String | Required | Trek classification: "special_trek", "benchmarking_trek", "research_trek", "regular_trek" |
| trekStartDate | Timestamp | Required | Planned/scheduled trek start date |
| trekEndDate | Timestamp | Optional | Planned/scheduled trek end date (usually 3 days after start for normal trek) |
| startDate | Timestamp | Required | Trek/climb session actual start timestamp (when first station is scanned) |
| endDate | Timestamp | Optional | Trek/climb session actual end timestamp (null if in-progress) |
| status | String | Default: "in_progress" | "in_progress", "completed", "abandoned" |
| totalDuration | Number | Optional | Total trek duration in minutes |
| highestStationReached | Number | Default: 0 | Highest station number visited in this climb (1-14) |
| stationsVisited | Array\<Number\> | Default: [] | Array of station numbers visited [1, 3, 5, 8, ...] |
| totalDistance | Number | Optional | Total distance covered (km) |
| createdAt | Timestamp | Auto-generated | Climb record creation timestamp |
| updatedAt | Timestamp | Auto-updated | Last modification timestamp |

**trekType Values:**
- "special_trek" - Special trekking category
- "benchmarking_trek" - Benchmarking trek
- "research_trek" - Research trek
- "regular_trek" - Regular recreational trek (default)

**status Values:**
- "in_progress" - Currently active trek session
- "completed" - Trek finished (endDate set)
- "abandoned" - Trek stopped before completion

**Relationships:**
- N:1 with USERS (many climbs belong to one user)
- 1:N with CLIMB_STATIONS (one climb has many station visits - subcollection)

---

### 15.1 CLIMB_STATIONS Subcollection (New)
**Path:** `/users/{userId}/climbs/{climbId}/stations/{climbStationId}`

**Purpose:** Individual station tracking within a specific climb/trek session. Records when user visits each station during this climb.

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **climbStationId (PK)** | String | Auto-generated | Firestore document ID |
| **climbId (FK)** | String | Required | Reference to parent climb |
| **stationId** | Number | Required | Station number (1-14) |
| stationName | String | Required | Station name (e.g., "Station 1: Base Camp") |
| visitedAt | Timestamp | Required | When station was visited/scanned |
| durationFromPrevious | Number | Optional | Minutes since previous station visit |
| latitude | Number | Optional | GPS latitude at scan |
| longitude | Number | Optional | GPS longitude at scan |
| isGeofenced | Boolean | Default: true | Location verified flag |
| isCheckpoint | Boolean | Default: false | true = major checkpoint (1, 5, 8, 11, 14) |
| order | Number | Required | Visit order in this climb (1st, 2nd, 3rd station visited) |

**Relationships:**
- N:1 with CLIMBS (many station visits in one climb)
- Reference to static station data (stations_test.json)

---

## Data Model Diagram (NoSQL - Firestore)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          USERS (Main Collection)                            │
├─────────────────────────────────────────────────────────────────────────────┤
│ PK: userId (String)                                                         │
│ • firstName, lastName, email, birthDate, gender                             │
│ • profileImage, badges[], followingCount, followersCount, postsCount        │
│ • pendingFollowRequests[], sentFollowRequests[]                             │
└─────────────────────────────────────────────────────────────────────────────┘
      │                                                                    
      │ 1:N                                                                
      ├──────────────────────────────────────────────────────────────┐    
      │                                                              │    
      ▼                                                              ▼    
┌──────────────────────────────────────┐              ┌──────────────────────────┐
│  BOOKINGS (Group Booking) ★ UPDATED  │              │  POSTS (Top-level)       │
├──────────────────────────────────────┤              ├──────────────────────────┤
│ PK: bookingId                        │              │ PK: postId               │
│ FK: userId (booker only)             │              │ FK: userId               │
│ • bookingType                        │              │ • caption, imageUrls[]   │
│ • primaryContact {object}            │              │ • privacy, likesCount    │
│ • affiliation, trekDate              │              │ • commentsCount          │
│ • hometown, notes                    │              │ • createdAt, updatedAt   │
│ • totalMembers (calculated)          │              └──────────────────────────┘
│ • status, createdAt, updatedAt       │                       │
└──────────────────────────────────────┘                       │ 1:N
      │                                                         │
      │ 1:N (contains multiple members) ★ NEW                  ▼
      ▼                                  ┌───────────────────────────────────┐
┌──────────────────────────────────────┐ │  COMMENTS (Subcollection)         │
│  MEMBERS (Subcollection) ★ NEW       │ ├───────────────────────────────────┤
├──────────────────────────────────────┤ │ PK: commentId                     │
│ PK: memberId                         │ │ FK: postId, userId                │
│ FK: bookingId, userId (nullable)     │ │ • userName, userPhotoUrl          │
│ • firstName, lastName, middleName    │ │ • text, likesCount, repliesCount  │
│ • gender, birthDate, category        │ │ • createdAt                       │
│ • isPrimaryContact                   │ └───────────────────────────────────┘
│ • hasAccount (Boolean) ★ NEW         │           │
│ • fileRequirements {}                │           │ 1:N
│ • attachments[]                      │           ▼
│ • memberStatus, createdAt, updatedAt │ ┌───────────────────────────────────┐
└──────────────────────────────────────┘ │  REPLIES (Nested Subcollection)   │
                                          ├───────────────────────────────────┤
                                          │ PK: replyId                       │
                                          │ FK: postId, commentId, userId     │
                                          │ • userName, userPhotoUrl          │
                                          │ • text, likesCount, createdAt     │
                                          └───────────────────────────────────┘


┌────────────────────────────────┐         ┌───────────────────────────────────┐
│  CALENDAR_CONFIG (Top-level)   │         │ FILE_REQUIREMENTS ★ NEW (Ref)     │
├────────────────────────────────┤         ├───────────────────────────────────┤
│ PK: dateKey (YYYY-MM-DD)       │         │ Path: /system_settings            │
│ • date, isClosed               │         │ • student {}                      │
│ • maxSlots, currentBookings    │         │ • senior_citizen {}               │
│ • lastUpdated, notes           │         │ • davao_oriental_resident {}      │
└────────────────────────────────┘         │ • ocfdo {}                        │
                                           │ • outside_davao_oriental {}       │
                                           │ • children_8_15 {}                │
                                           │ • mfsm {}                         │
                                           │ (For dynamic member file setup)   │
                                           └───────────────────────────────────┘
```

---

## USER SUBCOLLECTIONS (Nested in /users/{userId})

```
    │ FK: userId                  │             │ FK: userId               │
    │ • title, message, type      │             │ • stationName, visitedAt │
    │ • timestamp, isRead         │             │ • latitude, longitude    │
    │ • actionType, actionData    │             │ • isGeofenced            │
    │ • followRequestId           │             └──────────────────────────┘
    └─────────────────────────────┘             

    /users/{userId}/achievements                /users/{userId}/certificates
    ┌─────────────────────────────┐             ┌──────────────────────────┐
    │ ACHIEVEMENTS                │             │ CERTIFICATES             │
    ├─────────────────────────────┤             ├──────────────────────────┤
    │ PK: achievementId           │             │ PK: certificateId        │
    │ FK: userId                  │             │ FK: userId               │
    │ • name, description         │             │ • trekkerName            │
    │ • category, icon, rarity    │             │ • certificateType        │
    │ • difficulty, requirement   │             │ • dateEarned             │
    │ • unlockedAt                │             │ • stationsVisited        │
    │ • isNotificationShown       │             │ • totalDistance          │
    └─────────────────────────────┘             │ • verificationCode       │
                                                 └──────────────────────────┘

    /users/{userId}/bookmarks
    ┌─────────────────────────────┐
    │ BOOKMARKS                   │
    ├─────────────────────────────┤
    │ PK: bookmarkId (postId)     │
    │ FK: userId, postId          │
    │ • createdAt                 │
    └─────────────────────────────┘

    /users/{userId}/climbs ★ NEW                /users/{userId}/climbs/{climbId}/stations ★ NEW
    ┌─────────────────────────────┐             ┌──────────────────────────┐
    │ CLIMBS                      │             │ CLIMB_STATIONS           │
    ├─────────────────────────────┤             ├──────────────────────────┤
    │ PK: climbId                 │             │ PK: climbStationId       │
    │ FK: userId                  │             │ FK: climbId              │
    │ • climbName, description ★  │             │ • stationId, stationName │
    │ • trekType ★ NEW            │             │ • visitedAt              │
    │ • trekStartDate ★ NEW       │             │ • durationFromPrevious   │
    │ • trekEndDate ★ NEW         │             │ • latitude, longitude    │
    │ • startDate, endDate        │             │ • isGeofenced            │
    │ • status (in progress...)   │             │ • isCheckpoint, order    │
    │ • stationsVisited []        │             └──────────────────────────┘
    │ • highestStationReached     │
    │ • totalDuration, totalDist  │
    └─────────────────────────────┘
              ▲                                            ▲
              │                                            │
              └────────────────────────────────────────────┘
              1:N (one climb contains many station visits)


┌──────────────────────────────────────────────────────────────────────────┐
│                   LIKES SUBCOLLECTIONS (Nested Structure)                 │
└──────────────────────────────────────────────────────────────────────────┘

    /posts/{postId}/likes/{likeId}
    ┌─────────────────────────────┐
    │ LIKES (on Posts)            │
    ├─────────────────────────────┤
    │ PK: likeId (userId)         │
    │ FK: userId, postId          │
    │ • createdAt                 │
    └─────────────────────────────┘

    /posts/{postId}/comments/{commentId}/likes/{likeId}
    ┌─────────────────────────────┐
    │ LIKES (on Comments)         │
    ├─────────────────────────────┤
    │ PK: likeId (userId)         │
    │ FK: userId, commentId       │
    │ • createdAt                 │
    └─────────────────────────────┘

    /posts/{postId}/comments/{commentId}/replies/{replyId}/likes/{likeId}
    ┌─────────────────────────────┐
    │ LIKES (on Replies)          │
    ├─────────────────────────────┤
    │ PK: likeId (userId)         │
    │ FK: userId, replyId         │
    │ • createdAt                 │
    └─────────────────────────────┘
```

---

## Relationship Cardinality Summary

| Parent Entity | Relationship | Child Entity | Cardinality |
|--------------|--------------|--------------|-------------|
| USERS | creates | BOOKINGS | 1:N |
| BOOKINGS | contains | MEMBERS | 1:N ★ NEW |
| USERS | creates | POSTS | 1:N |
| USERS | writes | COMMENTS | 1:N |
| USERS | writes | REPLIES | 1:N |
| USERS | receives | NOTIFICATIONS | 1:N |
| USERS | visits | VISITED_STATIONS | 1:N |
| USERS | has | CLIMBS | 1:N ★ NEW |
| CLIMBS | contains | CLIMB_STATIONS | 1:N ★ NEW |
| USERS | unlocks | ACHIEVEMENTS | 1:N |
| USERS | earns | CERTIFICATES | 1:N |
| USERS | saves | BOOKMARKS | 1:N |
| USERS | follows/followed by | USERS | M:N (self-referential) |
| POSTS | has | COMMENTS | 1:N |
| POSTS | has | LIKES | 1:N |
| POSTS | bookmarked in | BOOKMARKS | 1:N |
| COMMENTS | has | REPLIES | 1:N |
| COMMENTS | has | LIKES | 1:N |
| REPLIES | has | LIKES | 1:N |
| CALENDAR_CONFIG | referenced by | BOOKINGS | 1:N |

---

## Key Constraints & Validations

### 1. USERS Collection
- `email` must be unique
- `userId` is immutable (Firebase Auth UID)
- `badges[]` can only contain valid achievement IDs
- `followersCount` and `followingCount` auto-updated

### 2. BOOKINGS Collection
## Key Constraints & Validations

### 1. USERS Collection
- `email` must be unique
- `userId` is immutable (Firebase Auth UID)
- `badges[]` can only contain valid achievement IDs
- `followersCount` and `followingCount` auto-updated

### 2. BOOKINGS Collection
- `userId` must reference existing authenticated user (primary contact/booker only)
- `bookingType` must be: "special_trekking", "benchmarking_trek", "research_trek", or "regular_trek"
- `trekDate` must be at least `bufferDays` (default 3) days in future
- `status` must be: "pending", "approved", "declined", or "cancelled"
- `primaryContact` auto-filled from USERS collection on booking creation
- `totalMembers` calculated from MEMBERS subcollection count
- One user can only have one booking per date

### 2.1 MEMBERS Subcollection
- Each booking must have at least 1 member (the primary contact)
- All member fields (personal info) entered by authenticated user
- `userId` is optional: String (if member has account) or null (if guest member)
- `hasAccount` indicates whether member has Firebase authentication
- `isPrimaryContact` = true only for booking creator
- `category` must match one of 7 defined categories (student, senior_citizen, davao_oriental_resident, ocfdo, outside_davao_oriental, children_8_15, mfsm)
- `memberStatus` must be: "pending", "incomplete", "complete", "verified", or "rejected"
- `fileRequirements.requiredFiles` dynamically populated based on selected `category`
- All attachments uploaded by primary contact on behalf of each member

### 3. POSTS Collection
- `userId` must reference existing user
- `imageUrls[]` max length: 4
- `privacy` must be: "public", "followers", or "private"
- Counters (`likesCount`, `commentsCount`) auto-updated

### 4. CALENDAR_CONFIG Collection
- `dateKey` format: YYYY-MM-DD
- `maxSlots` range: 0-45
- Normal capacity: 30, special events: up to 45
- `isClosed` = true blocks all bookings

### 5. CERTIFICATES Collection
- `certificateType` must be: "camp3", "fullTrek", or "peakConqueror"
- `verificationCode` must be unique
- Generated only after meeting station visit requirements

### 6. CLIMBS Subcollection ★ NEW
- `climbId` is unique per user and auto-generated
- `userId` must reference existing user
- `trekType` must be one of: "special_trek", "benchmarking_trek", "research_trek", "regular_trek"
- `trekStartDate` required, `trekEndDate` optional (can be null for flexible-duration treks)
- `startDate` required (when first station scanned), `endDate` optional (null if in-progress)
- `status` must be: "in_progress", "completed", or "abandoned"
- `climbName` and `description` optional but recommended
- `stationsVisited` is ordered array of station numbers (1-14)
- `highestStationReached` must match max value in `stationsVisited`
- `totalDuration` calculated: endDate - startDate (in minutes)
- One user can have multiple active climbs (concurrent multi-trek support)

### 7. CLIMB_STATIONS Subcollection ★ NEW
- `climbStationId` auto-generated within each climb
- `climbId` required, must reference parent climb
- `stationId` required (1-14), must be valid station number
- `visitedAt` timestamp cannot be before parent climb's `startDate`
- `order` must be sequential (1, 2, 3, ...) within a climb
- `durationFromPrevious` auto-calculated from previous station's `visitedAt`
- `isCheckpoint` determined by stationId (hardcoded: 1, 5, 8, 11, 14)
- Only stations visited during active (`in_progress`) climbs can be added

---

## Security Rules Summary

### Authentication & Authorization
- All operations require Firebase Authentication
- Users can only read/write their own data (except public reads)
- Admin role required for system settings and calendar config

### Collection-Level Rules
1. **USERS**: Users can read all profiles (for social features), write only their own
2. **BOOKINGS**: Users can create/read/update their own, admins can manage all
3. **MEMBERS**: Only authenticated booking creator can add/edit/delete members for their own booking
4. **CLIMBS** ★ NEW: Only authenticated user can create/read/update/delete their own climbs; admins can read all
5. **CLIMB_STATIONS** ★ NEW: Only authenticated user can add station visits to their own in-progress climbs; locked after climb completion
6. **POSTS**: Public posts readable by all, private posts only by owner
7. **COMMENTS/REPLIES**: Readable by authenticated users, writable by all, deletable by owner
8. **LIKES**: Any authenticated user can like/unlike
9. **NOTIFICATIONS**: Users can read/delete their own, any user can create for others
10. **SUBCOLLECTIONS**: Users can only access their own subcollections
8. **SYSTEM_SETTINGS**: Read public, write admin only
9. **CALENDAR_CONFIG**: Read public, write admin only

---

## Data Synchronization & Offline Support

### Offline-First Collections
1. **ACHIEVEMENTS**: Stored locally in SharedPreferences, synced to Firestore when online
2. **VISITED_STATIONS**: Cached in SQLite, synced when connectivity restored
3. **POSTS**: Cached for viewing, uploads queued when offline

### Sync Strategy
- **Achievements**: Local unlock → Queue → Firebase sync
- **Station Visits**: Local mark → Queue → Firestore update
- **Bookings**: Requires online connectivity
- **Social Posts**: Queue uploads, fetch updates on reconnect

---

## Static Data References

### External JSON Files (Not in Firestore)
1. **stations_test.json**: Station metadata (7 stations)
   - Station ID, name, coordinates, elevation, content
   - Referenced by VISITED_STATIONS collection

2. **badge.json**: Achievement definitions
   - Achievement criteria, rarity, icons
   - Referenced by ACHIEVEMENTS subcollection

---

## Indexes & Query Optimization

### Recommended Firestore Indexes

1. **BOOKINGS Collection**
   ```
   - userId + trekDate (Ascending)
   - trekDate + status (Ascending)
   - status + createdAt (Descending)
   ```

2. **POSTS Collection**
   ```
   - userId + createdAt (Descending)
   - privacy + createdAt (Descending)
   - createdAt (Descending) [for feed]
   ```

3. **COMMENTS Subcollection**
   ```
   - postId + createdAt (Ascending)
   ```

4. **VISITED_STATIONS Subcollection**
   ```
   - userId + visitedAt (Descending)
   ```

5. **ACHIEVEMENTS Subcollection**
   ```
   - userId + unlockedAt (Descending)
   - userId + rarity (for filtering)
   ```

---

## Database Size Estimates

### Per User (Approximate)
- User profile: 1-2 KB
- Bookings: 5-10 KB per booking
- Posts: 10-50 KB per post (excluding images)
- Achievements: 2-5 KB per achievement (15+ achievements)
- Certificates: 3-5 KB per certificate
- Visited Stations: 1 KB per station visit (7 stations)
- Notifications: 1 KB per notification

### Storage
- User-generated images: Stored in Firebase Cloud Storage
- E-certificate PDFs: Stored in Firebase Cloud Storage
- Booking documents: Stored in Firebase Cloud Storage

---

## Conclusion

This ERD represents a comprehensive, normalized database structure for the Mt. Hamiguitan TrekScan+ application. The design leverages Firebase Firestore's hierarchical document model with subcollections for related data, ensuring efficient queries, proper access control, and offline-first capabilities. The structure supports all core features including user management, booking verification, social networking, achievement tracking, and e-certificate generation while maintaining data integrity and security.
