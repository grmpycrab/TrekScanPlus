/**
 * delete_test_climb_sessions.js
 *
 * Deletes test ClimbSession documents created by add_test_climb_sessions.js.
 *
 * Usage:
 *   node delete_test_climb_sessions.js <userId> [sessionId1 sessionId2 ...]
 *
 *   • With session IDs: deletes only those specific sessions.
 *   • Without session IDs: deletes ALL sessions whose name starts with "[A]",
 *     "[B]", "[C]", or "[D]" (safe prefix used by the add script).
 *
 * Examples:
 *   node delete_test_climb_sessions.js abc123
 *   node delete_test_climb_sessions.js abc123 uuid-1 uuid-2 uuid-3 uuid-4
 */

'use strict';

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

const userId = process.argv[2];
if (!userId) {
  console.error('\n❌  Usage: node delete_test_climb_sessions.js <userId> [sessionId...]\n');
  process.exit(1);
}

const specificIds = process.argv.slice(3);

async function main() {
  const collectionRef = db.collection('users').doc(userId).collection('climbs');

  let toDelete = [];

  if (specificIds.length > 0) {
    toDelete = specificIds;
    console.log(`\n🗑   Deleting ${toDelete.length} specific session(s)...\n`);
  } else {
    // Find all test sessions by name prefix.
    console.log('\n🔍  No session IDs provided — scanning for test sessions...\n');
    const snapshot = await collectionRef
      .where('description', '==', 'Created by add_test_climb_sessions.js')
      .get();

    if (snapshot.empty) {
      console.log('   Nothing found. All clean.\n');
      await admin.app().delete();
      return;
    }
    toDelete = snapshot.docs.map((d) => d.id);
    console.log(`   Found ${toDelete.length} test session(s).\n`);
  }

  for (const id of toDelete) {
    await collectionRef.doc(id).delete();
    console.log(`  ✅  Deleted: ${id}`);
  }

  console.log(`\n✔   ${toDelete.length} session(s) removed from users/${userId}/climbs/\n`);
  await admin.app().delete();
}

main().catch((err) => {
  console.error('❌  Error:', err.message);
  process.exit(1);
});
