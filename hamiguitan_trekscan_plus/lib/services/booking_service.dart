import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../models/booking_model.dart';
import '../models/notification_model.dart';
import 'notification_services.dart';

class BookingService {
  BookingService._();
  static final instance = BookingService._();

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _notificationService = NotificationService();

  /// Create a booking document and return its generated id
  Future<String> createBooking(BookingModel booking) async {
    final data = booking.toMap();
    // Remove id if present so Firestore generates one
    data.remove('id');
    final docRef = await _firestore.collection('bookings').add(data);
    return docRef.id;
  }

  /// Update editable booking fields (typically user-provided info)
  Future<void> updateBooking(
    String bookingId, {
    String? affiliation,
    int? numberOfPorters,
    String? notes,
    bool resubmitDeclined = false,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (affiliation != null) {
      updateData['affiliation'] = affiliation;
    }
    if (numberOfPorters != null) {
      updateData['numberOfPorters'] = numberOfPorters;
    }
    // Allow clearing notes by sending null
    updateData['notes'] = notes;

    // If resubmitting a declined booking, reset status to pending and clear admin notes
    if (resubmitDeclined) {
      updateData['status'] = 'pending';
      updateData['adminNotes'] = null;
    }

    await _firestore.collection('bookings').doc(bookingId).update(updateData);
  }

  /// Upload a PlatformFile to storage under bookings/{bookingId}/attachments/
  /// Returns Attachment metadata on success.
  Future<Attachment> uploadAttachment(
    String bookingId,
    PlatformFile file, {
    void Function(int, int)? onProgress,
  }) async {
    final rand = Random().nextInt(100000);
    final name = '${DateTime.now().millisecondsSinceEpoch}_$rand\_${file.name}';
    final path = 'bookings/$bookingId/attachments/$name';
    final ref = _storage.ref(path);

    UploadTask uploadTask;

    // Create metadata to avoid null pointer exceptions
    final metadata = SettableMetadata(
      contentType: file.extension != null
          ? _getMimeType(file.extension!)
          : 'application/octet-stream',
    );

    if (file.path != null) {
      uploadTask = ref.putFile(File(file.path!), metadata);
    } else if (file.bytes != null) {
      uploadTask = ref.putData(file.bytes!, metadata);
    } else {
      throw ArgumentError('File has neither path nor bytes');
    }

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((s) {
        onProgress(s.bytesTransferred, s.totalBytes);
      });
    }

    try {
      final snapshot = await uploadTask;
      final url = await ref.getDownloadURL();
      final meta = Attachment(
        storagePath: snapshot.ref.fullPath,
        downloadURL: url,
        fileName: file.name,
        mimeType: snapshot.metadata?.contentType,
        size: snapshot.totalBytes,
        uploadedAt: Timestamp.now(),
      );

      // Append metadata to booking doc with retry logic for reliability
      try {
        print(
          'DEBUG: Updating booking $bookingId with attachment ${meta.fileName}',
        );
        print('DEBUG: Attachment metadata: ${meta.toMap()}');

        await _firestore
            .collection('bookings')
            .doc(bookingId)
            .update({
              'attachments': FieldValue.arrayUnion([meta.toMap()]),
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException(
                'Firestore update timeout after 10 seconds',
              ),
            );

        print('DEBUG: Successfully updated Firestore with attachment');
      } catch (e) {
        print('ERROR: Firestore attachment metadata update failed: $e');
        print('ERROR: Stack trace: ${e.toString()}');
        // Still rethrow so caller knows about the issue
        rethrow;
      }

      return meta;
    } on FirebaseException catch (e) {
      print('ERROR uploading file: ${e.code} - ${e.message}');
      print('ERROR: Firebase exception details: ${e.toString()}');
      rethrow;
    } catch (e) {
      print('ERROR uploading file: $e');
      print('ERROR: Stack trace: ${e.toString()}');
      rethrow;
    }
  }

  /// Helper to determine MIME type from file extension
  String _getMimeType(String extension) {
    final ext = extension.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'doc':
        return 'application/msword';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> createBookingWithAttachments(
    BookingModel booking,
    List<PlatformFile> files, {
    void Function(int, int)? onProgress,
  }) async {
    final bookingId = await createBooking(booking);
    for (final f in files) {
      try {
        await uploadAttachment(bookingId, f, onProgress: onProgress);
      } catch (_) {
        // continue on individual file errors
      }
    }
  }

  Stream<List<BookingModel>> streamBookingsForUser(String uid) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BookingModel.fromDoc(d)).toList());
  }

  /// Start listening to booking status changes for notifications
  /// Call this when user logs in to monitor booking updates from admin
  void startBookingStatusListener(String userId) {
    final Map<String, String> _lastKnownStatus = {};

    _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.modified) {
              final booking = BookingModel.fromDoc(change.doc);
              final bookingId = booking.id!;
              final currentStatus = booking.status;
              final previousStatus = _lastKnownStatus[bookingId];

              // Only send notification if status actually changed
              if (previousStatus != null && previousStatus != currentStatus) {
                _sendBookingStatusNotification(
                  userId: userId,
                  bookingId: bookingId,
                  status: currentStatus,
                  adminNotes: booking.adminNotes,
                );
              }

              _lastKnownStatus[bookingId] = currentStatus;
            } else if (change.type == DocumentChangeType.added) {
              // Track initial status for new bookings
              final booking = BookingModel.fromDoc(change.doc);
              if (booking.id != null) {
                _lastKnownStatus[booking.id!] = booking.status;
              }
            }
          }
        });
  }

  Future<void> cancelBooking(String bookingId) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update booking status (for admin approval/decline) with notification
  Future<void> updateBookingStatus(
    String bookingId, {
    required String status,
    String? adminNotes,
  }) async {
    // Get booking to retrieve userId for notification
    final bookingDoc = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    if (!bookingDoc.exists) {
      throw Exception('Booking not found');
    }

    final userId = bookingDoc.data()?['userId'] as String?;
    if (userId == null) {
      throw Exception('User ID not found in booking');
    }

    // Update booking status
    final updateData = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (adminNotes != null) {
      updateData['adminNotes'] = adminNotes;
    }

    await _firestore.collection('bookings').doc(bookingId).update(updateData);

    // Send notification based on status
    await _sendBookingStatusNotification(
      userId: userId,
      bookingId: bookingId,
      status: status,
      adminNotes: adminNotes,
    );
  }

  /// Send notification when booking status changes
  Future<void> _sendBookingStatusNotification({
    required String userId,
    required String bookingId,
    required String status,
    String? adminNotes,
  }) async {
    String title;
    String message;
    NotificationType type;

    switch (status.toLowerCase()) {
      case 'approved':
        title = 'Booking Approved ✓';
        message =
            adminNotes ??
            'Your trek booking has been approved! Get ready for your adventure.';
        type = NotificationType.success;
        break;
      case 'declined':
      case 'rejected':
        title = 'Booking Declined';
        message =
            adminNotes ??
            'Your trek booking has been declined. Please contact support for more information.';
        type = NotificationType.alert;
        break;
      case 'pending':
        title = 'Booking Under Review';
        message = 'Your booking is being reviewed by our team.';
        type = NotificationType.info;
        break;
      case 'cancelled':
        title = 'Booking Cancelled';
        message = 'Your trek booking has been cancelled.';
        type = NotificationType.warning;
        break;
      default:
        title = 'Booking Status Updated';
        message =
            adminNotes ?? 'Your booking status has been updated to: $status';
        type = NotificationType.info;
    }

    final notification = NotificationModel(
      id: '', // Will be generated by Firestore
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
      actionType: 'booking',
      actionData: bookingId,
    );

    try {
      await _notificationService.sendNotificationForUser(userId, notification);
    } catch (e) {
      // Log error but don't fail the booking update
      print('Failed to send booking notification: $e');
    }
  }

  /// Delete an attachment from both Storage and Firestore
  Future<void> deleteAttachment(String bookingId, Attachment attachment) async {
    try {
      // Delete from Storage
      final storageRef = _storage.ref(attachment.storagePath);
      await storageRef.delete();

      // Remove from Firestore
      await _firestore.collection('bookings').doc(bookingId).update({
        'attachments': FieldValue.arrayRemove([attachment.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('ERROR deleting attachment: $e');
      rethrow;
    }
  }
}
