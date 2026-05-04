import 'package:app_links/app_links.dart';
import '../utils/app_logger.dart';
import '../config/app_router.dart';

/// Handles deep link resolution and navigation for the app.
///
/// Supports two URI schemes:
/// - `https://trekscanplus.app/posts/{postId}`
/// - `trekscanplus://posts/{postId}`
///
/// Extraction reason: deep link parsing was embedded in `_MyAppState`,
/// mixing URI logic with widget lifecycle. This class has no UI dependency —
/// it navigates via [navigatorKey] instead of a widget context.
class DeepLinkHandler {
  /// Checks for a link that launched the app from a closed/cold state.
  ///
  /// Call once from the first post-frame callback.
  static Future<void> handleInitialLink() async {
    try {
      final appLinks = AppLinks();
      final link = await appLinks.getInitialLink();
      if (link != null) {
        AppLogger.d('[DeepLink] Initial link: $link');
        _handleLink(link.toString());
      }
    } catch (e) {
      AppLogger.e('[DeepLink] Error getting initial link: $e');
    }
  }

  /// Subscribes to incoming deep links while the app is running.
  ///
  /// Call once from the first post-frame callback.
  static void startListening() {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen(
      (Uri link) {
        AppLogger.d('[DeepLink] Received link: $link');
        _handleLink(link.toString());
      },
      onError: (err) {
        AppLogger.e('[DeepLink] Stream error: $err');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  static void _handleLink(String link) {
    try {
      final uri = Uri.parse(link);
      AppLogger.d(
        '[DeepLink] Parsed URI — scheme: ${uri.scheme}, '
        'path: ${uri.path}, host: ${uri.host}',
      );

      String? postId;

      if (uri.scheme == 'https' && uri.host == 'trekscanplus.app') {
        if (uri.path.startsWith('/posts/')) {
          postId = uri.path.replaceFirst('/posts/', '');
        }
      } else if (uri.scheme == 'trekscanplus') {
        if (uri.host == 'posts' && uri.path.isNotEmpty) {
          postId = uri.path.replaceFirst('/', '');
        }
      }

      if (postId != null && postId.isNotEmpty) {
        AppLogger.d('[DeepLink] Navigating to post: $postId');
        navigatorKey.currentState?.pushNamed('/post-detail', arguments: postId);
      } else {
        AppLogger.w('[DeepLink] Could not extract postId from link');
      }
    } catch (e) {
      AppLogger.e('[DeepLink] Error handling deep link: $e');
    }
  }
}
