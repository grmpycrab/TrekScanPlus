import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'user_service.dart';
import 'email_verification_service.dart';
import '../../utils/app_logger.dart';

class FirebaseAuthService {
  FirebaseAuthService._internal();

  static final FirebaseAuthService instance = FirebaseAuthService._internal();

  // Lazy-initialize FirebaseAuth to ensure Firebase is initialized first
  late final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  FirebaseAuth get _auth {
    try {
      return _firebaseAuth;
    } catch (e) {
      throw Exception('Firebase not initialized: $e');
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if email is already used by a different auth provider
  Future<bool> isEmailAlreadyUsed(String email) async {
    try {
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);
      return signInMethods.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('Error checking email availability: $e');
      }
      return false;
    }
  }

  /// Get existing sign-in methods for an email
  Future<List<String>> getSignInMethodsForEmail(String email) async {
    try {
      return await _auth.fetchSignInMethodsForEmail(email);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('Error fetching sign-in methods: $e');
      }
      return [];
    }
  }

  /// Get user-friendly provider name from sign-in methods
  String getProviderName(List<String> signInMethods) {
    if (signInMethods.contains('google.com')) {
      return 'Google';
    } else if (signInMethods.contains('password')) {
      return 'email and password';
    } else if (signInMethods.contains('facebook.com')) {
      return 'Facebook';
    } else if (signInMethods.contains('apple.com')) {
      return 'Apple';
    }
    return 'another method';
  }

  /// Sign up with email and password
  Future<void> signUp({required String email, required String password}) async {
    try {
      // Check if email is already used
      final isEmailUsed = await isEmailAlreadyUsed(email);
      if (isEmailUsed) {
        final signInMethods = await getSignInMethodsForEmail(email);
        final providerName = getProviderName(signInMethods);
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message:
              'This email is already registered with $providerName. Please sign in using that method or use a different email address.',
        );
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send 6-digit verification code instead of email link
      if (userCredential.user != null) {
        await EmailVerificationService.instance.sendVerificationCode(email);
        if (kDebugMode) {
          AppLogger.i('✉️ Verification code sent');
        }
      }

      // Ensure the user document exists in Firestore for newly created users
      if (userCredential.user != null) {
        try {
          await UserService.instance.createOrUpdateUserFromFirebase(
            userCredential.user!,
          );
        } catch (e) {
          // Log Firestore error but don't block user signup
          if (kDebugMode) {
            AppLogger.i(
              'Warning: Failed to create user document in Firestore: $e',
            );
            AppLogger.i(
              'User was created in Firebase Auth, but Firestore sync failed.',
            );
            AppLogger.i(
              'User can proceed - data will sync when network is available.',
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        AppLogger.i('Sign up error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e, st) {
      // Sometimes a Pigeon type-cast error happens even though the user was created
      // Check if we have a current user before throwing
      if (kDebugMode) {
        AppLogger.i('Sign up Pigeon cast error: $e');
        print(st);
      }

      final fallbackUser = _auth.currentUser;
      if (fallbackUser != null) {
        if (kDebugMode) {
          AppLogger.i(
            'User was created despite Pigeon error. Continuing with user: ${fallbackUser.email}',
          );
        }
        // Ensure Firestore has a user document for this account
        try {
          await UserService.instance.createOrUpdateUserFromFirebase(
            fallbackUser,
          );
        } catch (e) {
          // Log Firestore error but don't block signup
          if (kDebugMode) {
            AppLogger.i(
              'Warning: Failed to create user document in Firestore: $e',
            );
          }
        }
        // User created successfully despite the error, so continue
        return;
      }

      // If no current user, rethrow
      rethrow;
    }
  }

  /// Log in with email and password
  /// Resilient to Pigeon type-cast errors: if error occurs but user is authenticated, proceeds anyway
  Future<UserCredential?> logIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        AppLogger.i('🔐 Email login successful');
      }

      // Update/create the Firestore user document when logging in
      if (userCredential.user != null) {
        try {
          await UserService.instance.createOrUpdateUserFromFirebase(
            userCredential.user!,
          );
        } catch (e) {
          // Log Firestore error but don't block login - user is authenticated
          if (kDebugMode) {
            AppLogger.i(
              'Warning: Failed to update user document in Firestore: $e',
            );
            AppLogger.i(
              'User can proceed - data will sync when network is available.',
            );
          }
          // Don't rethrow - user is successfully authenticated in Firebase Auth
        }
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        AppLogger.i('Login error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e, st) {
      // Sometimes a Pigeon type-cast error happens even though the user was authenticated
      // Check if we have a current user before throwing
      if (kDebugMode) {
        AppLogger.i('Login Pigeon cast error: $e');
        print(st);
      }

      final fallbackUser = _auth.currentUser;
      if (fallbackUser != null) {
        if (kDebugMode) {
          AppLogger.i(
            'User was authenticated despite Pigeon error. Continuing with user: ${fallbackUser.email}',
          );
        }
        // Ensure Firestore has a user document for this account
        try {
          await UserService.instance.createOrUpdateUserFromFirebase(
            fallbackUser,
          );
        } catch (e) {
          // Log Firestore error but don't block login - user is authenticated
          if (kDebugMode) {
            AppLogger.i(
              'Warning: Failed to create user document in Firestore: $e',
            );
          }
        }
        // User created successfully despite the error, so continue
        return null; // Return null to signal we should proceed anyway
      }

      // If no current user, rethrow
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (kDebugMode) {
        AppLogger.i('User signed out successfully');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        AppLogger.i('Sign out error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        AppLogger.i('Reset password error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  /// Send email verification code
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await EmailVerificationService.instance.sendVerificationCode(
          user.email!,
        );
        if (kDebugMode) {
          AppLogger.i('✅ User account verified');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('Send verification code error: $e');
      }
      rethrow;
    }
  }

  /// Check if current user's email is verified (from Firestore)
  Future<bool> isEmailVerified() async {
    return await EmailVerificationService.instance.isEmailVerified();
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  /// Sign in with Google
  ///
  /// Returns the signed in [User] when successful, or `null` when the
  /// user cancelled the sign-in flow. This method is resilient to a
  /// plugin/platform-side Pigeon type-cast mismatch: if `signInWithCredential`
  /// throws but the Firebase native SDK reports a current user, we return
  /// that user so the app can continue.
  ///
  /// Also extracts first and last names from Google profile and saves them to Firestore.
  Future<User?> signInWithGoogle() async {
    try {
      // Use a single GoogleSignIn instance so we can control cached state.
      final googleSignIn = GoogleSignIn();

      // Ensure any previously cached Google account for this app is cleared so
      // the system will show the account chooser. Without this, the plugin may
      // return the last used account silently.
      try {
        await googleSignIn.signOut();
      } catch (_) {
        // ignore errors from signOut; proceed to signIn which will still show chooser
      }

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        if (kDebugMode) {
          AppLogger.i('Google sign-in cancelled by user');
        }
        return null;
      }

      if (kDebugMode) {
        AppLogger.i('👤 Google user signed in');
        AppLogger.i('  - Display name: ${googleUser.displayName}');
      }

      // Check if this email is already used with email/password authentication
      final signInMethods = await getSignInMethodsForEmail(googleUser.email);
      if (signInMethods.contains('password') &&
          !signInMethods.contains('google.com')) {
        // Email is already registered with email/password, not Google
        throw FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          message:
              'An account already exists with this email address but was registered using email and password. Please sign in using your email and password instead.',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (kDebugMode) {
        AppLogger.i(
          'Google auth obtained. Access token: ${googleAuth.accessToken != null}, ID token: ${googleAuth.idToken != null}',
        );
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the User (or, if the platform code throws a
      // Pigeon-related type error, fall back to the current user reported by
      // the Firebase SDK).
      try {
        final userCredential = await _auth.signInWithCredential(credential);

        // Ensure Firestore has a user document for this account
        if (userCredential.user != null) {
          try {
            // Extract first and last names from Google profile
            String firstName = '';
            String lastName = '';

            if (googleUser.displayName != null &&
                googleUser.displayName!.isNotEmpty) {
              final nameParts = googleUser.displayName!.split(' ');
              firstName = nameParts.first;
              if (nameParts.length > 1) {
                lastName = nameParts.skip(1).join(' ');
              }
            }

            if (kDebugMode) {
              AppLogger.i(
                'Extracted from Google: firstName="$firstName", lastName="$lastName"',
              );
            }

            await UserService.instance.createOrUpdateUserFromFirebase(
              userCredential.user!,
              firstName: firstName.isNotEmpty ? firstName : null,
              lastName: lastName.isNotEmpty ? lastName : null,
            );
          } catch (e) {
            // Log Firestore error but don't block sign-in
            if (kDebugMode) {
              AppLogger.i(
                'Warning: Failed to create user document in Firestore: $e',
              );
              AppLogger.i(
                'User was created in Firebase Auth, but Firestore sync failed.',
              );
              AppLogger.i(
                'User can proceed - data will sync when network is available.',
              );
            }
          }
        }

        if (kDebugMode) {
          AppLogger.i(
            'Firebase sign in successful: ${userCredential.user?.email}',
          );
        }

        return userCredential.user;
      } catch (e, st) {
        // Sometimes a mismatch between plugin/platform generated Pigeon
        // types causes a Dart-side cast error even though the native SDK
        // has completed the sign-in. Detect that case and return the
        // current user if available.
        if (kDebugMode) {
          AppLogger.i('Error while converting UserCredential: $e');
          print(st);
        }

        final fallbackUser = _auth.currentUser;
        if (fallbackUser != null) {
          if (kDebugMode) {
            AppLogger.i(
              'Returning fallback currentUser: ${fallbackUser.email}',
            );
          }
          // Ensure Firestore has a user document for this account and then return it.
          try {
            await UserService.instance.createOrUpdateUserFromFirebase(
              fallbackUser,
            );
          } catch (e) {
            // Log Firestore error but don't block sign-in
            if (kDebugMode) {
              AppLogger.i(
                'Warning: Failed to create user document in Firestore: $e',
              );
            }
          }
          return fallbackUser;
        }

        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        AppLogger.i(
          'FirebaseAuthException - Google sign in failed: ${e.code} - ${e.message}',
        );
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('Generic exception - Google sign in failed: $e');
      }
      rethrow;
    }
  }
}
