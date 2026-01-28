import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'member.dart';

class Attachment {
  final String storagePath;
  final String downloadURL;
  final String fileName;
  final String? mimeType;
  final int size;
  final Timestamp uploadedAt;

  Attachment({
    required this.storagePath,
    required this.downloadURL,
    required this.fileName,
    this.mimeType,
    required this.size,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() => {
    'storagePath': storagePath,
    'downloadURL': downloadURL,
    'fileName': fileName,
    'mimeType': mimeType,
    'size': size,
    'uploadedAt': uploadedAt,
  };

  factory Attachment.fromMap(Map<String, dynamic> m) => Attachment(
    storagePath: m['storagePath'] as String,
    downloadURL: m['downloadURL'] as String,
    fileName: m['fileName'] as String,
    mimeType: m['mimeType'] as String?,
    size: (m['size'] as num).toInt(),
    uploadedAt: m['uploadedAt'] as Timestamp,
  );
}

class BookingModel {
  final String id; // Now non-nullable - always generated or from Firestore
  final String userId;
  final String affiliation;
  final Timestamp trekDate;
  final String
  trekType; // 'special_trek', 'benchmarking_trek', 'research_trek', 'regular_trek'
  final String hometown; // Primary contact's hometown/city
  final String phoneNumber; // Primary contact's phone number
  final String? notes;
  final String? adminNotes;
  List<Attachment> attachments;
  List<Member> members; // Group members - primary contact is first member
  String status;
  String
  submissionStatus; // 'draft' (saved locally) or 'submitted' (sent to system)
  final Timestamp createdAt;
  Timestamp? updatedAt;

  BookingModel({
    String? id,
    required this.userId,
    required this.affiliation,
    required this.trekDate,
    required this.trekType,
    this.hometown = '',
    this.phoneNumber = '',
    this.notes,
    this.adminNotes,
    this.attachments = const [],
    this.members = const [],
    this.status = 'pending',
    this.submissionStatus = 'draft', // Default to draft when creating
    Timestamp? createdAt,
    this.updatedAt,
  }) : id = id ?? _generateDraftId(),
       createdAt = createdAt ?? Timestamp.now();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id, // Always include ID
      'userId': userId,
      'affiliation': affiliation,
      'trekDate': trekDate,
      'trekType': trekType,
      'hometown': hometown,
      'phoneNumber': phoneNumber,
      'notes': notes,
      'adminNotes': adminNotes,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'members': members.map((m) => m.toMap()).toList(),
      'totalMembers': members.length,
      'status': status,
      'submissionStatus': submissionStatus,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    return map;
  }

  /// Parse adminNotes from Firestore which might be String, List, or Map
  /// Firebase stores it as JSON string: '[{"id":"...","text":"...","adminName":"..."}]'
  static String? _parseAdminNotes(dynamic adminNotes) {
    if (adminNotes == null) return null;

    // If it's a String, try to parse it as JSON first
    if (adminNotes is String) {
      final trimmed = adminNotes.trim();
      if (trimmed.isEmpty) return null;

      // Check if it's a JSON string (starts with [ or {)
      if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
        try {
          final parsed = jsonDecode(trimmed);
          // Recursively parse the decoded JSON
          return _parseAdminNotes(parsed);
        } catch (e) {
          // If JSON parsing fails, return null to hide malformed data
          return null;
        }
      }
      // Plain text string
      return trimmed;
    }

    // If it's a List (e.g., [{"text": "..."}]), extract first message
    if (adminNotes is List && adminNotes.isNotEmpty) {
      final first = adminNotes.first;
      if (first is Map) {
        // Try common field names for the message (text, message, note, adminNotes)
        final message =
            first['text'] ??
            first['message'] ??
            first['note'] ??
            first['adminNotes'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      } else if (first is String) {
        return first.trim().isEmpty ? null : first.trim();
      }
    }

    // If it's a Map, extract message field
    if (adminNotes is Map) {
      final message =
          adminNotes['text'] ??
          adminNotes['message'] ??
          adminNotes['note'] ??
          adminNotes['adminNotes'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    // Fallback: return null to hide unparseable data
    return null;
  }

  /// Generate a unique draft ID for local storage
  /// Format: draft_TIMESTAMP_RANDOM to ensure uniqueness
  static String _generateDraftId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(100000);
    return 'draft_${timestamp}_$random';
  }

  factory BookingModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      userId: data['userId'] as String,
      affiliation: data['affiliation'] as String? ?? '',
      trekDate: data['trekDate'] as Timestamp,
      trekType: data['trekType'] as String? ?? 'regular_trek',
      hometown: data['hometown'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      notes: data['notes'] as String?,
      adminNotes: _parseAdminNotes(data['adminNotes']),
      attachments:
          (data['attachments'] as List<dynamic>?)
              ?.map((e) => Attachment.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      members: const [], // Members loaded separately from subcollection
      status: data['status'] as String? ?? 'pending',
      submissionStatus: data['submissionStatus'] as String? ?? 'submitted',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  /// Create BookingModel from JSON data (for local storage)
  factory BookingModel.fromJson(Map<String, dynamic> data) {
    return BookingModel(
      id: data['id'] as String?,
      userId: data['userId'] as String,
      affiliation: data['affiliation'] as String? ?? '',
      trekDate: _parseTimestamp(data['trekDate']),
      trekType: data['trekType'] as String? ?? 'regular_trek',
      hometown: data['hometown'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      notes: data['notes'] as String?,
      adminNotes: _parseAdminNotes(data['adminNotes']),
      attachments:
          (data['attachments'] as List<dynamic>?)
              ?.map((e) => Attachment.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      members:
          (data['members'] as List<dynamic>?)
              ?.map((e) => Member.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      status: data['status'] as String? ?? 'pending',
      submissionStatus: data['submissionStatus'] as String? ?? 'draft',
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: data['updatedAt'] != null
          ? _parseTimestamp(data['updatedAt'])
          : null,
    );
  }

  /// Helper to parse Timestamp from various formats
  static Timestamp _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value;
    } else if (value is String) {
      return Timestamp.fromDate(DateTime.parse(value));
    } else if (value is int) {
      return Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(value));
    } else if (value is Map<String, dynamic>) {
      // Firestore timestamp format: {_seconds: int, _nanoseconds: int}
      final seconds = value['_seconds'] as int? ?? 0;
      final nanoseconds = value['_nanoseconds'] as int? ?? 0;
      return Timestamp.fromDate(
        DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000) + (nanoseconds ~/ 1000000),
        ),
      );
    }
    return Timestamp.now();
  }

  /// Get display name for submission status
  String get submissionStatusDisplayName {
    switch (submissionStatus.toLowerCase()) {
      case 'draft':
        return 'Draft (Not Submitted)';
      case 'submitted':
        return 'Submitted';
      default:
        return submissionStatus;
    }
  }

  /// Check if booking is a draft
  bool get isDraft => submissionStatus.toLowerCase() == 'draft';

  /// Create a copy of this booking with modified fields
  BookingModel copyWith({
    String? id,
    String? userId,
    String? affiliation,
    Timestamp? trekDate,
    String? trekType,
    String? hometown,
    String? phoneNumber,
    String? notes,
    String? adminNotes,
    List<Attachment>? attachments,
    List<Member>? members,
    String? status,
    String? submissionStatus,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      affiliation: affiliation ?? this.affiliation,
      trekDate: trekDate ?? this.trekDate,
      trekType: trekType ?? this.trekType,
      hometown: hometown ?? this.hometown,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      notes: notes ?? this.notes,
      adminNotes: adminNotes ?? this.adminNotes,
      attachments: attachments ?? this.attachments,
      members: members ?? this.members,
      status: status ?? this.status,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
