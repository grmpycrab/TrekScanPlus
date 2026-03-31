/**
 * Firebase Admin Script to Add 30 Test Bookings
 * 
 * This script adds 30 test bookings to a specific date to test the booking limit.
 * 
 * Prerequisites:
 * 1. Install Firebase Admin SDK: npm install firebase-admin
 * 2. Download service account key from Firebase Console:
 *    - Go to Project Settings > Service Accounts
 *    - Click "Generate New Private Key"
 *    - Save as serviceAccountKey.json in the scripts folder
 * 
 * Usage:
 * 1. Configure TARGET_DATE and other settings below
 * 2. Run: node scripts/add_test_bookings.js
 * 
 * To clean up:
 * Run: node scripts/delete_test_bookings.js
 */

const admin = require('firebase-admin');
const path = require('path');

// ============================================
// CONFIGURATION
// ============================================

// Path to your service account key file
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

// Target date for test bookings (YYYY-MM-DD)
const TARGET_DATE = new Date('2025-12-02');

// Number of bookings to create (max 30)
const NUMBER_OF_BOOKINGS = 30;

// Number of porters per booking (affects slot calculation)
const PORTERS_PER_BOOKING = 0;

// User ID to assign bookings to (replace with actual user ID from Firebase Auth)
const TEST_USER_ID = 'WoGQ7rEaQTdNKOaWyj1r5LSjMor2'; // Update this with a real user ID

// ============================================

async function main() {
    console.log('🚀 Starting test booking creation script...\n');

    try {
        // Initialize Firebase Admin
        const serviceAccount = require(serviceAccountPath);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });

        const db = admin.firestore();

        console.log('📅 Target Date:', TARGET_DATE.toISOString().split('T')[0]);
        console.log('📊 Bookings to create:', NUMBER_OF_BOOKINGS);
        console.log('👷 Porters per booking:', PORTERS_PER_BOOKING);
        console.log('💺 Slots per booking:', 1 + PORTERS_PER_BOOKING);
        console.log('');

        // Confirm before proceeding
        console.log('⚠️  This will create', NUMBER_OF_BOOKINGS, 'test bookings.');
        console.log('Press Ctrl+C to cancel, or wait 3 seconds to continue...\n');
        await new Promise(resolve => setTimeout(resolve, 3000));

        // Create test bookings
        let successCount = 0;
        let failCount = 0;

        console.log('📝 Creating bookings...\n');

        const batch = db.batch();
        const bookingsRef = db.collection('bookings');

        for (let i = 1; i <= NUMBER_OF_BOOKINGS; i++) {
            try {
                // Vary the data for more realistic testing
                const hometowns = ['inside_san_isidro', 'inside_davao_oriental', 'outside_davao_oriental'];
                const hometown = hometowns[i % 3];
                const isSenior = i % 4 === 0; // Every 4th booking is a senior
                const phoneNumber = `0912345${String(6000 + i).padStart(4, '0')}`; // Generate unique phone numbers

                const bookingData = {
                    userId: TEST_USER_ID,
                    affiliation: `Test Affiliation ${i}`,
                    trekDate: admin.firestore.Timestamp.fromDate(TARGET_DATE),
                    numberOfPorters: PORTERS_PER_BOOKING,
                    trekType: i % 2 === 0 ? 'recreational' : 'research', // Alternate between types
                    hometown: hometown,
                    isSenior: isSenior,
                    phoneNumber: phoneNumber,
                    notes: `Test booking ${i} - Created for testing booking limits`,
                    adminNotes: null,
                    attachments: [],
                    status: 'approved', // Mark as approved to count towards limit
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                };

                const docRef = bookingsRef.doc();
                batch.set(docRef, bookingData);

                successCount++;

                // Progress indicator
                if (i % 5 === 0) {
                    console.log(`  Prepared ${i}/${NUMBER_OF_BOOKINGS} bookings...`);
                }
            } catch (e) {
                failCount++;
                console.log(`❌ Error preparing booking ${i}:`, e.message);
            }
        }

        // Commit the batch
        console.log('\n⏳ Committing batch write...');
        await batch.commit();

        console.log('  Bookings committed!');

        // Create buffer days for approved bookings
        console.log('\n📅 Creating buffer days (trek down days)...');
        const bufferBatch = db.batch();
        let bufferCount = 0;

        const dayAfter = new Date(TARGET_DATE);
        dayAfter.setDate(dayAfter.getDate() + 1);
        const bufferDateKey = `${dayAfter.getFullYear()}-${String(dayAfter.getMonth() + 1).padStart(2, '0')}-${String(dayAfter.getDate()).padStart(2, '0')}`;
        const trekDateKey = `${TARGET_DATE.getFullYear()}-${String(TARGET_DATE.getMonth() + 1).padStart(2, '0')}-${String(TARGET_DATE.getDate()).padStart(2, '0')}`;

        const bufferRef = db.collection('calendar_config').doc(bufferDateKey);
        bufferBatch.set(bufferRef, {
            date: admin.firestore.Timestamp.fromDate(dayAfter),
            isClosed: true,
            maxSlots: 0,
            reason: 'Trek down day - Trekkers descending',
            customNote: `Blocked due to approved trek starting on ${trekDateKey}`,
            isTrekDownDay: true,
            originalTrekDate: trekDateKey,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        bufferCount++;

        await bufferBatch.commit();
        console.log(`  Created ${bufferCount} buffer day: ${bufferDateKey}`);

        console.log('\n✨ Completed!\n');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('📊 Results:');
        console.log(`     Successful: ${successCount}`);
        console.log(`   ❌ Failed: ${failCount}`);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        // Count total bookings for this date
        const querySnapshot = await db
            .collection('bookings')
            .where('trekDate', '==', admin.firestore.Timestamp.fromDate(TARGET_DATE))
            .get();

        // Calculate slots used
        let totalSlotsUsed = 0;
        querySnapshot.forEach(doc => {
            const data = doc.data();
            const porters = data.numberOfPorters || 0;
            totalSlotsUsed += 1 + porters;
        });

        console.log(`📈 Current Status for ${TARGET_DATE.toISOString().split('T')[0]}:`);
        console.log(`   📋 Total bookings: ${querySnapshot.size}`);
        console.log(`   💺 Slots used: ${totalSlotsUsed} / 30`);

        if (totalSlotsUsed >= 30) {
            console.log('   🔴 Date is FULL (≥30 slots)');
        } else if (totalSlotsUsed >= 25) {
            console.log('   🟡 Date is CRITICAL (≥25 slots)');
        } else {
            console.log('   🟢 Date has available slots');
        }

        console.log('\n💡 Next Steps:');
        console.log('1. Open the app and navigate to Book a Climb');
        console.log(`2. Try to book on ${TARGET_DATE.toISOString().split('T')[0]}`);
        console.log('3. Verify that the system prevents booking if slots are full\n');

        console.log('🗑️  To clean up test data:');
        console.log('   Run: node scripts/delete_test_bookings.js\n');

    } catch (error) {
        console.error('❌ Error:', error.message);
        console.error('\n💡 Troubleshooting:');
        console.error('1. Make sure serviceAccountKey.json exists in the scripts folder');
        console.error('2. Update TEST_USER_ID with a valid user ID from Firebase Auth');
        console.error('3. Ensure Firebase Admin SDK is installed: npm install firebase-admin\n');
    } finally {
        process.exit(0);
    }
}

main();
