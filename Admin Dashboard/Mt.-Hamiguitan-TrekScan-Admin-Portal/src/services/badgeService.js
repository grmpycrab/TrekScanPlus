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

async function getClaimsByStatus(status) {
  const snap = await getDocs(
    query(
      collection(db, 'badge_claims'),
      where('status', '==', status),
      orderBy('submittedAt', 'desc'),
    ),
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
  const snap = await getDocs(
    query(
      collection(db, 'badge_definitions'),
      orderBy('createdAt', 'desc'),
    ),
  );
  return snap.docs.map((d) => ({ ...d.data(), id: d.id }));
}

export async function createBadgeDefinition(data) {
  await addDoc(collection(db, 'badge_definitions'), {
    ...data,
    isActive: true,
    createdAt: serverTimestamp(),
  });
}

export async function toggleBadgeDefinitionActive(badgeId, isActive) {
  await updateDoc(doc(db, 'badge_definitions', badgeId), { isActive });
}
