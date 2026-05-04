import '../../../utils/app_logger.dart';

/// Lightweight analytics stub. Logs events locally via [AppLogger].
/// Swap the implementation here when a real analytics backend (e.g.
/// Firebase Analytics) is added — callers in ViewModels remain unchanged.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  void logEvent(String name, {Map<String, Object>? params}) {
    AppLogger.i('[Analytics] $name${params != null ? ' $params' : ''}');
  }
}
