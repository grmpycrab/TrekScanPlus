// Group Booking Service - Firestore operations for group bookings and join requests
import {
  collection,
  collectionGroup,
  doc,
  getDoc,
  getDocs,
  updateDoc,
  query,
  where,
  orderBy,
  onSnapshot,
  writeBatch,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import { db } from '../config/firebase';

const GROUPS_COL = 'groupBookings';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const groupFromDoc = (snap) => ({ id: snap.id, ...snap.data() });

const requestFromDoc = (snap) => ({ id: snap.id, ...snap.data() });

/** Convert a Firestore Timestamp (or seconds object) to a JS Date. */
export const tsToDate = (ts) => {
  if (!ts) return null;
  if (ts instanceof Timestamp) return ts.toDate();
  if (ts.seconds != null) return new Date(ts.seconds * 1000);
  if (ts instanceof Date) return ts;
  return new Date(ts);
};

/** Format a trek date for display. */
export const formatGroupDate = (ts) => {
  const d = tsToDate(ts);
  if (!d) return '—';
  return d.toLocaleDateString('en-PH', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

// ---------------------------------------------------------------------------
// Group Booking reads
// ---------------------------------------------------------------------------

/**
 * Fetch all group bookings with optional status filter.
 * @param {string|null} statusFilter - e.g. 'open', 'pending_review', 'approved'
 */
export const getAllGroupBookings = async (statusFilter = null) => {
  try {
    let q = collection(db, GROUPS_COL);
    if (statusFilter && statusFilter !== 'all') {
      q = query(q, where('status', '==', statusFilter), orderBy('trekDate'));
    } else {
      q = query(q, orderBy('createdAt', 'desc'));
    }
    const snap = await getDocs(q);
    return snap.docs.map(groupFromDoc);
  } catch (err) {
    console.error('getAllGroupBookings:', err);
    throw err;
  }
};

/**
 * Fetch a single group booking by ID.
 */
export const getGroupBookingById = async (groupId) => {
  try {
    const snap = await getDoc(doc(db, GROUPS_COL, groupId));
    return snap.exists() ? groupFromDoc(snap) : null;
  } catch (err) {
    console.error('getGroupBookingById:', err);
    throw err;
  }
};

/**
 * Real-time subscription to all group bookings.
 * @param {function} onData - called with array of group bookings on each update
 * @param {function} onError - called on stream error
 * @param {string|null} statusFilter
 * @returns {function} unsubscribe
 */
export const subscribeToGroupBookings = (onData, onError, statusFilter = null) => {
  let q;
  if (statusFilter && statusFilter !== 'all') {
    q = query(
      collection(db, GROUPS_COL),
      where('status', '==', statusFilter),
      orderBy('trekDate'),
    );
  } else {
    q = query(collection(db, GROUPS_COL), orderBy('createdAt', 'desc'));
  }

  return onSnapshot(
    q,
    (snap) => onData(snap.docs.map(groupFromDoc)),
    (err) => {
      console.error('subscribeToGroupBookings error:', err);
      onError?.(err);
    },
  );
};

// ---------------------------------------------------------------------------
// Join Request reads
// ---------------------------------------------------------------------------

/**
 * Fetch all join requests for a specific group, optionally filtered by status.
 */
export const getJoinRequests = async (groupId, statusFilter = null) => {
  try {
    const ref = collection(db, GROUPS_COL, groupId, 'joinRequests');
    let q = statusFilter
      ? query(ref, where('status', '==', statusFilter), orderBy('createdAt', 'desc'))
      : query(ref, orderBy('createdAt', 'desc'));
    const snap = await getDocs(q);
    return snap.docs.map(requestFromDoc);
  } catch (err) {
    console.error('getJoinRequests:', err);
    throw err;
  }
};

/**
 * Real-time subscription to join requests for a group.
 * @returns {function} unsubscribe
 */
export const subscribeToJoinRequests = (groupId, onData, onError, statusFilter = null) => {
  const ref = collection(db, GROUPS_COL, groupId, 'joinRequests');
  const q = statusFilter
    ? query(ref, where('status', '==', statusFilter), orderBy('createdAt', 'desc'))
    : query(ref, orderBy('createdAt', 'desc'));

  return onSnapshot(
    q,
    (snap) => onData(snap.docs.map(requestFromDoc)),
    (err) => {
      console.error('subscribeToJoinRequests error:', err);
      onError?.(err);
    },
  );
};

/**
 * Fetch all pending join requests across every group (admin overview).
 * Requires a Firestore collectionGroup index on joinRequests/status.
 */
export const getAllPendingJoinRequests = async () => {
  try {
    const q = query(
      collectionGroup(db, 'joinRequests'),
      where('status', '==', 'pending'),
      orderBy('createdAt', 'desc'),
    );
    const snap = await getDocs(q);
    return snap.docs.map(requestFromDoc);
  } catch (err) {
    console.error('getAllPendingJoinRequests:', err);
    throw err;
  }
};

// ---------------------------------------------------------------------------
// Group Booking mutations (admin)
// ---------------------------------------------------------------------------

/**
 * Update the status of a group booking.
 * @param {string} groupId
 * @param {string} status - 'open'|'pending_review'|'approved'|'declined'|'full'|'completed'|'cancelled'
 * @param {Object} extra - optional { adminNotes, linkedBookingId }
 */
export const updateGroupStatus = async (groupId, status, extra = {}) => {
  try {
    const ref = doc(db, GROUPS_COL, groupId);
    await updateDoc(ref, {
      status,
      ...(extra.adminNotes != null && { adminNotes: extra.adminNotes }),
      ...(extra.linkedBookingId != null && { linkedBookingId: extra.linkedBookingId }),
      updatedAt: serverTimestamp(),
    });
  } catch (err) {
    console.error('updateGroupStatus:', err);
    throw err;
  }
};

// ---------------------------------------------------------------------------
// Join Request mutations (admin)
// ---------------------------------------------------------------------------

/**
 * Admin approves a join request.
 * Atomically: sets request approved + increments currentSlots + marks full if needed.
 */
export const approveJoinRequest = async (groupId, requestId, adminUid) => {
  try {
    const groupRef = doc(db, GROUPS_COL, groupId);
    const requestRef = doc(db, GROUPS_COL, groupId, 'joinRequests', requestId);

    const [groupSnap, requestSnap] = await Promise.all([
      getDoc(groupRef),
      getDoc(requestRef),
    ]);

    if (!groupSnap.exists()) throw new Error('Group not found');
    if (!requestSnap.exists()) throw new Error('Join request not found');

    const group = groupSnap.data();
    const request = requestSnap.data();

    if (group.currentSlots >= group.maxSlots) {
      throw new Error('Group is already full — no slots remaining.');
    }

    const newSlots = (group.currentSlots ?? 1) + 1;
    const newGroupStatus = newSlots >= group.maxSlots ? 'full' : group.status;

    const batch = writeBatch(db);

    batch.update(requestRef, {
      status: 'approved',
      affiliation: group.affiliation,
      reviewedAt: serverTimestamp(),
      reviewedBy: adminUid,
      updatedAt: serverTimestamp(),
    });

    batch.update(groupRef, {
      currentSlots: newSlots,
      status: newGroupStatus,
      updatedAt: serverTimestamp(),
    });

    await batch.commit();
    return { newSlots, newGroupStatus };
  } catch (err) {
    console.error('approveJoinRequest:', err);
    throw err;
  }
};

/**
 * Admin declines a join request with an optional reason.
 */
export const declineJoinRequest = async (groupId, requestId, adminUid, reason = null) => {
  try {
    const requestRef = doc(db, GROUPS_COL, groupId, 'joinRequests', requestId);
    await updateDoc(requestRef, {
      status: 'declined',
      declineReason: reason ?? null,
      reviewedAt: serverTimestamp(),
      reviewedBy: adminUid,
      updatedAt: serverTimestamp(),
    });
  } catch (err) {
    console.error('declineJoinRequest:', err);
    throw err;
  }
};

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

/** Human-readable label for a trek type key. */
export const trekTypeLabel = (type) => {
  const map = {
    regular_trek: 'Regular',
    special_trek: 'Special',
    research_trek: 'Research',
    government_official: 'Government / Official',
    benchmarking_trek: 'Benchmarking',
  };
  return map[type] ?? type;
};

/** Human-readable label for a booking classification key. */
export const classificationLabel = (c) => {
  const map = {
    regular: 'Regular',
    special: 'Special',
    government_official: 'Government / Official',
    off_season: 'Off-Season',
  };
  return map[c] ?? c;
};

/** CSS-friendly status color. */
export const groupStatusColor = (status) => {
  const map = {
    open: '#16a34a',
    pending_review: '#d97706',
    approved: '#2563eb',
    full: '#9333ea',
    declined: '#dc2626',
    completed: '#6b7280',
    cancelled: '#6b7280',
  };
  return map[status] ?? '#6b7280';
};
