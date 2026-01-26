# TrekScan+ NoSQL Data Model Diagram - Design Documentation

## Overview

This document explains the noSQL data model for the Mt. Hamiguitan TrekScan+ application using Firebase Firestore. The accompanying draw.io diagram visualizes the collection hierarchy, document structure, and relationships between entities.

---

## Data Model Organization

### Document-Based Hierarchy

The TrekScan+ data model is organized in a **hierarchical, document-oriented structure** with three organizational patterns:

#### 1. **Top-Level Collections**
Collections at the root level that store independent entities:

| Collection | Purpose | Key Identifier |
|-----------|---------|----------------|
| **USERS** | User profiles, authentication, social data | userId (Firebase Auth UID) |
| **BOOKINGS** | Group trek bookings and reservations | bookingId |
| **POSTS** | Social media posts from trekkers | postId |
| **CALENDAR_CONFIG** | Date-specific booking configuration | dateKey (YYYY-MM-DD) |

#### 2. **Subcollections** (Nested in Parent Documents)
Collections nested within parent documents for hierarchical data:

| Path | Parent | Purpose |
|------|--------|---------|
| `/bookings/{bookingId}/members` | BOOKINGS | Individual trek participants |
| `/posts/{postId}/comments` | POSTS | Post comments |
| `/posts/{postId}/comments/{commentId}/replies` | COMMENTS | Comment replies |
| `/posts/{postId}/likes` | POSTS | Post likes |
| `/users/{userId}/climbs` | USERS | Individual trek sessions |
| `/users/{userId}/climbs/{climbId}/stations` | CLIMBS | Station visits within a climb |
| `/users/{userId}/achievements` | USERS | Unlocked achievements |
| `/users/{userId}/certificates` | USERS | Earned certificates |
| `/users/{userId}/bookmarks` | USERS | Bookmarked posts |

#### 3. **Reference Documents**
System-level configuration documents for shared data:

| Document | Location | Purpose |
|----------|----------|---------|
| **FILE_REQUIREMENTS** | `/system_settings/file_requirements` | Category-specific file upload requirements |
| **SYSTEM_SETTINGS** | `/system_settings/{settingId}` | Global system configuration |

---

## Embedded Data vs. References

### Strategy: Hybrid Approach

The model uses **both embedded data and references** strategically based on access patterns and scalability requirements.

#### **Embedded Data (Denormalization)**

Embedded objects within documents improve query performance and reduce database reads:

```
BOOKINGS document contains:
  {
    bookingId: "B123",
    userId: "U456",
    primaryContact: {              // ← EMBEDDED OBJECT
      userId: "U456",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com",
      birthDate: "1990-05-15",
      gender: "Male"
    },
    trekDate: timestamp,
    totalMembers: 5                // ← AUTO-CALCULATED from MEMBERS subcollection
  }
```

**Advantages:**
- Single read for complete booking info
- No need for joins across collections
- Faster retrieval of frequently accessed data
- Atomic updates when all related data changes together

**Used for:**
- User display information in posts/comments
- Primary contact details in bookings
- Attachment metadata in member documents

---

#### **References (Normalization)**

Foreign key references connect documents across collections while avoiding data duplication:

```
MEMBERS document (nested in BOOKINGS):
  {
    memberId: "M789",
    bookingId: "B123",               // ← REFERENCE to parent
    userId: "U999" | null,            // ← REFERENCE to user (optional)
    firstName: "Jane",
    lastName: "Smith",
    category: "student"
  }

CLIMB_STATIONS document (nested in CLIMBS):
  {
    climbStationId: "CS001",
    climbId: "C001",                 // ← REFERENCE to parent climb
    stationId: 5,                    // ← REFERENCE to static station data
    stationName: "Station 5",
    visitedAt: timestamp
  }
```

**Advantages:**
- Avoid storing duplicate copies of data
- Changes to referenced data propagate automatically
- Reduced storage footprint
- Maintains referential integrity patterns

**Used for:**
- User IDs in bookings, posts, comments
- Parent document IDs in subcollections
- Calendar config references in bookings

---

## Data Model Patterns

### Pattern 1: Parent-Subcollection Relationship

**Purpose:** Store collections of related items belonging to a single parent

```
BOOKINGS (Parent)
  └─ MEMBERS (Subcollection)
     Each booking can have many members
     Query: db.collection('bookings').doc(bookingId)
            .collection('members').where(...)
```

**Benefits:**
- Automatic cascading deletes when parent is deleted
- Scoped queries reduce security rule complexity
- Organizes data hierarchically

**Used for:** Members in a booking, comments on a post, likes on content

---

### Pattern 2: Nested Subcollections (3+ Levels)

**Purpose:** Deeply hierarchical data relationships

```
POSTS (Level 1)
  └─ COMMENTS (Level 2)
     └─ REPLIES (Level 3)
        └─ LIKES (Level 4)
```

**Query Pattern:**
```
db.collection('posts').doc(postId)
  .collection('comments').doc(commentId)
  .collection('replies').get()
```

**Benefits:**
- Deep permission scoping
- Natural representation of threaded conversations
- Prevents overly long subcollection paths

---

### Pattern 3: Denormalized Counts

**Purpose:** Efficient statistics without complex queries

```
POSTS document includes:
  {
    postId: "P123",
    likesCount: 45,          // ← Denormalized counter
    commentsCount: 12,       // ← Updated via transaction
    sharesCount: 8
  }
```

**Update Strategy:** Use Firebase Cloud Functions to atomically update counters when likes/comments are added

**Benefits:**
- Instant access to statistics
- No expensive aggregation queries
- Suitable for mobile applications

---

## Flexibility & Scalability Features

### 1. **Dynamic Field Requirements**

**FILE_REQUIREMENTS Reference Document:**

```json
{
  "student": {
    "files": ["school_id", "birth_certificate", "valid_id"],
    "description": "Requirements for student participants"
  },
  "senior_citizen": {
    "files": ["senior_id", "birth_certificate", "valid_id"],
    "description": "Requirements for senior citizens"
  }
}
```

**Flexibility Benefit:** Add new categories or change file requirements without schema migrations. The app reads this reference document to dynamically render form fields.

---

### 2. **Optional & Nullable Fields**

Schema supports optional and nullable fields using union types:

```
MEMBERS document:
  userId: string | null        // Can be null for guest members
  middleName: string | null    // Optional
  facebookAccount: string | null

CLIMBS document:
  climbName: string | null     // Optional user-given name
  endDate: timestamp | null    // Null if climb in-progress
```

**Scalability Benefit:** New fields can be added without affecting existing documents. Backward compatibility maintained.

---

### 3. **Array Types for Flexible Collections**

Arrays handle variable-length data within a document:

```
USERS document:
  badges: Array<string>              // Dynamic achievement list
  followingCount: number              // Counter

CLIMBS document:
  stationsVisited: Array<number>     // [1, 3, 5, 8, 14]
  
MEMBERS document:
  attachments: Array<Attachment>     // Multiple file uploads
```

**Scalability Benefit:** Don't need separate subcollection for every small item. Better for small, bounded collections.

---

### 4. **Status Enums for State Management**

Predefined status values enable efficient querying and filtering:

```
BOOKINGS:
  status: "pending" | "approved" | "declined" | "cancelled"

CLIMBS:
  status: "in_progress" | "completed" | "abandoned"

MEMBERS:
  memberStatus: "pending" | "incomplete" | "complete" | "verified" | "rejected"
```

**Indexes:**
```
db.collection('bookings')
  .where('status', '==', 'pending')
  .where('trekDate', '>=', startDate)
  .get()
```

---

### 5. **Auto-Calculated & Denormalized Values**

Server-side calculations stored for query efficiency:

```
BOOKINGS:
  totalMembers: number   // Calculated from members subcollection count
  primaryContact: {...}  // Snapshot from USERS at booking creation

CLIMBS:
  highestStationReached: number  // Max of stationsVisited array
  totalDuration: number          // endDate - startDate (minutes)
```

**Cloud Function Update:** Triggered when members added/removed or stations visited:

```javascript
// Triggered on MEMBERS document creation/deletion
exports.updateBookingMemberCount = functions
  .firestore.document('bookings/{bookingId}/members/{memberId}')
  .onWrite(async (change, context) => {
    const bookingRef = db.collection('bookings')
      .doc(context.params.bookingId);
    const memberCount = await bookingRef
      .collection('members').count().get();
    await bookingRef.update({
      totalMembers: memberCount.data().count
    });
  });
```

---

## Query Patterns & Performance

### Efficient Query Examples

#### 1. **Get User's Bookings**
```javascript
const userBookings = await db
  .collection('bookings')
  .where('userId', '==', currentUserId)
  .orderBy('trekDate', 'desc')
  .limit(10)
  .get();
```

**Index Required:** `userId + trekDate (Descending)`

---

#### 2. **Get Booking Members**
```javascript
const bookingMembers = await db
  .collection('bookings')
  .doc(bookingId)
  .collection('members')
  .where('memberStatus', '==', 'verified')
  .get();
```

**Index Required:** None (scoped to single parent document)

---

#### 3. **Get User's Climb Progress**
```javascript
const currentClimb = await db
  .collection('users')
  .doc(userId)
  .collection('climbs')
  .where('status', '==', 'in_progress')
  .limit(1)
  .get();

const stations = await db
  .collection('users')
  .doc(userId)
  .collection('climbs')
  .doc(climbId)
  .collection('stations')
  .orderBy('visitedAt', 'asc')
  .get();
```

**Indexes Required:**
- `climbs: status`
- `stations: visitedAt (Ascending)`

---

#### 4. **Get Post Feed**
```javascript
const publicPosts = await db
  .collection('posts')
  .where('privacy', '==', 'public')
  .orderBy('createdAt', 'desc')
  .limit(20)
  .get();
```

**Index Required:** `privacy + createdAt (Descending)`

---

## Scalability Considerations

### Handling Large Subcollections

**Problem:** Some subcollections may grow very large (e.g., many likes on popular posts)

**Solution: Sharded Counters**

```javascript
// Instead of storing 1000+ documents in /posts/{postId}/likes
// Use a sharded counter approach with Cloud Functions

// In the POSTS document:
{
  postId: "P123",
  likesCount: 1250,
  likeCounterShards: 10  // Number of shards for distributed updates
}

// Actual likes distributed across shards:
/posts/{postId}/likeShards/{shardId}/likes/{userId}
```

---

### Handling Read-Heavy Workloads

**Problem:** Frequent reads on user profiles from many documents

**Solution: Caching Strategy**

```
Profile reads:
1. Load from local SQLite cache
2. If not found, fetch from Firestore
3. Write to local cache with TTL
4. Periodically sync in background
```

---

### Handling Write-Heavy Workloads

**Problem:** Many station visits recorded rapidly during climbs

**Solution: Batch Writes & Transactions**

```javascript
const batch = db.batch();

stationVisits.forEach(visit => {
  const docRef = db
    .collection('users').doc(userId)
    .collection('climbs').doc(climbId)
    .collection('stations').doc();
  batch.set(docRef, visit);
});

await batch.commit();  // Single atomic write
```

---

## Data Relationships Summary

### One-to-Many (1:N)

| Relationship | Query |
|-------------|-------|
| USERS → BOOKINGS | `bookings.where('userId', '==', uid)` |
| BOOKINGS → MEMBERS | `bookings/{id}/members.getAll()` |
| USERS → CLIMBS | `users/{id}/climbs.getAll()` |
| CLIMBS → CLIMB_STATIONS | `climbs/{id}/stations.getAll()` |
| POSTS → COMMENTS | `posts/{id}/comments.getAll()` |
| COMMENTS → LIKES | `comments/{id}/likes.getAll()` |

### Many-to-Many (M:N)

| Relationship | Implementation |
|-------------|----------------|
| USERS ↔ USERS (followers) | Bidirectional arrays in USERS document |
| USERS ↔ ACHIEVEMENTS | ACHIEVEMENTS subcollection for each user |
| POSTS ↔ USERS (bookmarks) | BOOKMARKS subcollection for each user |

### Cross-Collection References

| Reference | Type |
|-----------|------|
| BOOKINGS → CALENDAR_CONFIG | Indexed reference by trekDate |
| MEMBERS → FILE_REQUIREMENTS | System config reference |
| CLIMB_STATIONS → Station Static Data | Reference to stations_test.json |

---

## Security & Access Control

### Collection-Level Rules

```
USERS
  ├─ Read: Public (profiles for social features)
  └─ Write: Self only

BOOKINGS
  ├─ Read: Owner + Admin
  ├─ Create: Authenticated users
  └─ Update: Owner + Admin

BOOKINGS.MEMBERS
  ├─ Read: Parent booking owner + Admin
  └─ Write: Parent booking creator only

CLIMBS
  ├─ Read: Owner (or Admin)
  └─ Write: Owner only

POSTS
  ├─ Read: Depends on privacy setting
  └─ Write: Author only

SYSTEM_SETTINGS, FILE_REQUIREMENTS
  ├─ Read: Public
  └─ Write: Admin only
```

---

## Offline-First Architecture

### Local Sync Collections

Data synced between local SQLite and Firestore:

1. **ACHIEVEMENTS** - Unlocked achievements synced when online
2. **VISITED_STATIONS** - Station visits queued for sync
3. **CLIMB_STATIONS** - Individual station visits cached locally
4. **POSTS** - Drafted posts cached locally

### Sync Flow

```
User Offline:
  1. Save data to local SQLite
  2. Queue operations in SyncQueue collection
  3. UI shows local copy with "pending sync" indicator

User Online:
  1. Execute queued operations to Firestore
  2. Sync any server changes back to local
  3. Remove completed operations from queue
```

---

## Conclusion

The TrekScan+ noSQL data model uses a **hybrid approach** combining:

✅ **Embedded data** for frequently co-accessed information
✅ **Subcollections** for hierarchical relationships
✅ **References** for cross-collection relationships
✅ **Denormalization** for query performance
✅ **Flexible schema** with optional/nullable fields
✅ **Arrays** for bounded collections
✅ **Status enums** for efficient filtering

This design provides:
- **Scalability**: Handles growth in users, bookings, and content
- **Flexibility**: New features addable without schema migrations
- **Performance**: Optimized query patterns with appropriate indexes
- **Offline Support**: Local-first sync for mobile reliability
- **Security**: Granular access control per collection
