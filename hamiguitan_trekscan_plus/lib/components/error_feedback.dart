import 'package:flutter/material.dart';

enum ErrorType { error, warning, info, success }

class ErrorFeedback extends StatelessWidget {
  final String message;
  final ErrorType type;
  final VoidCallback? onDismiss;
  final Duration duration;

  const ErrorFeedback({
    super.key,
    required this.message,
    this.type = ErrorType.error,
    this.onDismiss,
    this.duration = const Duration(seconds: 5),
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors['background'],
        border: Border(left: BorderSide(color: colors['border']!, width: 4)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colors['border']!.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_getIcon(), color: colors['icon'], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitle(),
                  style: TextStyle(
                    color: colors['title'],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: colors['text'], fontSize: 13),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, color: colors['icon'], size: 18),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Map<String, Color> _getColors() {
    switch (type) {
      case ErrorType.error:
        return {
          'background': Colors.red.shade50,
          'border': Colors.red.shade400,
          'icon': Colors.red.shade700,
          'title': Colors.red.shade900,
          'text': Colors.red.shade800,
        };
      case ErrorType.warning:
        return {
          'background': Colors.orange.shade50,
          'border': Colors.orange.shade400,
          'icon': Colors.orange.shade700,
          'title': Colors.orange.shade900,
          'text': Colors.orange.shade800,
        };
      case ErrorType.info:
        return {
          'background': Colors.blue.shade50,
          'border': Colors.blue.shade400,
          'icon': Colors.blue.shade700,
          'title': Colors.blue.shade900,
          'text': Colors.blue.shade800,
        };
      case ErrorType.success:
        return {
          'background': Colors.green.shade50,
          'border': Colors.green.shade400,
          'icon': Colors.green.shade700,
          'title': Colors.green.shade900,
          'text': Colors.green.shade800,
        };
    }
  }

  IconData _getIcon() {
    switch (type) {
      case ErrorType.error:
        return Icons.error_outline;
      case ErrorType.warning:
        return Icons.warning_amber;
      case ErrorType.info:
        return Icons.info_outline;
      case ErrorType.success:
        return Icons.check_circle_outline;
    }
  }

  String _getTitle() {
    switch (type) {
      case ErrorType.error:
        return 'Error';
      case ErrorType.warning:
        return 'Warning';
      case ErrorType.info:
        return 'Information';
      case ErrorType.success:
        return 'Success';
    }
  }
}

class ErrorHandler {
  static String getErrorMessage(String error) {
    final errorLower = error.toLowerCase();

    // Network errors
    if (errorLower.contains('network') ||
        errorLower.contains('connection') ||
        errorLower.contains('socket') ||
        errorLower.contains('timeout')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Authentication errors
    if (errorLower.contains('invalid-credential') ||
        errorLower.contains('invalid-email')) {
      return 'Invalid email or password. Please check and try again.';
    }

    if (errorLower.contains('user-not-found')) {
      return 'User not found. Please sign up first.';
    }

    if (errorLower.contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    }

    if (errorLower.contains('email-already-in-use')) {
      if (errorLower.contains('google')) {
        return 'This email is already registered with Google. Please sign in using Google instead.';
      } else if (errorLower.contains('email and password')) {
        return 'This email is already registered with email and password. Please sign in using that method instead.';
      }
      return 'This email is already registered with another method. Please sign in using the original method or use a different email address.';
    }

    if (errorLower.contains('weak-password')) {
      return 'Password is too weak. Use at least 8 characters with uppercase, lowercase, and numbers.';
    }

    if (errorLower.contains('too-many-requests')) {
      return 'Too many login attempts. Please try again later.';
    }

    if (errorLower.contains('account-exists-with-different-credential')) {
      if (errorLower.contains('email and password')) {
        return 'An account already exists with this email address but was registered using email and password. Please sign in using your email and password instead.';
      }
      return 'An account exists with this email using a different sign-in method. Please use the original sign-in method.';
    }

    if (errorLower.contains('operation-not-allowed')) {
      return 'This sign-in method is not enabled. Please contact support.';
    }

    if (errorLower.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    }

    if (errorLower.contains('invalid-api-key')) {
      return 'Configuration error. Please try again later.';
    }

    // Generic errors
    if (errorLower.contains('failed')) {
      return 'Operation failed. Please try again.';
    }

    return 'An unexpected error occurred. Please try again.';
  }

  static ErrorType getErrorType(String error) {
    final errorLower = error.toLowerCase();

    if (errorLower.contains('success')) {
      return ErrorType.success;
    }

    if (errorLower.contains('warning')) {
      return ErrorType.warning;
    }

    if (errorLower.contains('network') || errorLower.contains('connection')) {
      return ErrorType.warning;
    }

    return ErrorType.error;
  }

  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    ErrorType type = ErrorType.error,
    Duration duration = const Duration(seconds: 5),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ErrorFeedback(
          message: message,
          type: type,
          duration: duration,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: duration,
      ),
    );
  }
}
