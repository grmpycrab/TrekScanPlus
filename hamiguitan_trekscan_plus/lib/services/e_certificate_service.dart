import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/e_certificate.dart';
import '../models/station_data.dart';
import 'certificate_email_service.dart';
import '../utils/app_logger.dart';

class ECertificateService {
  static final ECertificateService _instance = ECertificateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CertificateEmailService _emailService =
      CertificateEmailService.instance;
  late SharedPreferences _prefs;

  List<ECertificate> _userCertificates = [];
  String? _currentUserId;
  bool _isInitialized = false;

  ECertificateService._internal();

  factory ECertificateService() {
    return _instance;
  }

  /// Static getter for singleton instance
  static ECertificateService get instance => _instance;

  /// Initialize the service
  Future<void> init({String? userId, SharedPreferences? prefs}) async {
    if (_isInitialized) return;

    try {
      // Use current user ID if not provided
      final currentUserId = userId ?? _auth.currentUser?.uid;
      _currentUserId = currentUserId;

      // Initialize SharedPreferences
      if (prefs != null) {
        _prefs = prefs;
      } else {
        _prefs = await SharedPreferences.getInstance();
      }

      _isInitialized = true;

      // Load existing certificates from local storage
      await _loadCertificatesLocally();

      // If authenticated, load from Firebase
      if (currentUserId != null) {
        await _loadCertificatesFromFirebase(currentUserId);
      }
    } catch (e) {
      AppLogger.i('Error initializing ECertificateService: $e');
      rethrow;
    }
  }

  /// Reset initialization (call when user changes)
  void resetInitialization() {
    _isInitialized = false;
    _userCertificates = [];
    _currentUserId = null;
  }

  /// [DEPRECATED — auto-generation disabled]
  ///
  /// Certificates are no longer issued automatically by the mobile app.
  /// They are now issued manually by admins through the TrekScan Admin Portal
  /// (Certificates page), which writes directly to the user's
  /// `users/{userId}/certificates` subcollection in Firestore.
  ///
  /// The eligibility rules below are retained for reference and are mirrored
  /// in the admin portal's certificateService.js:
  ///   - Camp 3        : reached Station 8 / Camp 3, or 8+ stations visited
  ///   - Full Trek     : 13+ stations visited
  ///   - Peak Conqueror: Station 14 (Peak) visited
  ///
  /// Callers of this method will now always receive null. Remove call-sites
  /// when convenient.
  Future<ECertificate?> checkAndAwardCertificate(
    List<StationData> visitedStations, {
    String? trekkerName,
    DateTime? trekStartDate,
    DateTime? trekEndDate,
    double? totalDistance,
    int? totalTimeMinutes,
  }) async {
    // Auto-generation disabled — admin portal is the sole issuance channel.
    AppLogger.i(
      'checkAndAwardCertificate called but auto-generation is disabled. '
      'Certificates must be issued via the admin portal.',
    );
    return null;
  }

  /// Load certificates from local storage
  Future<void> _loadCertificatesLocally() async {
    try {
      final keys = _prefs.getKeys();
      final certKeys = keys
          .where((key) => key.startsWith('certificate_'))
          .toList();

      _userCertificates = [];
      for (final key in certKeys) {
        final jsonString = _prefs.getString(key);
        if (jsonString != null) {
          try {
            final json = jsonDecode(jsonString) as Map<String, dynamic>;
            _userCertificates.add(ECertificate.fromJson(json));
          } catch (e) {
            AppLogger.i('Error parsing certificate from local storage: $e');
          }
        }
      }
    } catch (e) {
      AppLogger.i('Error loading certificates from local storage: $e');
    }
  }

  /// Load certificates from Firebase
  Future<void> _loadCertificatesFromFirebase(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('certificates')
          .get();

      if (snapshot.docs.isEmpty) return;

      // Merge with local certificates
      for (final doc in snapshot.docs) {
        final firestoreCert = ECertificate.fromFirestore(doc);

        // Check if already have this certificate locally
        final index = _userCertificates.indexWhere(
          (c) => c.certificateId == firestoreCert.certificateId,
        );

        if (index >= 0) {
          // Update local with Firebase version (in case of sync)
          _userCertificates[index] = firestoreCert;
        } else {
          // Add new certificate from Firebase
          _userCertificates.add(firestoreCert);
        }
      }
    } catch (e) {
      AppLogger.i('Error loading certificates from Firebase: $e');
      // Don't rethrow - we still have local certificates
    }
  }

  /// Get all certificates for current user
  List<ECertificate> getAllCertificates() {
    return List.unmodifiable(_userCertificates);
  }

  /// Stream all certificates for current user
  /// Listens to Firestore for real-time updates
  Stream<List<ECertificate>> streamAllCertificates() {
    // Get current user ID from Firebase Auth
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Stream.value([]);
    }

    // Update the current user ID
    _currentUserId = userId;

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('certificates')
        .snapshots()
        .map<List<ECertificate>>((snapshot) {
          try {
            _userCertificates = snapshot.docs
                .map((doc) => ECertificate.fromFirestore(doc))
                .toList();
            return List.unmodifiable(_userCertificates);
          } catch (e) {
            AppLogger.e('Error parsing certificates: $e');
            return <ECertificate>[];
          }
        });
  }

  /// Get certificates by type
  List<ECertificate> getCertificatesByType(CertificateType type) {
    return _userCertificates
        .where((cert) => cert.certificateType == type)
        .toList();
  }

  /// Check if user has specific certificate
  bool hasCertificate(CertificateType type) {
    return _userCertificates.any((cert) => cert.certificateType == type);
  }

  /// Get certificate by ID
  ECertificate? getCertificateById(String certificateId) {
    try {
      return _userCertificates.firstWhere(
        (c) => c.certificateId == certificateId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Verify certificate by verification code
  Future<bool> verifyCertificate(String verificationCode) async {
    try {
      // Check local first
      final localCert = _userCertificates
          .where((c) => c.verificationCode == verificationCode)
          .firstOrNull;

      if (localCert != null) {
        return localCert.isVerified;
      }

      // Check Firebase
      if (_currentUserId != null) {
        final snapshot = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('certificates')
            .where('verificationCode', isEqualTo: verificationCode)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final cert = ECertificate.fromFirestore(snapshot.docs.first);
          return cert.isVerified;
        }
      }

      return false;
    } catch (e) {
      AppLogger.i('Error verifying certificate: $e');
      return false;
    }
  }

  /// Get total number of certificates earned
  int getCertificateCount() {
    return _userCertificates.length;
  }

  /// Get most recent certificate
  ECertificate? getMostRecentCertificate() {
    if (_userCertificates.isEmpty) return null;
    _userCertificates.sort((a, b) => b.dateEarned.compareTo(a.dateEarned));
    return _userCertificates.first;
  }

  /// Manually send certificate email (for retry or user request)
  Future<bool> sendCertificateEmail(ECertificate certificate) async {
    try {
      return await _emailService.sendCertificateEmail(certificate);
    } catch (e) {
      AppLogger.i('Error sending certificate email: $e');
      return false;
    }
  }

  /// Send all earned certificates via email
  Future<bool> sendAllCertificatesEmail() async {
    try {
      if (_userCertificates.isEmpty) return false;
      return await _emailService.sendAllCertificatesEmail(_userCertificates);
    } catch (e) {
      AppLogger.i('Error sending all certificates: $e');
      return false;
    }
  }

  /// Update current user (call when user changes)
  Future<void> setCurrentUser(String? userId) async {
    _currentUserId = userId;
    if (userId != null) {
      // Reload certificates for new user
      _userCertificates = [];
      await _loadCertificatesLocally();
      await _loadCertificatesFromFirebase(userId);
    }
  }
}
