/**
 * add_test_climb_sessions.js
 *
 * Creates test ClimbSession documents in Firestore to exercise the
 * inactivity-reminder, auto-complete, and per-station stats features.
 *
 * Usage:
 *   node add_test_climb_sessions.js <userId>
 *
 * Prerequisites:
 *   npm install   (installs firebase-admin)
 *   serviceAccountKey.json must be present in this directory.
 *
 * Scenarios created
 * ─────────────────
 *  A  active_recent     — ongoing, last scan < 30 min ago     → no notification
 *  B  active_idle_2h    — ongoing, last scan exactly 3 h ago  → fires reminder
 *  C  active_idle_73h   — ongoing, last scan 73 h ago         → fires auto-complete
 *  D  completed_full    — completed session with full stats    → display only
 *
 * The session IDs are printed at the end so you can pass them to
 * delete_test_climb_sessions.js for cleanup.
 */

'use strict';

const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');
const serviceAccount = require('./serviceAccountKey.json');

// ─── Firebase init ──────────────────────────────────────────────────────────
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// ─── CLI arg ─────────────────────────────────────────────────────────────────
const userId = process.argv[2];
if (!userId) {
  console.error('\n❌  Usage: node add_test_climb_sessions.js <userId>\n');
  console.error('   Find your userId in Firestore → users collection,');
  console.error('   or copy it from the Firebase Auth console.\n');
  process.exit(1);
}

// ─── Station stubs (real IDs from stations_test.json) ─────────────────────
const STATIONS = [
  { id: '56okrkt0pb', name: 'UNESCO Marker',   elevation: 449,  distanceToNextKm: null },
  { id: 'hu2c5c0kfn', name: 'Crossing Stampa', elevation: 682,  distanceToNextKm: 0.7  },
  { id: 'um6j8dnii4', name: 'Puting Bato',     elevation: 696,  distanceToNextKm: null },
  { id: '3ko938o2gb', name: 'Lantawan 1',       elevation: 839,  distanceToNextKm: 4.0  },
  { id: '33ii1jrc5s', name: 'Camp 4',           elevation: 999,  distanceToNextKm: null },
];

// ─── Helpers ──────────────────────────────────────────────────────────────────
function iso(date) {
  return date.toISOString();
}

/** Simulate scanning a sequence of stations separated by [minutesBetween] min. */
function buildVisits(stations, startTime, minutesBetween) {
  const visits = [];
  let prevDistanceToNext = null;

  for (let i = 0; i < stations.length; i++) {
    const s = stations[i];
    const scannedAt = new Date(startTime.getTime() + i * minutesBetween * 60_000);

    // Duration at this station = gap to next scan (null for the last station).
    const durationAtStation =
      i < stations.length - 1 ? minutesBetween * 60 : null;

    // distanceFromPrevious = distanceToNextKm of the PREVIOUS station.
    const distanceFromPrevious = prevDistanceToNext ?? null;

    visits.push({
      stationId: s.id,
      stationName: s.name,
      scannedAt: iso(scannedAt),
      elevation: s.elevation,
      distanceFromPrevious,
      durationAtStation,
    });

    prevDistanceToNext = s.distanceToNextKm;
  }
  return visits;
}

function totalDistanceFromVisits(visits) {
  return visits.reduce((sum, v) => sum + (v.distanceFromPrevious ?? 0), 0);
}

// ─── Session builders ─────────────────────────────────────────────────────────
function makeSession(overrides) {
  const id = uuidv4();
  const now = new Date();

  return {
    id,
    name: `Test Trek — ${now.toISOString().slice(0, 10)}`,
    description: 'Created by add_test_climb_sessions.js',
    trekType: 'regular_trek',
    createdAt: iso(now),
    trekStartDate: null,
    trekEndDate: null,
    startedAt: null,
    completedAt: null,
    status: 'ongoing',
    visitedStations: [],
    totalDuration: null,
    totalDistance: null,
    lastActivityAt: null,
    syncPending: false,
    createdOffline: false,
    ...overrides,
  };
}

// ─── Scenario A: active, recent scan (< 30 min ago) ──────────────────────────
function scenarioA_active_recent(now) {
  const started = new Date(now.getTime() - 90 * 60_000);     // 1.5 h ago
  const lastScan = new Date(now.getTime() - 20 * 60_000);    // 20 min ago
  const visits = buildVisits(STATIONS.slice(0, 3), started, 25);

  return makeSession({
    name: '[A] Active — Recent (< 30 min)',
    startedAt: iso(started),
    lastActivityAt: iso(lastScan),
    visitedStations: visits,
    totalDistance: totalDistanceFromVisits(visits),
    syncPending: false,
  });
}

// ─── Scenario B: active, 3 h of inactivity → reminder should fire ────────────
function scenarioB_active_idle_2h(now) {
  const started = new Date(now.getTime() - 5 * 60 * 60_000); // 5 h ago
  const lastScan = new Date(now.getTime() - 3 * 60 * 60_000);// 3 h ago (> 2 h threshold)
  const visits = buildVisits(STATIONS.slice(0, 4), started, 30);

  return makeSession({
    name: '[B] Active — 3h Idle (reminder threshold)',
    startedAt: iso(started),
    lastActivityAt: iso(lastScan),
    visitedStations: visits,
    totalDistance: totalDistanceFromVisits(visits),
    syncPending: false,
  });
}

// ─── Scenario C: active, 73 h of inactivity → auto-complete should trigger ───
function scenarioC_active_idle_73h(now) {
  const started = new Date(now.getTime() - 75 * 60 * 60_000);  // 75 h ago
  const lastScan = new Date(now.getTime() - 73 * 60 * 60_000); // 73 h ago (> 72 h threshold)
  const visits = buildVisits(STATIONS.slice(0, 2), started, 45);

  return makeSession({
    name: '[C] Active — 73h Idle (auto-complete threshold)',
    startedAt: iso(started),
    lastActivityAt: iso(lastScan),
    visitedStations: visits,
    totalDistance: totalDistanceFromVisits(visits),
    syncPending: false,
  });
}

// ─── Scenario D: completed session with accurate stats ────────────────────────
function scenarioD_completed(now) {
  const started = new Date(now.getTime() - 8 * 60 * 60_000);     // 8 h ago
  const completed = new Date(now.getTime() - 30 * 60_000);        // 30 min ago
  const visits = buildVisits(STATIONS, started, 60);

  // Stamp durationAtStation for the last visit manually.
  const lastVisitScannedAt = new Date(
    started.getTime() + (STATIONS.length - 1) * 60 * 60_000
  );
  const lastDuration = Math.floor((completed - lastVisitScannedAt) / 1000);
  visits[visits.length - 1].durationAtStation = lastDuration;

  const totalDistKm = totalDistanceFromVisits(visits);
  const totalDurationSecs = Math.floor((completed - started) / 1000);

  return makeSession({
    name: '[D] Completed — Full Stats',
    startedAt: iso(started),
    completedAt: iso(completed),
    lastActivityAt: iso(completed),
    status: 'completed',
    visitedStations: visits,
    totalDuration: totalDurationSecs,
    totalDistance: totalDistKm,
    syncPending: false,
  });
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const now = new Date();
  const sessions = [
    scenarioA_active_recent(now),
    scenarioB_active_idle_2h(now),
    scenarioC_active_idle_73h(now),
    scenarioD_completed(now),
  ];

  const collectionRef = db.collection('users').doc(userId).collection('climbs');

  console.log(`\n📂  Writing to: users/${userId}/climbs/\n`);

  const createdIds = [];
  for (const session of sessions) {
    await collectionRef.doc(session.id).set(session);
    createdIds.push(session.id);
    console.log(`  ✅  ${session.name}`);
    console.log(`      id: ${session.id}`);
  }

  console.log('\n─────────────────────────────────────────────────────────────');
  console.log('📋  Session IDs (copy for cleanup):');
  console.log(`    ${createdIds.join(' ')}`);
  console.log('\n🧹  To delete: node delete_test_climb_sessions.js', userId, createdIds.join(' '));
  console.log('─────────────────────────────────────────────────────────────\n');

  console.log('✔   Done. Restart the app and wait for the inactivity timer');
  console.log('    (fires every 30 min) to observe notifications and auto-complete.\n');

  await admin.app().delete();
}

main().catch((err) => {
  console.error('❌  Error:', err.message);
  process.exit(1);
});
