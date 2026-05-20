import 'package:cloud_firestore/cloud_firestore.dart';
import 'booking_model.dart';
import 'member.dart';

/// Firestore path: `groupBookings/{groupId}/joinRequests/{requestId}`
///
/// Created when a user submits a request to join an existing [GroupBooking].
/// The organizer receives a notification and can accept or decline.
/// On acceptance the affiliation is updated to the group's affiliation and
/// the user is added to the group roster.
class JoinRequest {
  final String id;
  final String groupId;
  final String userId; // requesting user
  final String userDisplayName;

  /// The member info filled in by the requesting user
  final Member member;

  /// Porter preference (per-member service)
  final bool porterRequested;

  /// Starts as 'pending_group'; updated to the group's affiliation on approval
  String affiliation;

  /// 'pending' | 'approved' | 'declined'
  String status;

  final String? notes;
  final String? declineReason;

  final List<Attachment> attachments;

  final Timestamp createdAt;
  Timestamp? updatedAt;
  Timestamp? reviewedAt;
  String? reviewedBy; // organizer userId

  JoinRequest({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userDisplayName,
    required this.member,
    this.porterRequested = false,
    this.affiliation = 'pending_group',
    this.status = 'pending',
    this.notes,
    this.declineReason,
    this.attachments = const [],
    Timestamp? createdAt,
    this.updatedAt,
    this.reviewedAt,
    this.reviewedBy,
  }) : createdAt = createdAt ?? Timestamp.now();

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDeclined => status == 'declined';

  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'userId': userId,
    'userDisplayName': userDisplayName,
    'member': member.toMap(),
    'porterRequested': porterRequested,
    'affiliation': affiliation,
    'status': status,
    'notes': notes,
    'declineReason': declineReason,
    'attachments': attachments.map((a) => a.toMap()).toList(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'reviewedAt': reviewedAt,
    'reviewedBy': reviewedBy,
  };

  factory JoinRequest.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JoinRequest(
      id: doc.id,
      groupId: d['groupId'] as String,
      userId: d['userId'] as String,
      userDisplayName: d['userDisplayName'] as String? ?? '',
      member: Member.fromMap(
        Map<String, dynamic>.from(d['member'] as Map),
      ),
      porterRequested: d['porterRequested'] as bool? ?? false,
      affiliation: d['affiliation'] as String? ?? 'pending_group',
      status: d['status'] as String? ?? 'pending',
      notes: d['notes'] as String?,
      declineReason: d['declineReason'] as String?,
      attachments: (d['attachments'] as List<dynamic>?)
              ?.map((e) => Attachment.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: d['updatedAt'] as Timestamp?,
      reviewedAt: d['reviewedAt'] as Timestamp?,
      reviewedBy: d['reviewedBy'] as String?,
    );
  }

  JoinRequest copyWith({
    String? id,
    String? groupId,
    String? userId,
    String? userDisplayName,
    Member? member,
    bool? porterRequested,
    String? affiliation,
    String? status,
    String? notes,
    String? declineReason,
    List<Attachment>? attachments,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Timestamp? reviewedAt,
    String? reviewedBy,
  }) => JoinRequest(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    userId: userId ?? this.userId,
    userDisplayName: userDisplayName ?? this.userDisplayName,
    member: member ?? this.member,
    porterRequested: porterRequested ?? this.porterRequested,
    affiliation: affiliation ?? this.affiliation,
    status: status ?? this.status,
    notes: notes ?? this.notes,
    declineReason: declineReason ?? this.declineReason,
    attachments: attachments ?? this.attachments,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    reviewedBy: reviewedBy ?? this.reviewedBy,
  );
}
