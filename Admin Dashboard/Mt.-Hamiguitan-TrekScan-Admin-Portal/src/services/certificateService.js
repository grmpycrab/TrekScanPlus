import {
  collection,
  doc,
  getDocs,
  setDoc,
  query,
  where,
  orderBy,
  Timestamp,
} from 'firebase/firestore';
import { db } from '../config/firebase';

// Firestore paths mirror what the Flutter ECertificateService uses:
//   users/{userId}/certificates/{certificateId}
// Climb completion data is stored under climb_sessions collection.

const CERT_TYPE = {
  camp3:         { key: 'camp3',         title: 'Camp 3 Achievement',    description: 'Reached Camp 3 (Station 8) of Mt. Hamiguitan' },
  fullTrek:      { key: 'fullTrek',      title: 'Full Trek Completion',   description: 'Completed the full Mt. Hamiguitan trek (13+ stations)' },
  peakConqueror: { key: 'peakConqueror', title: 'Peak Conqueror',         description: 'Conquered the peak of Mt. Hamiguitan (Station 14)' },
};

export { CERT_TYPE };

/** Generate a certificate ID in the same format as the Flutter service. */
const generateCertId = () => {
  const ts = Date.now();
  const rnd = Math.floor(Math.random() * 1000);
  return `CERT_${ts}_${rnd}`;
};

/** Generate a verification code (XXX-XXXX-XXXX). */
const generateVerificationCode = () => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 11; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return `${code.slice(0, 3)}-${code.slice(3, 7)}-${code.slice(7, 11)}`;
};

/**
 * Fetch all users who have a completed climb session.
 * Returns an array of { userId, user, session, stationsVisited, eligibleTypes, issuedTypes }.
 */
export const getEligibleUsers = async () => {
  try {
    // Fetch all completed climb sessions
    const sessionsSnap = await getDocs(
      query(collection(db, 'climb_sessions'), where('status', '==', 'completed')),
    );

    if (sessionsSnap.empty) return [];

    // Group by userId — keep the most-visited session per user
    const byUser = {};
    for (const d of sessionsSnap.docs) {
      const s = { id: d.id, ...d.data() };
      const uid = s.userId;
      if (!uid) continue;
      const visited = Array.isArray(s.visitedStations) ? s.visitedStations.length : (s.stationsVisited ?? 0);
      if (!byUser[uid] || visited > byUser[uid].stationsVisited) {
        byUser[uid] = { ...s, stationsVisited: visited };
      }
    }

    // Fetch user profiles and existing certificates
    const results = await Promise.all(
      Object.entries(byUser).map(async ([userId, session]) => {
        // User profile
        let user = null;
        try {
          const userSnap = await getDocs(
            query(collection(db, 'users'), where('__name__', '==', userId)),
          );
          if (!userSnap.empty) user = { id: userId, ...userSnap.docs[0].data() };
        } catch (_) {}

        // Already-issued certificates for this user
        const certsSnap = await getDocs(
          collection(db, 'users', userId, 'certificates'),
        );
        const issuedTypes = certsSnap.docs.map((c) => c.data().certificateType);

        // Determine eligibility
        const eligibleTypes = [];
        const visited = session.visitedStations ?? [];
        const stationCount = typeof visited === 'number' ? visited : visited.length;
        const visitedNames = Array.isArray(visited) ? visited.map((s) => (typeof s === 'string' ? s : s?.name ?? '')).join(' ') : '';

        const hasPeak = visitedNames.includes('Station 14') || visitedNames.includes('Peak');
        const hasCamp3 = visitedNames.includes('Camp 3') || visitedNames.includes('Station 8') || stationCount >= 8;
        const hasFullTrek = stationCount >= 13;

        if (hasPeak)     eligibleTypes.push('peakConqueror');
        if (hasFullTrek) eligibleTypes.push('fullTrek');
        if (hasCamp3)    eligibleTypes.push('camp3');

        return { userId, user, session, stationsVisited: stationCount, eligibleTypes, issuedTypes };
      }),
    );

    // Only return users eligible for at least one certificate
    return results.filter((r) => r.eligibleTypes.length > 0);
  } catch (error) {
    console.error('certificateService.getEligibleUsers error:', error);
    throw error;
  }
};

/**
 * Issue a certificate to a user.
 * Writes to users/{userId}/certificates/{certId} — same path the Flutter app reads.
 *
 * @param {string} userId
 * @param {string} certType - 'camp3' | 'fullTrek' | 'peakConqueror'
 * @param {string} trekkerName - display name for the certificate
 * @param {Object} session - the climb session data (stationsVisited, totalDistance, etc.)
 * @param {string} issuedBy - admin name
 */
export const issueCertificate = async (userId, certType, trekkerName, session = {}, issuedBy = 'Admin') => {
  if (!CERT_TYPE[certType]) throw new Error(`Unknown certificate type: ${certType}`);

  const certId = generateCertId();
  const verificationCode = generateVerificationCode();
  const now = Timestamp.now();

  const cert = {
    certificateId: certId,
    userId,
    trekkerName: trekkerName || 'Trekker',
    certificateType: certType,
    dateEarned: now,
    stationsVisited: session.stationsVisited ?? 0,
    totalDistance: session.totalDistance ?? 0,
    totalTimeMinutes: session.totalTimeMinutes ?? 0,
    trekStartDate: session.startDate ?? null,
    trekEndDate: session.endDate ?? null,
    isVerified: true,
    verificationCode,
    issuedBy,
    issuedAt: now,
    createdAt: now,
    lastUpdated: now,
  };

  await setDoc(doc(db, 'users', userId, 'certificates', certId), cert);
  return cert;
};

/**
 * Fetch all certificates across all users (admin view).
 * Returns flat array sorted newest first.
 */
export const getAllCertificates = async () => {
  try {
    // We need to query across users — Firestore doesn't support
    // collection-group queries on subcollections without an index.
    // Use collectionGroup if available, otherwise fetch per user.
    const { collectionGroup } = await import('firebase/firestore');
    const snap = await getDocs(
      query(collectionGroup(db, 'certificates'), orderBy('createdAt', 'desc')),
    );
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  } catch (error) {
    console.error('certificateService.getAllCertificates error:', error);
    throw error;
  }
};

/**
 * Fetch certificates for a single user.
 */
export const getCertificatesByUser = async (userId) => {
  try {
    const snap = await getDocs(
      query(collection(db, 'users', userId, 'certificates'), orderBy('createdAt', 'desc')),
    );
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  } catch (error) {
    console.error('certificateService.getCertificatesByUser error:', error);
    throw error;
  }
};

/** Format a Firestore Timestamp or seconds-based object to a readable date string. */
export const formatCertDate = (ts) => {
  if (!ts) return '—';
  const date = ts instanceof Timestamp ? ts.toDate() : ts?.seconds ? new Date(ts.seconds * 1000) : new Date(ts);
  return date.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
};
