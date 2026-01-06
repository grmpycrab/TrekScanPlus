import 'package:flutter/material.dart';
import '../../theme/new_color.dart';
import '../services/e_certificate_service.dart';
import '../services/certificate_pdf_service.dart';
import '../services/permission_service.dart';
import '../models/e_certificate.dart';

/// A comprehensive reusable e-certificate badge component with full functionality:
/// - Trophy badge showing certificate count
/// - Certificate list modal
/// - Detailed certificate view
/// - Download PDF
/// - Share certificate
/// - Email certificate
///
/// This component can be used anywhere in the app (banner, profile, etc.)
/// and provides the complete e-certificate experience.
class ECertificateBadge extends StatelessWidget {
  final ECertificateService certificateService;

  const ECertificateBadge({super.key, required this.certificateService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ECertificate>>(
      stream: certificateService.streamAllCertificates(),
      builder: (context, snapshot) {
        final certificates = snapshot.data ?? [];
        final certificateCount = certificates.length;

        return GestureDetector(
          onTap: () => _showCertificatesModal(context, certificates),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade400, Colors.amber.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  certificateCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCertificatesModal(
    BuildContext context,
    List<ECertificate> certificates,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 16),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Certificates',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Certificates list
            Expanded(
              child: certificates.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: certificates.length,
                      itemBuilder: (context, index) {
                        return _buildCertificateCard(
                          context,
                          certificates[index],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateCard(BuildContext context, ECertificate certificate) {
    final colors = _getCertificateColors(certificate.certificateType);

    return GestureDetector(
      onTap: () => _showCertificateDetail(context, certificate),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors['light']!, colors['main']!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors['main']!.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Certificate type and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          certificate.getTitle(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Earned ${_formatCertificateDate(certificate.dateEarned)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _getCertificateIcon(certificate.certificateType),
                    color: Colors.white,
                    size: 32,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCertificateStat(
                    'Stations',
                    certificate.stationsVisited.toString(),
                  ),
                  _buildCertificateStat(
                    'Distance',
                    '${certificate.totalDistance.toStringAsFixed(1)} km',
                  ),
                  _buildCertificateStat(
                    'Time',
                    '${certificate.totalTimeMinutes} min',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCertificateStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  void _showCertificateDetail(BuildContext context, ECertificate certificate) {
    Navigator.pop(context); // Close the modal
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _getCertificateColors(
                        certificate.certificateType,
                      )['light']!,
                      _getCertificateColors(
                        certificate.certificateType,
                      )['main']!,
                    ],
                  ),
                ),
                child: Icon(
                  _getCertificateIcon(certificate.certificateType),
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                certificate.getTitle(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                certificate.getDescription(),
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Trekker Name', certificate.trekkerName),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Date Earned',
                      _formatCertificateDate(certificate.dateEarned),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Stations Visited',
                      certificate.stationsVisited.toString(),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Total Distance',
                      '${certificate.totalDistance.toStringAsFixed(1)} km',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Total Time',
                      '${certificate.totalTimeMinutes} minutes',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Verification Code',
                      certificate.verificationCode,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Action buttons row
              Row(
                children: [
                  // Download PDF button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _downloadCertificatePdf(context, certificate),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Share button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareCertificate(context, certificate),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Email button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _emailCertificate(context, certificate),
                      icon: const Icon(Icons.email, size: 18),
                      label: const Text('Email'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Close button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Map<String, Color> _getCertificateColors(CertificateType type) {
    switch (type) {
      case CertificateType.camp3:
        return {
          'main': const Color(0xFF8B4513),
          'light': const Color(0xFFD2691E),
        };
      case CertificateType.fullTrek:
        return {
          'main': const Color(0xFF4169E1),
          'light': const Color(0xFF6495ED),
        };
      case CertificateType.peakConqueror:
        return {
          'main': const Color(0xFFFFD700),
          'light': const Color(0xFFFFA500),
        };
    }
  }

  IconData _getCertificateIcon(CertificateType type) {
    switch (type) {
      case CertificateType.camp3:
        return Icons.location_on;
      case CertificateType.fullTrek:
        return Icons.terrain;
      case CertificateType.peakConqueror:
        return Icons.emoji_events;
    }
  }

  String _formatCertificateDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  // PDF and Email Action Handlers
  Future<void> _downloadCertificatePdf(
    BuildContext context,
    ECertificate certificate,
  ) async {
    try {
      // Request storage permission first
      final permissionService = PermissionService.instance;
      final hasPermission = await permissionService.requestStoragePermission(
        context,
      );

      if (!hasPermission) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to save certificate'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF...'),
          duration: Duration(seconds: 1),
        ),
      );

      final pdfService = CertificatePdfService.instance;
      final file = await pdfService.saveCertificateToDownloads(certificate);

      if (!context.mounted) return;

      if (file != null) {
        // Get a user-friendly path message
        final pathMessage = file.path.contains('Android/data')
            ? 'Certificate saved! You can share it from your profile.'
            : 'Certificate saved to ${file.path}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pathMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () => _shareCertificate(context, certificate),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to save certificate. Please check storage permissions.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _shareCertificate(
    BuildContext context,
    ECertificate certificate,
  ) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing to share...'),
          duration: Duration(seconds: 1),
        ),
      );

      final pdfService = CertificatePdfService.instance;
      await pdfService.shareCertificate(certificate);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing certificate: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _emailCertificate(
    BuildContext context,
    ECertificate certificate,
  ) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sending email...'),
          duration: Duration(seconds: 2),
        ),
      );

      final success = await certificateService.sendCertificateEmail(
        certificate,
      );

      if (!context.mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate email sent successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to send email. Please check your internet connection.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.card_membership_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No certificates yet',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete adventures to earn certificates',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
