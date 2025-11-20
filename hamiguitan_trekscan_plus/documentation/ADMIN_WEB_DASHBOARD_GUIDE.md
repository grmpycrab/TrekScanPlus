# Admin Web Dashboard - Booking Management Guide

## Overview
This guide explains how the admin web dashboard should update booking statuses to automatically trigger notifications in the mobile app.

## How It Works

1. **Admin updates booking status** in Firestore (from web dashboard)
2. **Mobile app listener detects** the status change automatically
3. **Notification is sent** to the user's device
4. **User sees notification** in their notifications sheet
5. **For declined bookings**: User can edit and resubmit their booking

## Declined Booking Flow

When a booking is declined:
- User receives a notification with admin's reason
- Booking card shows "Declined" status in red
- **"Edit Request" button** appears on the booking card
- User can tap "Edit Request" to:
  - Fix any errors (typos, wrong dates, etc.)
  - See the admin's rejection reason
  - Update booking details
  - Add/remove attachments
  - **Resubmit** - Status automatically resets to "Pending" for re-review

This reduces booking traffic and allows users to correct mistakes without creating new requests.

## Firestore Structure

### Bookings Collection
```
/bookings/{bookingId}
  - userId: string
  - status: string (pending, approved, declined, cancelled)
  - adminNotes: string (optional - will be shown in notification)
  - affiliation: string
  - trekDate: timestamp
  - numberOfPorters: number
  - trekType: string
  - notes: string
  - attachments: array
  - createdAt: timestamp
  - updatedAt: timestamp
```

## Admin Dashboard Implementation

### JavaScript/Firebase Example

```javascript
import { getFirestore, doc, updateDoc, serverTimestamp } from 'firebase/firestore';

const db = getFirestore();

// Approve a booking
async function approveBooking(bookingId, adminNotes) {
  const bookingRef = doc(db, 'bookings', bookingId);
  
  await updateDoc(bookingRef, {
    status: 'approved',
    adminNotes: adminNotes || 'Your trek booking has been approved! Get ready for your adventure.',
    updatedAt: serverTimestamp()
  });
}

// Decline a booking
async function declineBooking(bookingId, reason) {
  const bookingRef = doc(db, 'bookings', bookingId);
  
  await updateDoc(bookingRef, {
    status: 'declined',
    adminNotes: reason || 'Your trek booking has been declined. Please contact support for more information.',
    updatedAt: serverTimestamp()
  });
}

// Generic status update
async function updateBookingStatus(bookingId, status, adminNotes = null) {
  const bookingRef = doc(db, 'bookings', bookingId);
  
  const updateData = {
    status: status,
    updatedAt: serverTimestamp()
  };
  
  if (adminNotes) {
    updateData.adminNotes = adminNotes;
  }
  
  await updateDoc(bookingRef, updateData);
}
```

### REST API Example (if using Firebase Admin SDK)

```javascript
const admin = require('firebase-admin');
const db = admin.firestore();

app.post('/api/bookings/:bookingId/approve', async (req, res) => {
  const { bookingId } = req.params;
  const { adminNotes } = req.body;
  
  try {
    await db.collection('bookings').doc(bookingId).update({
      status: 'approved',
      adminNotes: adminNotes || 'Your trek booking has been approved!',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ success: true, message: 'Booking approved. User will be notified.' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/bookings/:bookingId/decline', async (req, res) => {
  const { bookingId } = req.params;
  const { reason } = req.body;
  
  try {
    await db.collection('bookings').doc(bookingId).update({
      status: 'declined',
      adminNotes: reason,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ success: true, message: 'Booking declined. User will be notified.' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

## Notification Messages

The mobile app automatically generates appropriate notifications based on status:

| Status | Notification Title | Notification Type |
|--------|-------------------|-------------------|
| `approved` | "Booking Approved ✓" | Success (Green) |
| `declined` or `rejected` | "Booking Declined" | Alert (Red) |
| `pending` | "Booking Under Review" | Info (Blue) |
| `cancelled` | "Booking Cancelled" | Warning (Orange) |

### Admin Notes
- If you provide `adminNotes`, it will replace the default message
- **For declined bookings**: Admin notes are shown to the user when they edit the booking
- Use admin notes to give specific reasons or instructions
- Examples:
  - **Approval**: "Your booking is approved! Please arrive 30 minutes early."
  - **Decline**: "Date is fully booked. Please select another date."
  - **Decline**: "Missing required documents. Please upload valid ID."
  - **Decline**: "Invalid affiliation. Please provide correct institution name."

> **Tip**: When declining, provide clear actionable feedback so users know exactly what to fix when they resubmit.

## Example UI Flow

```
Admin Dashboard
  ↓
View Pending Bookings
  ↓
Select Booking → View Details
  ↓
[Approve] or [Decline] Button
  ↓
(Optional) Add admin notes
  ↓
Confirm Action
  ↓
Update Firestore → Mobile app receives notification
```

## Testing

1. **Create a test booking** from mobile app
2. **Login to admin dashboard**
3. **Update booking status** to "approved" with custom admin notes
4. **Check mobile app** - notification should appear immediately
5. **Tap notification** - should show booking details

## Security Rules

Make sure your Firestore rules allow admin to update bookings:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /bookings/{bookingId} {
      // Users can read their own bookings
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      
      // Users can create bookings
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      
      // Only admins can update booking status
      allow update: if request.auth != null && 
                       hasAdminRole(request.auth.uid);
    }
    
    function hasAdminRole(userId) {
      return get(/databases/$(database)/documents/users/$(userId)).data.role == 'admin';
    }
  }
}
```

## Important Notes

- ✅ **No need to manually send notifications** - the mobile app handles this automatically
- ✅ **Instant notifications** - users receive updates in real-time
- ✅ **Status field is case-insensitive** - "Approved", "approved", "APPROVED" all work
- ✅ **Admin notes are optional** but recommended for better user experience
- ⚠️ **Always update** `updatedAt` field when changing status
- ⚠️ **Verify admin permissions** before allowing status updates

## Supported Status Values

- `pending` - Default status when booking is created
- `approved` - Booking is confirmed
- `declined` - Booking is rejected
- `rejected` - Same as declined
- `cancelled` - Booking is cancelled (by user or admin)

Any other status will show as "Booking Status Updated" with info notification type.
