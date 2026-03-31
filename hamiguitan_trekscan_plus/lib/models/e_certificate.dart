// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:cloud_firestore/cloud_firestore.dart';

enum CertificateType {
  camp3, // Reached Camp 3 (Station 8)
  fullTrek, // Visited all stations
  peakConqueror, // Reached Peak (Station 14)
}

class ECertificate {
  final String certificateId;
  final String userId;
  final String trekkerName;
  final CertificateType certificateType;
  final DateTime dateEarned;
  final int stationsVisited;
  final double totalDistance; // in km
  final int totalTimeMinutes;
  final DateTime? trekStartDate;
  final DateTime? trekEndDate;
  final bool isVerified;
  final String verificationCode; // Unique code for verification
  final DateTime createdAt;
  final DateTime? lastUpdated;

  const ECertificate({
    required this.certificateId,
    required this.userId,
    required this.trekkerName,
    required this.certificateType,
    required this.dateEarned,
    required this.stationsVisited,
    required this.totalDistance,
    required this.totalTimeMinutes,
    this.trekStartDate,
    this.trekEndDate,
    this.isVerified = true,
    required this.verificationCode,
    required this.createdAt,
    this.lastUpdated,
  });

  /// Get certificate title based on type
  String getTitle() {
    switch (certificateType) {
      case CertificateType.camp3:
        return 'Camp 3 Trekker';
      case CertificateType.fullTrek:
        return 'Mt. Hamiguitan Full Trek Completer';
      case CertificateType.peakConqueror:
        return 'Mt. Hamiguitan Peak Conqueror';
    }
  }

  /// Get certificate description
  String getDescription() {
    switch (certificateType) {
      case CertificateType.camp3:
        return 'For successfully trekking from Station 1 (UNESCO Marker) to Station 8 (Camp 3)';
      case CertificateType.fullTrek:
        return 'For completing the entire Mt. Hamiguitan trail, visiting all stations';
      case CertificateType.peakConqueror:
        return 'For conquering the peak of Mt. Hamiguitan (Station 14) and reaching the highest point';
    }
  }

  /// Get certificate color based on type (for UI)
  String getColorCode() {
    switch (certificateType) {
      case CertificateType.camp3:
        return '#4CAF50'; // Green
      case CertificateType.fullTrek:
        return '#2196F3'; // Blue
      case CertificateType.peakConqueror:
        return '#FF9800'; // Orange
    }
  }

  /// Format date for certificate
  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Get certificate details as formatted string
  String getFormattedDetails() {
    final buffer = StringBuffer();
    buffer.writeln('Certificate Type: ${getTitle()}');
    buffer.writeln('Trekker Name: $trekkerName');
    buffer.writeln('Date Earned: ${formatDate(dateEarned)}');
    buffer.writeln('Stations Visited: $stationsVisited');
    buffer.writeln('Total Distance: ${totalDistance.toStringAsFixed(1)} km');
    buffer.writeln(
      'Total Time: ${(totalTimeMinutes / 60).toStringAsFixed(1)} hours',
    );
    buffer.writeln('Verification Code: $verificationCode');
    return buffer.toString();
  }

  factory ECertificate.fromJson(Map<String, dynamic> json) {
    return ECertificate(
      certificateId: json['certificateId'] as String,
      userId: json['userId'] as String,
      trekkerName: json['trekkerName'] as String,
      certificateType: CertificateType.values.firstWhere(
        (type) =>
            type.toString().split('.').last ==
            (json['certificateType'] as String),
        orElse: () => CertificateType.camp3,
      ),
      dateEarned: json['dateEarned'] != null
          ? DateTime.parse(json['dateEarned'] as String)
          : DateTime.now(),
      stationsVisited: json['stationsVisited'] as int? ?? 0,
      totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0.0,
      totalTimeMinutes: json['totalTimeMinutes'] as int? ?? 0,
      trekStartDate: json['trekStartDate'] != null
          ? DateTime.parse(json['trekStartDate'] as String)
          : null,
      trekEndDate: json['trekEndDate'] != null
          ? DateTime.parse(json['trekEndDate'] as String)
          : null,
      isVerified: json['isVerified'] as bool? ?? true,
      verificationCode: json['verificationCode'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }

  factory ECertificate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convert Timestamp fields to DateTime
    DateTime _parseTimestamp(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    return ECertificate(
      certificateId: doc.id,
      userId: data['userId'] as String? ?? '',
      trekkerName: data['trekkerName'] as String? ?? '',
      certificateType: CertificateType.values.firstWhere(
        (type) =>
            type.toString().split('.').last ==
            (data['certificateType'] as String? ?? 'camp3'),
        orElse: () => CertificateType.camp3,
      ),
      dateEarned: _parseTimestamp(data['dateEarned']),
      stationsVisited: data['stationsVisited'] as int? ?? 0,
      totalDistance: (data['totalDistance'] as num?)?.toDouble() ?? 0.0,
      totalTimeMinutes: data['totalTimeMinutes'] as int? ?? 0,
      trekStartDate: data['trekStartDate'] != null
          ? _parseTimestamp(data['trekStartDate'])
          : null,
      trekEndDate: data['trekEndDate'] != null
          ? _parseTimestamp(data['trekEndDate'])
          : null,
      isVerified: data['isVerified'] as bool? ?? true,
      verificationCode: data['verificationCode'] as String? ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      lastUpdated: data['lastUpdated'] != null
          ? _parseTimestamp(data['lastUpdated'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'certificateId': certificateId,
      'userId': userId,
      'trekkerName': trekkerName,
      'certificateType': certificateType.toString().split('.').last,
      'dateEarned': dateEarned.toIso8601String(),
      'stationsVisited': stationsVisited,
      'totalDistance': totalDistance,
      'totalTimeMinutes': totalTimeMinutes,
      'trekStartDate': trekStartDate?.toIso8601String(),
      'trekEndDate': trekEndDate?.toIso8601String(),
      'isVerified': isVerified,
      'verificationCode': verificationCode,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  ECertificate copyWith({
    String? certificateId,
    String? userId,
    String? trekkerName,
    CertificateType? certificateType,
    DateTime? dateEarned,
    int? stationsVisited,
    double? totalDistance,
    int? totalTimeMinutes,
    DateTime? trekStartDate,
    DateTime? trekEndDate,
    bool? isVerified,
    String? verificationCode,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) {
    return ECertificate(
      certificateId: certificateId ?? this.certificateId,
      userId: userId ?? this.userId,
      trekkerName: trekkerName ?? this.trekkerName,
      certificateType: certificateType ?? this.certificateType,
      dateEarned: dateEarned ?? this.dateEarned,
      stationsVisited: stationsVisited ?? this.stationsVisited,
      totalDistance: totalDistance ?? this.totalDistance,
      totalTimeMinutes: totalTimeMinutes ?? this.totalTimeMinutes,
      trekStartDate: trekStartDate ?? this.trekStartDate,
      trekEndDate: trekEndDate ?? this.trekEndDate,
      isVerified: isVerified ?? this.isVerified,
      verificationCode: verificationCode ?? this.verificationCode,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
