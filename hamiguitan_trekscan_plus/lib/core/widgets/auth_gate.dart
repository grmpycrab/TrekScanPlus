import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_router.dart';
import '../viewmodels/auth_view_model.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';
import '../../screens/main/main_screen.dart';
import 'app_shell.dart';

/// Callback fired once when a fully authenticated session is confirmed.
typedef OnServicesInitNeeded = void Function(String userId);

/// Callback fired when the user signs out.
typedef OnLogout = void Function();

/// Maps [AuthViewModel] state to the correct initial screen.
///
/// Decision table:
/// | [AuthStatus]         | Screen                    |
/// |----------------------|---------------------------|
/// | loading              | loading spinner           |
/// | unauthenticated      | [LoginScreen]             |
/// | unverified           | [EmailVerificationScreen] |
/// | authenticated        | [MainScreen]              |
///
/// When status transitions to [AuthStatus.authenticated], fires
/// [onServicesInitNeeded] exactly once per session so the caller can
/// initialize user-scoped services without this widget knowing about them.
///
/// MVVM role: View — zero business logic, zero Firebase imports.
class AuthGate extends StatefulWidget {
  final OnServicesInitNeeded? onServicesInitNeeded;
  final OnLogout? onLogout;

  const AuthGate({super.key, this.onServicesInitNeeded, this.onLogout});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _serviceInitFired = false;
  AuthStatus? _prevStatus;

  /// Called on every Consumer rebuild. Detects status transitions and
  /// drives navigation imperatively via [navigatorKey] so that any
  /// existing navigator stack is correctly replaced — not just the
  /// MaterialApp.home property (which only affects the initial route).
  void _handleStatusTransition(AuthViewModel vm) {
    if (vm.status == _prevStatus) return;
    final incoming = vm.status;
    _prevStatus = incoming;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Fire lifecycle callbacks once per transition
      if (incoming == AuthStatus.authenticated &&
          vm.userId != null &&
          !_serviceInitFired) {
        _serviceInitFired = true;
        widget.onServicesInitNeeded?.call(vm.userId!);
      }
      if (incoming == AuthStatus.unauthenticated) {
        _serviceInitFired = false;
        widget.onLogout?.call();
      }

      // Imperative navigation — works regardless of what is currently
      // on the navigator stack (e.g. after a manual pushAndRemoveUntil
      // in a settings screen, or after a cold start).
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      switch (incoming) {
        case AuthStatus.unauthenticated:
          nav.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        case AuthStatus.unverified:
          nav.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
            (route) => false,
          );
        case AuthStatus.authenticated:
          nav.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
          );
        case AuthStatus.loading:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, vm, _) {
        _handleStatusTransition(vm);

        // The switch below provides the correct initial screen on cold
        // start (before navigatorKey has a state). Subsequent transitions
        // are handled imperatively in _handleStatusTransition.
        return switch (vm.status) {
          AuthStatus.loading => AppShell(
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          ),
          AuthStatus.unauthenticated => const AppShell(home: LoginScreen()),
          AuthStatus.unverified => const AppShell(
            home: EmailVerificationScreen(),
          ),
          AuthStatus.authenticated => const AppShell(home: MainScreen()),
        };
      },
    );
  }
}
