import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../utils/app_logger.dart';

class EmailVerificationService {
  EmailVerificationService._internal();
  static final EmailVerificationService instance =
      EmailVerificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generate a random 6-digit verification code
  String _generateVerificationCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Send verification code to user's email
  Future<void> sendVerificationCode(String email) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Generate verification code
      final code = _generateVerificationCode();
      final expiryTime = DateTime.now().add(const Duration(minutes: 15));

      // Store code in Firestore
      await _firestore.collection('email_verifications').doc(user.uid).set({
        'code': code,
        'email': email,
        'expiryTime': Timestamp.fromDate(expiryTime),
        'createdAt': FieldValue.serverTimestamp(),
        'verified': false,
        'attempts': 0,
      });

      // Send email via Cloud Function trigger
      // The Cloud Function will listen to this collection and send the email
      await _firestore.collection('mail').add({
        'to': email,
        'subject': 'TrekScan Plus - Email Verification Code',
        'code': code,
        'expiresAt': Timestamp.fromDate(expiryTime),
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      if (kDebugMode) {
        AppLogger.i('✉️ Verification code sent to $email');
        AppLogger.i('🔢 CODE (for testing): $code');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('❌ Error sending verification code: $e');
      }
      rethrow;
    }
  }

  /// Verify the code entered by user
  Future<bool> verifyCode(String code) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final doc = await _firestore
          .collection('email_verifications')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        throw Exception(
          'No verification code found. Please request a new code.',
        );
      }

      final data = doc.data()!;
      final storedCode = data['code'] as String;
      final expiryTime = (data['expiryTime'] as Timestamp).toDate();
      final verified = data['verified'] as bool? ?? false;
      final attempts = data['attempts'] as int? ?? 0;

      // Check if already verified
      if (verified) {
        return true;
      }

      // Check if expired
      if (DateTime.now().isAfter(expiryTime)) {
        throw Exception(
          'Verification code has expired. Please request a new code.',
        );
      }

      // Check max attempts (5 attempts)
      if (attempts >= 5) {
        throw Exception(
          'Maximum verification attempts exceeded. Please request a new code.',
        );
      }

      // Increment attempts
      await _firestore.collection('email_verifications').doc(user.uid).update({
        'attempts': FieldValue.increment(1),
      });

      // Verify code
      if (code.trim() == storedCode) {
        // Mark as verified
        await _firestore.collection('email_verifications').doc(user.uid).update(
          {'verified': true, 'verifiedAt': FieldValue.serverTimestamp()},
        );

        // Update user's emailVerified status in Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          AppLogger.i('✅ Email verified successfully for ${user.email}');
        }

        return true;
      } else {
        if (kDebugMode) {
          AppLogger.i(
            '❌ Invalid verification code. Attempts: ${attempts + 1}/5',
          );
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('❌ Error verifying code: $e');
      }
      rethrow;
    }
  }

  /// Check if user's email is verified (from Firestore)
  Future<bool> isEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection('email_verifications')
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;

      final verified = doc.data()?['verified'] as bool? ?? false;
      return verified;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('❌ Error checking verification status: $e');
      }
      return false;
    }
  }

  /// Get remaining time for code expiry
  Future<Duration?> getRemainingTime() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('email_verifications')
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;

      final expiryTime = (doc.data()?['expiryTime'] as Timestamp?)?.toDate();
      if (expiryTime == null) return null;

      final remaining = expiryTime.difference(DateTime.now());
      return remaining.isNegative ? null : remaining;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('❌ Error getting remaining time: $e');
      }
      return null;
    }
  }

  /// Get number of attempts made
  Future<int> getAttempts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final doc = await _firestore
          .collection('email_verifications')
          .doc(user.uid)
          .get();

      if (!doc.exists) return 0;

      return doc.data()?['attempts'] as int? ?? 0;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('❌ Error getting attempts: $e');
      }
      return 0;
    }
  }
}
