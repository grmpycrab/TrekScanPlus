import {
  collection, doc, getDoc, setDoc, getDocs, onSnapshot,
  query, where, orderBy, limit, serverTimestamp, writeBatch, Timestamp,
} from 'firebase/firestore';
import { db } from '../config/firebase';

// ---------------------------------------------------------------------------
// Resolution type registry
// ---------------------------------------------------------------------------

export const RESOLUTION_TYPES = [
  { value: 'government',      label: 'Government Resolution' },
  { value: 'internal_policy', label: 'Internal Policy Update' },
  { value: 'seasonal',        label: 'Seasonal Adjustment' },
  { value: 'administrative',  label: 'Administrative Decision' },
  { value: 'initial',         label: 'Initial Setup' },
];

// ---------------------------------------------------------------------------
// Default pricing template  (field names kept identical to the Flutter model)
// ---------------------------------------------------------------------------

export const DEFAULT_PRICING = {
  basePricePerPerson: 3000,
  categories: {
    student: {
      displayName: 'Student',
      discount: 50,
      notes: '50% discount — with valid school ID',
    },
    senior_citizen: {
      displayName: 'Senior Citizen',
      discount: 20,
      notes: '20% discount — with valid senior ID',
    },
    davao_oriental_resident: {
      displayName: 'Davao Oriental Resident',
      discount: 50,
      notes: '50% discount',
    },
    ocfdo: {
      displayName: 'OCFDO Member',
      discount: 67,
      notes: '67% discount (≈ ₱1,000)',
    },
    children_8_15: {
      displayName: 'Children (8–15)',
      discount: 50,
      notes: '50% discount — must be with adult',
    },
    mfsm: {
      displayName: 'MFSM Member',
      discount: 25,
      notes: '25% discount',
    },
    outside_davao_oriental: {
      displayName: 'Outside Davao Oriental',
      discount: 0,
      notes: 'Full price',
    },
  },
  services: {
    porter:    500,
    guide:    1000,
    scientist: 1500,
  },
  seasonalRules: {
    offSeasonStart: '07-01',
    offSeasonEnd:   '09-30',
    allowedBookingTypes: ['special_trek', 'government_official', 'research_trek'],
  },
};

// ---------------------------------------------------------------------------
// Read — active version
// ---------------------------------------------------------------------------

/** Real-time subscription to the single active pricing version. */
export const subscribeToActivePricingVersion = (onData, onError) =>
  onSnapshot(
    query(
      collection(db, 'pricingVersions'),
      where('status', '==', 'active'),
      limit(1),
    ),
    (snap) =>
      onData(snap.empty ? null : { id: snap.docs[0].id, ...snap.docs[0].data() }),
    (err) => {
      console.error('subscribeToActivePricingVersion error:', err);
      onError?.(err);
    },
  );

/** One-shot fetch of the active pricing version. */
export const getActivePricingVersion = async () => {
  const snap = await getDocs(
    query(
      collection(db, 'pricingVersions'),
      where('status', '==', 'active'),
      limit(1),
    ),
  );
  if (snap.empty) return null;
  return { id: snap.docs[0].id, ...snap.docs[0].data() };
};

// ---------------------------------------------------------------------------
// Read — version history
// ---------------------------------------------------------------------------

/** Real-time subscription to all pricing versions, newest first. */
export const subscribeToPricingVersions = (onData, onError) =>
  onSnapshot(
    query(collection(db, 'pricingVersions'), orderBy('effectiveFrom', 'desc')),
    (snap) => onData(snap.docs.map((d) => ({ id: d.id, ...d.data() }))),
    (err) => {
      console.error('subscribeToPricingVersions error:', err);
      onError?.(err);
    },
  );

// ---------------------------------------------------------------------------
// Write — create a new pricing version (supersedes current active)
// ---------------------------------------------------------------------------

/**
 * Creates a new pricing version in `pricingVersions`.
 *
 * Steps (atomic batch write):
 *   1. Supersede the current active version (set status → 'superseded', effectiveUntil).
 *   2. Insert the new version with status → 'active'.
 *   3. Back-fill supersededBy on the old version.
 *
 * @param {Object} opts
 * @param {Object}        opts.pricing         - Full pricing data (DEFAULT_PRICING shape)
 * @param {Date|string}   opts.effectiveFrom   - When the new version takes effect
 * @param {string}        opts.resolutionRef   - Reference number / title (required)
 * @param {string}        opts.resolutionType  - One of RESOLUTION_TYPES[].value (required)
 * @param {string}        [opts.resolutionNotes] - Free-text remarks
 * @param {string}        opts.versionNumber   - Sequential version number (computed by caller)
 * @param {string}        opts.adminUid        - UID of the admin making the change
 * @returns {string}  ID of the new version document
 */
export const createPricingVersion = async ({
  pricing,
  effectiveFrom,
  resolutionRef,
  resolutionType,
  resolutionNotes = '',
  versionNumber,
  adminUid,
}) => {
  const effectiveFromTs =
    effectiveFrom instanceof Date
      ? Timestamp.fromDate(effectiveFrom)
      : Timestamp.fromDate(new Date(effectiveFrom));

  const batch   = writeBatch(db);
  const newRef  = doc(collection(db, 'pricingVersions'));

  // 1. Find and supersede the current active version
  const activeSnap = await getDocs(
    query(collection(db, 'pricingVersions'), where('status', '==', 'active'), limit(1)),
  );

  if (!activeSnap.empty) {
    batch.update(activeSnap.docs[0].ref, {
      status:        'superseded',
      effectiveUntil: effectiveFromTs,
      supersededAt:  serverTimestamp(),
      supersededBy:  newRef.id,
    });
  }

  // 2. Insert the new active version
  batch.set(newRef, {
    ...sanitisePricing(pricing),
    versionNumber:   versionNumber ?? 1,
    effectiveFrom:   effectiveFromTs,
    effectiveUntil:  null,
    status:          'active',
    resolutionRef,
    resolutionType,
    resolutionNotes,
    createdBy:       adminUid,
    createdAt:       serverTimestamp(),
    supersededAt:    null,
    supersededBy:    null,
  });

  await batch.commit();
  return newRef.id;
};

// ---------------------------------------------------------------------------
// Write — one-time migration from legacy pricingConfig/current
// ---------------------------------------------------------------------------

/**
 * If no `pricingVersions` documents exist yet, reads `pricingConfig/current`
 * and creates the first version from it.  Safe to call on every load.
 */
export const migrateFromLegacy = async (adminUid) => {
  // Guard: only migrate if the collection is empty
  const existingSnap = await getDocs(
    query(collection(db, 'pricingVersions'), limit(1)),
  );
  if (!existingSnap.empty) return;

  // Try to read the legacy document
  let legacyData = null;
  try {
    const legacySnap = await getDoc(doc(db, 'pricingConfig', 'current'));
    if (legacySnap.exists()) legacyData = legacySnap.data();
  } catch (_) { /* ignore — will use defaults */ }

  const pricing = legacyData ? sanitisePricing(legacyData) : sanitisePricing(DEFAULT_PRICING);

  await setDoc(doc(collection(db, 'pricingVersions')), {
    ...pricing,
    versionNumber:   1,
    effectiveFrom:   serverTimestamp(),
    effectiveUntil:  null,
    status:          'active',
    resolutionRef:   'Initial Setup',
    resolutionType:  'initial',
    resolutionNotes: legacyData
      ? 'Automatically migrated from legacy pricing configuration.'
      : 'First pricing version — created from system defaults.',
    createdBy:    adminUid ?? 'system',
    createdAt:    serverTimestamp(),
    supersededAt: null,
    supersededBy: null,
  });
};

// ---------------------------------------------------------------------------
// Calculation helpers  (mirror of Flutter PricingService)
// ---------------------------------------------------------------------------

/** Per-person price after applying category discount. */
export const calculateMemberPrice = (version, categoryKey) => {
  const base     = version?.basePricePerPerson ?? DEFAULT_PRICING.basePricePerPerson;
  const discount = version?.categories?.[categoryKey]?.discount ?? 0;
  return Math.round(base * (1 - discount / 100));
};

/** Returns true if the given JS Date falls within the configured off-season window. */
export const isOffSeason = (version, date) => {
  const rules = version?.seasonalRules ?? DEFAULT_PRICING.seasonalRules;
  const mmdd  = `${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  return mmdd >= rules.offSeasonStart && mmdd <= rules.offSeasonEnd;
};

/** Human-readable Firestore Timestamp → "May 1, 2026" */
export const formatVersionDate = (ts) => {
  if (!ts) return 'Present';
  const d = ts.toDate ? ts.toDate() : new Date(ts);
  return d.toLocaleDateString('en-PH', { year: 'numeric', month: 'short', day: 'numeric' });
};

/** Label for a resolution type value. */
export const resolutionTypeLabel = (value) =>
  RESOLUTION_TYPES.find((r) => r.value === value)?.label ?? value ?? '—';

// ---------------------------------------------------------------------------
// Private utilities
// ---------------------------------------------------------------------------

/** Strip Firestore Timestamps so the object can be stored cleanly. */
function sanitisePricing(obj) {
  return JSON.parse(
    JSON.stringify(obj, (_, v) =>
      v && typeof v === 'object' && typeof v.toDate === 'function' ? undefined : v,
    ),
  );
}
