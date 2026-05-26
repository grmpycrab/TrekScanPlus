// All Firestore reads here use getDocs() — a single-invocation promise.
// onSnapshot() (real-time subscription) is intentionally NOT used anywhere in
// this module to prevent listener accumulation and render-loop side-effects.

import {
  collection,
  query,
  where,
  orderBy,
  getDocs,
  addDoc,
  updateDoc,
  doc,
  setDoc,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from '../config/firebase.js';

// ── Claims queue ─────────────────────────────────────────────────────────────

// Shared 12-second timeout wrapper — prevents any single Firestore getDocs
// call from hanging the UI forever (missing index / security rule / SDK init).
function withTimeout(promise, label) {
  return new Promise((resolve, reject) => {
    const id = setTimeout(() => {
      reject(new Error(`[badgeService] ${label} timed out — open DevTools Console/Network to diagnose`));
    }, 12000);
    promise.then(
      (v) => { clearTimeout(id); resolve(v); },
      (e) => { clearTimeout(id); reject(e); },
    );
  });
}

async function getClaimsByStatus(status) {
  const snap = await withTimeout(
    getDocs(
      query(
        collection(db, 'badge_claims'),
        where('status', '==', status),
        orderBy('submittedAt', 'desc'),
      ),
    ),
    `getClaimsByStatus(${status})`,
  );
  // Spread doc.data() after id so the Firestore id field is always
  // the authoritative key — never overwritten by a stale data.id value.
  return snap.docs.map((d) => ({ ...d.data(), id: d.id }));
}

export async function getAllClaims() {
  const [pending, approved, rejected] = await Promise.all([
    getClaimsByStatus('PENDING'),
    getClaimsByStatus('APPROVED'),
    getClaimsByStatus('REJECTED'),
  ]);
  return { pending, approved, rejected };
}

export async function approveClaim(claimId, claim) {
  const { userId, badgeId, badgeName } = claim;

  await setDoc(doc(db, 'users', userId, 'achievements', badgeId), {
    id: badgeId,
    name: badgeName,
    isUnlocked: true,
    claimStatus: 'APPROVED',
    unlockedAt: new Date().toISOString(),
    syncedAt: serverTimestamp(),
  });

  await updateDoc(doc(db, 'badge_claims', claimId), {
    status: 'APPROVED',
    reviewedAt: serverTimestamp(),
    reviewNote: null,
  });
}

export async function rejectClaim(claimId, note = '') {
  await updateDoc(doc(db, 'badge_claims', claimId), {
    status: 'REJECTED',
    reviewedAt: serverTimestamp(),
    reviewNote: note || null,
  });
}

// ── Badge definitions (admin-created) ────────────────────────────────────────

export async function getBadgeDefinitions() {
  // 12-second hard timeout so the UI never hangs on a stalled Firestore request.
  // If the promise is still pending after 12 s the error surfaces in the console
  // so the caller can see the real failure reason (missing index, security rule, etc.)
  const timeoutId = { id: null };
  const timeout = new Promise((_, reject) => {
    timeoutId.id = setTimeout(
      () => reject(new Error('[badgeService] getBadgeDefinitions timed out — check Firestore rules and single-field index on createdAt')),
      12000,
    );
  });

  try {
    const snap = await Promise.race([
      getDocs(query(collection(db, 'badge_definitions'), orderBy('createdAt', 'desc'))),
      timeout,
    ]);
    clearTimeout(timeoutId.id);
    return snap.docs.map((d) => ({ ...d.data(), id: d.id }));
  } catch (err) {
    clearTimeout(timeoutId.id);
    throw err; // re-throw so the caller's catch block can log it
  }
}

export async function createBadgeDefinition(data) {
  const ref = await addDoc(collection(db, 'badge_definitions'), {
    ...data,
    isActive: true,
    createdAt: serverTimestamp(),
  });
  return ref.id;
}

export async function toggleBadgeDefinitionActive(badgeId, isActive) {
  await updateDoc(doc(db, 'badge_definitions', badgeId), { isActive });
}
