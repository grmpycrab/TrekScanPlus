/**
 * Cloud Functions for TrekScan Plus
 * 
 * Automatic buffer day management:
 * - Creates buffer day when booking is approved
 * - Removes buffer day when booking is cancelled/rejected
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');

// Set timezone to Philippine Time to match app behavior
process.env.TZ = 'Asia/Manila';

admin.initializeApp();
const db = admin.firestore();

// Set region to match Firestore location
const region = 'asia-southeast1';

// Global resource limits applied to every callable function.
// Prevents runaway billing (DoS amplification) and unbounded execution.
const runtimeOpts = {
  timeoutSeconds: 15,
  maxInstances: 10,
};

// Initialize SendGrid
const sendgridKey = process.env.SENDGRID_KEY;
if (sendgridKey) {
    sgMail.setApiKey(sendgridKey);
}

/**
 * Format date as YYYY-MM-DD in Philippine timezone
 * This matches how the Flutter app creates date keys
 */
function formatDateKey(date) {
    // Convert to Philippine timezone
    const options = {
        timeZone: 'Asia/Manila',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit'
    };

    const parts = new Intl.DateTimeFormat('en-US', options).formatToParts(date);
    const year = parts.find(p => p.type === 'year').value;
    const month = parts.find(p => p.type === 'month').value;
    const day = parts.find(p => p.type === 'day').value;

    return `${year}-${month}-${day}`;
}

/**
 * Check if user already has a booking on the same date
 * Prevents duplicate bookings on the same date
 */
exports.validateNoDuplicateBooking = functions.runWith(runtimeOpts).region(region).firestore
    .document('bookings/{bookingId}')
    .onCreate(async (snap, context) => {
        const booking = snap.data();
        const bookingId = context.params.bookingId;

        if (!booking.userId || !booking.trekDate) {
            console.log(`Booking ${bookingId}: Missing userId or trekDate`);
            return null;
        }

        const trekDate = booking.trekDate.toDate();
        const startOfDay = new Date(trekDate.getFullYear(), trekDate.getMonth(), trekDate.getDate());
        const endOfDay = new Date(trekDate.getFullYear(), trekDate.getMonth(), trekDate.getDate(), 23, 59, 59);

        try {
            // Query for other bookings by the same user on the same date
            const existingBookings = await db.collection('bookings')
                .where('userId', '==', booking.userId)
                .where('trekDate', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
                .where('trekDate', '<=', admin.firestore.Timestamp.fromDate(endOfDay))
                .get();

            // Should only be the current booking
            if (existingBookings.size > 1) {
                console.log(`🚫 Duplicate booking detected: ${booking.userId} on ${formatDateKey(trekDate)}`);

                // Delete the new booking to prevent duplicates
                await snap.ref.delete();
                console.log(`  Duplicate booking ${bookingId} deleted`);

                return { action: 'deleted', reason: 'duplicate_booking' };
            }

            console.log(`  Booking ${bookingId} validated: No duplicates found`);
            return { action: 'validated' };

        } catch (error) {
            console.error(`Error validating booking: ${error.message}`);
            // Don't fail the booking creation, just log the error
            return null;
        }
    });

/**
 * Update server timestamp metadata for client synchronization
 * This ensures all clients use the same server time
 */
exports.updateServerTimestamp = functions.runWith(runtimeOpts).region(region).https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
    }
    try {
        const timestamp = admin.firestore.FieldValue.serverTimestamp();
        await db.collection('_metadata').doc('timestamp').set({ timestamp }, { merge: true });

        return {
            success: true,
            timestamp: new Date().toISOString()
        };
    } catch (error) {
        console.error('Error updating server timestamp:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

/**
 * Trigger when a booking document is created or updated
 * Automatically manages buffer days based on booking status
 */
exports.onBookingStatusChange = functions.runWith(runtimeOpts).region(region).firestore
    .document('bookings/{bookingId}')
    .onWrite(async (change, context) => {
        const bookingId = context.params.bookingId;

        // Get old and new data
        const oldData = change.before.exists ? change.before.data() : null;
        const newData = change.after.exists ? change.after.data() : null;

        // Get old and new status (normalize to lowercase for comparison)
        const oldStatus = oldData?.status?.toLowerCase();
        const newStatus = newData?.status?.toLowerCase();

        // Get trek date (from newData if exists, otherwise from oldData for deletions)
        const trekDate = (newData?.trekDate || oldData?.trekDate)?.toDate();

        if (!trekDate) {
            console.log(`Booking ${bookingId}: No trek date, skipping`);
            return null;
        }

        const trekDateKey = formatDateKey(trekDate);
        const dayAfter = new Date(trekDate);
        dayAfter.setDate(dayAfter.getDate() + 1);
        const bufferDateKey = formatDateKey(dayAfter);

        console.log(`Booking ${bookingId}: Status changed from "${oldStatus}" to "${newStatus}"`);
        console.log(`Trek date: ${trekDateKey}, Buffer day: ${bufferDateKey}`);

        // Case 1: Booking approved (create buffer day)
        if (newStatus === 'approved' && oldStatus !== 'approved') {
            console.log(`Creating buffer day for ${bufferDateKey}`);

            await db.collection('calendar_config').doc(bufferDateKey).set({
                date: admin.firestore.Timestamp.fromDate(dayAfter),
                isClosed: true,
                maxSlots: 0,
                reason: 'Trek down day - Trekkers descending',
                customNote: `Blocked due to approved trek starting on ${trekDateKey}`,
                isTrekDownDay: true,
                originalTrekDate: trekDateKey,
                lastUpdated: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });

            console.log(`  Buffer day created: ${bufferDateKey}`);
            return { action: 'created', bufferDate: bufferDateKey };
        }

        // Case 2: Booking no longer approved (remove buffer day if it was this booking's)
        if (oldStatus === 'approved' && newStatus !== 'approved') {
            console.log(`Checking if buffer day ${bufferDateKey} should be removed`);

            const bufferDoc = await db.collection('calendar_config').doc(bufferDateKey).get();

            if (bufferDoc.exists) {
                const bufferData = bufferDoc.data();

                // Only remove if this buffer was created by this booking
                if (bufferData.isTrekDownDay && bufferData.originalTrekDate === trekDateKey) {
                    // Check if there are other approved bookings on the same date
                    const otherBookings = await db.collection('bookings')
                        .where('trekDate', '==', admin.firestore.Timestamp.fromDate(trekDate))
                        .where('status', '==', 'approved')
                        .get();

                    // Only delete if no other approved bookings exist for this date
                    if (otherBookings.empty || (otherBookings.size === 1 && otherBookings.docs[0].id === bookingId)) {
                        await db.collection('calendar_config').doc(bufferDateKey).delete();
                        console.log(`  Buffer day removed: ${bufferDateKey}`);
                        return { action: 'removed', bufferDate: bufferDateKey };
                    } else {
                        console.log(`⚠️  Buffer day ${bufferDateKey} kept (other approved bookings exist)`);
                        return { action: 'kept', bufferDate: bufferDateKey, reason: 'other_bookings_exist' };
                    }
                }
            }
        }

        // Case 3: Booking deleted (remove buffer day)
        if (!change.after.exists && oldStatus === 'approved') {
            console.log(`Booking deleted, checking buffer day ${bufferDateKey}`);

            const bufferDoc = await db.collection('calendar_config').doc(bufferDateKey).get();

            if (bufferDoc.exists) {
                const bufferData = bufferDoc.data();

                if (bufferData.isTrekDownDay && bufferData.originalTrekDate === trekDateKey) {
                    // Check for other approved bookings
                    const otherBookings = await db.collection('bookings')
                        .where('trekDate', '==', admin.firestore.Timestamp.fromDate(trekDate))
                        .where('status', '==', 'approved')
                        .get();

                    if (otherBookings.empty) {
                        await db.collection('calendar_config').doc(bufferDateKey).delete();
                        console.log(`  Buffer day removed: ${bufferDateKey}`);
                        return { action: 'removed', bufferDate: bufferDateKey };
                    }
                }
            }
        }

        console.log(`No buffer day action needed`);
        return null;
    });

/**
 * Manual trigger to sync all buffer days
 * Call this via Firebase Console or HTTP function
 */
exports.syncAllBufferDays = functions.runWith(runtimeOpts).region(region).https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
    }
    if (!context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Admin access required.');
    }
    console.log('Starting manual buffer day sync...');

    try {
        // Get all approved bookings
        const bookingsSnapshot = await db.collection('bookings')
            .where('status', '==', 'approved')
            .get();

        console.log(`Found ${bookingsSnapshot.size} approved bookings`);

        // Track buffer days that should exist
        const bufferDays = new Map();

        for (const doc of bookingsSnapshot.docs) {
            const data = doc.data();
            const trekDate = data.trekDate?.toDate();

            if (!trekDate) continue;

            const trekDateKey = formatDateKey(trekDate);
            const dayAfter = new Date(trekDate);
            dayAfter.setDate(dayAfter.getDate() + 1);
            const bufferDateKey = formatDateKey(dayAfter);

            if (!bufferDays.has(bufferDateKey)) {
                bufferDays.set(bufferDateKey, {
                    date: admin.firestore.Timestamp.fromDate(dayAfter),
                    isClosed: true,
                    maxSlots: 0,
                    reason: 'Trek down day - Trekkers descending',
                    customNote: `Blocked due to approved trek starting on ${trekDateKey}`,
                    isTrekDownDay: true,
                    originalTrekDate: trekDateKey,
                    lastUpdated: admin.firestore.FieldValue.serverTimestamp()
                });
            }
        }

        // Get existing buffer days
        const configSnapshot = await db.collection('calendar_config')
            .where('isTrekDownDay', '==', true)
            .get();

        // Remove outdated buffer days
        let removedCount = 0;
        for (const doc of configSnapshot.docs) {
            if (!bufferDays.has(doc.id)) {
                await doc.ref.delete();
                removedCount++;
            }
        }

        // Add/update buffer days
        const batch = db.batch();
        let updatedCount = 0;

        for (const [dateKey, data] of bufferDays) {
            const docRef = db.collection('calendar_config').doc(dateKey);
            batch.set(docRef, data, { merge: true });
            updatedCount++;
        }

        await batch.commit();

        const result = {
            totalApprovedBookings: bookingsSnapshot.size,
            bufferDaysCreated: bufferDays.size,
            outdatedRemoved: removedCount,
            updated: updatedCount
        };

        console.log('Sync complete:', result);
        return result;

    } catch (error) {
        console.error('Error syncing buffer days:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

/**
 * Send FCM notification when booking status changes
 * This triggers whenever a booking is updated
 */
exports.sendBookingStatusNotification = functions.runWith(runtimeOpts).region(region).firestore
    .document('bookings/{bookingId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();
        const bookingId = context.params.bookingId;

        // Only send notification if status changed
        if (newData.status === oldData.status) {
            console.log(`📍 [FCM] Status not changed for booking ${bookingId}`);
            return;
        }

        const userId = newData.userId;
        const newStatus = newData.status;
        const adminNotes = newData.adminNotes || '';

        try {
            // Get user's FCM token
            const userDoc = await db.collection('users').doc(userId).get();
            if (!userDoc.exists) {
                console.log(`⚠️ [FCM] User ${userId} not found`);
                return;
            }

            const userFCMToken = userDoc.data().fcmToken;
            if (!userFCMToken) {
                console.log(`⚠️ [FCM] No FCM token for user ${userId}`);
                return;
            }

            // Prepare notification message based on status
            let title = 'Booking Updated';
            let body = 'Your booking has been updated';
            let notificationType = 'info';

            if (newStatus.toLowerCase() === 'approved') {
                title = '  Booking Approved!';
                body = 'Your booking has been approved and is ready to go.';
                notificationType = 'success';
            } else if (newStatus.toLowerCase() === 'rejected') {
                title = '❌ Booking Rejected';
                body = adminNotes || 'Your booking was rejected.';
                notificationType = 'error';
            } else if (newStatus.toLowerCase() === 'changes required') {
                title = '⚠️ Changes Required';
                body = adminNotes || 'Admin notes: Please review and update.';
                notificationType = 'warning';
            } else if (newStatus.toLowerCase() === 'pending') {
                title = '⏳ Booking Submitted';
                body = 'Your booking has been submitted for review.';
                notificationType = 'info';
            }

            // Send FCM message
            const message = {
                token: userFCMToken,
                notification: {
                    title: title,
                    body: body,
                },
                data: {
                    bookingId: bookingId,
                    status: newStatus,
                    notificationType: notificationType,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
                android: {
                    priority: 'high',
                    notification: {
                        sound: 'default',
                        channelId: 'booking_updates',
                        defaultVibrateTimings: true,
                        defaultLightSettings: true,
                    },
                },
                apns: {
                    headers: {
                        'apns-priority': '10',
                    },
                    payload: {
                        aps: {
                            alert: {
                                title: title,
                                body: body,
                            },
                            sound: 'default',
                            badge: 1,
                        },
                    },
                },
            };

            const response = await admin.messaging().send(message);
            console.log(`  [FCM] Notification sent to user ${userId}:`, response);
            return { success: true, messageId: response };

        } catch (error) {
            console.error(`❌ [FCM] Error sending notification for booking ${bookingId}:`, error);
            return { success: false, error: error.message };
        }
    });

/**
 * Grant the admin custom claim to a user.
 *
 * Bootstrap flow: if the caller IS the seed admin email (set via
 *   firebase functions:config:set admin.seed_email="you@example.com")
 * they can self-grant admin on first login. After that, existing admins
 * can promote other users by passing { uid: '<target-uid>' }.
 */
exports.grantAdminClaim = functions.runWith(runtimeOpts).region(region).https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
    }

    const seedEmail = process.env.ADMIN_SEED_EMAIL;
    const callerRecord = await admin.auth().getUser(context.auth.uid);
    const isSeedAdmin = seedEmail && callerRecord.email === seedEmail;
    const isAlreadyAdmin = context.auth.token.admin === true;

    if (!isSeedAdmin && !isAlreadyAdmin) {
        throw new functions.https.HttpsError('permission-denied', 'Not authorized to grant admin claims.');
    }

    const targetUid = (data && data.uid) ? data.uid : context.auth.uid;
    await admin.auth().setCustomUserClaims(targetUid, { admin: true });

    console.log(`Admin claim granted to uid: ${targetUid} by uid: ${context.auth.uid}`);
    return { success: true, uid: targetUid };
});

/**
 * Send verification code emails
 * Listens to the /mail collection and sends emails with verification codes
 */
exports.sendVerificationEmail = functions.runWith(runtimeOpts).region(region).firestore
    .document('mail/{mailId}')
    .onCreate(async (snap, context) => {
        const mailData = snap.data();
        const mailId = context.params.mailId;

        console.log(`📧 Processing email ${mailId} to: ${mailData.to}`);

        try {
            if (!sendgridKey) {
                console.warn('⚠️ SendGrid API key not configured. Email not sent.');
                console.log(`📧 Would send to: ${mailData.to}, Code: ${mailData.code}`);

                await snap.ref.update({
                    processed: true,
                    processedAt: admin.firestore.FieldValue.serverTimestamp(),
                    status: 'no_api_key'
                });
                return { success: false, reason: 'no_api_key' };
            }

            // Send email with SendGrid
            const msg = {
                to: mailData.to,
                from: 'keyntharly@gmail.com', // Use your verified sender email
                subject: mailData.subject || 'TrekScan Plus - Email Verification Code',
                text: `Your verification code is: ${mailData.code}\n\nThis code will expire in 15 minutes.\n\nIf you didn't request this code, please ignore this email.`,
                html: `
                    <!DOCTYPE html>
                    <html>
                    <head>
                        <meta charset="UTF-8">
                        <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    </head>
                    <body style="margin: 0; padding: 0; background-color: #f4f4f4; font-family: Arial, sans-serif;">
                        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 20px;">
                            <tr>
                                <td align="center">
                                    <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden;">
                                        <tr>
                                            <td style="background-color: #252B30; padding: 30px; text-align: center;">
                                                <h1 style="color: #ffffff; margin: 0; font-size: 24px;">TrekScan Plus</h1>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td style="padding: 40px 30px;">
                                                <h2 style="color: #252B30; margin: 0 0 20px; font-size: 20px;">Email Verification</h2>
                                                <p style="color: #666; margin: 0 0 20px; font-size: 16px; line-height: 1.5;">
                                                    Thank you for signing up! Please use the verification code below to complete your registration:
                                                </p>
                                                <div style="background-color: #f8f9fa; border: 2px solid #252B30; border-radius: 8px; padding: 30px; text-align: center; margin: 30px 0;">
                                                    <p style="color: #666; margin: 0 0 10px; font-size: 14px; text-transform: uppercase; letter-spacing: 1px;">Verification Code</p>
                                                    <p style="color: #252B30; margin: 0; font-size: 36px; font-weight: bold; letter-spacing: 8px; font-family: 'Courier New', monospace;">
                                                        ${mailData.code}
                                                    </p>
                                                </div>
                                                <p style="color: #666; margin: 20px 0; font-size: 14px; line-height: 1.5;">
                                                    ⏱️ <strong>This code will expire in 15 minutes.</strong>
                                                </p>
                                                <p style="color: #666; margin: 20px 0; font-size: 14px; line-height: 1.5;">
                                                    If you didn't request this code, please ignore this email.
                                                </p>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td style="background-color: #f8f9fa; padding: 20px 30px; text-align: center; border-top: 1px solid #e0e0e0;">
                                                <p style="color: #999; margin: 0; font-size: 12px;">
                                                    © 2025 TrekScan Plus - Hamiguitan Mountain Range
                                                </p>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>
                        </table>
                    </body>
                    </html>
                `,
            };

            await sgMail.send(msg);
            console.log(`  Email sent successfully to ${mailData.to}`);

            // Mark as sent
            await snap.ref.update({
                processed: true,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'sent'
            });

            return { success: true };

        } catch (error) {
            console.error(`❌ Error sending email ${mailId}:`, error);

            // Log detailed error information
            if (error.response) {
                console.error('SendGrid Error Response:', JSON.stringify(error.response.body, null, 2));
            }

            await snap.ref.update({
                processed: true,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'error',
                error: error.message,
                errorDetails: error.response?.body || error.message
            });

            return { success: false, error: error.message };
        }
    });

/**
 * Process certificate email queue.
 * Flutter writes to certificateEmailQueue/{docId} — this trigger picks it up
 * and sends via SendGrid (same pattern as sendVerificationEmail).
 */
exports.processCertificateEmailQueue = functions.runWith({
    timeoutSeconds: 120,
    maxInstances: 10,
}).region(region).firestore
    .document('certificateEmailQueue/{docId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const docId = context.params.docId;

        console.log(`📧 Processing certificate email ${docId} to: ${data.to}`);

        if (!sendgridKey) {
            console.warn('⚠️ SendGrid API key not configured. Certificate email not sent.');
            await snap.ref.update({ processed: true, status: 'no_api_key',
                processedAt: admin.firestore.FieldValue.serverTimestamp() });
            return;
        }

        try {
            let msg;
            if (data.bulk && Array.isArray(data.certificates)) {
                // Bulk: multiple certificates in one email
                const attachments = data.certificates
                    .filter(c => c.pdfBase64)
                    .map(c => ({
                        content: c.pdfBase64,
                        filename: `${(c.certificateData.title || 'Certificate').replace(/\s+/g, '_')}_Certificate.pdf`,
                        type: 'application/pdf',
                        disposition: 'attachment',
                    }));
                const items = data.certificates.map(c => {
                    const cd = c.certificateData;
                    return `<div style="background:white;padding:15px;margin:10px 0;border-left:4px solid ${cd.colorHex||'#4CAF50'};border-radius:4px;">
                        <h4 style="margin:0 0 10px 0;">${cd.title}</h4>
                        <p style="margin:5px 0;font-size:14px;">Earned on: ${cd.dateEarned}</p>
                        <p style="margin:5px 0;font-size:14px;">Stations: ${cd.stationsVisited} | Distance: ${cd.totalDistance} km</p>
                    </div>`;
                }).join('');
                msg = {
                    to: data.to,
                    from: { email: 'keyntharly@gmail.com', name: 'Mt. Hamiguitan TrekScan' },
                    subject: `Your Mt. Hamiguitan Certificates (${data.certificates.length} earned)`,
                    html: `<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px">
                        <div style="background:linear-gradient(135deg,#667eea,#764ba2);color:white;padding:30px;text-align:center;border-radius:10px 10px 0 0">
                            <h1>🎉 Amazing Achievement!</h1>
                            <p>You've earned ${data.certificates.length} Mt. Hamiguitan Certificates</p>
                        </div>
                        <div style="background:#f9f9f9;padding:30px;border-radius:0 0 10px 10px">
                            <p>Dear <strong>${data.recipientName || 'Trekker'}</strong>,</p>
                            ${items}
                            <p>All certificates are attached as PDF files.</p>
                            <p>Best regards,<br><strong>The Mt. Hamiguitan TrekScan Team</strong></p>
                        </div></body></html>`,
                    attachments,
                };
            } else {
                // Single certificate
                const cert = data.certificateData;
                const attachments = data.pdfBase64 ? [{
                    content: data.pdfBase64,
                    filename: `${(cert.title || 'Certificate').replace(/\s+/g, '_')}_Certificate.pdf`,
                    type: 'application/pdf',
                    disposition: 'attachment',
                }] : [];
                msg = {
                    to: data.to,
                    from: { email: 'keyntharly@gmail.com', name: 'Mt. Hamiguitan TrekScan' },
                    subject: `🏆 Your Mt. Hamiguitan ${cert.title} Certificate`,
                    html: _buildCertificateEmailHtml(cert, data.recipientName || 'Trekker'),
                    attachments,
                };
            }

            await sgMail.send(msg);
            console.log(`✅ Certificate email sent to ${data.to}`);
            await snap.ref.update({
                processed: true,
                status: 'sent',
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        } catch (error) {
            console.error(`❌ Certificate email error:`, error.response?.body || error.message);
            await snap.ref.update({
                processed: true,
                status: 'error',
                error: error.message,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
    });

/**
 * (Kept for reference — no longer called from the Flutter app.
 *  Certificate emails now go through certificateEmailQueue Firestore trigger.)
 */
exports._sendCertificateEmail_deprecated = functions.runWith({
    timeoutSeconds: 60,
    maxInstances: 10,
}).region(region).https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be signed in.');
    }

    const { to, recipientName, certificateData, pdfBase64 } = data;

    if (!to || !certificateData) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: to, certificateData');
    }

    // Only allow users to send to their own verified email
    if (to !== context.auth.token.email) {
        throw new functions.https.HttpsError('permission-denied', 'Can only send certificates to your own email.');
    }

    if (!sendgridKey) {
        throw new functions.https.HttpsError('internal', 'Email service is not configured.');
    }

    const attachments = pdfBase64 ? [{
        content: pdfBase64,
        filename: `${(certificateData.title || 'Certificate').replace(/\s+/g, '_')}_Certificate.pdf`,
        type: 'application/pdf',
        disposition: 'attachment',
    }] : [];

    const msg = {
        to,
        from: { email: 'keyntharly@gmail.com', name: 'Mt. Hamiguitan TrekScan' },
        subject: `🏆 Your Mt. Hamiguitan ${certificateData.title} Certificate`,
        html: _buildCertificateEmailHtml(certificateData, recipientName || 'Trekker'),
        attachments,
    };

    try {
        await sgMail.send(msg);
        console.log(`✅ Certificate email sent to ${to}`);
        return { success: true };
    } catch (error) {
        console.error('❌ sendCertificateEmail error:', error.response?.body || error.message);
        throw new functions.https.HttpsError('internal', 'Failed to send certificate email.');
    }
});

/**
 * Send all earned certificates in a single email with multiple PDF attachments.
 */
exports.sendAllCertificatesEmail = functions.runWith({
    timeoutSeconds: 120,
    maxInstances: 10,
}).region(region).https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be signed in.');
    }

    const { to, recipientName, certificates } = data;

    if (!to || !certificates || !Array.isArray(certificates) || certificates.length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: to, certificates[]');
    }

    if (to !== context.auth.token.email) {
        throw new functions.https.HttpsError('permission-denied', 'Can only send certificates to your own email.');
    }

    if (!sendgridKey) {
        throw new functions.https.HttpsError('internal', 'Email service is not configured.');
    }

    const attachments = certificates
        .filter(c => c.pdfBase64)
        .map(c => ({
            content: c.pdfBase64,
            filename: `${(c.certificateData.title || 'Certificate').replace(/\s+/g, '_')}_Certificate.pdf`,
            type: 'application/pdf',
            disposition: 'attachment',
        }));

    const certificateItems = certificates.map(c => {
        const cd = c.certificateData;
        return `
        <div style="background:white;padding:15px;margin:10px 0;border-left:4px solid ${cd.colorHex || '#4CAF50'};border-radius:4px;">
            <h4 style="margin:0 0 10px 0;">${cd.title}</h4>
            <p style="margin:5px 0;font-size:14px;">Earned on: ${cd.dateEarned}</p>
            <p style="margin:5px 0;font-size:14px;">Stations: ${cd.stationsVisited} | Distance: ${cd.totalDistance} km</p>
        </div>`;
    }).join('');

    const html = `
<!DOCTYPE html><html><head>
<style>
  body{font-family:Arial,sans-serif;line-height:1.6;color:#333;max-width:600px;margin:0 auto;padding:20px}
  .header{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:white;padding:30px;text-align:center;border-radius:10px 10px 0 0}
  .content{background:#f9f9f9;padding:30px;border-radius:0 0 10px 10px}
</style></head><body>
  <div class="header"><h1>🎉 Amazing Achievement!</h1>
    <p>You've earned ${certificates.length} Mt. Hamiguitan Certificates</p></div>
  <div class="content">
    <p>Dear <strong>${recipientName || 'Trekker'}</strong>,</p>
    <p>Congratulations! You've earned multiple certificates for your trekking achievements:</p>
    ${certificateItems}
    <p style="margin-top:30px;">All certificates are attached to this email as PDF files.</p>
    <p>Best regards,<br><strong>The Mt. Hamiguitan TrekScan Team</strong></p>
  </div>
</body></html>`;

    const msg = {
        to,
        from: { email: 'keyntharly@gmail.com', name: 'Mt. Hamiguitan TrekScan' },
        subject: `Your Mt. Hamiguitan Certificates (${certificates.length} earned)`,
        html,
        attachments,
    };

    try {
        await sgMail.send(msg);
        console.log(`✅ Bulk certificate email (${certificates.length}) sent to ${to}`);
        return { success: true };
    } catch (error) {
        console.error('❌ sendAllCertificatesEmail error:', error.response?.body || error.message);
        throw new functions.https.HttpsError('internal', 'Failed to send certificates email.');
    }
});

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

function _buildCertificateEmailHtml(cert, userName) {
    return `
<!DOCTYPE html><html><head><style>
  body{font-family:Arial,sans-serif;line-height:1.6;color:#333;max-width:600px;margin:0 auto;padding:20px}
  .header{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:white;padding:30px;text-align:center;border-radius:10px 10px 0 0}
  .content{background:#f9f9f9;padding:30px;border-radius:0 0 10px 10px}
  .badge{background:${cert.colorHex || '#4CAF50'};color:white;padding:15px;border-radius:8px;text-align:center;margin:20px 0}
  .details{background:white;padding:20px;border-left:4px solid ${cert.colorHex || '#4CAF50'};margin:20px 0}
  .row{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid #eee}
  .footer{text-align:center;padding:20px;color:#666;font-size:12px}
</style></head><body>
  <div class="header"><h1>🏔️ Congratulations!</h1><p>You've earned a Mt. Hamiguitan Certificate</p></div>
  <div class="content">
    <p>Dear <strong>${userName}</strong>,</p>
    <p>Congratulations on achieving this incredible milestone! We are thrilled to present you with your official certificate for completing:</p>
    <div class="badge"><h2 style="margin:0">${cert.title}</h2></div>
    <p>${cert.description}</p>
    <div class="details">
      <h3>Your Achievement Details:</h3>
      <div class="row"><span><strong>Date Completed:</strong></span><span>${cert.dateEarned}</span></div>
      <div class="row"><span><strong>Stations Visited:</strong></span><span>${cert.stationsVisited} stations</span></div>
      <div class="row"><span><strong>Total Distance:</strong></span><span>${cert.totalDistance} km</span></div>
      <div class="row"><span><strong>Total Time:</strong></span><span>${(cert.totalTimeMinutes / 60).toFixed(1)} hours</span></div>
      <div class="row"><span><strong>Verification Code:</strong></span><span><code>${cert.verificationCode}</code></span></div>
    </div>
    <p>Your official certificate is attached to this email as a PDF file.</p>
    <p style="margin-top:30px;">Thank you for exploring the beautiful Mt. Hamiguitan Range Wildlife Sanctuary, a UNESCO World Heritage Site.</p>
    <p><strong>Keep exploring!</strong></p>
    <p>Best regards,<br><strong>The Mt. Hamiguitan TrekScan Team</strong></p>
  </div>
  <div class="footer">
    <p>Mt. Hamiguitan Range Wildlife Sanctuary<br>UNESCO World Heritage Site<br>This is an automated email. Please do not reply.</p>
    <p style="font-size:10px;margin-top:20px;">Certificate issued on ${cert.createdAt}</p>
  </div>
</body></html>`;
}

