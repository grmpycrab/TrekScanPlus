import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/e_certificate.dart';
import 'certificate_pdf_service.dart';
import '../../utils/app_logger.dart';

/// Sends certificate emails by writing to the `certificateEmailQueue`
/// Firestore collection. A Cloud Function listens to that collection and
/// delivers the email via SendGrid — the same pattern used for verification
/// code emails (the `mail` collection).
class CertificateEmailService {
  static final CertificateEmailService _instance =
      CertificateEmailService._internal();

  CertificateEmailService._internal();

  factory CertificateEmailService() {
    return _instance;
  }

  static CertificateEmailService get instance => _instance;

  final _pdfService = CertificatePdfService.instance;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<bool> sendCertificateEmail(ECertificate certificate) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      final pdfFile = await _pdfService.generateCertificatePdf(certificate);
      final pdfBase64 = base64Encode(await pdfFile.readAsBytes());

      await _firestore.collection('certificateEmailQueue').add({
        'to': user.email,
        'recipientName': user.displayName ?? 'Trekker',
        'certificateData': _certificateToMap(certificate),
        'pdfBase64': pdfBase64,
        'bulk': false,
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      return true;
    } catch (e) {
      AppLogger.e('Certificate email queue failed: $e');
      return false;
    }
  }

  Future<bool> sendAllCertificatesEmail(List<ECertificate> certificates) async {
    if (certificates.isEmpty) return false;

    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      final certs = <Map<String, dynamic>>[];
      for (final cert in certificates) {
        final pdfFile = await _pdfService.generateCertificatePdf(cert);
        certs.add({
          'certificateData': _certificateToMap(cert),
          'pdfBase64': base64Encode(await pdfFile.readAsBytes()),
        });
      }

      await _firestore.collection('certificateEmailQueue').add({
        'to': user.email,
        'recipientName': user.displayName ?? 'Trekker',
        'certificates': certs,
        'bulk': true,
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      return true;
    } catch (e) {
      AppLogger.e('Bulk certificate email queue failed: $e');
      return false;
    }
  }

  Map<String, dynamic> _certificateToMap(ECertificate certificate) {
    return {
      'title': certificate.getTitle(),
      'description': certificate.getDescription(),
      'colorHex': _getColorHex(certificate.certificateType),
      'dateEarned': certificate.formatDate(certificate.dateEarned),
      'stationsVisited': certificate.stationsVisited,
      'totalDistance': certificate.totalDistance.toStringAsFixed(1),
      'totalTimeMinutes': certificate.totalTimeMinutes,
      'verificationCode': certificate.verificationCode,
      'createdAt': certificate.formatDate(certificate.createdAt),
    };
  }

  String _getColorHex(CertificateType type) {
    switch (type) {
      case CertificateType.camp3:
        return '#4CAF50';
      case CertificateType.fullTrek:
        return '#2196F3';
      case CertificateType.peakConqueror:
        return '#FF9800';
    }
  }
}
