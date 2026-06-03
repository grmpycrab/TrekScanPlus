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
import '../models/member.dart';
import '../models/trek_type.dart';
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

  /// Returns true when the organizer is allowed to edit the group.
  /// Editing is permitted only when the group has not yet been submitted
  /// for admin review, or when the admin has sent it back for changes.
  static bool isEditable(String status) =>
      status == 'open' || status == 'changes_required';

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
        group.trekType == TrekType.regular.value &&
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

  /// Real-time stream of groups created by [organizerId] (excludes archived).
  Stream<List<GroupBooking>> streamOrganizerGroups(String organizerId) {
    return _groups
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(GroupBooking.fromDoc)
            .where((g) => !g.isArchived)
            .toList());
  }

  /// Real-time stream of groups the user has joined (approved requests).
  ///
  /// Listens to the [joinRequests] collectionGroup so the "Groups I Joined"
  /// tab updates immediately when a new request is approved — fixing the
  /// stale-tab bug where a one-shot [getDocs] was used as the trigger.
  ///
  /// Requires the composite index:
  ///   collectionGroup(joinRequests) → userId ASC, status ASC
  /// (Already created by the original [getDocs] query in this method.)
  Stream<List<GroupBooking>> streamJoinedGroups(String userId) {
    return _db
        .collectionGroup('joinRequests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .asyncMap((snap) async {
          final groupIds = snap.docs
              .map((d) => d['groupId'] as String)
              .toSet()
              .toList();

          if (groupIds.isEmpty) return <GroupBooking>[];

          final groupSnap = await _groups
              .where(FieldPath.documentId, whereIn: groupIds)
              .get();

          return groupSnap.docs
              .map(GroupBooking.fromDoc)
              .where((g) => !g.isArchived)
              .toList();
        });
  }

  /// Update group status (admin use).
  ///
  /// Setting status to 'cancelled' automatically marks the group as archived
  /// so it is hidden from all users' "My Groups" lists.
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
      if (status == 'cancelled') 'isArchived': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GROUP EDITING
  // ──────────────────────────────────────────────────────────────────────────

  /// Update editable group booking fields.
  /// Only call when [isEditable] returns true for the current status.
  Future<void> updateGroupBooking(
    String groupId, {
    String? groupName,
    Timestamp? trekDate,
    int? maxSlots,
    String? trekType,
    String? affiliation,
    bool? guideRequired,
    bool? scientistRequired,
    String? notes,
    Member? organizerMember,
    List<Member>? guestMembers,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (groupName != null) data['groupName'] = groupName;
    if (trekDate != null) {
      data['trekDate'] = trekDate;
      data['seasonType'] = resolveSeasonType(trekDate.toDate());
    }
    if (maxSlots != null) data['maxSlots'] = maxSlots;
    if (trekType != null) data['trekType'] = trekType;
    if (affiliation != null) data['affiliation'] = affiliation;
    if (guideRequired != null) data['guideRequired'] = guideRequired;
    if (scientistRequired != null) data['scientistRequired'] = scientistRequired;
    if (notes != null) data['notes'] = notes;
    if (organizerMember != null) {
      data['organizerMember'] = organizerMember.toMap();
    }
    if (guestMembers != null) {
      data['guestMembers'] = guestMembers.map((m) => m.toMap()).toList();
    }
    await _groups.doc(groupId).update(data);
    AppLogger.i('GroupBooking $groupId updated');
  }

  /// Delete a group-level attachment from both Storage and Firestore.
  Future<void> deleteGroupAttachment(
    String groupId,
    Attachment attachment,
  ) async {
    try {
      await _storage.ref(attachment.storagePath).delete();
    } catch (e) {
      AppLogger.w('Storage delete failed for ${attachment.storagePath}: $e');
    }
    await _groups.doc(groupId).update({
      'attachments': FieldValue.arrayRemove([attachment.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// After fixing what the admin flagged, reset status to pending_review
  /// and clear the admin's note so they see a fresh submission.
  Future<void> resubmitGroup(String groupId) async {
    await _groups.doc(groupId).update({
      'status': 'pending_review',
      'adminNotes': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    AppLogger.i('GroupBooking $groupId resubmitted for review');
  }

  /// Update a join request's member details and/or porter preference.
  /// Only call when the request status allows editing (pending / changes_required).
  Future<void> updateJoinRequestDetails(
    String groupId,
    String requestId, {
    Member? member,
    bool? porterRequested,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (member != null) data['member'] = member.toMap();
    if (porterRequested != null) data['porterRequested'] = porterRequested;
    await _requests(groupId).doc(requestId).update(data);
    AppLogger.i('JoinRequest $requestId details updated');
  }

  /// Soft-deletes a group by marking it archived — hidden from all list views.
  Future<void> archiveGroup(String groupId) async {
    await _groups.doc(groupId).update({
      'isArchived': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    AppLogger.i('GroupBooking $groupId archived');
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

  /// Real-time stream of a single [GroupBooking] document.
  Stream<GroupBooking?> streamGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map(
          (doc) => doc.exists ? GroupBooking.fromDoc(doc) : null,
        );
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

  /// Real-time stream of ALL join requests submitted by [userId] across every
  /// group.  Powers the "Requests" tab in [MyBookingsScreen].
  ///
  /// Requires a Firestore composite index on `joinRequests`:
  ///   userId ASC, createdAt DESC
  Stream<List<JoinRequest>> streamUserJoinRequests(String userId) {
    return _db
        .collectionGroup('joinRequests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(JoinRequest.fromDoc).toList());
  }

  /// Allows an approved member to leave a group they joined.
  ///
  /// Batch-writes atomically:
  /// - Marks the user's approved request as 'withdrawn'
  /// - Decrements [currentSlots]
  /// - Re-opens the group if it was previously 'full'
  Future<void> leaveGroup(String groupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final requestSnap = await _requests(groupId)
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();

    if (requestSnap.docs.isEmpty) {
      throw Exception('No approved membership found for this group.');
    }

    final requestDocId = requestSnap.docs.first.id;
    final groupDoc = await _groups.doc(groupId).get();
    if (!groupDoc.exists) throw Exception('Group not found');

    final group = GroupBooking.fromDoc(groupDoc);
    final newSlots = (group.currentSlots - 1).clamp(0, group.maxSlots);
    final newStatus = group.status == 'full' ? 'open' : group.status;

    final batch = _db.batch();

    batch.update(_requests(groupId).doc(requestDocId), {
      'status': 'withdrawn',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_groups.doc(groupId), {
      'currentSlots': newSlots,
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    AppLogger.i('User $uid left group $groupId');
  }

  /// Allows a trekker to withdraw their own pending join request.
  Future<void> withdrawJoinRequest(String groupId, String requestId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final doc = await _requests(groupId).doc(requestId).get();
    if (!doc.exists) throw Exception('Request not found');

    final request = JoinRequest.fromDoc(doc);
    if (request.userId != uid) throw Exception('Not authorised');
    if (!request.isPending) {
      throw Exception('Only pending requests can be withdrawn');
    }

    await _requests(groupId).doc(requestId).update({
      'status': 'withdrawn',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    AppLogger.i('JoinRequest $requestId withdrawn by $uid');
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

  /// Organizer requests a member to fix/replace their documents.
  /// Sets the join request status to 'changes_required' and stores the note.
  Future<void> requestJoinDocumentChanges(
    String groupId,
    String requestId, {
    required String note,
  }) async {
    final organizerId = _auth.currentUser?.uid;
    if (organizerId == null) throw Exception('Not authenticated');

    await _requests(groupId).doc(requestId).update({
      'status': 'changes_required',
      'changesNote': note,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': organizerId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    AppLogger.i('Requested document changes for join request $requestId');
  }

  /// Delete a specific attachment from a join request (Storage + Firestore).
  Future<void> deleteJoinRequestAttachment(
    String groupId,
    String requestId,
    Attachment attachment,
  ) async {
    try {
      await _storage.ref(attachment.storagePath).delete();
    } catch (e) {
      AppLogger.w('Storage delete failed for ${attachment.storagePath}: $e');
    }
    await _requests(groupId).doc(requestId).update({
      'attachments': FieldValue.arrayRemove([attachment.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Member resubmits their join request after fixing their documents.
  /// Resets status back to 'pending' and clears the organizer's note.
  Future<void> resubmitJoinRequest(
    String groupId,
    String requestId,
  ) async {
    await _requests(groupId).doc(requestId).update({
      'status': 'pending',
      'changesNote': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    AppLogger.i('Join request $requestId resubmitted for group $groupId');
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

  /// Upload a document for the group organizer or a guest member.
  ///
  /// Files are stored at `groupBookings/{groupId}/attachments/` and appended
  /// to the group document's `attachments` array so admins can review them.
  Future<Attachment> uploadMemberAttachment(
    String groupId,
    PlatformFile file, {
    String? memberName,
  }) async {
    final rand = Random().nextInt(100000);
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${rand}_${file.name}';
    final path = 'groupBookings/$groupId/attachments/$name';
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

    await _groups.doc(groupId).update({
      'attachments': FieldValue.arrayUnion([attachment.toMap()]),
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
      ext != null &&
      ['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif']
          .contains(ext.toLowerCase());

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'gif':
        return 'image/gif';
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
