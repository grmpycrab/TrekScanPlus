import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../viewmodels/auth_view_model.dart';

/// Wraps the widget tree with all top-level state providers.
///
/// Providers registered here:
/// - [ThemeService]  — active theme / mode
/// - [AuthViewModel] — authentication state (loading, authed, unverified, etc.)
///
/// Future: when migrating to Riverpod, replace with a [ProviderScope] and
/// add feature-level providers in this file.
class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
      ],
      child: child,
    );
  }
}
