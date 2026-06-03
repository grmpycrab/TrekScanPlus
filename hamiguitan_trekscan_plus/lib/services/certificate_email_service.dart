import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/e_certificate.dart';
import 'certificate_pdf_service.dart';
import '../../utils/app_logger.dart';

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

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  Future<bool> sendCertificateEmail(ECertificate certificate) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      final pdfFile = await _pdfService.generateCertificatePdf(certificate);
      final pdfBase64 = base64Encode(await pdfFile.readAsBytes());

      final callable = _functions.httpsCallable('sendCertificateEmail');
      await callable.call({
        'to': user.email,
        'recipientName': user.displayName ?? 'Trekker',
        'certificateData': _certificateToMap(certificate),
        'pdfBase64': pdfBase64,
      });

      return true;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.e('Certificate email failed [${e.code}]: ${e.message}');
      return false;
    } catch (e) {
      AppLogger.e('Certificate email failed: $e');
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

      final callable = _functions.httpsCallable('sendAllCertificatesEmail');
      await callable.call({
        'to': user.email,
        'recipientName': user.displayName ?? 'Trekker',
        'certificates': certs,
      });

      return true;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.e('Bulk certificate email failed [${e.code}]: ${e.message}');
      return false;
    } catch (e) {
      AppLogger.e('Bulk certificate email failed: $e');
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
