import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'user_service.dart';

class FirebaseAuthService {
  FirebaseAuthService._internal();

  static final FirebaseAuthService instance = FirebaseAuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Sign up with email and password
  Future<void> signUp({required String email, required String password}) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Ensure the user document exists in Firestore for newly created users
      if (userCredential.user != null) {
        try {
          await UserService.instance.createOrUpdateUserFromFirebase(
            userCredential.user!,
          );
        } catch (e) {
          // Log Firestore error but don't block user signup
          if (kDebugMode) {
            print(
              '⚠️ Warning: Failed to create user document in Firestore: $e',
            );
            print(
              'User was created in Firebase Auth, but Firestore sync failed.',
            );
            print(
              'User can proceed - data will sync when network is available.',
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Sign up error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e, st) {
      // Sometimes a Pigeon type-cast error happens even though the user was created
      // Check if we have a current user before throwing
      if (kDebugMode) {
        print('⚠️ Sign up Pigeon cast error: $e');
        print(st);
      }

      final fallbackUser = _firebaseAuth.currentUser;
      if (fallbackUser != null) {
        if (kDebugMode) {
          print(
            '✅ User was created despite Pigeon error. Continuing with user: ${fallbackUser.email}',
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
            print(
              '⚠️ Warning: Failed to create user document in Firestore: $e',
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
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print('✅ Email login successful: ${userCredential.user?.email}');
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
            print(
              '⚠️ Warning: Failed to update user document in Firestore: $e',
            );
            print(
              'User can proceed - data will sync when network is available.',
            );
          }
          // Don't rethrow - user is successfully authenticated in Firebase Auth
        }
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Login error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e, st) {
      // Sometimes a Pigeon type-cast error happens even though the user was authenticated
      // Check if we have a current user before throwing
      if (kDebugMode) {
        print('⚠️ Login Pigeon cast error: $e');
        print(st);
      }

      final fallbackUser = _firebaseAuth.currentUser;
      if (fallbackUser != null) {
        if (kDebugMode) {
          print(
            '✅ User was authenticated despite Pigeon error. Continuing with user: ${fallbackUser.email}',
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
            print(
              '⚠️ Warning: Failed to create user document in Firestore: $e',
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
      await _firebaseAuth.signOut();
      if (kDebugMode) {
        print('✅ User signed out successfully');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Sign out error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Reset password error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _firebaseAuth.currentUser != null;
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
          print('Google sign-in cancelled by user');
        }
        return null;
      }

      if (kDebugMode) {
        print('Google user signed in: ${googleUser.email}');
        print('Google display name: ${googleUser.displayName}');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (kDebugMode) {
        print(
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
        final userCredential = await _firebaseAuth.signInWithCredential(
          credential,
        );

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
              print(
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
              print(
                '⚠️ Warning: Failed to create user document in Firestore: $e',
              );
              print(
                'User was created in Firebase Auth, but Firestore sync failed.',
              );
              print(
                'User can proceed - data will sync when network is available.',
              );
            }
          }
        }

        if (kDebugMode) {
          print('Firebase sign in successful: ${userCredential.user?.email}');
        }

        return userCredential.user;
      } catch (e, st) {
        // Sometimes a mismatch between plugin/platform generated Pigeon
        // types causes a Dart-side cast error even though the native SDK
        // has completed the sign-in. Detect that case and return the
        // current user if available.
        if (kDebugMode) {
          print('Error while converting UserCredential: $e');
          print(st);
        }

        final fallbackUser = _firebaseAuth.currentUser;
        if (fallbackUser != null) {
          if (kDebugMode) {
            print('Returning fallback currentUser: ${fallbackUser.email}');
          }
          // Ensure Firestore has a user document for this account and then return it.
          try {
            await UserService.instance.createOrUpdateUserFromFirebase(
              fallbackUser,
            );
          } catch (e) {
            // Log Firestore error but don't block sign-in
            if (kDebugMode) {
              print(
                '⚠️ Warning: Failed to create user document in Firestore: $e',
              );
            }
          }
          return fallbackUser;
        }

        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(
          'FirebaseAuthException - Google sign in failed: ${e.code} - ${e.message}',
        );
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Generic exception - Google sign in failed: $e');
      }
      rethrow;
    }
  }
}
