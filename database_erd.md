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

**Purpose:** Stores trek booking information and verification documents

| Field Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| **bookingId (PK)** | String | Auto-generated | Firestore document ID |
| **userId (FK)** | String | Required | Reference to users collection |
| affiliation | String | Required | Organization/school affiliation |
| trekDate | Timestamp | Required | Scheduled trek date |
| numberOfPorters | Number | Required | Number of porters needed |
| trekType | String | Required | "recreational" or "research" |
| hometown | String | Optional | User's hometown/city |
| isSenior | Boolean | Default: false | Senior citizen status |
| phoneNumber | String | Required | Contact phone number |
| notes | String | Optional | User notes/special requests |
| adminNotes | String | Optional | Admin comments |
| attachments | Array\<Attachment\> | Default: [] | Uploaded verification documents |
| status | String | Default: "pending" | "pending", "approved", "declined", "cancelled" |
| createdAt | Timestamp | Auto-generated | Booking creation timestamp |
| updatedAt | Timestamp | Auto-updated | Last modification timestamp |

**Attachment Object Structure:**
```json
{
  "storagePath": "String - Firebase Storage path",
  "downloadURL": "String - Public download URL",
  "fileName": "String - Original file name",
  "mimeType": "String - File MIME type",
  "size": "Number - File size in bytes",
  "uploadedAt": "Timestamp - Upload timestamp"
}
```

**Relationships:**
- N:1 with USERS (many bookings belong to one user)
- 1:1 with CALENDAR_CONFIG (booking date references calendar config)

---

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

### 12. SYSTEM_SETTINGS Collection
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

### 13. CALENDAR_CONFIG Collection
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

## Entity-Relationship Diagram (Visual)

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
┌──────────────────────────────┐                    ┌──────────────────────────┐
│  BOOKINGS (Top-level)        │                    │  POSTS (Top-level)       │
├──────────────────────────────┤                    ├──────────────────────────┤
│ PK: bookingId                │                    │ PK: postId               │
│ FK: userId                   │                    │ FK: userId               │
│ • affiliation, trekDate      │                    │ • caption, imageUrls[]   │
│ • numberOfPorters, trekType  │                    │ • privacy, likesCount    │
│ • hometown, isSenior         │                    │ • commentsCount          │
│ • phoneNumber, notes         │                    │ • createdAt, updatedAt   │
│ • attachments[], status      │                    └──────────────────────────┘
│ • createdAt, updatedAt       │                              │
└──────────────────────────────┘                              │ 1:N
      │                                                        │
      │ N:1                                                    ▼
      │                                    ┌───────────────────────────────────┐
      ▼                                    │  COMMENTS (Subcollection)         │
┌────────────────────────────┐            ├───────────────────────────────────┤
│  CALENDAR_CONFIG           │            │ PK: commentId                     │
├────────────────────────────┤            │ FK: postId, userId                │
│ PK: dateKey (YYYY-MM-DD)   │            │ • userName, userPhotoUrl          │
│ • date, isClosed           │            │ • text, likesCount, repliesCount  │
│ • maxSlots, currentBookings│            │ • createdAt                       │
│ • lastUpdated, notes       │            └───────────────────────────────────┘
└────────────────────────────┘                          │
                                                        │ 1:N
                                                        ▼
                                        ┌───────────────────────────────────┐
                                        │  REPLIES (Nested Subcollection)   │
                                        ├───────────────────────────────────┤
                                        │ PK: replyId                       │
                                        │ FK: postId, commentId, userId     │
                                        │ • userName, userPhotoUrl          │
                                        │ • text, likesCount, createdAt     │
                                        └───────────────────────────────────┘


┌──────────────────────────────────────────────────────────────────────────┐
│                    USER SUBCOLLECTIONS (Nested in /users/{userId})       │
└──────────────────────────────────────────────────────────────────────────┘

    /users/{userId}/notifications                /users/{userId}/visitedStations
    ┌─────────────────────────────┐             ┌──────────────────────────┐
    │ NOTIFICATIONS               │             │ VISITED_STATIONS         │
    ├─────────────────────────────┤             ├──────────────────────────┤
    │ PK: notificationId          │             │ PK: stationId            │
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
| USERS | creates | POSTS | 1:N |
| USERS | writes | COMMENTS | 1:N |
| USERS | writes | REPLIES | 1:N |
| USERS | receives | NOTIFICATIONS | 1:N |
| USERS | visits | VISITED_STATIONS | 1:N |
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
- `userId` must reference existing user
- `trekDate` must be at least `bufferDays` (default 3) days in future
- `status` must be: "pending", "approved", "declined", or "cancelled"
- `numberOfPorters` must be ≥ 0
- `maxSlots` per date enforced via CALENDAR_CONFIG
- One user can only have one booking per date

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

---

## Security Rules Summary

### Authentication & Authorization
- All operations require Firebase Authentication
- Users can only read/write their own data (except public reads)
- Admin role required for system settings and calendar config

### Collection-Level Rules
1. **USERS**: Users can read all profiles (for social features), write only their own
2. **BOOKINGS**: Users can create/read/update their own, admins can manage all
3. **POSTS**: Public posts readable by all, private posts only by owner
4. **COMMENTS/REPLIES**: Readable by authenticated users, writable by all, deletable by owner
5. **LIKES**: Any authenticated user can like/unlike
6. **NOTIFICATIONS**: Users can read/delete their own, any user can create for others
7. **SUBCOLLECTIONS**: Users can only access their own subcollections
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
