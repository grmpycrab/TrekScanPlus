/**
 * Sync Trek Down Days (Buffer Days) in Firestore
 * 
 * This script synchronizes buffer days in calendar_config based on
 * approved bookings. It ensures consistency between bookings and
 * calendar configuration.
 * 
 * Run this:
 * - After initial setup
 * - When you suspect buffer days are out of sync
 * - Periodically (e.g., weekly) as maintenance
 * 
 * Usage:
 * node sync_buffer_days.js
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

async function syncBufferDays() {
    console.log('🔄 Syncing trek down days (buffer days)...\n');

    try {
        // Step 1: Get all approved bookings
        console.log('📋 Fetching approved bookings...');
        const bookingsSnapshot = await db.collection('bookings')
            .where('status', '==', 'approved')
            .get();

        console.log(`  Found ${bookingsSnapshot.size} approved bookings\n`);

        // Step 2: Calculate all buffer days that should exist
        const trekDownDays = new Map();

        for (const doc of bookingsSnapshot.docs) {
            const data = doc.data();
            const trekDate = data.trekDate?.toDate();

            if (!trekDate) {
                console.log(`⚠️  Skipping booking ${doc.id} - no trek date`);
                continue;
            }

            // Calculate day after (trek down day)
            const dayAfter = new Date(trekDate);
            dayAfter.setDate(dayAfter.getDate() + 1);
            const dateKey = formatDateKey(dayAfter);

            // Store buffer day info
            if (!trekDownDays.has(dateKey)) {
                trekDownDays.set(dateKey, {
                    date: admin.firestore.Timestamp.fromDate(dayAfter),
                    isClosed: true,
                    maxSlots: 0,
                    reason: 'Trek down day - Trekkers descending',
                    customNote: `Blocked due to approved trek starting on ${formatDateKey(trekDate)}`,
                    isTrekDownDay: true,
                    originalTrekDate: formatDateKey(trekDate),
                    lastUpdated: admin.firestore.FieldValue.serverTimestamp()
                });

                console.log(`📅 Buffer day identified: ${dateKey} (trek on ${formatDateKey(trekDate)})`);
            }
        }

        console.log(`\n  Identified ${trekDownDays.size} unique buffer days\n`);

        // Step 3: Get existing buffer days in calendar_config
        console.log('🔍 Checking existing buffer days in calendar_config...');
        const configSnapshot = await db.collection('calendar_config')
            .where('isTrekDownDay', '==', true)
            .get();

        console.log(`📊 Found ${configSnapshot.size} existing buffer days in calendar_config\n`);

        // Step 4: Remove outdated buffer days
        let removedCount = 0;
        for (const doc of configSnapshot.docs) {
            if (!trekDownDays.has(doc.id)) {
                console.log(`🗑️  Removing outdated buffer day: ${doc.id}`);
                await doc.ref.delete();
                removedCount++;
            }
        }

        if (removedCount > 0) {
            console.log(`\n  Removed ${removedCount} outdated buffer days\n`);
        }

        // Step 5: Add/update buffer days
        console.log('💾 Updating buffer days in calendar_config...');
        const batch = db.batch();
        let updatedCount = 0;

        for (const [dateKey, data] of trekDownDays) {
            const docRef = db.collection('calendar_config').doc(dateKey);
            batch.set(docRef, data, { merge: true });
            updatedCount++;
        }

        if (updatedCount > 0) {
            await batch.commit();
            console.log(`  Updated ${updatedCount} buffer days\n`);
        }

        // Summary
        console.log('📊 Sync Summary:');
        console.log(`  - Approved bookings: ${bookingsSnapshot.size}`);
        console.log(`  - Buffer days created: ${trekDownDays.size}`);
        console.log(`  - Outdated removed: ${removedCount}`);
        console.log(`  - Updated/created: ${updatedCount}`);
        console.log('\n✨ Trek down days synchronized successfully!');
        console.log('💡 All users will now see consistent buffer days in the calendar');

    } catch (error) {
        console.error('❌ Error syncing buffer days:', error);
        process.exit(1);
    }

    process.exit(0);
}

// Run the sync
syncBufferDays();
