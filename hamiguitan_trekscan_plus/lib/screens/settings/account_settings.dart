// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../core/services/user_service.dart';
import '../../theme/app_theme.dart';
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
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: !_isLoading,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(fontSize: 14, color: colors.text),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(fontSize: 13, color: colors.textSecondary),
          hintStyle: TextStyle(fontSize: 13, color: colors.textTertiary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.border, width: 0.8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.border, width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.borderLight, width: 0.6),
          ),
          filled: true,
          fillColor: colors.inputFill,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, colors),
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, colors),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      _StatusBanner(
                        icon: Icons.error_outline_rounded,
                        message: _errorMessage!,
                        bgColor: Colors.red.withValues(alpha: 0.08),
                        borderColor: Colors.red.withValues(alpha: 0.25),
                        textColor: Colors.red.shade700,
                      ),
                    if (_successMessage != null)
                      _StatusBanner(
                        icon: Icons.check_circle_outline_rounded,
                        message: _successMessage!,
                        bgColor: colors.green50,
                        borderColor: colors.green200,
                        textColor: colors.green700,
                      ),
                    if (_nameChangeCooldownDays > 0)
                      _StatusBanner(
                        icon: Icons.schedule_rounded,
                        message:
                            'You can change your name in $_nameChangeCooldownDays days',
                        bgColor: Colors.orange.withValues(alpha: 0.08),
                        borderColor: Colors.orange.withValues(alpha: 0.3),
                        textColor: Colors.orange.shade800,
                      ),

                    // ── Personal Information card ────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    color: colors.primary,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Text(
                                  'Personal Information',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.6,
                            color: colors.borderLight,
                          ),
                          // Form fields
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  hint: 'Enter your first name',
                                ),
                                _buildTextField(
                                  controller: _lastNameController,
                                  label: 'Last Name',
                                  hint: 'Enter your last name',
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: TextFormField(
                                    controller: _phoneController,
                                    enabled: !_isLoading,
                                    keyboardType: TextInputType.phone,
                                    style: TextStyle(
                                        fontSize: 14, color: colors.text),
                                    decoration: InputDecoration(
                                      labelText: 'Phone Number',
                                      hintText: 'e.g., 09123456789',
                                      labelStyle: TextStyle(
                                          fontSize: 13,
                                          color: colors.textSecondary),
                                      hintStyle: TextStyle(
                                          fontSize: 13,
                                          color: colors.textTertiary),
                                      helperText: _phoneValidationError == null
                                          ? 'Philippine mobile or landline number'
                                          : null,
                                      errorText: _phoneValidationError,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 13),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: colors.border, width: 0.8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: _phoneValidationError != null
                                              ? Colors.red
                                              : colors.border,
                                          width: 0.8,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: _phoneValidationError != null
                                              ? Colors.red
                                              : colors.primary,
                                          width: 1.5,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: colors.inputFill,
                                      prefixIcon: Icon(
                                        Icons.phone_outlined,
                                        size: 18,
                                        color: _phoneValidationError != null
                                            ? Colors.red
                                            : colors.iconMuted,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _phoneValidationError =
                                            _validatePhoneNumber(value);
                                      });
                                      if (_errorMessage != null &&
                                          _errorMessage!.contains('phone')) {
                                        setState(() => _errorMessage = null);
                                      }
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: TextFormField(
                                    controller: _birthDateController,
                                    enabled: !_isLoading,
                                    readOnly: true,
                                    onTap: _selectDate,
                                    style: TextStyle(
                                        fontSize: 14, color: colors.text),
                                    decoration: InputDecoration(
                                      labelText: 'Birth Date',
                                      hintText: 'Select your birth date',
                                      labelStyle: TextStyle(
                                          fontSize: 13,
                                          color: colors.textSecondary),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 13),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: colors.border, width: 0.8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: colors.border, width: 0.8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: colors.primary, width: 1.5),
                                      ),
                                      filled: true,
                                      fillColor: colors.inputFill,
                                      suffixIcon: Icon(
                                        Icons.calendar_today_outlined,
                                        size: 18,
                                        color: colors.iconMuted,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedGender,
                                    style: TextStyle(
                                        fontSize: 14, color: colors.text),
                                    decoration: InputDecoration(
                                      labelText: 'Gender',
                                      hintText: 'Select your gender',
                                      labelStyle: TextStyle(
                                          fontSize: 13,
                                          color: colors.textSecondary),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 13),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: colors.border, width: 0.8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: colors.border, width: 0.8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: colors.primary, width: 1.5),
                                      ),
                                      filled: true,
                                      fillColor: colors.inputFill,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'Male', child: Text('Male')),
                                      DropdownMenuItem(
                                          value: 'Female',
                                          child: Text('Female')),
                                      DropdownMenuItem(
                                          value: 'Other', child: Text('Other')),
                                    ],
                                    onChanged: _isLoading
                                        ? null
                                        : (value) => setState(
                                            () => _selectedGender = value),
                                  ),
                                ),
                                _buildTextField(
                                  controller: _nationalityController,
                                  label: 'Nationality',
                                  hint: 'Enter your nationality',
                                ),
                                _buildTextField(
                                  controller: _homeAddressController,
                                  label: 'Home Address',
                                  hint: 'Enter your home address',
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Save Button ───────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_outlined,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppTheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.border, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: colors.text,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Account Settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.message,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
  });

  final IconData icon;
  final String message;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
