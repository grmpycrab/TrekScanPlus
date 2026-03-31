import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../theme/color.dart';
import '../../utils/app_logger.dart';

class AccountSettingsScreen extends StatefulWidget {
  final UserModel? initialUserData;

  const AccountSettingsScreen({super.key, this.initialUserData});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _birthDateController;
  late TextEditingController _nationalityController;
  late TextEditingController _homeAddressController;
  String? _selectedGender;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _successMessage;
  String? _errorMessage;
  String? _phoneValidationError;
  int _nameChangeCooldownDays = 0;
  final UserService _userService = UserService.instance;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _birthDateController = TextEditingController();
    _nationalityController = TextEditingController();
    _homeAddressController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userData = await _userService.getUserOnce(user.uid);
        if (userData != null && mounted) {
          setState(() {
            _firstNameController.text = userData['firstName'] ?? '';
            _lastNameController.text = userData['lastName'] ?? '';
            _phoneController.text = userData['phoneNumber'] ?? '';
            _birthDateController.text = userData['birthDate'] ?? '';
            _nationalityController.text = userData['nationality'] ?? '';
            _homeAddressController.text = userData['homeAddress'] ?? '';
            _selectedGender = userData['gender'];
          });
        }
        await _checkNameChangeCooldown();
      } catch (e) {
        if (kDebugMode) {
          AppLogger.i('Error loading user data: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _nationalityController.dispose();
    _homeAddressController.dispose();
    super.dispose();
  }

  Future<void> _checkNameChangeCooldown() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final daysRemaining = await _userService
            .getNameChangeCooldownDaysRemaining(user.uid);
        setState(() {
          _nameChangeCooldownDays = daysRemaining;
        });
      } catch (e) {
        if (kDebugMode) {
          AppLogger.i('Error checking cooldown: $e');
        }
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  String? _validatePhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) {
      return null; // Phone number is optional
    }

    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < 7) {
      return 'Phone number is too short';
    }

    if (digitsOnly.length > 13) {
      return 'Phone number is too long';
    }

    if (digitsOnly.length == 11) {
      if (!digitsOnly.startsWith('09')) {
        return 'Mobile number must start with 09';
      }
    } else if (digitsOnly.length == 13) {
      if (!digitsOnly.startsWith('639')) {
        return 'International format must start with +639';
      }
    } else if (digitsOnly.length >= 7 && digitsOnly.length <= 10) {
      // Landline - accept various formats
      return null;
    } else {
      return 'Invalid phone number format';
    }

    return null;
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final phoneNumber = _phoneController.text.trim();
      final birthDate = _birthDateController.text.trim();
      final nationality = _nationalityController.text.trim();
      final homeAddress = _homeAddressController.text.trim();
      final gender = _selectedGender;

      if (firstName.isEmpty || lastName.isEmpty) {
        setState(() {
          _errorMessage = 'First name and last name are required';
        });
        return;
      }

      // Validate phone number if provided
      if (phoneNumber.isNotEmpty) {
        final phoneError = _validatePhoneNumber(phoneNumber);
        if (phoneError != null) {
          setState(() {
            _errorMessage = phoneError;
            _phoneValidationError = phoneError;
          });
          return;
        }
      }

      // Get current data to check if name changed
      final currentData = await _userService.getUserOnce(user.uid);
      final currentFirstName = currentData?['firstName'] ?? '';
      final currentLastName = currentData?['lastName'] ?? '';

      // Check if name has changed
      final nameChanged =
          firstName != currentFirstName || lastName != currentLastName;

      if (nameChanged) {
        // Check cooldown for name change
        if (_nameChangeCooldownDays > 0) {
          setState(() {
            _errorMessage =
                'You can change your name in $_nameChangeCooldownDays days';
          });
          return;
        }

        // Update name with cooldown
        final success = await _userService.updateUserName(
          uid: user.uid,
          firstName: firstName,
          lastName: lastName,
        );

        if (!success) {
          setState(() {
            _errorMessage = 'Cannot change name. Please try again later.';
          });
          return;
        }
      }

      // Always update all other information (phone, birthDate, gender, nationality, homeAddress)
      await _userService.updateUserInfo(
        uid: user.uid,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
        birthDate: birthDate.isNotEmpty ? birthDate : null,
        gender: gender,
        nationality: nationality.isNotEmpty ? nationality : null,
        homeAddress: homeAddress.isNotEmpty ? homeAddress : null,
      );

      setState(() {
        _successMessage = 'Profile updated successfully!';
      });

      // Check cooldown again after update
      await _checkNameChangeCooldown();

      // Show success message for 2 seconds then pop
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving changes: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_isLoading,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary),
          ),
          filled: true,
          fillColor: Color(0xFFFAFAFA),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: const Text(
            'Account Settings',
            style: TextStyle(
              color: SharedColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: SharedColors.white),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Account Settings',
          style: TextStyle(
            color: SharedColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SharedColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  border: Border.all(color: AppColors.red200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // Success Message
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.green50,
                  border: Border.all(color: AppColors.green200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: AppColors.green700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(color: AppColors.green700),
                      ),
                    ),
                  ],
                ),
              ),

            // Name Change Cooldown Warning
            if (_nameChangeCooldownDays > 0)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Color(0xFFFFE0B2),
                  border: Border.all(color: Color(0xFFFFCC80)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFF57C00)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can change your name in $_nameChangeCooldownDays days',
                        style: TextStyle(color: Color(0xFFF57C00)),
                      ),
                    ),
                  ],
                ),
              ),

            // Personal Information Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SharedColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 10,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person_outline,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // First Name
                  _buildTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    hint: 'Enter your first name',
                  ),

                  // Last Name
                  _buildTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    hint: 'Enter your last name',
                  ),

                  // Phone Number
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: _phoneController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'e.g., 09123456789 or (02)1234567',
                        helperText: _phoneValidationError == null
                            ? 'Philippine mobile or landline number'
                            : null,
                        errorText: _phoneValidationError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _phoneValidationError != null
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _phoneValidationError != null
                                ? Colors.red
                                : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _phoneValidationError != null
                                ? Colors.red
                                : AppColors.primary,
                          ),
                        ),
                        filled: true,
                        fillColor: Color(0xFFFAFAFA),
                        prefixIcon: Icon(
                          Icons.phone,
                          color: _phoneValidationError != null
                              ? Colors.red
                              : null,
                        ),
                      ),
                      onChanged: (value) {
                        // Real-time validation
                        setState(() {
                          _phoneValidationError = _validatePhoneNumber(value);
                        });

                        // Clear general error message when user starts typing
                        if (_errorMessage != null &&
                            _errorMessage!.contains('phone')) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                      },
                    ),
                  ),

                  // Birth Date
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: _birthDateController,
                      enabled: !_isLoading,
                      readOnly: true,
                      onTap: _selectDate,
                      decoration: InputDecoration(
                        labelText: 'Birth Date',
                        hintText: 'Select your birth date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                        filled: true,
                        fillColor: Color(0xFFFAFAFA),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                    ),
                  ),

                  // Gender
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        hintText: 'Select your gender',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                        filled: true,
                        fillColor: Color(0xFFFAFAFA),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _selectedGender = value;
                              });
                            },
                    ),
                  ),

                  // Nationality
                  _buildTextField(
                    controller: _nationalityController,
                    label: 'Nationality',
                    hint: 'Enter your nationality',
                  ),

                  // Home Address
                  _buildTextField(
                    controller: _homeAddressController,
                    label: 'Home Address',
                    hint: 'Enter your home address',
                    maxLines: 2,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            SharedColors.white,
                          ),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, color: SharedColors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Save Changes',
                            style: TextStyle(
                              color: SharedColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
