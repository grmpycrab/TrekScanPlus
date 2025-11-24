const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testCancellation() {
    try {
        console.log('\n🧪 Testing booking cancellation and buffer day removal...\n');

        // Get the Nov 24 booking
        const bookingId = 'TpAte3rpmkJS8nAYot3m';

        console.log(`📋 Booking ID: ${bookingId}`);

        // Get current booking status
        const bookingDoc = await db.collection('bookings').doc(bookingId).get();

        if (!bookingDoc.exists) {
            console.log('❌ Booking not found');
            return;
        }

        const bookingData = bookingDoc.data();
        console.log(`Current status: ${bookingData.status}`);
        console.log(`Trek date: ${bookingData.trekDate?.toDate()}`);

        // Check current buffer day
        const bufferDoc = await db.collection('calendar_config').doc('2025-11-25').get();
        console.log(`\nBuffer day (2025-11-25) exists: ${bufferDoc.exists}`);

        if (bufferDoc.exists) {
            const bufferData = bufferDoc.data();
            console.log(`  - Is Trek Down Day: ${bufferData.isTrekDownDay}`);
            console.log(`  - Original Trek Date: ${bufferData.originalTrekDate}`);
        }

        // Simulate cancellation
        console.log('\n🔄 Simulating cancellation...');
        await db.collection('bookings').doc(bookingId).update({
            status: 'cancelled',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log('✅ Booking status updated to cancelled');
        console.log('\n⏳ Waiting 3 seconds for Cloud Function to process...\n');

        await new Promise(resolve => setTimeout(resolve, 3000));

        // Check if buffer day was removed
        const bufferDocAfter = await db.collection('calendar_config').doc('2025-11-25').get();
        console.log(`Buffer day (2025-11-25) exists: ${bufferDocAfter.exists}`);

        if (bufferDocAfter.exists) {
            console.log('⚠️  Buffer day still exists (may have other bookings on same date)');
        } else {
            console.log('✅ Buffer day successfully removed!');
        }

        // Restore booking to approved for further testing
        console.log('\n🔄 Restoring booking to approved status...');
        await db.collection('bookings').doc(bookingId).update({
            status: 'approved',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log('⏳ Waiting 3 seconds for Cloud Function to recreate buffer day...\n');
        await new Promise(resolve => setTimeout(resolve, 3000));

        const bufferDocRestored = await db.collection('calendar_config').doc('2025-11-25').get();
        console.log(`Buffer day (2025-11-25) recreated: ${bufferDocRestored.exists}`);

        if (bufferDocRestored.exists) {
            console.log('✅ Buffer day successfully recreated!');
        } else {
            console.log('❌ Buffer day not recreated - check function logs');
        }

        console.log('\n✅ Test complete!\n');

    } catch (error) {
        console.error('Error:', error);
    } finally {
        process.exit(0);
    }
}

testCancellation();
