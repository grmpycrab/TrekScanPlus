import { doc, getDoc, setDoc } from 'firebase/firestore';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { db } from '../config/firebase.js';
import app from '../config/firebase.js';

const ADMIN_SEED_EMAIL = import.meta.env.VITE_ADMIN_SEED_EMAIL;

/**
 * Returns true if the user is an admin.
 * Primary check: Firebase ID token custom claim (server-side, unforgeable).
 * Fallback: Firestore role field — used ONLY on the very first login before
 * the grantAdminClaim function has had a chance to stamp the custom claim.
 * The Firestore security rules themselves never use this fallback.
 */
export const checkIsAdmin = async (user) => {
  const tokenResult = await user.getIdTokenResult(true);
  if (tokenResult.claims.admin === true) return true;

  // First-login fallback: check Firestore role while claim propagates
  try {
    const snap = await getDoc(doc(db, 'users', user.uid));
    return snap.exists() && snap.data().role === 'admin';
  } catch (_) {
    return false;
  }
};

/**
 * Calls the grantAdminClaim Cloud Function to set the admin custom claim.
 * For the seed admin: self-grants on first login.
 * For existing admins: can pass { uid } to promote another user.
 */
export const ensureAdminClaim = async (targetUid = null) => {
  const functions = getFunctions(app, 'asia-southeast1');
  const grant = httpsCallable(functions, 'grantAdminClaim');
  await grant(targetUid ? { uid: targetUid } : {});
};

/**
 * If the signed-in user is the seeded admin email, ensure the Firestore
 * document carries role: 'admin'. Safe to call on every login.
 * (Used for display/profile purposes only — NOT for security decisions.)
 */
export const ensureAdminSeedDocument = async (user) => {
  if (user.email !== ADMIN_SEED_EMAIL) return;
  await setDoc(
    doc(db, 'users', user.uid),
    {
      role: 'admin',
      email: user.email,
      displayName: user.displayName ?? 'Administrator',
      firstName: 'Administrator',
      lastName: '',
    },
    { merge: true },
  );
};

/**
 * Fetch the full Firestore profile for an admin user.
 * Returns null if the document does not exist.
 */
export const getAdminProfile = async (uid) => {
  const snap = await getDoc(doc(db, 'users', uid));
  return snap.exists() ? { uid, ...snap.data() } : null;
};
