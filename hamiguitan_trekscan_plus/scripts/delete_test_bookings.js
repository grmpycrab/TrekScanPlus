/**
 * Firebase Admin Script to Delete Test Bookings
 * 
 * This script deletes all test bookings created by add_test_bookings.js
 * 
 * Usage:
 * 1. Run: node scripts/delete_test_bookings.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Path to your service account key file
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

async function main() {
    console.log('🗑️  Starting test booking deletion script...\n');

    try {
        // Initialize Firebase Admin
        const serviceAccount = require(serviceAccountPath);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });

        const db = admin.firestore();

        // Find all test bookings (identified by notes containing "Test booking")
        console.log('🔍 Searching for test bookings...\n');

        const querySnapshot = await db
            .collection('bookings')
            .where('notes', '>=', 'Test booking')
            .where('notes', '<=', 'Test booking\uf8ff')
            .get();

        if (querySnapshot.empty) {
            console.log('✅ No test bookings found.\n');
            return;
        }

        console.log(`📊 Found ${querySnapshot.size} test bookings\n`);

        // Confirm before deleting
        console.log('⚠️  This will DELETE all test bookings.');
        console.log('Press Ctrl+C to cancel, or wait 3 seconds to continue...\n');
        await new Promise(resolve => setTimeout(resolve, 3000));

        // Delete in batches (Firestore batch limit is 500)
        const batchSize = 500;
        let deletedCount = 0;

        for (let i = 0; i < querySnapshot.docs.length; i += batchSize) {
            const batch = db.batch();
            const batchDocs = querySnapshot.docs.slice(i, i + batchSize);

            batchDocs.forEach(doc => {
                batch.delete(doc.ref);
            });

            await batch.commit();
            deletedCount += batchDocs.length;

            console.log(`🗑️  Deleted ${deletedCount}/${querySnapshot.size} bookings...`);
        }

        console.log('\n✨ Completed!\n');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log(`✅ Successfully deleted ${deletedCount} test bookings`);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    } catch (error) {
        console.error('❌ Error:', error.message);
        console.error('\n💡 Troubleshooting:');
        console.error('1. Make sure serviceAccountKey.json exists in the scripts folder');
        console.error('2. Ensure Firebase Admin SDK is installed: npm install firebase-admin\n');
    } finally {
        process.exit(0);
    }
}

main();
