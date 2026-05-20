import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import '../models/booking_model.dart';
import '../models/group_booking.dart';
import 'pricing_service.dart';
import '../models/join_request.dart';
import '../features/notification/models/notification_model.dart';
import '../features/notification/services/firestore_notification_service.dart';
import '../features/notification/services/fcm_service.dart';
import '../utils/app_logger.dart';

/// Top-level image compressor so it can be run via [compute].
Uint8List _compressImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  const maxDimension = 1920;
  img.Image resized;
  if (decoded.width > maxDimension || decoded.height > maxDimension) {
    resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxDimension)
        : img.copyResize(decoded, height: maxDimension);
  } else {
    resized = decoded;
  }
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}

/// Handles all Firestore and Storage operations for group bookings and
/// the join-request approval workflow.
///
/// Firestore layout:
///   groupBookings/{groupId}                  → [GroupBooking]
///   groupBookings/{groupId}/joinRequests/{id} → [JoinRequest]
class GroupBookingService {
  GroupBookingService._();
  static final instance = GroupBookingService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;
  final _notifications = InAppNotificationService();

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groupBookings');

  CollectionReference<Map<String, dynamic>> _requests(String groupId) =>
      _groups.doc(groupId).collection('joinRequests');

  // ──────────────────────────────────────────────────────────────────────────
  // OFF-SEASON HELPER
  // ──────────────────────────────────────────────────────────────────────────

  /// Delegates to [PricingService] so the off-season window is configured
  /// in a single place (Firestore `pricingVersions` → `seasonalRules`).
  static bool isOffSeason(DateTime date) =>
      PricingService.instance.isOffSeason(date);

  static String resolveSeasonType(DateTime date) =>
      isOffSeason(date) ? 'off_season' : 'regular';

  // ──────────────────────────────────────────────────────────────────────────
  // GROUP BOOKING CRUD
  // ──────────────────────────────────────────────────────────────────────────

  /// Create a new group booking.
  ///
  /// Off-season regular treks are rejected unless the type is 'special_trek'
  /// or 'government_official'.  The organizer automatically becomes slot #1.
  Future<String> createGroupBooking(GroupBooking group) async {
    final trekDate = group.trekDate.toDate();
    if (isOffSeason(trekDate) &&
        group.trekType == 'regular_trek' &&
        group.bookingClassification == 'regular') {
      throw Exception(
        'Regular bookings are restricted during the off-season '
        '(July 1 – September 30).  Submit a special or official booking instead.',
      );
    }

    final data = group.toMap()
      ..['seasonType'] = resolveSeasonType(trekDate)
      ..['currentSlots'] = 1 + group.guestMembers.length
      ..['status'] = 'open';

    data.remove('id');
    final ref = await _groups.add(data);
    AppLogger.i('GroupBooking created: ${ref.id}');
    return ref.id;
  }

  /// Fetch a single group booking.
  Future<GroupBooking?> getGroupBooking(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) return null;
    return GroupBooking.fromDoc(doc);
  }

  /// Real-time stream of all OPEN groups available for joining.
  Stream<List<GroupBooking>> streamOpenGroups() {
    return _groups
        .where('status', isEqualTo: 'open')
        .orderBy('trekDate')
        .snapshots()
        .map((snap) => snap.docs.map(GroupBooking.fromDoc).toList());
  }

  /// Real-time stream of groups created by [organizerId].
  Stream<List<GroupBooking>> streamOrganizerGroups(String organizerId) {
    return _groups
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(GroupBooking.fromDoc).toList());
  }

  /// Real-time stream of groups the user has joined (approved requests).
  Stream<List<GroupBooking>> streamJoinedGroups(String userId) async* {
    // Firestore can't do cross-collection group-queries here easily;
    // collect group IDs from approved join requests then stream those groups.
    final requestSnap = await _db
        .collectionGroup('joinRequests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .get();

    final groupIds = requestSnap.docs
        .map((d) => d['groupId'] as String)
        .toSet()
        .toList();

    if (groupIds.isEmpty) {
      yield [];
      return;
    }

    yield* _groups
        .where(FieldPath.documentId, whereIn: groupIds)
        .snapshots()
        .map((snap) => snap.docs.map(GroupBooking.fromDoc).toList());
  }

  /// Update group status (admin use).
  Future<void> updateGroupStatus(
    String groupId,
    String status, {
    String? adminNotes,
    String? linkedBookingId,
  }) async {
    await _groups.doc(groupId).update({
      'status': status,
      if (adminNotes != null) 'adminNotes': adminNotes,
      if (linkedBookingId != null) 'linkedBookingId': linkedBookingId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // JOIN REQUEST WORKFLOW
  // ──────────────────────────────────────────────────────────────────────────

  /// Submit a join request.  Notifies the organizer immediately.
  Future<String> submitJoinRequest(JoinRequest request) async {
    // Prevent duplicate pending requests from the same user
    final existing = await _requests(request.groupId)
        .where('userId', isEqualTo: request.userId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception(
        'You already have a pending join request for this group.',
      );
    }

    // Prevent joining a group the user already belongs to
    final approved = await _requests(request.groupId)
        .where('userId', isEqualTo: request.userId)
        .where('status', isEqualTo: 'approved')
        .get();
    if (approved.docs.isNotEmpty) {
      throw Exception('You are already a member of this group.');
    }

    final data = request.toMap()..remove('id');
    final ref = await _requests(request.groupId).add(data);

    // Notify organizer
    final group = await getGroupBooking(request.groupId);
    if (group != null) {
      await _notifyOrganizer(
        organizerId: group.organizerId,
        groupId: request.groupId,
        groupName: group.groupName,
        requestId: ref.id,
        requesterName: request.userDisplayName,
      );
    }

    AppLogger.i('JoinRequest submitted: ${ref.id}');
    return ref.id;
  }

  /// Real-time stream of join requests for a group (organizer view).
  Stream<List<JoinRequest>> streamJoinRequests(
    String groupId, {
    String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _requests(groupId);
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(JoinRequest.fromDoc).toList());
  }

  /// Stream a single user's own join request for a group.
  Stream<JoinRequest?> streamMyRequest(String groupId, String userId) {
    return _requests(groupId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snap) =>
            snap.docs.isEmpty ? null : JoinRequest.fromDoc(snap.docs.first));
  }

  /// Organizer approves a join request.
  ///
  /// - Updates request status → 'approved'
  /// - Sets affiliation to the group's affiliation
  /// - Increments [GroupBooking.currentSlots]
  /// - Marks group as 'full' if no slots remain
  /// - Notifies the requesting user
  Future<void> approveJoinRequest(String groupId, String requestId) async {
    final organizerId = _auth.currentUser?.uid;
    if (organizerId == null) throw Exception('Not authenticated');

    final groupDoc = await _groups.doc(groupId).get();
    if (!groupDoc.exists) throw Exception('Group not found');
    final group = GroupBooking.fromDoc(groupDoc);

    if (group.isFull) {
      throw Exception('Group is already full.  No more slots available.');
    }

    final requestDoc = await _requests(groupId).doc(requestId).get();
    if (!requestDoc.exists) throw Exception('Join request not found');
    final request = JoinRequest.fromDoc(requestDoc);

    final newSlots = group.currentSlots + 1;
    final newGroupStatus = newSlots >= group.maxSlots ? 'full' : group.status;

    // Batch update for atomicity
    final batch = _db.batch();

    batch.update(_requests(groupId).doc(requestId), {
      'status': 'approved',
      'affiliation': group.affiliation,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': organizerId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_groups.doc(groupId), {
      'currentSlots': newSlots,
      'status': newGroupStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Notify requester
    await _notifyRequester(
      userId: request.userId,
      groupId: groupId,
      requestId: requestId,
      groupName: group.groupName,
      approved: true,
    );

    AppLogger.i('JoinRequest $requestId approved for group $groupId');
  }

  /// Organizer declines a join request.
  Future<void> declineJoinRequest(
    String groupId,
    String requestId, {
    String? reason,
  }) async {
    final organizerId = _auth.currentUser?.uid;
    if (organizerId == null) throw Exception('Not authenticated');

    final requestDoc = await _requests(groupId).doc(requestId).get();
    if (!requestDoc.exists) throw Exception('Join request not found');
    final request = JoinRequest.fromDoc(requestDoc);

    final groupDoc = await _groups.doc(groupId).get();
    final group = GroupBooking.fromDoc(groupDoc);

    await _requests(groupId).doc(requestId).update({
      'status': 'declined',
      'declineReason': reason,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': organizerId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _notifyRequester(
      userId: request.userId,
      groupId: groupId,
      requestId: requestId,
      groupName: group.groupName,
      approved: false,
      declineReason: reason,
    );

    AppLogger.i('JoinRequest $requestId declined for group $groupId');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ATTACHMENT UPLOAD
  // ──────────────────────────────────────────────────────────────────────────

  /// Upload a file for a join request.
  Future<Attachment> uploadJoinRequestAttachment(
    String groupId,
    String requestId,
    PlatformFile file, {
    String? memberName,
  }) async {
    final rand = Random().nextInt(100000);
    final name = '${DateTime.now().millisecondsSinceEpoch}_${rand}_${file.name}';
    final path = 'groupBookings/$groupId/joinRequests/$requestId/attachments/$name';
    final ref = _storage.ref(path);

    final metadata = SettableMetadata(
      contentType: file.extension != null
          ? _mimeType(file.extension!)
          : 'application/octet-stream',
    );

    UploadTask task;
    if (file.bytes != null) {
      var bytes = file.bytes!;
      if (_isImage(file.extension)) {
        try {
          final compressed = await compute(_compressImageBytes, bytes);
          if (compressed.length < bytes.length) bytes = compressed;
        } catch (_) {}
      }
      task = ref.putData(bytes, metadata);
    } else if (file.path != null) {
      task = ref.putFile(File(file.path!), metadata);
    } else {
      throw ArgumentError('File has neither path nor bytes');
    }

    final snapshot = await task;
    final url = await ref.getDownloadURL();
    final attachment = Attachment(
      storagePath: snapshot.ref.fullPath,
      downloadURL: url,
      fileName: file.name,
      mimeType: snapshot.metadata?.contentType,
      size: snapshot.totalBytes,
      uploadedAt: Timestamp.now(),
      memberName: memberName,
    );

    await _requests(groupId).doc(requestId).update({
      'attachments': FieldValue.arrayUnion([attachment.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return attachment;
  }

  /// Upload the Letter of Communication for a special/official group booking.
  Future<Attachment> uploadLetterOfCommunication(
    String groupId,
    PlatformFile file,
  ) async {
    final rand = Random().nextInt(100000);
    final name = '${DateTime.now().millisecondsSinceEpoch}_${rand}_${file.name}';
    final path = 'groupBookings/$groupId/letter/$name';
    final ref = _storage.ref(path);

    final metadata = SettableMetadata(
      contentType: file.extension != null
          ? _mimeType(file.extension!)
          : 'application/octet-stream',
    );

    UploadTask task;
    if (file.bytes != null) {
      task = ref.putData(file.bytes!, metadata);
    } else if (file.path != null) {
      task = ref.putFile(File(file.path!), metadata);
    } else {
      throw ArgumentError('File has neither path nor bytes');
    }

    final snapshot = await task;
    final url = await ref.getDownloadURL();
    final attachment = Attachment(
      storagePath: snapshot.ref.fullPath,
      downloadURL: url,
      fileName: file.name,
      mimeType: snapshot.metadata?.contentType,
      size: snapshot.totalBytes,
      uploadedAt: Timestamp.now(),
    );

    await _groups.doc(groupId).update({
      'letterOfCommunication': attachment.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return attachment;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PRIVATE NOTIFICATIONS
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _notifyOrganizer({
    required String organizerId,
    required String groupId,
    required String groupName,
    required String requestId,
    required String requesterName,
  }) async {
    try {
      final notification = NotificationModel(
        id: '',
        title: 'New Join Request',
        message: '$requesterName wants to join "$groupName".',
        type: NotificationType.info,
        timestamp: DateTime.now(),
        isRead: false,
        actionType: 'join_request',
        actionData: '$groupId/$requestId',
      );
      await _notifications.sendNotificationForUser(organizerId, notification);
      await FCMService().sendNotificationToUser(
        targetUserId: organizerId,
        title: 'New Join Request',
        message: '$requesterName wants to join "$groupName".',
        actionType: 'join_request',
        actionData: '$groupId/$requestId',
      );
    } catch (e) {
      AppLogger.w('Failed to notify organizer: $e');
    }
  }

  Future<void> _notifyRequester({
    required String userId,
    required String groupId,
    required String requestId,
    required String groupName,
    required bool approved,
    String? declineReason,
  }) async {
    try {
      final title = approved ? 'Join Request Approved ✓' : 'Join Request Declined';
      final message = approved
          ? 'You have been accepted into "$groupName".'
          : 'Your request to join "$groupName" was declined.'
              '${declineReason != null ? " Reason: $declineReason" : ""}';

      final notification = NotificationModel(
        id: '',
        title: title,
        message: message,
        type: approved ? NotificationType.success : NotificationType.alert,
        timestamp: DateTime.now(),
        isRead: false,
        actionType: 'join_request_result',
        actionData: '$groupId/$requestId',
      );
      await _notifications.sendNotificationForUser(userId, notification);
      await FCMService().sendNotificationToUser(
        targetUserId: userId,
        title: title,
        message: message,
        actionType: approved ? 'join_approved' : 'join_declined',
        actionData: '$groupId/$requestId',
      );
    } catch (e) {
      AppLogger.w('Failed to notify requester: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  bool _isImage(String? ext) =>
      ext != null && ['jpg', 'jpeg', 'png', 'webp'].contains(ext.toLowerCase());

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}
