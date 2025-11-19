import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/e_certificate.dart';
import '../models/station_data.dart';

class ECertificateService {
  static final ECertificateService _instance = ECertificateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
    if (_isInitialized) {
      print('ECertificateService already initialized, skipping init()');
      return;
    }

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

      print('ECertificateService initialized for user: $currentUserId');
      _isInitialized = true;

      // Load existing certificates from local storage
      await _loadCertificatesLocally();

      // If authenticated, load from Firebase
      if (currentUserId != null) {
        await _loadCertificatesFromFirebase(currentUserId);
      }
    } catch (e) {
      print('Error initializing ECertificateService: $e');
      rethrow;
    }
  }

  /// Reset initialization (call when user changes)
  void resetInitialization() {
    _isInitialized = false;
    _userCertificates = [];
    _currentUserId = null;
  }

  /// Check if trekker is eligible for any certificate based on visited stations
  Future<ECertificate?> checkAndAwardCertificate(
    List<StationData> visitedStations, {
    String? trekkerName,
    DateTime? trekStartDate,
    DateTime? trekEndDate,
    double? totalDistance,
    int? totalTimeMinutes,
  }) async {
    if (visitedStations.isEmpty || _currentUserId == null) {
      return null;
    }

    try {
      final stationCount = visitedStations.length;

      // Check for Peak Conqueror (all stations visited)
      if (stationCount >= 14) {
        // Check if already awarded
        if (!_hasCertificate(CertificateType.peakConqueror)) {
          final cert = await _createAndAwardCertificate(
            CertificateType.peakConqueror,
            visitedStations,
            trekkerName: trekkerName,
            trekStartDate: trekStartDate,
            trekEndDate: trekEndDate,
            totalDistance: totalDistance ?? 0.0,
            totalTimeMinutes: totalTimeMinutes ?? 0,
          );
          print('✓ Peak Conqueror certificate awarded!');
          return cert;
        }
      }

      // Check for Full Trek (all stations visited)
      if (stationCount >= 14) {
        if (!_hasCertificate(CertificateType.fullTrek)) {
          final cert = await _createAndAwardCertificate(
            CertificateType.fullTrek,
            visitedStations,
            trekkerName: trekkerName,
            trekStartDate: trekStartDate,
            trekEndDate: trekEndDate,
            totalDistance: totalDistance ?? 0.0,
            totalTimeMinutes: totalTimeMinutes ?? 0,
          );
          print('✓ Full Trek certificate awarded!');
          return cert;
        }
      }

      // Check for Camp 3 (reached station 8 or higher)
      final reachedStation8 = visitedStations.any(
        (s) => s.name.contains('Camp 3') || s.name.contains('Station 8'),
      );
      if (reachedStation8 || stationCount >= 8) {
        if (!_hasCertificate(CertificateType.camp3)) {
          final cert = await _createAndAwardCertificate(
            CertificateType.camp3,
            visitedStations,
            trekkerName: trekkerName,
            trekStartDate: trekStartDate,
            trekEndDate: trekEndDate,
            totalDistance: totalDistance ?? 0.0,
            totalTimeMinutes: totalTimeMinutes ?? 0,
          );
          print('✓ Camp 3 certificate awarded!');
          return cert;
        }
      }

      return null;
    } catch (e) {
      print('Error checking and awarding certificate: $e');
      return null;
    }
  }

  /// Check if user already has a certificate of given type
  bool _hasCertificate(CertificateType type) {
    return _userCertificates.any((cert) => cert.certificateType == type);
  }

  /// Create and award a certificate
  Future<ECertificate> _createAndAwardCertificate(
    CertificateType type,
    List<StationData> visitedStations, {
    String? trekkerName,
    DateTime? trekStartDate,
    DateTime? trekEndDate,
    double totalDistance = 0.0,
    int totalTimeMinutes = 0,
  }) async {
    try {
      final certId = _generateCertificateId();
      final verificationCode = _generateVerificationCode();
      final currentUser = _auth.currentUser;
      final displayName = trekkerName ?? currentUser?.displayName ?? 'Trekker';

      final certificate = ECertificate(
        certificateId: certId,
        userId: _currentUserId!,
        trekkerName: displayName,
        certificateType: type,
        dateEarned: DateTime.now(),
        stationsVisited: visitedStations.length,
        totalDistance: totalDistance,
        totalTimeMinutes: totalTimeMinutes,
        trekStartDate: trekStartDate,
        trekEndDate: trekEndDate,
        isVerified: true,
        verificationCode: verificationCode,
        createdAt: DateTime.now(),
      );

      // Save locally
      await _saveCertificateLocally(certificate);

      // Sync to Firebase if authenticated
      if (_currentUserId != null) {
        await _saveCertificateToFirebase(certificate);
      }

      _userCertificates.add(certificate);
      return certificate;
    } catch (e) {
      print('Error creating certificate: $e');
      rethrow;
    }
  }

  /// Generate unique certificate ID
  String _generateCertificateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond % 1000;
    return 'CERT_${timestamp}_$random';
  }

  /// Generate unique verification code
  String _generateVerificationCode() {
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().microsecond;

    String code = '';
    for (int i = 0; i < 12; i++) {
      code += chars[(random + i) % chars.length];
    }

    // Format as XXX-XXXX-XXXX
    return '${code.substring(0, 3)}-${code.substring(3, 7)}-${code.substring(7, 11)}';
  }

  /// Save certificate to local storage
  Future<void> _saveCertificateLocally(ECertificate certificate) async {
    try {
      final key = _getCertificateStorageKey(certificate.certificateId);
      await _prefs.setString(key, jsonEncode(certificate.toJson()));
      print('Certificate saved locally: ${certificate.certificateId}');
    } catch (e) {
      print('Error saving certificate locally: $e');
    }
  }

  /// Save certificate to Firebase
  Future<void> _saveCertificateToFirebase(ECertificate certificate) async {
    try {
      if (_currentUserId == null) {
        print('Warning: Cannot sync certificate to Firebase - no user ID');
        return;
      }

      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('certificates')
          .doc(certificate.certificateId)
          .set({
            ...certificate.toJson(),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      print('Certificate synced to Firebase: ${certificate.certificateId}');
    } catch (e) {
      print('Error saving certificate to Firebase: $e');
      // Don't rethrow - certificate is still saved locally
    }
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
            print('Error parsing certificate from local storage: $e');
          }
        }
      }

      print(
        'Loaded ${_userCertificates.length} certificates from local storage',
      );
    } catch (e) {
      print('Error loading certificates from local storage: $e');
    }
  }

  /// Load certificates from Firebase
  Future<void> _loadCertificatesFromFirebase(String userId) async {
    try {
      print('Loading certificates from Firebase for user: $userId');

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('certificates')
          .get();

      if (snapshot.docs.isEmpty) {
        print('No certificates found in Firebase');
        return;
      }

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

      print('Merged ${snapshot.docs.length} certificates from Firebase');
    } catch (e) {
      print('Error loading certificates from Firebase: $e');
      // Don't rethrow - we still have local certificates
    }
  }

  /// Get all certificates for current user
  List<ECertificate> getAllCertificates() {
    return List.unmodifiable(_userCertificates);
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
      print('Error verifying certificate: $e');
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

  /// Get certificate storage key
  String _getCertificateStorageKey(String certificateId) {
    if (_currentUserId == null) {
      return 'certificate_$certificateId';
    }
    return 'certificate_${_currentUserId}_$certificateId';
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
