import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';

/// Wraps the widget tree with all top-level state providers.
///
/// Extraction reason: provider declarations were inlined in `main()`, mixing
/// bootstrap concerns with state wiring. All providers now live here.
///
/// Future: when migrating to Riverpod, replace [ChangeNotifierProvider] with
/// a [ProviderScope] and add feature-level providers in this file.
class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(create: (_) => ThemeService(), child: child);
  }
}
