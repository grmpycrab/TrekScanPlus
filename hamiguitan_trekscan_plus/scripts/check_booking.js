/**
 * Check specific booking and its buffer day
 * 
 * Usage:
 * node check_booking.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin (reuse if already initialized)
if (!admin.apps.length) {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

function formatDateKey(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

async function checkBooking() {
    console.log('🔍 Checking November 30 booking and December 1 buffer day\n');

    try {
        // Check for Nov 30 bookings
        const nov30Start = new Date('2025-11-30T00:00:00Z');
        const nov30End = new Date('2025-11-30T23:59:59Z');

        console.log('📋 Searching for bookings on November 30, 2025...');
        const bookingsSnapshot = await db.collection('bookings')
            .where('trekDate', '>=', admin.firestore.Timestamp.fromDate(nov30Start))
            .where('trekDate', '<=', admin.firestore.Timestamp.fromDate(nov30End))
            .get();

        console.log(`Found ${bookingsSnapshot.size} booking(s) on Nov 30\n`);

        if (bookingsSnapshot.size === 0) {
            console.log('❌ No bookings found for November 30, 2025');
            return;
        }

        for (const doc of bookingsSnapshot.docs) {
            const data = doc.data();
            const trekDate = data.trekDate?.toDate();
            const status = data.status;

            console.log('📄 Booking Details:');
            console.log(`   ID: ${doc.id}`);
            console.log(`   Trek Date: ${trekDate ? formatDateKey(trekDate) : 'N/A'}`);
            console.log(`   Status: ${status}`);
            console.log(`   Porters: ${data.numberOfPorters || 0}`);

            if (status !== 'approved') {
                console.log(`   ⚠️  Status is "${status}" - buffer days only created for approved bookings`);
            }

            // Check buffer day (Dec 1)
            const dayAfter = new Date(trekDate);
            dayAfter.setDate(dayAfter.getDate() + 1);
            const bufferDateKey = formatDateKey(dayAfter);

            console.log(`\n🔍 Checking buffer day: ${bufferDateKey}`);

            const bufferDoc = await db.collection('calendar_config').doc(bufferDateKey).get();

            if (bufferDoc.exists) {
                const bufferData = bufferDoc.data();
                console.log('  Buffer day EXISTS in calendar_config:');
                console.log(`   Date: ${bufferDateKey}`);
                console.log(`   Closed: ${bufferData.isClosed}`);
                console.log(`   Max Slots: ${bufferData.maxSlots}`);
                console.log(`   Reason: ${bufferData.reason}`);
                console.log(`   Is Trek Down Day: ${bufferData.isTrekDownDay}`);
                console.log(`   Original Trek: ${bufferData.originalTrekDate}`);
            } else {
                console.log(`❌ Buffer day DOES NOT EXIST in calendar_config`);
                console.log(`\n💡 Creating buffer day now...`);

                if (status === 'approved') {
                    await db.collection('calendar_config').doc(bufferDateKey).set({
                        date: admin.firestore.Timestamp.fromDate(dayAfter),
                        isClosed: true,
                        maxSlots: 0,
                        reason: 'Trek down day - Trekkers descending',
                        customNote: `Blocked due to approved trek starting on ${formatDateKey(trekDate)}`,
                        isTrekDownDay: true,
                        originalTrekDate: formatDateKey(trekDate),
                        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
                    });
                    console.log(`  Buffer day created: ${bufferDateKey}`);
                } else {
                    console.log(`⚠️  Skipping - booking is not approved`);
                }
            }
            console.log('\n' + '='.repeat(60) + '\n');
        }

        // Also check all approved bookings to see if any are missing buffer days
        console.log('🔍 Checking ALL approved bookings for missing buffer days...\n');
        const allApproved = await db.collection('bookings')
            .where('status', '==', 'approved')
            .get();

        let missingCount = 0;
        for (const doc of allApproved.docs) {
            const data = doc.data();
            const trekDate = data.trekDate?.toDate();
            if (!trekDate) continue;

            const dayAfter = new Date(trekDate);
            dayAfter.setDate(dayAfter.getDate() + 1);
            const bufferDateKey = formatDateKey(dayAfter);

            const bufferDoc = await db.collection('calendar_config').doc(bufferDateKey).get();

            if (!bufferDoc.exists || !bufferDoc.data()?.isTrekDownDay) {
                console.log(`❌ Missing buffer for trek on ${formatDateKey(trekDate)} → ${bufferDateKey}`);
                missingCount++;
            }
        }

        if (missingCount > 0) {
            console.log(`\n⚠️  Found ${missingCount} approved bookings without buffer days`);
            console.log(`💡 Run "node sync_buffer_days.js" to fix this`);
        } else {
            console.log(`  All approved bookings have buffer days`);
        }

    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }

    process.exit(0);
}

checkBooking();
