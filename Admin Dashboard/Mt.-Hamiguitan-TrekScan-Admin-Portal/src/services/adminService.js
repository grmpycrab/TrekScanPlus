import { doc, getDoc, setDoc } from 'firebase/firestore';
import { db } from '../config/firebase.js';

const ADMIN_SEED_EMAIL = import.meta.env.VITE_ADMIN_SEED_EMAIL;

/**
 * Returns true if the Firestore users/{uid} document has role === 'admin'.
 */
export const checkIsAdmin = async (uid) => {
  const snap = await getDoc(doc(db, 'users', uid));
  if (!snap.exists()) return false;
  return snap.data().role === 'admin';
};

/**
 * If the signed-in user is the seeded admin email, ensure the Firestore
 * document carries role: 'admin'. Safe to call on every login.
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
