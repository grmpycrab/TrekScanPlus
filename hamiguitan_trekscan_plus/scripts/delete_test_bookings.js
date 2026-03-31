/**
 * Firebase Admin Script to Delete Test Bookings
 * 
 * This script deletes all test bookings created by add_test_bookings.js
 * 
 * Prerequisites:
 * 1. Install Firebase Admin SDK: npm install firebase-admin
 * 2. serviceAccountKey.json must exist in the scripts folder
 * 
 * Usage:
 * Run: node scripts/delete_test_bookings.js
 */

const admin = require('firebase-admin');
const path = require('path');

// ============================================
// CONFIGURATION
// ============================================

// Path to your service account key file
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

// Target date for test bookings (YYYY-MM-DD) - should match add_test_bookings.js
const TARGET_DATE = new Date('2025-11-26');

// User ID that was used for test bookings
const TEST_USER_ID = 'mvV3LeGH0IemtxgCFe8O0dz9MRk1';

// ============================================

async function main() {
    console.log('🗑️  Starting test booking deletion script...\n');

    try {
        // Initialize Firebase Admin
        const serviceAccount = require(serviceAccountPath);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });

        const db = admin.firestore();

        console.log('📅 Target Date:', TARGET_DATE.toISOString().split('T')[0]);
        console.log('👤 User ID:', TEST_USER_ID);
        console.log('');

        // Find all test bookings
        console.log('🔍 Searching for test bookings...\n');

        const querySnapshot = await db
            .collection('bookings')
            .where('userId', '==', TEST_USER_ID)
            .where('trekDate', '==', admin.firestore.Timestamp.fromDate(TARGET_DATE))
            .get();

        if (querySnapshot.empty) {
            console.log('  No test bookings found. Nothing to delete.\n');
            return;
        }

        console.log(`📋 Found ${querySnapshot.size} test booking(s)\n`);

        // Confirm before proceeding
        console.log('⚠️  This will delete', querySnapshot.size, 'booking(s).');
        console.log('Press Ctrl+C to cancel, or wait 3 seconds to continue...\n');
        await new Promise(resolve => setTimeout(resolve, 3000));

        // Delete bookings in batches (Firestore batch limit is 500)
        let deleteCount = 0;
        let failCount = 0;
        const batchSize = 500;
        let batch = db.batch();
        let operationCount = 0;

        console.log('🗑️  Deleting bookings...\n');

        for (const doc of querySnapshot.docs) {
            try {
                batch.delete(doc.ref);
                operationCount++;
                deleteCount++;

                // Commit batch when reaching limit
                if (operationCount >= batchSize) {
                    await batch.commit();
                    console.log(`  Deleted ${deleteCount} bookings...`);
                    batch = db.batch();
                    operationCount = 0;
                }
            } catch (e) {
                failCount++;
                console.log(`❌ Error deleting booking ${doc.id}:`, e.message);
            }
        }

        // Commit remaining operations
        if (operationCount > 0) {
            await batch.commit();
        }

        console.log('  Bookings deleted!');

        // Delete buffer days
        console.log('\n📅 Cleaning up buffer days (trek down days)...');

        const dayAfter = new Date(TARGET_DATE);
        dayAfter.setDate(dayAfter.getDate() + 1);
        const bufferDateKey = `${dayAfter.getFullYear()}-${String(dayAfter.getMonth() + 1).padStart(2, '0')}-${String(dayAfter.getDate()).padStart(2, '0')}`;

        const bufferRef = db.collection('calendar_config').doc(bufferDateKey);
        const bufferDoc = await bufferRef.get();

        if (bufferDoc.exists) {
            const data = bufferDoc.data();
            // Only delete if it's a trek down day related to our target date
            if (data.isTrekDownDay) {
                await bufferRef.delete();
                console.log(`  Deleted buffer day: ${bufferDateKey}`);
            } else {
                console.log(`ℹ️  Buffer day exists but is not a trek down day - skipping`);
            }
        } else {
            console.log(`ℹ️  No buffer day found for ${bufferDateKey}`);
        }

        console.log('\n✨ Cleanup completed!\n');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('📊 Results:');
        console.log(`     Deleted: ${deleteCount}`);
        console.log(`   ❌ Failed: ${failCount}`);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        // Verify deletion
        const verifySnapshot = await db
            .collection('bookings')
            .where('userId', '==', TEST_USER_ID)
            .where('trekDate', '==', admin.firestore.Timestamp.fromDate(TARGET_DATE))
            .get();

        if (verifySnapshot.empty) {
            console.log('  Verification: All test bookings have been deleted\n');
        } else {
            console.log(`⚠️  Warning: ${verifySnapshot.size} booking(s) still remain\n`);
        }

        // Show current status
        const allBookingsSnapshot = await db
            .collection('bookings')
            .where('trekDate', '==', admin.firestore.Timestamp.fromDate(TARGET_DATE))
            .get();

        let totalSlotsUsed = 0;
        allBookingsSnapshot.forEach(doc => {
            const data = doc.data();
            if (data.status === 'approved') {
                const porters = data.numberOfPorters || 0;
                totalSlotsUsed += 1 + porters;
            }
        });

        console.log(`📈 Current Status for ${TARGET_DATE.toISOString().split('T')[0]}:`);
        console.log(`   📋 Total bookings: ${allBookingsSnapshot.size}`);
        console.log(`   💺 Slots used: ${totalSlotsUsed} / 30`);

        if (totalSlotsUsed >= 30) {
            console.log('   🔴 Date is FULL (≥30 slots)');
        } else if (totalSlotsUsed >= 25) {
            console.log('   🟡 Date is CRITICAL (≥25 slots)');
        } else if (totalSlotsUsed > 0) {
            console.log('   🟢 Date has available slots');
        } else {
            console.log('     Date is completely empty');
        }

        console.log('');

    } catch (error) {
        console.error('❌ Error:', error.message);
        console.error('\n💡 Troubleshooting:');
        console.error('1. Make sure serviceAccountKey.json exists in the scripts folder');
        console.error('2. Verify TEST_USER_ID matches the one used in add_test_bookings.js');
        console.error('3. Ensure Firebase Admin SDK is installed: npm install firebase-admin\n');
    } finally {
        process.exit(0);
    }
}

main();
