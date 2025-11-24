const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkTimezoneIssue() {
    try {
        const bookingId = 'TpAte3rpmkJS8nAYot3m';
        const doc = await db.collection('bookings').doc(bookingId).get();

        if (!doc.exists) {
            console.log('Booking not found');
            return;
        }

        const data = doc.data();
        const timestamp = data.trekDate;

        console.log('\n🔍 Analyzing timezone handling...\n');
        console.log('Firestore Timestamp:', timestamp);
        console.log('Timestamp seconds:', timestamp.seconds);
        console.log('Timestamp nanoseconds:', timestamp.nanoseconds);

        const date = timestamp.toDate();
        console.log('\nConverted to JS Date:', date);
        console.log('toString():', date.toString());
        console.log('toISOString():', date.toISOString());
        console.log('toUTCString():', date.toUTCString());

        console.log('\nLocal timezone methods:');
        console.log('getFullYear():', date.getFullYear());
        console.log('getMonth():', date.getMonth());
        console.log('getDate():', date.getDate());

        console.log('\nUTC timezone methods:');
        console.log('getUTCFullYear():', date.getUTCFullYear());
        console.log('getUTCMonth():', date.getUTCMonth());
        console.log('getUTCDate():', date.getUTCDate());

        console.log('\nDate key formats:');
        const localKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
        const utcKey = `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}-${String(date.getUTCDate()).padStart(2, '0')}`;

        console.log('Local date key:', localKey);
        console.log('UTC date key:', utcKey);

        // Check which buffer days exist
        console.log('\n🔍 Checking buffer days in calendar_config...\n');

        const nov24 = await db.collection('calendar_config').doc('2025-11-24').get();
        const nov25 = await db.collection('calendar_config').doc('2025-11-25').get();

        console.log('2025-11-24 exists:', nov24.exists);
        if (nov24.exists) {
            const data = nov24.data();
            console.log('  - isTrekDownDay:', data.isTrekDownDay);
            console.log('  - originalTrekDate:', data.originalTrekDate);
        }

        console.log('\n2025-11-25 exists:', nov25.exists);
        if (nov25.exists) {
            const data = nov25.data();
            console.log('  - isTrekDownDay:', data.isTrekDownDay);
            console.log('  - originalTrekDate:', data.originalTrekDate);
        }

    } catch (error) {
        console.error('Error:', error);
    } finally {
        process.exit(0);
    }
}

checkTimezoneIssue();
