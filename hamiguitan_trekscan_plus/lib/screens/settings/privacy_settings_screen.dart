// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/user_service.dart';
import '../../services/privacy_data_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _exporting = false;
  bool _deleting = false;

  // ── URL launcher ────────────────────────────────────────────────────────────

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  // ── Data export ─────────────────────────────────────────────────────────────

  Future<void> _handleExport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _exporting = true);
    try {
      await PrivacyDataService.exportAndShare(user.uid);
    } catch (e) {
      AppLogger.e('Data export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Account deletion ────────────────────────────────────────────────────────

  Future<void> _handleDeleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isGoogle =
        user.providerData.any((p) => p.providerId == 'google.com');
    final passwordCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DeleteConfirmDialog(
        isGoogleUser: isGoogle,
        passwordController: passwordCtrl,
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      // Re-authenticate before deletion (required by Firebase for sensitive ops).
      if (isGoogle) {
        try {
          final gs = GoogleSignIn();
          final gu = await gs.signIn();
          if (gu == null) throw Exception('Google sign-in cancelled');
          final ga = await gu.authentication;
          final cred = GoogleAuthProvider.credential(
            accessToken: ga.accessToken,
            idToken: ga.idToken,
          );
          await user.reauthenticateWithCredential(cred);
        } catch (e) {
          if (!e.toString().contains('PigeonUserDetails')) rethrow;
          AppLogger.i('Ignoring Pigeon wrapper error during Google reauth: $e');
        }
      } else {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: passwordCtrl.text,
        );
        await user.reauthenticateWithCredential(cred);
      }

      // Cascade-delete all Firestore data for this user.
      await UserService.instance.deleteUser(user.uid);

      // Delete the Firebase Auth account last.
      try {
        await user.delete();
      } catch (e) {
        if (!e.toString().contains('PigeonUserDetails')) rethrow;
        AppLogger.i('Ignoring Pigeon wrapper error during auth delete: $e');
      }

      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      AppLogger.e('Account deletion failed: $e');
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deletion failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  bottom: BorderSide(color: colors.border, width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: colors.text,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 36, minHeight: 36),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Privacy & Data',
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                children: [
                  // ── Your Data ──────────────────────────────────────────────
                  _SectionLabel('Your Data'),
                  _SettingGroup(children: [
                    _ActionRow(
                      icon: Icons.download_outlined,
                      label: 'Export Your Data',
                      subtitle:
                          'Download a JSON copy of all your personal data',
                      loading: _exporting,
                      onTap: _exporting ? null : _handleExport,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Includes your profile, visited stations, bookings, achievements, posts, and all other data associated with your account.',
                      style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Legal ──────────────────────────────────────────────────
                  _SectionLabel('Legal'),
                  _SettingGroup(children: [
                    _ActionRow(
                      icon: Icons.description_outlined,
                      label: 'Terms of Service',
                      subtitle: 'Read our terms and conditions',
                      onTap: () => _launchUrl(
                          'https://hamiguitan-trekscan.app/terms'),
                    ),
                    _ActionRow(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy Policy',
                      subtitle: 'How we collect and use your data',
                      onTap: () => _launchUrl(
                          'https://hamiguitan-trekscan.app/privacy'),
                    ),
                  ]),
                  const SizedBox(height: 28),

                  // ── Danger Zone ────────────────────────────────────────────
                  _SectionLabel('Danger Zone'),
                  _SettingGroup(children: [
                    _ActionRow(
                      icon: Icons.delete_forever_rounded,
                      label: _deleting ? 'Deleting account…' : 'Delete Account',
                      subtitle:
                          'Permanently delete your account and all data',
                      loading: _deleting,
                      isDestructive: true,
                      onTap: _deleting ? null : _handleDeleteAccount,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'This action is irreversible. All your profile data, posts, bookings, achievements, and account credentials will be permanently removed from our servers.',
                      style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Delete confirmation dialog ────────────────────────────────────────────────

class _DeleteConfirmDialog extends StatelessWidget {
  final bool isGoogleUser;
  final TextEditingController passwordController;

  const _DeleteConfirmDialog({
    required this.isGoogleUser,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 10),
          Text('Delete Account'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: const Text(
                'This will permanently delete your account, all posts, bookings, achievements, and visited-station records. This cannot be undone.',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            if (!isGoogleUser) ...[
              const Text('Enter your password to confirm:',
                  style: TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ] else
              const Text(
                'You will be prompted to sign in with Google to confirm your identity.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete Account'),
        ),
      ],
    );
  }
}

// ── Layout helpers (mirrors settings_screen.dart style) ──────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: colors.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Divider(
          height: 1,
          thickness: 0.6,
          indent: 65,
          color: colors.borderLight,
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: rows),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool loading;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
    this.isDestructive = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final iconColor = isDestructive
        ? Colors.red.shade400
        : (isDark ? colors.iconSubtle : colors.primary);
    final iconBg = isDestructive
        ? Colors.red.withOpacity(isDark ? 0.15 : 0.08)
        : (isDark
            ? Colors.white.withOpacity(0.07)
            : colors.primary.withOpacity(0.08));
    final labelColor =
        isDestructive ? Colors.red.shade400 : colors.text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onTap != null && !loading)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDestructive
                      ? Colors.red.shade300
                      : colors.iconMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
