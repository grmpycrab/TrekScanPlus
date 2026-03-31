# Cloud Functions - Buffer Day Automation

This directory contains Firebase Cloud Functions that automatically manage buffer days (trek down days) when bookings are created, updated, or deleted.

## Functions

### 1. `onBookingStatusChange`
**Trigger**: Firestore document write on `bookings/{bookingId}`

**What it does**:
- **When booking is approved**: Creates buffer day for the day after trek date
- **When booking is cancelled/rejected**: Removes buffer day (if no other approved bookings exist on same date)
- **When booking is deleted**: Removes buffer day (if no other approved bookings exist)

**Example**:
```
Booking approved for Nov 30
  ↓
Function automatically creates buffer day for Dec 1
  ↓
Calendar shows Dec 1 as "Trek down day - Trekkers descending"
```

### 2. `syncAllBufferDays`
**Trigger**: Manual call via Firebase Console or client app

**What it does**:
- Scans all approved bookings
- Creates missing buffer days
- Removes outdated buffer days
- Returns sync statistics

**Usage**:
```javascript
// From client app (requires authentication)
const functions = getFunctions();
const syncBufferDays = httpsCallable(functions, 'syncAllBufferDays');
const result = await syncBufferDays();
console.log(result.data);
```

## Deployment

### Prerequisites
1. Firebase CLI installed: `npm install -g firebase-tools`
2. Logged in: `firebase login`
3. Project initialized: `firebase init functions`

### Deploy Functions
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### Deploy Specific Function
```bash
firebase deploy --only functions:onBookingStatusChange
firebase deploy --only functions:syncAllBufferDays
```

## Testing

### Test Automatic Trigger
1. Create a test booking with `status: 'pending'`
2. Update status to `'approved'`
3. Check `calendar_config` collection for new buffer day
4. Update status to `'cancelled'`
5. Verify buffer day is removed

### Test Manual Sync
```bash
# Via Firebase Console
# Functions > syncAllBufferDays > Testing tab > Run function

# Or via curl
curl -X POST https://REGION-PROJECT_ID.cloudfunctions.net/syncAllBufferDays \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{}'
```

## Monitoring

### View Logs
```bash
# All functions
firebase functions:log

# Specific function
firebase functions:log --only onBookingStatusChange
```

### In Firebase Console
1. Go to Functions section
2. Click on function name
3. View Logs tab

## Local Development

### Run Functions Locally
```bash
cd functions
npm install
firebase emulators:start --only functions,firestore
```

### Test Locally
```bash
# In another terminal
curl -X POST http://localhost:5001/PROJECT_ID/REGION/syncAllBufferDays \
  -H "Content-Type: application/json" \
  -d '{}'
```

## Cost Optimization

These functions are designed to be cost-effective:
- **onBookingStatusChange**: Only runs when bookings change (not on every read)
- **Conditional logic**: Only writes to Firestore when necessary
- **Batch operations**: Uses batched writes when possible
- **Early returns**: Exits early if no action needed

**Estimated cost**: ~$0.40 per 1 million invocations (Cloud Functions tier 1)

## Troubleshooting

### Function not triggering
1. Check Firebase Console > Functions > Logs
2. Verify function is deployed: `firebase functions:list`
3. Check Firestore security rules allow writes to `calendar_config`

### Buffer days not created
1. Check function logs for errors
2. Verify booking has valid `trekDate` field
3. Ensure `status` field is exactly `'approved'` (lowercase)

### Duplicate buffer days
Run manual sync to clean up:
```bash
# Will remove duplicates and keep only one per date
firebase functions:call syncAllBufferDays
```

## Security

The functions run with **admin privileges** and bypass Firestore security rules. This is necessary to:
- Create buffer days automatically without user intervention
- Ensure consistency even if client app has bugs

**Important**: Add authentication checks to `syncAllBufferDays` if you expose it as a public HTTP endpoint.

## Migration from Scripts

If you've been using `sync_buffer_days.js` script:

### Before (Manual)
```bash
# Had to run manually after approving bookings
node scripts/sync_buffer_days.js
```

### After (Automatic)
```
Booking approved in app
  ↓
Cloud Function automatically creates buffer day
  ↓
No manual intervention needed!
```

### One-time Migration
1. Deploy functions: `firebase deploy --only functions`
2. Run manual sync once: Call `syncAllBufferDays` function
3. From now on, buffer days are automatic!

## Summary

  **Automatic**: Buffer days created when bookings approved
  **Real-time**: Updates appear immediately in all clients
  **Reliable**: Cloud Functions run even if app is closed
  **Cost-effective**: Only runs when bookings change
  **Scalable**: Handles thousands of bookings efficiently
