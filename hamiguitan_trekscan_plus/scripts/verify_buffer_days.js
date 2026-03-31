/**
 * Verify All Buffer Days for Advance Bookings
 * 
 * This script checks that ALL approved bookings (including advance bookings)
 * have corresponding buffer days in calendar_config.
 * 
 * Usage:
 * node verify_buffer_days.js
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

async function verifyBufferDays() {
    console.log('🔍 Verifying Buffer Days for All Bookings\n');

    try {
        // Get all approved bookings
        const bookingsSnapshot = await db.collection('bookings')
            .where('status', '==', 'approved')
            .get();

        console.log(`📋 Found ${bookingsSnapshot.size} approved bookings\n`);

        if (bookingsSnapshot.size === 0) {
            console.log('ℹ️  No approved bookings found. Nothing to verify.');
            process.exit(0);
        }

        const results = {
            total: 0,
            withBuffer: 0,
            missingBuffer: 0,
            current: 0,
            advance: 0,
            missing: []
        };

        const now = new Date();
        const currentMonth = now.getMonth();
        const currentYear = now.getFullYear();

        // Sort bookings by date for better display
        const sortedDocs = bookingsSnapshot.docs.sort((a, b) => {
            const dateA = a.data().trekDate?.toDate() || new Date(0);
            const dateB = b.data().trekDate?.toDate() || new Date(0);
            return dateA.getTime() - dateB.getTime();
        });

        for (const doc of sortedDocs) {
            const data = doc.data();
            const trekDate = data.trekDate?.toDate();

            if (!trekDate) continue;

            results.total++;

            // Check if this is an advance booking
            const isAdvance = trekDate.getFullYear() > currentYear ||
                (trekDate.getFullYear() === currentYear && trekDate.getMonth() > currentMonth);

            if (isAdvance) {
                results.advance++;
            } else {
                results.current++;
            }

            const trekDateKey = formatDateKey(trekDate);

            // Calculate buffer day (day after)
            const dayAfter = new Date(trekDate);
            dayAfter.setDate(dayAfter.getDate() + 1);
            const bufferDateKey = formatDateKey(dayAfter);

            // Check if buffer day exists
            const bufferDoc = await db.collection('calendar_config').doc(bufferDateKey).get();

            if (bufferDoc.exists && bufferDoc.data().isTrekDownDay) {
                results.withBuffer++;
                const bufferData = bufferDoc.data();
                console.log(`  ${trekDateKey} → ${bufferDateKey} ${isAdvance ? '(ADVANCE)' : '(CURRENT)'}`);

                // Verify it points to correct trek
                if (bufferData.originalTrekDate !== trekDateKey) {
                    console.log(`   ⚠️  WARNING: Points to ${bufferData.originalTrekDate} instead of ${trekDateKey}`);
                }
            } else {
                results.missingBuffer++;
                results.missing.push({
                    bookingId: doc.id,
                    trekDate: trekDateKey,
                    bufferDate: bufferDateKey,
                    isAdvance
                });
                console.log(`❌ ${trekDateKey} → ${bufferDateKey} MISSING ${isAdvance ? '(ADVANCE)' : '(CURRENT)'}`);
            }
        }

        console.log('\n' + '='.repeat(60));
        console.log('📊 Verification Summary:');
        console.log('='.repeat(60));
        console.log(`Total approved bookings:     ${results.total}`);
        console.log(`  - Current/past month:      ${results.current}`);
        console.log(`  - Advance bookings:        ${results.advance}`);
        console.log(`\nBuffer day status:`);
        console.log(`    With buffer days:       ${results.withBuffer}`);
        console.log(`  ❌ Missing buffer days:    ${results.missingBuffer}`);

        if (results.missingBuffer > 0) {
            console.log('\n⚠️  MISSING BUFFER DAYS:');
            results.missing.forEach(item => {
                console.log(`   - Booking ${item.bookingId}`);
                console.log(`     Trek: ${item.trekDate}, Buffer: ${item.bufferDate} ${item.isAdvance ? '(ADVANCE)' : ''}`);
            });
            console.log('\n💡 Fix: Run "node sync_buffer_days.js" to create missing buffer days');
        } else {
            console.log('\n✨ All bookings have buffer days! System is in sync.');
        }

        console.log('\n📅 Date Range Coverage:');
        if (sortedDocs.length > 0) {
            const firstBooking = sortedDocs[0].data().trekDate?.toDate();
            const lastBooking = sortedDocs[sortedDocs.length - 1].data().trekDate?.toDate();

            if (firstBooking && lastBooking) {
                console.log(`   Earliest: ${formatDateKey(firstBooking)}`);
                console.log(`   Latest:   ${formatDateKey(lastBooking)}`);

                const monthsDiff = (lastBooking.getFullYear() - firstBooking.getFullYear()) * 12 +
                    (lastBooking.getMonth() - firstBooking.getMonth());
                console.log(`   Span:     ${monthsDiff} months`);
            }
        }

    } catch (error) {
        console.error('❌ Error verifying buffer days:', error);
        process.exit(1);
    }

    process.exit(0);
}

// Run verification
verifyBufferDays();
