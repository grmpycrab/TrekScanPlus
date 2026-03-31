import 'package:flutter/cupertino.dart';

/// Centralized dialogue handler for consistent UI across the app
/// Uses Cupertino design for native iOS feel
class AppDialogueHandler {
  /// Show a simple alert dialogue with a message and OK button
  static Future<void> showAlert({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'OK',
  }) {
    return showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  /// Show a confirmation dialogue with Yes/No or custom options
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'No',
    bool isDestructive = false,
  }) async {
    return await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            isDestructiveAction: isDestructive,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Show a dialogue with custom actions
  static Future<T?> showCustomActions<T>({
    required BuildContext context,
    required String title,
    String? message,
    required List<DialogueAction<T>> actions,
  }) {
    return showCupertinoDialog<T>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(title),
        content: message != null
            ? Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(message),
              )
            : null,
        actions: actions.map((action) {
          return CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, action.value),
            isDestructiveAction: action.isDestructive,
            isDefaultAction: action.isDefault,
            child: Text(action.label),
          );
        }).toList(),
      ),
    );
  }

  /// Show a success dialogue with checkmark icon
  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    String? message,
    String buttonText = 'OK',
  }) {
    return showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Column(
          children: [
            const Icon(
              CupertinoIcons.check_mark_circled_solid,
              color: CupertinoColors.systemGreen,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(title),
          ],
        ),
        content: message != null
            ? Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(message),
              )
            : null,
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  /// Show an error dialogue with warning icon
  static Future<void> showError({
    required BuildContext context,
    required String title,
    String? message,
    String buttonText = 'OK',
  }) {
    return showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Column(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              color: CupertinoColors.systemRed,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(title),
          ],
        ),
        content: message != null
            ? Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(message),
              )
            : null,
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  /// Show a loading dialogue (without dismiss button)
  static Future<void> showLoading({
    required BuildContext context,
    String message = 'Loading...',
  }) {
    return showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      // ignore: deprecated_member_use
      builder: (BuildContext context) => WillPopScope(
        onWillPop: () async => false,
        child: CupertinoAlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 14),
              const SizedBox(height: 12),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  /// Show an input dialogue for text input
  static Future<String?> showInput({
    required BuildContext context,
    required String title,
    String? message,
    String? placeholder,
    String? initialValue,
    String confirmText = 'Submit',
    String cancelText = 'Cancel',
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );

    return showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                child: Text(message),
              ),
            CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              keyboardType: keyboardType,
              maxLength: maxLength,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            isDefaultAction: true,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Show a choice dialogue with multiple options
  static Future<T?> showChoice<T>({
    required BuildContext context,
    required String title,
    String? message,
    required List<ChoiceOption<T>> options,
    bool showCancel = true,
    String cancelText = 'Cancel',
  }) {
    final actions = <Widget>[
      ...options.map((option) {
        return CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, option.value),
          isDestructiveAction: option.isDestructive,
          isDefaultAction: option.isDefault,
          child: Text(option.label),
        );
      }),
      if (showCancel)
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelText),
        ),
    ];

    return showCupertinoDialog<T>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(title),
        content: message != null
            ? Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(message),
              )
            : null,
        actions: actions,
      ),
    );
  }

  /// Dismiss the currently showing dialogue
  static void dismiss(BuildContext context) {
    Navigator.pop(context);
  }
}

/// Helper class for dialogue actions
class DialogueAction<T> {
  final String label;
  final T value;
  final bool isDestructive;
  final bool isDefault;

  const DialogueAction({
    required this.label,
    required this.value,
    this.isDestructive = false,
    this.isDefault = false,
  });
}

/// Helper class for choice options
class ChoiceOption<T> {
  final String label;
  final T value;
  final IconData? icon;
  final bool isDestructive;
  final bool isDefault;

  const ChoiceOption({
    required this.label,
    required this.value,
    this.icon,
    this.isDestructive = false,
    this.isDefault = false,
  });
}
