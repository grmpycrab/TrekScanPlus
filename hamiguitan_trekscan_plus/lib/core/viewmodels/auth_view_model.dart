import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../services/firebase_auth_service.dart';
import '../../utils/app_logger.dart';

/// The possible states of the authenticated session.
///
/// - [loading]         — stream not yet resolved, or verifying email
/// - [unauthenticated] — no signed-in user
/// - [unverified]      — email/password user whose email is not yet verified
/// - [authenticated]   — fully valid session (verified email or OAuth)
enum AuthStatus { loading, unauthenticated, unverified, authenticated }

/// Owns all authentication state for the app.
///
/// MVVM role: ViewModel
/// - Subscribes to [FirebaseAuthService.authStateChanges] once.
/// - Resolves email-verification status asynchronously.
/// - Exposes a single [status] field + [userId] to the View.
/// - Zero widget imports — no [BuildContext] dependency.
///
/// Consumed by [AuthGate] via `context.watch<AuthViewModel>()`.
class AuthViewModel extends ChangeNotifier {
  AuthStatus _status = AuthStatus.loading;
  String? _userId;
  StreamSubscription<User?>? _authSub;

  AuthStatus get status => _status;

  /// The UID of the currently authenticated user, or `null` when not signed in.
  String? get userId => _userId;

  bool get isLoading => _status == AuthStatus.loading;

  AuthViewModel() {
    _authSub = FirebaseAuthService.instance.authStateChanges.listen(
      _onAuthChanged,
      onError: (e) => AppLogger.e('[AuthViewModel] Stream error: $e'),
    );
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _setStatus(AuthStatus.unauthenticated, userId: null);
      return;
    }

    // Show loading while verifying
    _setStatus(AuthStatus.loading, userId: null);

    final isEmailPasswordUser = user.providerData.any(
      (info) => info.providerId == 'password',
    );

    if (isEmailPasswordUser) {
      final isVerified = await FirebaseAuthService.instance.isEmailVerified();
      if (isVerified) {
        _setStatus(AuthStatus.authenticated, userId: user.uid);
        AppLogger.i('[AuthViewModel] User authenticated (email verified)');
      } else {
        _setStatus(AuthStatus.unverified, userId: null);
        AppLogger.i('[AuthViewModel] User unverified');
      }
    } else {
      // OAuth providers (Google, etc.) are always considered verified
      _setStatus(AuthStatus.authenticated, userId: user.uid);
      AppLogger.i('[AuthViewModel] User authenticated (OAuth)');
    }
  }

  void _setStatus(AuthStatus status, {required String? userId}) {
    _status = status;
    _userId = userId;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
