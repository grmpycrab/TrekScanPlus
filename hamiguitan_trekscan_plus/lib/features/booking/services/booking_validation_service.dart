import 'package:file_picker/file_picker.dart';
import '../../../models/member.dart';
import '../models/document_requirements.dart';

class BookingValidationService {
  /// Validates member name (no numbers, no special chars, reasonable length)
  static String? validateName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    value = value.trim();

    // Check length
    if (value.length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    if (value.length > 50) {
      return '$fieldName cannot exceed 50 characters';
    }

    // Check for valid characters (letters, spaces, hyphens, apostrophes only)
    final nameRegex = RegExp(r"^[a-zA-Z\s\-\']+$");
    if (!nameRegex.hasMatch(value)) {
      return '$fieldName can only contain letters, spaces, hyphens, and apostrophes';
    }

    // Check for multiple consecutive spaces
    if (value.contains('  ')) {
      return '$fieldName cannot contain multiple consecutive spaces';
    }

    return null;
  }

  /// Validates contact/phone number
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Contact number is required';
    }

    value = value.trim().replaceAll(RegExp(r'[\s\-\(\)]+'), '');

    // Check if it contains only digits and optional + at start
    if (!RegExp(r'^(\+\d{1,3})?\d{7,15}$').hasMatch(value)) {
      return 'Contact number must be 7-15 digits (optionally with +country code)';
    }

    // Check length after formatting
    if (value.length < 10) {
      return 'Contact number is too short (minimum 10 digits with country code)';
    }

    return null;
  }

  /// Validates birth date (YYYY-MM-DD format and reasonable age)
  static String? validateBirthDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Birth date is required';
    }

    value = value.trim();

    // Check format (YYYY-MM-DD)
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateRegex.hasMatch(value)) {
      return 'Birth date must be in YYYY-MM-DD format';
    }

    try {
      final birthDate = DateTime.parse(value);
      final today = DateTime.now();

      // Check if date is in the future
      if (birthDate.isAfter(today)) {
        return 'Birth date cannot be in the future';
      }

      // Calculate age
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }

      // Check minimum age (5 years)
      if (age < 5) {
        return 'Participant must be at least 5 years old';
      }

      // Check maximum age (130 years)
      if (age > 130) {
        return 'Please enter a valid birth date';
      }

      return null;
    } catch (e) {
      return 'Invalid date format. Please use YYYY-MM-DD';
    }
  }

  /// Validates nationality
  static String? validateNationality(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nationality is required';
    }

    value = value.trim();

    if (value.length < 2) {
      return 'Nationality must be at least 2 characters';
    }

    if (value.length > 50) {
      return 'Nationality cannot exceed 50 characters';
    }

    // Allow letters, spaces, and hyphens only
    if (!RegExp(r"^[a-zA-Z\s\-]+$").hasMatch(value)) {
      return 'Nationality can only contain letters, spaces, and hyphens';
    }

    return null;
  }

  /// Validates home address
  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Home address is required';
    }

    value = value.trim();

    if (value.length < 5) {
      return 'Address must be at least 5 characters';
    }

    if (value.length > 200) {
      return 'Address cannot exceed 200 characters';
    }

    // Reject obviously invalid addresses with excessive special characters
    final specialCharCount = RegExp(
      r'[!@#$%^&*()_+=\[\]{};:".<>?/\\|`~]',
    ).allMatches(value).length;
    if (specialCharCount > 3) {
      return 'Address contains too many special characters';
    }

    return null;
  }

  /// Validates gender selection
  static String? validateGender(String? value) {
    if (value == null || value.isEmpty) {
      return 'Gender is required';
    }

    const validGenders = ['male', 'female', 'other'];
    if (!validGenders.contains(value.toLowerCase())) {
      return 'Please select a valid gender option';
    }

    return null;
  }

  /// Validates participant category
  static String? validateCategory(String? value, List<String> validCategories) {
    if (value == null || value.isEmpty) {
      return 'Participant category is required';
    }

    if (!validCategories.contains(value)) {
      return 'Please select a valid participant category';
    }

    return null;
  }

  /// Validates trek date (must be future date and available)
  static String? validateTrekDate(DateTime? date) {
    if (date == null) {
      return 'Trek date is required';
    }

    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);

    // Trek must be at least 1 day in the future
    if (date.isBefore(tomorrow)) {
      return 'Trek date must be in the future (minimum 1 day from today)';
    }

    // Trek cannot be more than 2 years in the future
    final maxDate = DateTime(today.year + 2, today.month, today.day);
    if (date.isAfter(maxDate)) {
      return 'Trek date cannot be more than 2 years in the future';
    }

    return null;
  }

  /// Validates booking contact number
  static String? validateBookingContactNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Contact number is required';
    }

    return validatePhoneNumber(value);
  }

  /// Validates hometown/location
  static String? validateHometown(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Hometown is required';
    }

    value = value.trim();

    if (value.length < 2) {
      return 'Hometown must be at least 2 characters';
    }

    if (value.length > 100) {
      return 'Hometown cannot exceed 100 characters';
    }

    // Allow letters, spaces, hyphens, commas
    if (!RegExp(r"^[a-zA-Z\s\-,]+$").hasMatch(value)) {
      return 'Hometown can only contain letters, spaces, hyphens, and commas';
    }

    return null;
  }

  /// Validates affiliation/organization name
  static String? validateAffiliation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Affiliation is required';
    }

    value = value.trim();

    if (value.length < 2) {
      return 'Affiliation must be at least 2 characters';
    }

    if (value.length > 150) {
      return 'Affiliation cannot exceed 150 characters';
    }

    return null;
  }

  /// Validates trek type selection
  static String? validateTrekType(String? value, List<String> validTypes) {
    if (value == null || value.isEmpty) {
      return 'Trek type is required';
    }

    if (!validTypes.contains(value)) {
      return 'Please select a valid trek type';
    }

    return null;
  }

  /// Validates minimum number of members
  static String? validateMemberCount(int memberCount, int minMembers) {
    if (memberCount < minMembers) {
      return 'At least $minMembers member(s) required';
    }

    return null;
  }

  /// Validates maximum number of members
  static String? validateMaxMembers(int memberCount, int maxMembers) {
    if (memberCount > maxMembers) {
      return 'Maximum $maxMembers members allowed';
    }

    return null;
  }

  /// Validates date availability with slot information
  static String? validateDateAvailability(
    Map<String, dynamic> availabilityInfo,
  ) {
    if (availabilityInfo['isClosed'] == true) {
      return 'Trek date is closed: ${availabilityInfo['closureReason'] ?? 'Maintenance day'}';
    }

    if (availabilityInfo['isBufferDay'] == true) {
      return 'Cannot book on this date - trek down day (conflict with ${availabilityInfo['conflictDate']})';
    }

    if (availabilityInfo['available'] != true) {
      final remaining = availabilityInfo['remaining'] ?? 0;
      return 'No slots available for this date (only $remaining slots remaining)';
    }

    return null;
  }

  /// Calculate age from birth date string (YYYY-MM-DD)
  static int? calculateAge(String birthDateStr) {
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final today = DateTime.now();

      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }

      return age >= 0 ? age : null;
    } catch (e) {
      return null;
    }
  }

  /// Returns a map of member display name → list of missing required document
  /// names. An empty map means every member has all required documents uploaded.
  static Map<String, List<String>> validateAllMemberDocuments(
    List<Member> members,
    Map<String, Map<String, List<PlatformFile>>> memberDocuments,
  ) {
    final missing = <String, List<String>>{};
    for (var i = 0; i < members.length; i++) {
      final member = members[i];
      final memberDocs = memberDocuments[i.toString()] ?? {};
      final requiredDocs =
          DocumentRequirements.getRequiredDocumentsForCategory(member.category);
      final missingForMember = requiredDocs
          .where((docName) => memberDocs[docName]?.isNotEmpty != true)
          .toList();
      if (missingForMember.isNotEmpty) {
        final displayName = '${member.firstName} ${member.lastName}'.trim();
        missing[displayName.isEmpty ? 'Member ${i + 1}' : displayName] =
            missingForMember;
      }
    }
    return missing;
  }

  /// Format phone number for display
  static String formatPhoneNumber(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]+'), '');

    if (cleaned.startsWith('+')) {
      return cleaned; // Keep international format as-is
    }

    // Format as (XXX) XXX-XXXX for standard numbers
    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    }

    return cleaned; // Return as-is if doesn't match expected format
  }

  /// Get validation status summary for a member
  static Map<String, bool> getMemberValidationStatus({
    required String firstName,
    required String lastName,
    required String gender,
    required String birthDate,
    required String phoneNumber,
    required String nationality,
    required String address,
    required String category,
    required List<String> validCategories,
  }) {
    return {
      'firstName': validateName(firstName, 'First name') == null,
      'lastName': validateName(lastName, 'Last name') == null,
      'gender': validateGender(gender) == null,
      'birthDate': validateBirthDate(birthDate) == null,
      'phoneNumber': validatePhoneNumber(phoneNumber) == null,
      'nationality': validateNationality(nationality) == null,
      'address': validateAddress(address) == null,
      'category': validateCategory(category, validCategories) == null,
    };
  }

  /// Check if all member fields are valid
  static bool isValidMember({
    required String firstName,
    required String lastName,
    required String gender,
    required String birthDate,
    required String phoneNumber,
    required String nationality,
    required String address,
    required String category,
    required List<String> validCategories,
  }) {
    final status = getMemberValidationStatus(
      firstName: firstName,
      lastName: lastName,
      gender: gender,
      birthDate: birthDate,
      phoneNumber: phoneNumber,
      nationality: nationality,
      address: address,
      category: category,
      validCategories: validCategories,
    );

    return status.values.every((isValid) => isValid);
  }
}
