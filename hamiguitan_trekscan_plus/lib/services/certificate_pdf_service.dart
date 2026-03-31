import 'dart:io';
//import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/e_certificate.dart';
import '../utils/app_logger.dart';

class CertificatePdfService {
  static final CertificatePdfService _instance =
      CertificatePdfService._internal();

  CertificatePdfService._internal();

  factory CertificatePdfService() {
    return _instance;
  }

  static CertificatePdfService get instance => _instance;

  /// Generate PDF certificate
  Future<File> generateCertificatePdf(ECertificate certificate) async {
    final pdf = pw.Document();

    // Load custom font for better appearance
    final fontBold = await PdfGoogleFonts.merriweatherBold();
    final fontRegular = await PdfGoogleFonts.merriweatherRegular();
    final fontItalic = await PdfGoogleFonts.merriweatherItalic();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: _getCertificateColor(certificate.certificateType),
                width: 3,
              ),
            ),
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 20),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey400, width: 2),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'CERTIFICATE OF ACHIEVEMENT',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 24,
                          color: _getCertificateColor(
                            certificate.certificateType,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        certificate.getTitle(),
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 18,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 40),

                // Main Content
                pw.Text(
                  'This is to certify that',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 15),
                pw.Text(
                  certificate.trekkerName.toUpperCase(),
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 28,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 15),
                pw.Container(
                  width: 200,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey600, width: 1),
                    ),
                  ),
                ),

                pw.SizedBox(height: 30),

                // Description
                pw.Container(
                  width: 450,
                  child: pw.Text(
                    certificate.getDescription(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: fontItalic,
                      fontSize: 14,
                      color: PdfColors.grey800,
                      height: 1.5,
                    ),
                  ),
                ),

                pw.SizedBox(height: 30),

                // Trek Details
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      _buildDetailRow(
                        'Date Completed',
                        certificate.formatDate(certificate.dateEarned),
                        fontBold,
                        fontRegular,
                      ),
                      pw.SizedBox(height: 8),
                      _buildDetailRow(
                        'Stations Visited',
                        '${certificate.stationsVisited} stations',
                        fontBold,
                        fontRegular,
                      ),
                      pw.SizedBox(height: 8),
                      _buildDetailRow(
                        'Total Distance',
                        '${certificate.totalDistance.toStringAsFixed(1)} km',
                        fontBold,
                        fontRegular,
                      ),
                      pw.SizedBox(height: 8),
                      _buildDetailRow(
                        'Total Time',
                        '${(certificate.totalTimeMinutes / 60).toStringAsFixed(1)} hours',
                        fontBold,
                        fontRegular,
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Footer with verification code
                pw.Container(
                  padding: const pw.EdgeInsets.only(top: 20),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.grey400, width: 2),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Mt. Hamiguitan Range Wildlife Sanctuary',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'UNESCO World Heritage Site',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 15),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            'Verification Code: ',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 9,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.Text(
                            certificate.verificationCode,
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 9,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Issued on ${certificate.formatDate(certificate.createdAt)}',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 8,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Save PDF to temporary directory
    final directory = await getTemporaryDirectory();
    final fileName =
        'certificate_${certificate.certificateType.toString().split('.').last}_${certificate.certificateId}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    AppLogger.i('📄 PDF certificate generated: ${file.path}');
    return file;
  }

  /// Build detail row for trek information
  pw.Widget _buildDetailRow(
    String label,
    String value,
    pw.Font fontBold,
    pw.Font fontRegular,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 11,
            color: PdfColors.grey800,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: fontRegular,
            fontSize: 11,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  /// Get certificate color based on type
  PdfColor _getCertificateColor(CertificateType type) {
    switch (type) {
      case CertificateType.camp3:
        return PdfColors.green700; // Green for Camp 3
      case CertificateType.fullTrek:
        return PdfColor.fromInt(0xFF1976D2); // Blue for Full Trek
      case CertificateType.peakConqueror:
        return PdfColor.fromInt(0xFFF57C00); // Orange for Peak Conqueror
    }
  }

  /// Print certificate (for physical printing)
  Future<void> printCertificate(ECertificate certificate) async {
    final file = await generateCertificatePdf(certificate);
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Certificate_${certificate.trekkerName}',
    );
  }

  /// Share certificate PDF
  Future<void> shareCertificate(ECertificate certificate) async {
    final file = await generateCertificatePdf(certificate);
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: 'Mt_Hamiguitan_Certificate_${certificate.trekkerName}.pdf',
    );
  }

  /// Save certificate to device storage
  Future<File?> saveCertificateToDownloads(ECertificate certificate) async {
    try {
      final file = await generateCertificatePdf(certificate);
      final fileName =
          'Mt_Hamiguitan_Certificate_${certificate.trekkerName}_${certificate.certificateType.toString().split('.').last}.pdf';

      // For Android, use app's external storage directory (accessible without special permissions)
      if (Platform.isAndroid) {
        // Get the app's external storage directory (works without MANAGE_EXTERNAL_STORAGE)
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Create a "Certificates" folder in app's directory
          final certificatesDir = Directory('${directory.path}/Certificates');
          if (!await certificatesDir.exists()) {
            await certificatesDir.create(recursive: true);
          }

          final savedFile = File('${certificatesDir.path}/$fileName');
          await file.copy(savedFile.path);

          AppLogger.i('Certificate saved: ${savedFile.path}');
          return savedFile;
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final savedFile = File('${directory.path}/$fileName');
      await file.copy(savedFile.path);

      AppLogger.i('Certificate saved: ${savedFile.path}');
      return savedFile;
    } catch (e) {
      AppLogger.e('Error saving certificate: $e');
      return null;
    }
  }
}
