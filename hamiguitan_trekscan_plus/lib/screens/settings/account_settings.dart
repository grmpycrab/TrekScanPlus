import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  bool _isInitializing = true;
  String? _successMessage;
  String? _errorMessage;
  int _nameChangeCooldownDays = 0;
  final UserService _userService = UserService.instance;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _birthDateController = TextEditingController();
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
            _selectedGender = userData['gender'];
          });
        }
        await _checkNameChangeCooldown();
      } catch (e) {
        if (kDebugMode) {
          print('Error loading user data: $e');
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

      // Always update all other information (phone, birthDate, gender)
      await _userService.updateUserInfo(
        uid: user.uid,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
        birthDate: birthDate.isNotEmpty ? birthDate : null,
        gender: gender,
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
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDanger
              ? Colors.red.withOpacity(0.05)
              : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDanger
                ? Colors.red.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDanger ? Colors.red : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDanger ? Colors.red : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if user is using Google Sign-In
    final isGoogleUser = user.providerData.any(
      (info) => info.providerId == 'google.com',
    );

    if (isGoogleUser) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Google Account'),
            ],
          ),
          content: const Text(
            'You are signed in with Google. Password management is handled through your Google account settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Change Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock_open),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock_reset),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New passwords do not match'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user?.email != null) {
                  // Reauthenticate user
                  final credential = EmailAuthProvider.credential(
                    email: user!.email!,
                    password: currentPasswordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);

                  // Update password
                  await user.updatePassword(newPasswordController.text);

                  Navigator.pop(context, true);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Change Password',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check authentication provider
    final isGoogleUser = user.providerData.any(
      (info) => info.providerId == 'google.com',
    );

    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone. All your data will be permanently deleted.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            if (!isGoogleUser) ...[
              const Text(
                'Enter your password to confirm:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
            ] else ...[
              const Text(
                'You will need to sign in again with Google to confirm this action.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) return;

                // Reauthenticate based on provider
                if (isGoogleUser) {
                  // Reauthenticate with Google
                  final GoogleSignIn googleSignIn = GoogleSignIn();
                  final GoogleSignInAccount? googleUser = await googleSignIn
                      .signIn();

                  if (googleUser == null) {
                    throw Exception('Google sign-in cancelled');
                  }

                  final GoogleSignInAuthentication googleAuth =
                      await googleUser.authentication;
                  final credential = GoogleAuthProvider.credential(
                    accessToken: googleAuth.accessToken,
                    idToken: googleAuth.idToken,
                  );
                  await currentUser.reauthenticateWithCredential(credential);
                } else {
                  // Reauthenticate with email/password
                  if (currentUser.email == null) {
                    throw Exception('Email not found');
                  }
                  final credential = EmailAuthProvider.credential(
                    email: currentUser.email!,
                    password: passwordController.text,
                  );
                  await currentUser.reauthenticateWithCredential(credential);
                }

                // Delete user data from Firestore (with cascade deletion)
                await _userService.deleteUser(currentUser.uid);

                // Delete Firebase Auth account
                await currentUser.delete();

                Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Navigate to login screen
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
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
                          color: AppColors.textPrimary,
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
                ],
              ),
            ),

            const SizedBox(height: 20),

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
                            Colors.white,
                          ),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Save Changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Security Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
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
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Security',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    icon: Icons.lock_outline,
                    iconColor: Colors.blue,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: _changePassword,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Danger Zone Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
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
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Danger Zone',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    icon: Icons.delete_forever,
                    iconColor: Colors.red,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account and data',
                    onTap: _deleteAccount,
                    isDanger: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
