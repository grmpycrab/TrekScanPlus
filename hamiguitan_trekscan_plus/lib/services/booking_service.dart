import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../models/booking_model.dart';

class BookingService {
  BookingService._();
  static final instance = BookingService._();

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  /// Create a booking document and return its generated id
  Future<String> createBooking(BookingModel booking) async {
    final data = booking.toMap();
    // Remove id if present so Firestore generates one
    data.remove('id');
    final docRef = await _firestore.collection('bookings').add(data);
    return docRef.id;
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

  Future<void> cancelBooking(String bookingId) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
