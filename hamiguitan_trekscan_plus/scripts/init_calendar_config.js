/**
 * Initialize Calendar Configuration in Firestore
 * 
 * This script creates the initial system settings and demonstrates
 * how to manage calendar configuration for the TrekScan Plus app.
 * 
 * Prerequisites:
 * 1. Firebase Admin SDK initialized
 * 2. serviceAccountKey.json in the same directory
 * 3. Node.js installed
 * 
 * Usage:
 * node init_calendar_config.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function initializeCalendarConfig() {
    console.log('🚀 Initializing Calendar Configuration...\n');

    try {
        // 1. Create system settings
        console.log('📝 Creating system settings...');
        await db.collection('system_settings').doc('calendar').set({
            defaultMaxSlots: 30,
            criticalThreshold: 5,
            allowWeekendBookings: true,
            advanceBookingDays: 1825, // 5 years in advance
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('✅ System settings created\n');

        // 2. Example: Close Christmas Day
        const christmasDate = new Date('2025-12-25T00:00:00Z');
        const christmasKey = '2025-12-25';
        console.log(`📅 Closing date: ${christmasKey} (Christmas)`);
        await db.collection('calendar_config').doc(christmasKey).set({
            date: admin.firestore.Timestamp.fromDate(christmasDate),
            isClosed: true,
            maxSlots: 0,
            reason: 'Christmas Holiday',
            customNote: 'Park closed for holiday observance',
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('✅ Christmas closed\n');

        // 3. Example: Set custom limit for New Year's Eve
        const newYearDate = new Date('2025-12-31T00:00:00Z');
        const newYearKey = '2025-12-31';
        console.log(`📅 Setting custom limit: ${newYearKey} (New Year's Eve)`);
        await db.collection('calendar_config').doc(newYearKey).set({
            date: admin.firestore.Timestamp.fromDate(newYearDate),
            isClosed: false,
            maxSlots: 45,
            reason: 'New Year Special Event - Increased Capacity',
            customNote: 'Extended hours and additional staff (max 45 slots)',
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('✅ New Years Eve configured with 45 slots\n');

        // 4. Example: Reduce capacity for conservation period
        const conservationDate = new Date('2025-11-30T00:00:00Z');
        const conservationKey = '2025-11-30';
        console.log(`📅 Reducing capacity: ${conservationKey} (Conservation)`);
        await db.collection('calendar_config').doc(conservationKey).set({
            date: admin.firestore.Timestamp.fromDate(conservationDate),
            isClosed: false,
            maxSlots: 15,
            reason: 'Conservation Period',
            customNote: 'Reforestation activities in progress',
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('✅ Conservation period set to 15 slots\n');

        console.log('🎉 Calendar configuration initialized successfully!\n');
        console.log('📊 Summary:');
        console.log('  - System defaults: 30 slots, 5 critical threshold');
        console.log('  - Christmas (2025-12-25): CLOSED');
        console.log('  - New Year (2025-12-31): 45 slots (max allowed)');
        console.log('  - Conservation (2025-11-30): 15 slots');
        console.log('\n✨ Your app can now use centralized calendar configuration!');
        console.log('💡 Note: Max slots can range from 0-45 (default 30)');

    } catch (error) {
        console.error('❌ Error initializing calendar config:', error);
        process.exit(1);
    }

    process.exit(0);
}

// Helper functions for manual operations

async function closeDate(dateString, reason, customNote = null) {
    const date = new Date(`${dateString}T00:00:00Z`);
    await db.collection('calendar_config').doc(dateString).set({
        date: admin.firestore.Timestamp.fromDate(date),
        isClosed: true,
        maxSlots: 0,
        reason: reason,
        customNote: customNote,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`✅ Closed ${dateString}: ${reason}`);
}

async function openDate(dateString) {
    await db.collection('calendar_config').doc(dateString).delete();
    console.log(`✅ Opened ${dateString} (reverted to system defaults)`);
}

async function setDateMaxSlots(dateString, maxSlots, reason = null) {
    const date = new Date(`${dateString}T00:00:00Z`);
    await db.collection('calendar_config').doc(dateString).set({
        date: admin.firestore.Timestamp.fromDate(date),
        isClosed: false,
        maxSlots: maxSlots,
        reason: reason || `Custom limit: ${maxSlots} slots`,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`✅ Set ${dateString} to ${maxSlots} slots${reason ? `: ${reason}` : ''}`);
}

async function updateSystemSettings(updates) {
    await db.collection('system_settings').doc('calendar').update({
        ...updates,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('✅ System settings updated:', updates);
}

// Run initialization
initializeCalendarConfig();

// Export helper functions for manual use
module.exports = {
    closeDate,
    openDate,
    setDateMaxSlots,
    updateSystemSettings
};
