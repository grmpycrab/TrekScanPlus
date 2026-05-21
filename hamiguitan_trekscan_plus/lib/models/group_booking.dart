import 'package:cloud_firestore/cloud_firestore.dart';
import 'booking_model.dart';
import 'member.dart';
import 'trek_type.dart';

/// Firestore collection: `groupBookings`
///
/// A group booking is created by an organizer and can be joined by other
/// users through a [JoinRequest] workflow.  Once the admin approves the
/// group booking, all approved join-request members become part of the trek.
class GroupBooking {
  final String id;
  final String organizerId;
  final String organizerName;
  final String groupName;
  final Timestamp trekDate;

  /// Values: 'regular_trek' | 'special_trek' | 'government_official' |
  ///         'research_trek' | 'benchmarking_trek'
  final String trekType;

  /// Values: 'regular' | 'special' | 'government_official' | 'off_season'
  final String bookingClassification;

  /// Values: 'regular' | 'off_season'
  final String seasonType;

  /// Shared affiliation for all approved members
  final String affiliation;

  /// Maximum number of trekkers the organizer allows (incl. organizer)
  final int maxSlots;

  /// Number of currently approved members (organizer + approved join requests).
  /// Kept as a cached counter; source of truth is the joinRequests subcollection.
  final int currentSlots;

  /// 'open' | 'pending_review' | 'approved' | 'declined' | 'full' |
  /// 'completed' | 'cancelled'
  String status;

  final bool guideRequired; // Group-level tour guide
  final bool scientistRequired; // Group-level scientist
  final String? notes;

  /// Letter of Communication attachment — required for special / official bookings
  final Attachment? letterOfCommunication;

  final String? adminNotes;

  /// Firestore ID of the corresponding booking document created after admin
  /// approves the group (links group ↔ booking for roster tracking)
  final String? linkedBookingId;

  /// Organizer's full member record (personal info + category + porter choice)
  final Member? organizerMember;

  /// Walk-in / guest members added by the organizer during group creation.
  /// Registered app-users who join later appear as join requests instead.
  final List<Member> guestMembers;

  /// Documents uploaded for the organizer and guest members during group
  /// creation, stored at `groupBookings/{id}/attachments/`.
  final List<Attachment> attachments;

  final Timestamp createdAt;
  Timestamp? updatedAt;

  GroupBooking({
    required this.id,
    required this.organizerId,
    required this.organizerName,
    required this.groupName,
    required this.trekDate,
    required this.trekType,
    this.bookingClassification = 'regular',
    this.seasonType = 'regular',
    required this.affiliation,
    this.maxSlots = 30,
    this.currentSlots = 1, // organizer counts as slot 1
    this.status = 'open',
    this.guideRequired = false,
    this.scientistRequired = false,
    this.notes,
    this.letterOfCommunication,
    this.adminNotes,
    this.linkedBookingId,
    this.organizerMember,
    this.guestMembers = const [],
    this.attachments = const [],
    Timestamp? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  int get availableSlots => maxSlots - currentSlots;
  bool get isFull => currentSlots >= maxSlots;
  bool get isOpen => status == 'open' && !isFull;

  Map<String, dynamic> toMap() => {
    'organizerId': organizerId,
    'organizerName': organizerName,
    'groupName': groupName,
    'trekDate': trekDate,
    'trekType': trekType,
    'bookingClassification': bookingClassification,
    'seasonType': seasonType,
    'affiliation': affiliation,
    'maxSlots': maxSlots,
    'currentSlots': currentSlots,
    'status': status,
    'guideRequired': guideRequired,
    'scientistRequired': scientistRequired,
    'notes': notes,
    'letterOfCommunication': letterOfCommunication?.toMap(),
    'adminNotes': adminNotes,
    'linkedBookingId': linkedBookingId,
    'organizerMember': organizerMember?.toMap(),
    'guestMembers': guestMembers.map((m) => m.toMap()).toList(),
    'attachments': attachments.map((a) => a.toMap()).toList(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory GroupBooking.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupBooking(
      id: doc.id,
      organizerId: d['organizerId'] as String,
      organizerName: d['organizerName'] as String? ?? '',
      groupName: d['groupName'] as String? ?? '',
      trekDate: d['trekDate'] as Timestamp,
      trekType: d['trekType'] as String? ?? TrekType.regular.value,
      bookingClassification: d['bookingClassification'] as String? ?? 'regular',
      seasonType: d['seasonType'] as String? ?? 'regular',
      affiliation: d['affiliation'] as String? ?? '',
      maxSlots: (d['maxSlots'] as num?)?.toInt() ?? 30,
      currentSlots: (d['currentSlots'] as num?)?.toInt() ?? 1,
      status: d['status'] as String? ?? 'open',
      guideRequired: d['guideRequired'] as bool? ?? false,
      scientistRequired: d['scientistRequired'] as bool? ?? false,
      notes: d['notes'] as String?,
      letterOfCommunication: d['letterOfCommunication'] != null
          ? Attachment.fromMap(
              Map<String, dynamic>.from(d['letterOfCommunication'] as Map),
            )
          : null,
      adminNotes: d['adminNotes'] as String?,
      linkedBookingId: d['linkedBookingId'] as String?,
      organizerMember: d['organizerMember'] != null
          ? Member.fromMap(
              Map<String, dynamic>.from(d['organizerMember'] as Map),
            )
          : null,
      guestMembers: (d['guestMembers'] as List<dynamic>?)
              ?.map((e) => Member.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      attachments: (d['attachments'] as List<dynamic>?)
              ?.map((e) => Attachment.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }

  GroupBooking copyWith({
    String? id,
    String? organizerId,
    String? organizerName,
    String? groupName,
    Timestamp? trekDate,
    String? trekType,
    String? bookingClassification,
    String? seasonType,
    String? affiliation,
    int? maxSlots,
    int? currentSlots,
    String? status,
    bool? guideRequired,
    bool? scientistRequired,
    String? notes,
    Attachment? letterOfCommunication,
    String? adminNotes,
    String? linkedBookingId,
    Member? organizerMember,
    List<Member>? guestMembers,
    List<Attachment>? attachments,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) => GroupBooking(
    id: id ?? this.id,
    organizerId: organizerId ?? this.organizerId,
    organizerName: organizerName ?? this.organizerName,
    groupName: groupName ?? this.groupName,
    trekDate: trekDate ?? this.trekDate,
    trekType: trekType ?? this.trekType,
    bookingClassification: bookingClassification ?? this.bookingClassification,
    seasonType: seasonType ?? this.seasonType,
    affiliation: affiliation ?? this.affiliation,
    maxSlots: maxSlots ?? this.maxSlots,
    currentSlots: currentSlots ?? this.currentSlots,
    status: status ?? this.status,
    guideRequired: guideRequired ?? this.guideRequired,
    scientistRequired: scientistRequired ?? this.scientistRequired,
    notes: notes ?? this.notes,
    letterOfCommunication: letterOfCommunication ?? this.letterOfCommunication,
    adminNotes: adminNotes ?? this.adminNotes,
    linkedBookingId: linkedBookingId ?? this.linkedBookingId,
    organizerMember: organizerMember ?? this.organizerMember,
    guestMembers: guestMembers ?? this.guestMembers,
    attachments: attachments ?? this.attachments,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Human-readable classification label
  String get classificationLabel {
    switch (bookingClassification) {
      case 'special':
        return 'Special';
      case 'government_official':
        return 'Government / Official';
      case 'off_season':
        return 'Off-Season (Special Approval)';
      default:
        return 'Regular';
    }
  }

  /// Human-readable trek type label
  String get trekTypeLabel {
    if (trekType == TrekType.research.value) return 'Research';
    if (trekType == TrekType.special.value) return 'Special';
    if (trekType == TrekType.benchmarking.value) return 'Benchmarking';
    if (trekType == 'government_official') return 'Government / Official';
    return 'Regular';
  }
}
