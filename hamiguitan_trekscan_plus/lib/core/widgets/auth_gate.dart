import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_auth_service.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/email_verification_screen.dart';
import '../../screens/main/main_screen.dart';
import 'app_shell.dart';

/// Callback fired when a verified (or OAuth) user session is confirmed.
/// The [userId] is passed so the caller can initialize user-scoped services.
typedef OnServicesInitNeeded = void Function(String userId);

/// Listens to the Firebase auth stream and resolves the correct initial screen.
///
/// Decision tree:
/// - Auth loading  → loading spinner
/// - No user       → [LoginScreen]
/// - Email user, unverified → [EmailVerificationScreen]
/// - Verified / OAuth user  → [MainScreen] + fires [onServicesInitNeeded]
///
/// All screens are mounted inside [AppShell] so theme and navigation
/// infrastructure are always present.
///
/// MVVM role: View. No business logic — purely translates auth state
/// to the appropriate screen. Service init is delegated via callback.
class AuthGate extends StatelessWidget {
  /// Called (once per verified session) with the authenticated user's UID.
  final OnServicesInitNeeded? onServicesInitNeeded;

  const AuthGate({super.key, this.onServicesInitNeeded});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuthService.instance.authStateChanges,
      initialData: FirebaseAuthService.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppShell(
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const AppShell(home: LoginScreen());
        }

        return FutureBuilder<bool>(
          future: FirebaseAuthService.instance.isEmailVerified(),
          builder: (context, verificationSnapshot) {
            if (verificationSnapshot.connectionState ==
                ConnectionState.waiting) {
              return AppShell(
                home: const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final isVerified = verificationSnapshot.data ?? false;
            final isEmailPasswordUser = user.providerData.any(
              (info) => info.providerId == 'password',
            );

            if (isEmailPasswordUser && !isVerified) {
              return const AppShell(home: EmailVerificationScreen());
            }

            // Verified user (email or OAuth) — trigger service init once.
            if (isVerified) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onServicesInitNeeded?.call(user.uid);
              });
            }

            return const AppShell(home: MainScreen());
          },
        );
      },
    );
  }
}
