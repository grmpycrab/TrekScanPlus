import 'package:flutter/foundation.dart';

/// Abstract base class for custom log handlers
/// Implement this to add file logging, remote logging, etc.
abstract class LogHandler {
  void handle(String message);
}

/// Centralized logging utility for the application
/// Handles all logging with consistent formatting and levels
class AppLogger {
  static const String _debug = 'DEBUG';
  static const String _info = 'INFO';
  static const String _warning = 'WARNING';
  static const String _error = 'ERROR';

  /// Global enable/disable flag for logging
  static bool _logsEnabled = true;

  /// List of custom log handlers for extensibility
  static final List<LogHandler> _handlers = [];

  /// Enable all logging
  static void enableLogs() {
    _logsEnabled = true;
  }

  /// Disable all logging
  static void disableLogs() {
    _logsEnabled = false;
  }

  /// Add a custom log handler (e.g., for file or remote logging)
  static void addHandler(LogHandler handler) {
    _handlers.add(handler);
  }

  /// Remove a custom log handler
  static void removeHandler(LogHandler handler) {
    _handlers.remove(handler);
  }

  /// Clear all custom handlers
  static void clearHandlers() {
    _handlers.clear();
  }

  /// Debug level log
  /// Use for detailed debugging information
  static void d(String message) {
    _log(_debug, message);
  }

  /// Info level log
  /// Use for general informational messages
  static void i(String message) {
    _log(_info, message);
  }

  /// Warning level log
  /// Use for warning messages
  static void w(String message) {
    _log(_warning, message);
  }

  /// Error level log
  /// Use for error messages
  static void e(String message) {
    _log(_error, message);
  }

  /// Internal log method
  /// Formats and outputs log messages in debug mode only
  static void _log(String level, String message) {
    if (!kDebugMode || !_logsEnabled) return;

    final now = DateTime.now();
    final timestamp = _formatTimestamp(now);
    final log = '[$timestamp] [$level] | $message';

    // Print to console
    AppLogger.i(log);

    // Send to all registered handlers
    for (final handler in _handlers) {
      handler.handle(log);
    }
  }

  /// Format timestamp as YYYY-MM-DD HH:mm:ss
  static String _formatTimestamp(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
