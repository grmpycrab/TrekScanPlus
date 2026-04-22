# Application Logging Configuration

## Overview

The app now has enhanced logging with multiple levels and filtering capabilities for cleaner console output.

## Log Levels (in order of priority)

| Level       | Priority    | Use Case                                      |
| ----------- | ----------- | --------------------------------------------- |
| **VERBOSE** | 0 (Lowest)  | Very detailed traces, every method call       |
| **DEBUG**   | 1           | Detailed debugging information                |
| **INFO**    | 2           | General informational messages ✅ **Default** |
| **WARNING** | 3           | Warning messages                              |
| **ERROR**   | 4 (Highest) | Error messages only                           |

## Current Configuration

**In `main.dart`:**

```dart
AppLogger.setLogLevel(LogLevel.info); // Show INFO, WARNING, ERROR only
```

This suppresses:

- ✂️ VERBOSE logs
- ✂️ DEBUG logs
- ✅ INFO logs (messages, initialization)
- ✅ WARNING logs
- ✅ ERROR logs

## Suppressed System Tags (Auto-Filtered)

The following noisy system tags are automatically filtered:

- `GoogleApiManager` - Google Play Services errors
- `FlagStore` / `FlagRegistrar` - Phenotype API errors
- `ProviderInstaller` - Provider installer warnings

See [app_logger.dart](lib/utils/app_logger.dart#L35-L44) for the full list.

## How to Change Logging Level

### Option 1: Change at Startup (Recommended)

In `main.dart`:

```dart
// Show everything (very verbose)
AppLogger.setLogLevel(LogLevel.debug);

// Show only warnings and errors (very quiet)
AppLogger.setLogLevel(LogLevel.warning);
```

### Option 2: Suppress Specific Tags

```dart
// Hide logs containing specific keywords
AppLogger.suppressTag('MyService');
AppLogger.suppressTag('Firebase');
```

### Option 3: Disable Logging Entirely

```dart
AppLogger.disableLogs();
// Later:
AppLogger.enableLogs();
```

## Terminal Commands for Filtering

### View only Flutter app logs

```bash
flutter run -v | grep -E "flutter|I/flutter"
```

### View only app logs (no system noise)

```bash
flutter run 2>&1 | grep "I/flutter"
```

### View only INFO level logs

```bash
flutter run 2>&1 | grep "\[INFO\]"
```

### View only ERROR logs

```bash
flutter run 2>&1 | grep -E "ERROR|Exception"
```

### On actual device (Android)

```bash
adb logcat | grep "flutter"
```

## Best Practices

1. **Development**: Use `LogLevel.debug` to see detailed traces
2. **Testing**: Use `LogLevel.info` (current default) for cleaner output
3. **Production**: Use `LogLevel.warning` to see only important messages

## Example Output

### Before (Noisy)

```
I/flutter (31594): [2026-04-22 10:35:37] [INFO] | FCM initialized successfully
E/GoogleApiManager(31594): Failed to get service from broker...
W/FlagRegistrar(31594): Failed to register...
I/flutter (31594): [2026-04-22 10:35:37] [INFO] | [NotificationService] Initialized successfully
```

### After (Clean)

```
[2026-04-22 10:35:37] [INFO] | FCM initialized successfully
[2026-04-22 10:35:37] [INFO] | [NotificationService] Initialized successfully
```

## Adding Custom Log Handlers

For file logging, analytics, or crash reporting:

```dart
class FileLogHandler extends LogHandler {
  @override
  void handle(String message) {
    // Write to file, send to analytics, etc.
  }
}

// Add in main.dart:
AppLogger.addHandler(FileLogHandler());
```
