import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/user_service.dart';
import '../../theme/color.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final UserService _userService = UserService.instance;
  bool _isGoogleUser = false;

  @override
  void initState() {
    super.initState();
    _checkAuthProvider();
  }

  void _checkAuthProvider() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _isGoogleUser = user.providerData.any(
          (info) => info.providerId == 'google.com',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Security & Privacy',
          style: TextStyle(color: SharedColors.white, fontWeight: FontWeight.bold),
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
            // Password & Authentication Section
            _buildSectionCard(
              title: 'Password & Authentication',
              icon: Icons.lock,
              iconColor: Colors.blue,
              children: [
                _buildSecurityOption(
                  icon: Icons.password_rounded,
                  title: 'Change Password',
                  subtitle: _isGoogleUser
                      ? 'Managed through Google account'
                      : 'Update your account password',
                  onTap: _isGoogleUser ? null : _changePassword,
                  trailing: _isGoogleUser
                      ? const Text(
                          'N/A',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
                const Divider(height: 1),
                _buildSecurityOption(
                  icon: Icons.fingerprint,
                  title: 'Touch ID',
                  subtitle: 'Use fingerprint to unlock',
                  onTap: null,
                  trailing: _buildComingSoonBadge(),
                ),
                const Divider(height: 1),
                _buildSecurityOption(
                  icon: Icons.face,
                  title: 'Face ID',
                  subtitle: 'Use face recognition to unlock',
                  onTap: null,
                  trailing: _buildComingSoonBadge(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Privacy Section
            _buildSectionCard(
              title: 'Privacy',
              icon: Icons.privacy_tip,
              iconColor: Colors.green,
              children: [
                _buildSecurityOption(
                  icon: Icons.visibility_off,
                  title: 'Private Account',
                  subtitle: 'Require approval for new followers',
                  onTap: null,
                  trailing: _buildComingSoonBadge(),
                ),
                const Divider(height: 1),
                _buildSecurityOption(
                  icon: Icons.block,
                  title: 'Blocked Users',
                  subtitle: 'Manage blocked accounts',
                  onTap: null,
                  trailing: _buildComingSoonBadge(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Data & Activity Section
            _buildSectionCard(
              title: 'Data & Activity',
              icon: Icons.storage,
              iconColor: Colors.orange,
              children: [
                _buildSecurityOption(
                  icon: Icons.download,
                  title: 'Download Your Data',
                  subtitle: 'Request a copy of your data',
                  onTap: null,
                  trailing: _buildComingSoonBadge(),
                ),
                const Divider(height: 1),
                _buildSecurityOption(
                  icon: Icons.history,
                  title: 'Login Activity',
                  subtitle: 'See where you\'re logged in',
                  onTap: null,
                  trailing: _buildComingSoonBadge(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Danger Zone
            _buildDangerZoneCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    return Container(
      decoration: BoxDecoration(
        color: SharedColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          _buildSecurityOption(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account and data',
            onTap: _deleteAccount,
            isDanger: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
    bool isDanger = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDanger
                  ? Colors.red
                  : onTap == null
                  ? AppColors.textSecondary
                  : AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDanger
                          ? Colors.red
                          : onTap == null
                          ? AppColors.textSecondary
                          : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDanger
                          ? Colors.red.shade300
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
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

  Widget _buildComingSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: const Text(
        'Coming Soon',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.orange,
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
              // Validate passwords
              if (newPasswordController.text.isEmpty ||
                  confirmPasswordController.text.isEmpty ||
                  currentPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

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
                // Reauthenticate
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPasswordController.text,
                );
                await user.reauthenticateWithCredential(credential);

                // Update password
                await user.updatePassword(newPasswordController.text);

                Navigator.pop(context, true);
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
              style: TextStyle(color: SharedColors.white),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            if (!_isGoogleUser) ...[
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
                if (_isGoogleUser) {
                  // Reauthenticate with Google
                  try {
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
                  } catch (e) {
                    // Ignore Pigeon casting errors - they're harmless
                    if (!e.toString().contains('PigeonUserDetails')) {
                      rethrow;
                    }
                    print('⚠️ Ignoring Pigeon error: $e');
                  }
                } else {
                  // Reauthenticate with email/password
                  if (currentUser.email == null) {
                    throw Exception('Email not found');
                  }
                  try {
                    final credential = EmailAuthProvider.credential(
                      email: currentUser.email!,
                      password: passwordController.text,
                    );
                    await currentUser.reauthenticateWithCredential(credential);
                  } catch (e) {
                    // Ignore Pigeon casting errors - they're harmless
                    if (!e.toString().contains('PigeonUserDetails')) {
                      rethrow;
                    }
                    print('⚠️ Ignoring Pigeon error: $e');
                  }
                }

                // Delete user data from Firestore (with cascade deletion)
                await _userService.deleteUser(currentUser.uid);

                // Delete Firebase Auth account
                try {
                  await currentUser.delete();
                } catch (e) {
                  // Ignore Pigeon casting errors - they're harmless
                  if (!e.toString().contains('PigeonUserDetails')) {
                    rethrow;
                  }
                  print('⚠️ Ignoring Pigeon error during account deletion: $e');
                }

                Navigator.pop(context, true);
              } catch (e) {
                print('❌ Delete account error: $e');
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
              style: TextStyle(color: SharedColors.white),
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
}
