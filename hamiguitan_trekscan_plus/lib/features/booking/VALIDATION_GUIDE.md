# Booking Validation Guide

This document describes the comprehensive validation system for the booking feature.

## Overview

The `BookingValidationService` provides centralized, reusable validation for all booking inputs. It eliminates false/invalid data by enforcing strict format, length, and business logic rules.

## Validation Service Location

```
lib/features/booking/services/booking_validation_service.dart
```

## Available Validators

### Member Data Validators

#### 1. **Name Validation** (`validateName`)

- **Accepts**: Letters, spaces, hyphens, apostrophes
- **Rejects**: Numbers, special characters (except listed above)
- **Rules**:
  - Minimum 2 characters
  - Maximum 50 characters
  - No multiple consecutive spaces
- **Example**:

  ```dart
  BookingValidationService.validateName('John', 'First name')
  // Returns: null (valid)

  BookingValidationService.validateName('123', 'First name')
  // Returns: "First name can only contain letters, spaces, hyphens, and apostrophes"
  ```

#### 2. **Phone Number Validation** (`validatePhoneNumber`)

- **Format**: 7-15 digits with optional +country code
- **Rules**:
  - Allows only digits and optional + prefix
  - Spaces, hyphens, parentheses are stripped before validation
  - Minimum 10 digits total (including country code)
- **Example**:

  ```dart
  BookingValidationService.validatePhoneNumber('+63 905 123 4567')
  // Returns: null (valid)

  BookingValidationService.validatePhoneNumber('123')
  // Returns: "Contact number is too short..."
  ```

#### 3. **Birth Date Validation** (`validateBirthDate`)

- **Format**: YYYY-MM-DD (required)
- **Rules**:
  - Must be a valid date
  - Cannot be in the future
  - Age must be between 5 and 130 years
- **Example**:

  ```dart
  BookingValidationService.validateBirthDate('2000-05-15')
  // Returns: null (valid)

  BookingValidationService.validateBirthDate('2025-12-25')
  // Returns: "Birth date cannot be in the future"
  ```

#### 4. **Nationality Validation** (`validateNationality`)

- **Accepts**: Letters, spaces, hyphens
- **Rules**:
  - Minimum 2 characters
  - Maximum 50 characters
- **Example**:
  ```dart
  BookingValidationService.validateNationality('Filipino')
  // Returns: null (valid)
  ```

#### 5. **Address Validation** (`validateAddress`)

- **Rules**:
  - Minimum 5 characters
  - Maximum 200 characters
  - Maximum 3 special characters allowed
- **Example**:
  ```dart
  BookingValidationService.validateAddress('123 Main St, City')
  // Returns: null (valid)
  ```

#### 6. **Gender Validation** (`validateGender`)

- **Valid Values**: 'male', 'female', 'other'
- **Case-insensitive**

#### 7. **Category Validation** (`validateCategory`)

- **Validates Against**: Provided list of valid categories
- **Example**:
  ```dart
  final validCategories = ['student', 'senior_citizen', 'adult'];
  BookingValidationService.validateCategory('student', validCategories)
  // Returns: null (valid)
  ```

### Booking Data Validators

#### 8. **Trek Date Validation** (`validateTrekDate`)

- **Rules**:
  - Must be at least 1 day in the future
  - Cannot be more than 2 years in the future
- **Example**:
  ```dart
  final futureDate = DateTime.now().add(Duration(days: 5));
  BookingValidationService.validateTrekDate(futureDate)
  // Returns: null (valid)
  ```

#### 9. **Hometown Validation** (`validateHometown`)

- **Accepts**: Letters, spaces, hyphens, commas
- **Rules**:
  - Minimum 2 characters
  - Maximum 100 characters
- **Example**:
  ```dart
  BookingValidationService.validateHometown('Davao City, Philippines')
  // Returns: null (valid)
  ```

#### 10. **Affiliation Validation** (`validateAffiliation`)

- **Rules**:
  - Minimum 2 characters
  - Maximum 150 characters

#### 11. **Trek Type Validation** (`validateTrekType`)

- **Validates Against**: Provided list of valid trek types
- **Example**:
  ```dart
  final validTypes = ['day_trek', 'overnight_trek'];
  BookingValidationService.validateTrekType('day_trek', validTypes)
  // Returns: null (valid)
  ```

#### 12. **Member Count Validation**

- `validateMemberCount(count, minMembers)` - Checks minimum members
- `validateMaxMembers(count, maxMembers)` - Checks maximum members

#### 13. **Date Availability Validation** (`validateDateAvailability`)

- **Checks**:
  - If date is closed
  - If date is a buffer/trek-down day
  - If slots are available
- **Example**:
  ```dart
  final availabilityInfo = await dateService.checkDateAvailability(date, members.length);
  String? error = BookingValidationService.validateDateAvailability(availabilityInfo);
  ```

## Utility Functions

### Age Calculation

```dart
int? age = BookingValidationService.calculateAge('2000-05-15');
// Returns: 24 (or null if invalid)
```

### Phone Number Formatting

```dart
String formatted = BookingValidationService.formatPhoneNumber('+639051234567');
// Returns: "+639051234567" (international format preserved)
```

### Member Validation Status

Get validation status for all member fields at once:

```dart
Map<String, bool> status = BookingValidationService.getMemberValidationStatus(
  firstName: 'John',
  lastName: 'Doe',
  gender: 'male',
  birthDate: '2000-05-15',
  phoneNumber: '+63 905 123 4567',
  nationality: 'Filipino',
  address: '123 Main St',
  category: 'student',
  validCategories: categories,
);
// Returns: {'firstName': true, 'lastName': true, ...}
```

### Check if Member is Fully Valid

```dart
bool isValid = BookingValidationService.isValidMember(
  firstName: 'John',
  lastName: 'Doe',
  // ... other fields
);
```

## Integration Examples

### In TextFormField

```dart
TextFormField(
  controller: firstNameController,
  validator: (value) => BookingValidationService.validateName(value, 'First name'),
)
```

### In DropdownButtonFormField

```dart
DropdownButtonFormField<String>(
  value: selectedGender,
  validator: (value) => BookingValidationService.validateGender(value),
)
```

### For Custom Validation Logic

```dart
String? trekDateError = BookingValidationService.validateTrekDate(selectedDate);
if (trekDateError != null) {
  showError(trekDateError);
  return;
}
```

## Validation Error Messages

All validators return:

- **`null`** if validation passes
- **`String`** containing error message if validation fails

Examples of error messages:

```
"First name is required"
"First name must be at least 2 characters"
"First name can only contain letters, spaces, hyphens, and apostrophes"
"Contact number is too short (minimum 10 digits with country code)"
"Birth date cannot be in the future"
"Trek date must be in the future (minimum 1 day from today)"
"Trek date is closed: Maintenance day"
"Cannot book on this date - trek down day (conflict with 2026-04-20)"
```

## Supported Validation Types

✅ **Format Validation**

- Date formats (YYYY-MM-DD)
- Phone number patterns
- Character sets

✅ **Length Validation**

- Minimum and maximum character counts
- Prevents empty inputs

✅ **Character Validation**

- No numbers in names
- No excessive special characters
- Allowed character sets per field

✅ **Business Logic Validation**

- Age checks (5-130 years)
- Future date validation
- Slot availability
- Buffer period checks
- Trek date constraints

## Adding New Validations

To add a new validator:

```dart
static String? validateNewField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'New Field is required';
  }

  value = value.trim();

  // Add your validation logic
  if (!isValid(value)) {
    return 'Error message';
  }

  return null;
}
```

Then integrate it into forms:

```dart
validator: (value) => BookingValidationService.validateNewField(value)
```

## Best Practices

1. **Always use the validation service** for consistency
2. **Validate on form submission**, not just real-time
3. **Show specific error messages** to help users fix issues
4. **Use debouncing** for real-time validation to avoid lag
5. **Test edge cases** (empty strings, very long strings, special characters)
6. **Combine with visual feedback** (error colors, icons, messages)

## Testing

When testing validation, cover:

- Empty/null inputs
- Minimum and maximum lengths
- Special characters and edge cases
- Boundary dates (very old, very young, future)
- Invalid formats (wrong date format, phone numbers)
- International phone numbers

Example test:

```dart
test('validates names correctly', () {
  expect(BookingValidationService.validateName('John', 'First name'), isNull);
  expect(BookingValidationService.validateName('123', 'First name'), isNotNull);
  expect(BookingValidationService.validateName('a', 'First name'), isNotNull);
});
```
