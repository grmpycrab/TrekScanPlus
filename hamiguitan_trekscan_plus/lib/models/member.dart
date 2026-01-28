import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an individual member in a group booking
class Member {
  String? id; // Firestore document ID
  final String firstName;
  final String lastName;
  final String gender; // 'male', 'female', 'other'
  final String birthDate; // YYYY-MM-DD format
  final String contactNumber;
  final String nationality;
  final String homeAddress;
  final String
  category; // 'student', 'senior_citizen', 'davao_oriental_resident', 'ocfdo', 'outside_davao_oriental', 'children_8_15', 'mfsm'
  final bool isPrimaryContact; // true if this member is the booking creator
  final bool hasAccount; // true if member has Firebase account
  final String? userId; // Firebase Auth UID if hasAccount=true
  final List<Map<String, dynamic>>
  attachments; // Category-specific file attachments
  String
  memberStatus; // 'pending', 'incomplete', 'complete', 'verified', 'rejected'
  final Timestamp createdAt;
  Timestamp? updatedAt;

  Member({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.birthDate,
    required this.contactNumber,
    required this.nationality,
    required this.homeAddress,
    required this.category,
    this.isPrimaryContact = false,
    this.hasAccount = false,
    this.userId,
    this.attachments = const [],
    this.memberStatus = 'pending',
    Timestamp? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'gender': gender,
    'birthDate': birthDate,
    'contactNumber': contactNumber,
    'nationality': nationality,
    'homeAddress': homeAddress,
    'category': category,
    'isPrimaryContact': isPrimaryContact,
    'hasAccount': hasAccount,
    if (userId != null) 'userId': userId,
    'attachments': attachments,
    'memberStatus': memberStatus,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory Member.fromMap(Map<String, dynamic> map) => Member(
    id: map['id'] as String?,
    firstName: map['firstName'] as String,
    lastName: map['lastName'] as String,
    gender: map['gender'] as String,
    birthDate: map['birthDate'] as String,
    contactNumber: map['contactNumber'] as String,
    nationality: map['nationality'] as String,
    homeAddress: map['homeAddress'] as String,
    category: map['category'] as String,
    isPrimaryContact: map['isPrimaryContact'] as bool? ?? false,
    hasAccount: map['hasAccount'] as bool? ?? false,
    userId: map['userId'] as String?,
    attachments:
        (map['attachments'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [],
    memberStatus: map['memberStatus'] as String? ?? 'pending',
    createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
    updatedAt: map['updatedAt'] as Timestamp?,
  );

  factory Member.fromDoc(DocumentSnapshot doc) =>
      Member.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id});

  /// Get full name
  String get fullName => '$firstName $lastName';

  /// Get member category display name
  String get categoryDisplayName {
    switch (category) {
      case 'student':
        return 'Student';
      case 'senior_citizen':
        return 'Senior Citizen';
      case 'davao_oriental_resident':
        return 'Davao Oriental Resident';
      case 'ocfdo':
        return 'OCFDO Member';
      case 'outside_davao_oriental':
        return 'Outside Davao Oriental';
      case 'children_8_15':
        return 'Children (8-15)';
      case 'mfsm':
        return 'MFSM Member';
      default:
        return category;
    }
  }

  /// Create a copy of this member with optional field overrides
  Member copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? gender,
    String? birthDate,
    String? contactNumber,
    String? nationality,
    String? homeAddress,
    String? category,
    bool? isPrimaryContact,
    bool? hasAccount,
    String? userId,
    List<Map<String, dynamic>>? attachments,
    String? memberStatus,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) => Member(
    id: id ?? this.id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    gender: gender ?? this.gender,
    birthDate: birthDate ?? this.birthDate,
    contactNumber: contactNumber ?? this.contactNumber,
    nationality: nationality ?? this.nationality,
    homeAddress: homeAddress ?? this.homeAddress,
    category: category ?? this.category,
    isPrimaryContact: isPrimaryContact ?? this.isPrimaryContact,
    hasAccount: hasAccount ?? this.hasAccount,
    userId: userId ?? this.userId,
    attachments: attachments ?? this.attachments,
    memberStatus: memberStatus ?? this.memberStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
