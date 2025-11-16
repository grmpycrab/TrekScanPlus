import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../theme/color.dart';

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
  String? _selectedGender;
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;
  int _nameChangeCooldownDays = 0;
  final UserService _userService = UserService.instance;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.initialUserData?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.initialUserData?.lastName ?? '',
    );
    _phoneController = TextEditingController();
    _birthDateController = TextEditingController(
      text: widget.initialUserData?.birthDate ?? '',
    );
    _selectedGender = widget.initialUserData?.gender;
    _checkNameChangeCooldown();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
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
          print('Error checking cooldown: $e');
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
      final gender = _selectedGender;

      if (firstName.isEmpty || lastName.isEmpty) {
        setState(() {
          _errorMessage = 'First name and last name are required';
        });
        return;
      }

      // Check if name has changed
      final nameChanged =
          firstName != widget.initialUserData?.firstName ||
          lastName != widget.initialUserData?.lastName;

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
      } else {
        // Update other information
        await _userService.updateUserInfo(
          uid: user.uid,
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
          birthDate: birthDate.isNotEmpty ? birthDate : null,
          gender: gender,
        );
      }

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
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF252B30),
        title: const Text(
          'Account Settings',
          style: TextStyle(color: Colors.white),
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
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
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
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(color: Colors.green.shade700),
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
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can change your name in $_nameChangeCooldownDays days',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // Personal Information Section
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

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
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: 'Enter your phone number',
              keyboardType: TextInputType.phone,
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
                  fillColor: Colors.grey[50],
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
                  fillColor: Colors.grey[50],
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
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

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: AppColors.buttonText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
