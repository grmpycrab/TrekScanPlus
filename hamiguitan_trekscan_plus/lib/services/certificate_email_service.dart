import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  /// Send certificate via email
  Future<bool> sendCertificateEmail(ECertificate certificate) async {
    // Declare variables at method scope
    String smtpEmail = '';

    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      // Generate PDF
      final pdfFile = await _pdfService.generateCertificatePdf(certificate);

      // Configure SMTP server from environment variables
      smtpEmail = dotenv.env['SMTP_EMAIL'] ?? '';
      final smtpPassword = dotenv.env['SMTP_PASSWORD'] ?? '';
      final appEmailFrom =
          dotenv.env['APP_EMAIL_FROM'] ?? 'noreply@hamiguitan-trek.com';
      final appName = dotenv.env['APP_NAME'] ?? 'Mt. Hamiguitan TrekScan';

      if (smtpEmail.isEmpty || smtpPassword.isEmpty) return false;

      final smtpServer = gmail(smtpEmail, smtpPassword);

      // Create email message
      final message = Message()
        ..from = Address(appEmailFrom, appName)
        ..recipients.add(user.email!)
        ..subject =
            '🏆 Your Mt. Hamiguitan ${certificate.getTitle()} Certificate'
        ..html = _generateEmailHtml(certificate, user.displayName ?? 'Trekker')
        ..attachments.add(FileAttachment(pdfFile));

      // Send email
      await send(message, smtpServer);
      return true;
    } on MailerException catch (e) {
      // Check for authentication errors
      if (e.message.contains('Authentication Failed') ||
          e.message.contains('BadCredentials')) {
        AppLogger.i(
          'Gmail App Password required. See ENV_SETUP.md for setup instructions.',
        );
        AppLogger.i(
          '   Generate at: https://myaccount.google.com/apppasswords\n',
        );
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Generate HTML email content
  String _generateEmailHtml(ECertificate certificate, String userName) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body {
      font-family: Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 30px;
      text-align: center;
      border-radius: 10px 10px 0 0;
    }
    .content {
      background: #f9f9f9;
      padding: 30px;
      border-radius: 0 0 10px 10px;
    }
    .certificate-badge {
      background: ${_getColorHex(certificate.certificateType)};
      color: white;
      padding: 15px;
      border-radius: 8px;
      text-align: center;
      margin: 20px 0;
    }
    .details {
      background: white;
      padding: 20px;
      border-left: 4px solid ${_getColorHex(certificate.certificateType)};
      margin: 20px 0;
    }
    .detail-row {
      display: flex;
      justify-content: space-between;
      padding: 8px 0;
      border-bottom: 1px solid #eee;
    }
    .footer {
      text-align: center;
      padding: 20px;
      color: #666;
      font-size: 12px;
    }
    .btn {
      display: inline-block;
      background: #4CAF50;
      color: white;
      padding: 12px 30px;
      text-decoration: none;
      border-radius: 5px;
      margin: 20px 0;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>🏔️ Congratulations!</h1>
    <p>You've earned a Mt. Hamiguitan Certificate</p>
  </div>
  
  <div class="content">
    <p>Dear <strong>$userName</strong>,</p>
    
    <p>Congratulations on achieving this incredible milestone! We are thrilled to present you with your official certificate for completing:</p>
    
    <div class="certificate-badge">
      <h2 style="margin: 0;">${certificate.getTitle()}</h2>
    </div>
    
    <p>${certificate.getDescription()}</p>
    
    <div class="details">
      <h3>Your Achievement Details:</h3>
      <div class="detail-row">
        <span><strong>Date Completed:</strong></span>
        <span>${certificate.formatDate(certificate.dateEarned)}</span>
      </div>
      <div class="detail-row">
        <span><strong>Stations Visited:</strong></span>
        <span>${certificate.stationsVisited} stations</span>
      </div>
      <div class="detail-row">
        <span><strong>Total Distance:</strong></span>
        <span>${certificate.totalDistance.toStringAsFixed(1)} km</span>
      </div>
      <div class="detail-row">
        <span><strong>Total Time:</strong></span>
        <span>${(certificate.totalTimeMinutes / 60).toStringAsFixed(1)} hours</span>
      </div>
      <div class="detail-row">
        <span><strong>Verification Code:</strong></span>
        <span><code>${certificate.verificationCode}</code></span>
      </div>
    </div>
    
    <p>Your official certificate is attached to this email as a PDF file. You can:</p>
    <ul>
      <li>📥 Download and save it to your device</li>
      <li>🖨️ Print it for your records</li>
      <li>📱 Share it on social media</li>
      <li>🔍 Verify it using the verification code</li>
    </ul>
    
    <p style="margin-top: 30px;">Thank you for exploring the beautiful Mt. Hamiguitan Range Wildlife Sanctuary, a UNESCO World Heritage Site. Your commitment to preserving this natural treasure is deeply appreciated.</p>
    
    <p><strong>Keep exploring!</strong></p>
    
    <p>Best regards,<br>
    <strong>The Mt. Hamiguitan TrekScan Team</strong></p>
  </div>
  
  <div class="footer">
    <p>Mt. Hamiguitan Range Wildlife Sanctuary<br>
    UNESCO World Heritage Site<br>
    This is an automated email. Please do not reply.</p>
    <p style="font-size: 10px; margin-top: 20px;">
      Certificate issued on ${certificate.formatDate(certificate.createdAt)}
    </p>
  </div>
</body>
</html>
''';
  }

  /// Get color hex code for certificate type
  String _getColorHex(CertificateType type) {
    switch (type) {
      case CertificateType.camp3:
        return '#4CAF50'; // Green
      case CertificateType.fullTrek:
        return '#2196F3'; // Blue
      case CertificateType.peakConqueror:
        return '#FF9800'; // Orange
    }
  }

  /// Send welcome email with all earned certificates (bulk send)
  Future<bool> sendAllCertificatesEmail(List<ECertificate> certificates) async {
    if (certificates.isEmpty) return false;

    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      // Generate all PDFs
      final List<File> pdfFiles = [];
      for (final cert in certificates) {
        final file = await _pdfService.generateCertificatePdf(cert);
        pdfFiles.add(file);
      }

      // Configure SMTP
      final smtpEmail = dotenv.env['SMTP_EMAIL'] ?? '';
      final smtpPassword = dotenv.env['SMTP_PASSWORD'] ?? '';
      final appEmailFrom =
          dotenv.env['APP_EMAIL_FROM'] ?? 'noreply@hamiguitan-trek.com';
      final appName = dotenv.env['APP_NAME'] ?? 'Mt. Hamiguitan TrekScan';

      if (smtpEmail.isEmpty || smtpPassword.isEmpty) {
        AppLogger.i('SMTP credentials not configured in .env file');
        return false;
      }

      final smtpServer = gmail(smtpEmail, smtpPassword);

      // Create message
      final message = Message()
        ..from = Address(appEmailFrom, appName)
        ..recipients.add(user.email!)
        ..subject =
            'Your Mt. Hamiguitan Certificates (${certificates.length} earned)'
        ..html = _generateBulkEmailHtml(
          certificates,
          user.displayName ?? 'Trekker',
        );

      // Attach all PDFs
      for (final pdfFile in pdfFiles) {
        message.attachments.add(FileAttachment(pdfFile));
      }

      // Send
      await send(message, smtpServer);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generate HTML for bulk email
  String _generateBulkEmailHtml(
    List<ECertificate> certificates,
    String userName,
  ) {
    final certificateItems = certificates
        .map(
          (cert) =>
              '''
      <div style="background: white; padding: 15px; margin: 10px 0; border-left: 4px solid ${_getColorHex(cert.certificateType)}; border-radius: 4px;">
        <h4 style="margin: 0 0 10px 0;">${cert.getTitle()}</h4>
        <p style="margin: 5px 0; font-size: 14px;">Earned on: ${cert.formatDate(cert.dateEarned)}</p>
        <p style="margin: 5px 0; font-size: 14px;">Stations: ${cert.stationsVisited} | Distance: ${cert.totalDistance.toStringAsFixed(1)} km</p>
      </div>
    ''',
        )
        .join('');

    return '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
  </style>
</head>
<body>
  <div class="header">
    <h1>🎉 Amazing Achievement!</h1>
    <p>You've earned ${certificates.length} Mt. Hamiguitan Certificates</p>
  </div>
  <div class="content">
    <p>Dear <strong>$userName</strong>,</p>
    <p>Congratulations! You've earned multiple certificates for your trekking achievements:</p>
    $certificateItems
    <p style="margin-top: 30px;">All certificates are attached to this email as PDF files.</p>
    <p>Best regards,<br><strong>The Mt. Hamiguitan TrekScan Team</strong></p>
  </div>
</body>
</html>
''';
  }
}
