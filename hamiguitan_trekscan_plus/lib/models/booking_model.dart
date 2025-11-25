import 'package:cloud_firestore/cloud_firestore.dart';

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
  String? id;
  final String userId;
  final String affiliation;
  final Timestamp trekDate;
  final int numberOfPorters;
  final String trekType; // recreational | research
  final String hometown; // User's hometown/city
  final bool isSenior; // Whether the user is a senior citizen
  final String phoneNumber; // Contact phone number
  final String? notes;
  final String? adminNotes;
  List<Attachment> attachments;
  String status;
  final Timestamp createdAt;
  Timestamp? updatedAt;

  BookingModel({
    this.id,
    required this.userId,
    required this.affiliation,
    required this.trekDate,
    required this.numberOfPorters,
    required this.trekType,
    this.hometown = '',
    this.isSenior = false,
    this.phoneNumber = '',
    this.notes,
    this.adminNotes,
    this.attachments = const [],
    this.status = 'pending',
    Timestamp? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'userId': userId,
    'affiliation': affiliation,
    'trekDate': trekDate,
    'numberOfPorters': numberOfPorters,
    'trekType': trekType,
    'hometown': hometown,
    'isSenior': isSenior,
    'phoneNumber': phoneNumber,
    'notes': notes,
    'adminNotes': adminNotes,
    'attachments': attachments.map((a) => a.toMap()).toList(),
    'status': status,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory BookingModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      userId: data['userId'] as String,
      affiliation: data['affiliation'] as String? ?? '',
      trekDate: data['trekDate'] as Timestamp,
      numberOfPorters: (data['numberOfPorters'] as num?)?.toInt() ?? 0,
      trekType: data['trekType'] as String? ?? 'recreational',
      hometown: data['hometown'] as String? ?? '',
      isSenior: data['isSenior'] as bool? ?? false,
      phoneNumber: data['phoneNumber'] as String? ?? '',
      notes: data['notes'] as String?,
      adminNotes: data['adminNotes'] as String?,
      attachments:
          (data['attachments'] as List<dynamic>?)
              ?.map((e) => Attachment.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      status: data['status'] as String? ?? 'pending',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }
}
