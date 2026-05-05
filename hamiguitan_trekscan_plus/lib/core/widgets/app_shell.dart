import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../../services/app_theme_builder.dart';
import '../../features/notification/services/notification_manager.dart';
import '../../features/notification/widgets/notification_banner.dart';
import '../../config/app_router.dart';

/// The root [MaterialApp] shell for the entire application.
///
/// Responsibilities:
/// - Applies the active theme via [ThemeService]
/// - Wires [navigatorKey] for out-of-context navigation
/// - Mounts the global [NotificationBannerOverlay]
/// - Delegates route configuration to [AppRouter]
///
/// Pass any auth-gated screen as [home]; shell stays constant.
///
/// MVVM role: View (pure widget, zero business logic).
class AppShell extends StatelessWidget {
  final Widget home;

  const AppShell({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        final themeData = AppThemeBuilder.getThemeData(
          themeService.selectedTheme,
          themeService.selectedMode,
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Hamiguitan TrekScan+',
          navigatorKey: navigatorKey,
          theme: themeData,
          builder: (context, child) => Stack(
            children: [
              child!,
              NotificationBannerOverlay(key: NotificationManager.overlayKey),
            ],
          ),
          home: home,
          routes: AppRouter.routes,
          onGenerateRoute: AppRouter.onGenerateRoute,
        );
      },
    );
  }
}
