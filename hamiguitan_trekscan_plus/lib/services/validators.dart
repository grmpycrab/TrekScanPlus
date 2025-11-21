class Validators {
  static String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Contact number is required';
    }
    final phoneRegex = RegExp(r'^\d{7,15}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid contact number';
    }
    return null;
  }

  static String? validAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Age is required';
    }
    final age = int.tryParse(value);
    if (age == null || age < 1 || age > 120) {
      return 'Enter a valid age (1-120)';
    }
    return null;
  }

  static String? validPorters(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Number of porters is required';
    }
    final porters = int.tryParse(value);
    if (porters == null) {
      return 'Enter a valid number';
    }
    if (porters < 0 || porters > 20) {
      return 'Number of porters must be between 0 and 20';
    }
    return null;
  }

  static String? validContactNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Contact number is required';
    }
    // Remove any spaces, dashes, or parentheses
    final cleanedValue = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check if it starts with +63 or 63 (Philippines country code)
    if (cleanedValue.startsWith('+63')) {
      final phoneRegex = RegExp(r'^\+63\d{10}$');
      if (!phoneRegex.hasMatch(cleanedValue)) {
        return 'Enter a valid Philippine number (+63 followed by 10 digits)';
      }
    } else if (cleanedValue.startsWith('63')) {
      final phoneRegex = RegExp(r'^63\d{10}$');
      if (!phoneRegex.hasMatch(cleanedValue)) {
        return 'Enter a valid Philippine number (63 followed by 10 digits)';
      }
    } else if (cleanedValue.startsWith('09')) {
      // Local format: 09XX-XXX-XXXX (11 digits)
      final phoneRegex = RegExp(r'^09\d{9}$');
      if (!phoneRegex.hasMatch(cleanedValue)) {
        return 'Enter a valid Philippine mobile number (09 followed by 9 digits)';
      }
    } else {
      return 'Enter a valid Philippine contact number';
    }
    return null;
  }
}
