import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/email_verification_screen.dart';
import '../screens/main/main_screen.dart';
import '../features/booking/screens/book_a_climb_screen.dart';
import '../screens/social/post_detail_screen.dart';

/// Global navigator key — required for navigation outside of widget context
/// (deep links, push notifications).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Centralises all route definitions for the app.
///
/// Responsibilities:
/// - Named static routes (`routes`)
/// - Dynamic routes with arguments (`onGenerateRoute`)
///
/// Add new routes here; do not put them in main.dart or individual widgets.
class AppRouter {
  /// Named routes that require no arguments.
  static Map<String, WidgetBuilder> get routes => {
    '/login': (context) => const LoginScreen(),
    '/signup': (context) => const SignUpScreen(),
    '/verify-email': (context) => const EmailVerificationScreen(),
    '/main': (context) => const MainScreen(),
  };

  /// Generates routes that require arguments passed via [RouteSettings.arguments].
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == '/post-detail') {
      final postId = settings.arguments as String?;
      if (postId != null) {
        return MaterialPageRoute(
          builder: (context) => PostDetailScreen(postId: postId),
        );
      }
    }

    if (settings.name == '/book-climb') {
      final bookingId = settings.arguments as String?;
      return MaterialPageRoute(
        builder: (context) =>
            BookAClimbScreenRefactored(highlightBookingId: bookingId),
      );
    }

    return null;
  }
}
