import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_view_model.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/email_verification_screen.dart';
import '../../screens/main/main_screen.dart';
import 'app_shell.dart';

/// Callback fired once when a fully authenticated session is confirmed.
typedef OnServicesInitNeeded = void Function(String userId);

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

  const AuthGate({super.key, this.onServicesInitNeeded});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _serviceInitFired = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, vm, _) {
        // Fire service init once when user becomes authenticated
        if (vm.status == AuthStatus.authenticated &&
            vm.userId != null &&
            !_serviceInitFired) {
          _serviceInitFired = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onServicesInitNeeded?.call(vm.userId!);
          });
        }

        // Reset flag when user signs out so next login re-initialises services
        if (vm.status == AuthStatus.unauthenticated) {
          _serviceInitFired = false;
        }

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
