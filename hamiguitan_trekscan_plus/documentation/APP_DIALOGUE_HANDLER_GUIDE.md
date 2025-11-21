# App Dialogue Handler - Quick Reference Guide

## Overview
Centralized dialogue handler using Cupertino design for consistent UI across the TrekScan+ app.

**File Location:** `lib/components/app_dialogue_handler.dart`

---

## Available Dialogue Types

### 1. Simple Alert
Shows a basic alert with a message and OK button.

```dart
await AppDialogueHandler.showAlert(
  context: context,
  title: 'Success',
  message: 'Your booking has been confirmed!',
  buttonText: 'OK', // Optional, defaults to 'OK'
);
```

**Use Cases:**
- Information messages
- Simple notifications
- Non-critical alerts

---

### 2. Confirmation Dialogue
Shows Yes/No dialogue for user confirmation.

```dart
final confirmed = await AppDialogueHandler.showConfirmation(
  context: context,
  title: 'Delete Post',
  message: 'Are you sure you want to delete this post? This action cannot be undone.',
  confirmText: 'Delete', // Optional, defaults to 'Yes'
  cancelText: 'Cancel',  // Optional, defaults to 'No'
  isDestructive: true,   // Optional, makes confirm button red
);

if (confirmed == true) {
  // User confirmed
  deletePost();
}
```

**Use Cases:**
- Delete confirmations
- Critical actions
- Logout confirmation
- Cancel booking

---

### 3. Success Dialogue
Shows a success message with a green checkmark icon.

```dart
await AppDialogueHandler.showSuccess(
  context: context,
  title: 'Booking Confirmed!',
  message: 'Your trek has been scheduled for Dec 25, 2024.', // Optional
  buttonText: 'Great!', // Optional
);
```

**Use Cases:**
- Successful booking
- Profile updated
- Achievement unlocked
- Payment completed

---

### 4. Error Dialogue
Shows an error message with a red warning icon.

```dart
await AppDialogueHandler.showError(
  context: context,
  title: 'Booking Failed',
  message: 'Unable to process your booking. Please try again later.', // Optional
  buttonText: 'OK', // Optional
);
```

**Use Cases:**
- API errors
- Validation failures
- Network issues
- Permission denied

---

### 5. Loading Dialogue
Shows a loading spinner (cannot be dismissed by user).

```dart
// Show loading
AppDialogueHandler.showLoading(
  context: context,
  message: 'Processing payment...', // Optional
);

// Perform async operation
await processPayment();

// Dismiss loading
AppDialogueHandler.dismiss(context);
```

**Use Cases:**
- API calls
- File uploads
- Payment processing
- Data synchronization

---

### 6. Input Dialogue
Allows user to enter text input.

```dart
final userName = await AppDialogueHandler.showInput(
  context: context,
  title: 'Edit Name',
  message: 'Enter your new display name', // Optional
  placeholder: 'John Doe',                // Optional
  initialValue: currentName,              // Optional
  confirmText: 'Save',                    // Optional
  cancelText: 'Cancel',                   // Optional
  keyboardType: TextInputType.text,       // Optional
  maxLength: 50,                          // Optional
);

if (userName != null && userName.isNotEmpty) {
  updateUserName(userName);
}
```

**Use Cases:**
- Edit profile fields
- Rename items
- Add comments
- Custom search

---

### 7. Choice Dialogue
Shows multiple options for user to choose from.

```dart
final choice = await AppDialogueHandler.showChoice<String>(
  context: context,
  title: 'Share Post',
  message: 'How would you like to share this post?', // Optional
  options: [
    ChoiceOption(
      label: 'Copy Link',
      value: 'copy',
      icon: CupertinoIcons.link,
    ),
    ChoiceOption(
      label: 'Share via SMS',
      value: 'sms',
      icon: CupertinoIcons.chat_bubble,
    ),
    ChoiceOption(
      label: 'Share via Email',
      value: 'email',
      icon: CupertinoIcons.mail,
    ),
  ],
  showCancel: true,       // Optional, defaults to true
  cancelText: 'Cancel',   // Optional
);

if (choice == 'copy') {
  copyLinkToClipboard();
} else if (choice == 'sms') {
  shareViaSMS();
} else if (choice == 'email') {
  shareViaEmail();
}
```

**Use Cases:**
- Share options
- Export formats
- Filter selections
- Action menus

---

### 8. Custom Actions Dialogue
Shows dialogue with fully customizable actions.

```dart
final action = await AppDialogueHandler.showCustomActions<String>(
  context: context,
  title: 'Manage Booking',
  message: 'What would you like to do with this booking?', // Optional
  actions: [
    DialogueAction(
      label: 'View Details',
      value: 'view',
      isDefault: true,
    ),
    DialogueAction(
      label: 'Reschedule',
      value: 'reschedule',
    ),
    DialogueAction(
      label: 'Cancel Booking',
      value: 'cancel',
      isDestructive: true,
    ),
  ],
);

switch (action) {
  case 'view':
    viewBookingDetails();
    break;
  case 'reschedule':
    rescheduleBooking();
    break;
  case 'cancel':
    cancelBooking();
    break;
}
```

**Use Cases:**
- Complex action menus
- Booking management
- Post options
- Admin actions

---

## Helper Classes

### DialogueAction
Used with `showCustomActions()`:

```dart
DialogueAction<T>(
  label: 'Button Text',
  value: returnValue,
  isDestructive: false,  // Makes text red
  isDefault: false,      // Makes text bold
)
```

### ChoiceOption
Used with `showChoice()`:

```dart
ChoiceOption<T>(
  label: 'Option Text',
  value: returnValue,
  icon: CupertinoIcons.icon_name,  // Optional
  isDestructive: false,             // Makes text red
  isDefault: false,                 // Makes text bold
)
```

---

## Common Patterns

### Delete Confirmation
```dart
final confirmed = await AppDialogueHandler.showConfirmation(
  context: context,
  title: 'Delete Item',
  message: 'This action cannot be undone.',
  confirmText: 'Delete',
  isDestructive: true,
);

if (confirmed == true) {
  await deleteItem();
  await AppDialogueHandler.showSuccess(
    context: context,
    title: 'Deleted',
    message: 'Item has been deleted successfully.',
  );
}
```

### Loading with Error Handling
```dart
try {
  AppDialogueHandler.showLoading(context: context, message: 'Saving...');
  
  await saveData();
  
  AppDialogueHandler.dismiss(context);
  
  await AppDialogueHandler.showSuccess(
    context: context,
    title: 'Saved',
    message: 'Your changes have been saved.',
  );
} catch (e) {
  AppDialogueHandler.dismiss(context);
  
  await AppDialogueHandler.showError(
    context: context,
    title: 'Save Failed',
    message: e.toString(),
  );
}
```

### Conditional Actions
```dart
final options = <ChoiceOption<String>>[
  ChoiceOption(label: 'Edit', value: 'edit', icon: CupertinoIcons.pencil),
  if (isOwner)
    ChoiceOption(
      label: 'Delete',
      value: 'delete',
      icon: CupertinoIcons.delete,
      isDestructive: true,
    ),
  ChoiceOption(label: 'Share', value: 'share', icon: CupertinoIcons.share),
];

final action = await AppDialogueHandler.showChoice(
  context: context,
  title: 'Post Options',
  options: options,
);
```

---

## Migration Examples

### Before (Old Way)
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Delete Post'),
    content: Text('Are you sure?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text('Delete'),
      ),
    ],
  ),
);
```

### After (New Way)
```dart
await AppDialogueHandler.showConfirmation(
  context: context,
  title: 'Delete Post',
  message: 'Are you sure?',
  confirmText: 'Delete',
  isDestructive: true,
);
```

---

## Best Practices

1. **Always use await** for dialogues that return values
2. **Check for null** when user can cancel (confirmation, input, choice)
3. **Use isDestructive** for delete/remove actions
4. **Dismiss loading** dialogues in try-finally blocks
5. **Keep messages concise** - mobile screens have limited space
6. **Use appropriate icons** in choice options for clarity
7. **Provide context** in error messages (what failed, why, what to do)

---

## Import Statement
```dart
import '../components/app_dialogue_handler.dart';
```

---

## Design Philosophy

- **Cupertino Design**: Native iOS feel for better UX
- **Consistency**: Same look and behavior across the app
- **Simplicity**: Easy-to-use API with sensible defaults
- **Flexibility**: Customizable for different use cases
- **Type Safety**: Generic types for action values
- **Accessibility**: Follows iOS accessibility guidelines
