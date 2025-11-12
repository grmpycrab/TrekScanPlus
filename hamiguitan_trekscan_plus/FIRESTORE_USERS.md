# Firestore `users` collection

This document describes the Firestore `users` collection schema, security suggestions, and admin dashboard access patterns for the TrekScanPlus project.

## Purpose
Store a canonical, minimal user profile for every authenticated user. The admin dashboard will read and manage these documents for administration and reporting.

## Collection path
`/users/{uid}`

## Document fields (recommended)
- `uid` (string) — Firebase Auth UID (document id should also be the UID).
- `email` (string|null) — user email.
- `displayName` (string|null) — user display name.
- `photoURL` (string|null) — avatar URL.
- `phoneNumber` (string|null) — phone number if provided.
- `providerData` (array) — simple list of provider ids, e.g. `["google.com"]`.
- `createdAt` (timestamp) — server timestamp when document was first created.
- `lastSeen` (timestamp) — server timestamp updated when user signs in.

Example document:

```
users/
  K9aBcDeFGh12345:
    uid: "K9aBcDeFGh12345"
    email: "alice@example.com"
    displayName: "Alice Doe"
    photoURL: "https://.../photo.jpg"
    providerData: ["google.com"]
    createdAt: 2025-11-12T12:34:56Z
    lastSeen: 2025-11-15T08:01:22Z
```

## Security rules (starter)
Place these in `firestore.rules`. They are intentionally conservative: users can read/write only their own document. Admins (via custom claim `admin=true`) can read and list all users.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, update: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null && request.auth.uid == userId;
      // Admins can read/list all users
      allow read: if request.auth.token.admin == true;
      allow delete: if request.auth.token.admin == true;
    }

    // Add additional admin-only paths if you need aggregate reports
  }
}
```

Notes:
- Admin privileges require setting a custom claim on a service account or admin user via the Firebase Admin SDK.
- For server-side admin dashboards, prefer using a service account and the Admin SDK instead of client auth.

## Indexes and queries
- You may want an index on `lastSeen` if you query recent users.
- For simple dashboards, read pages of users using `.orderBy('createdAt').limit(N)`.

## Recommended practices
- Use `FieldValue.serverTimestamp()` for `createdAt` and `lastSeen` to ensure server times are used.
- Avoid storing sensitive data (passwords, auth tokens) in Firestore.
- Consider using Cloud Functions to keep `users` in sync with other systems or to enrich user profiles on creation.

## Admin dashboard access
- Option A (recommended): use the Firebase Admin SDK on a trusted server. It can read all user docs without security rules restrictions.
- Option B: implement an admin sign-in with `admin` custom claim; restrict access in rules as shown above.

If you'd like, I can also add a Cloud Function that triggers on `auth.user().onCreate` to populate the `/users/{uid}` doc server-side (helps ensure reliable creation even if a client sign-in path changes). Let me know if you want that next.
