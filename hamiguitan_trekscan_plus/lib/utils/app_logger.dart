import 'package:flutter/foundation.dart';

/// Log level enumeration
enum LogLevel {
  verbose(0),
  debug(1),
  info(2),
  warning(3),
  error(4);

  final int priority;
  const LogLevel(this.priority);
}

/// Abstract base class for custom log handlers
/// Implement this to add file logging, remote logging, etc.
abstract class LogHandler {
  void handle(String message);
}

/// Centralized logging utility for the application
/// Handles all logging with consistent formatting and levels
class AppLogger {
  static const String _verbose = 'VERBOSE';
  static const String _debug = 'DEBUG';
  static const String _info = 'INFO';
  static const String _warning = 'WARNING';
  static const String _error = 'ERROR';

  /// Global enable/disable flag for logging
  static bool _logsEnabled = true;

  /// Current minimum log level to display
  static LogLevel _minLogLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// List of custom log handlers for extensibility
  static final List<LogHandler> _handlers = [];

  /// Tags to suppress from logging
  static final Set<String> _suppressedTags = {
    'GoogleApiManager',
    'FlagRegistrar',
    'FlagStore',
    'ProviderInstaller',
    'DynamiteModule',
    'Phenotype',
  };

  /// Enable all logging
  static void enableLogs() {
    _logsEnabled = true;
  }

  /// Disable all logging
  static void disableLogs() {
    _logsEnabled = false;
  }

  /// Set minimum log level to display
  /// In debug mode, defaults to DEBUG
  /// In release mode, defaults to INFO
  static void setLogLevel(LogLevel level) {
    _minLogLevel = level;
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

  /// Suppress logs from a specific tag/source
  static void suppressTag(String tag) {
    _suppressedTags.add(tag);
  }

  /// Verbose level log (lowest priority, use for detailed traces)
  static void v(String message) {
    _log(LogLevel.verbose, _verbose, message);
  }

  /// Debug level log
  /// Use for detailed debugging information
  static void d(String message) {
    _log(LogLevel.debug, _debug, message);
  }

  /// Info level log
  /// Use for general informational messages
  static void i(String message) {
    _log(LogLevel.info, _info, message);
  }

  /// Warning level log
  /// Use for warning messages
  static void w(String message) {
    _log(LogLevel.warning, _warning, message);
  }

  /// Error level log
  /// Use for error messages
  static void e(String message) {
    _log(LogLevel.error, _error, message);
  }

  /// Internal log method
  /// Formats and outputs log messages based on current level settings
  static void _log(LogLevel level, String levelName, String message) {
    if (!kDebugMode || !_logsEnabled) return;

    // Check log level threshold
    if (level.priority < _minLogLevel.priority) return;

    // Check if message should be suppressed (contains suppressed tags)
    for (final tag in _suppressedTags) {
      if (message.contains(tag)) return;
    }

    final now = DateTime.now();
    final timestamp = _formatTimestamp(now);
    final log = '[$timestamp] [$levelName] | $message';

    // Print to console directly (avoid recursion!)
    if (kDebugMode) {
      print(log);
    }

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
