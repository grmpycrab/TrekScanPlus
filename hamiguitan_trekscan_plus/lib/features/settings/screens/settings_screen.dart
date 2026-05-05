// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../core/widgets/app_dialogue_handler.dart';
import '../../../screens/settings/about_screen.dart';
import '../../../screens/settings/appearance_settings.dart';
import '../../../screens/settings/archived_bookings_screen.dart';
import '../../../screens/settings/badges_screen.dart';
import '../../../screens/settings/help_and_support_screen.dart';
import '../../../screens/settings/notification_settings.dart';
import '../../../screens/settings/account_settings.dart';
import '../../../screens/settings/security_screen.dart';
import '../viewmodels/settings_view_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsViewModel _vm;

  void _onVmChanged() {
    if (!mounted) return;
    if (_vm.error != null) {
      AppDialogueHandler.showError(
        context: context,
        title: 'Logout Failed',
        message: _vm.error!,
      ).then((_) => _vm.clearError());
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _vm = SettingsViewModel();
    _vm.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirmed = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      cancelText: 'Cancel',
      isDestructive: true,
    );
    if (confirmed == true) {
      await _vm.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Profile & Security ───────────────────────────────────
                  _SettingTile(
                    icon: Icons.person_outline,
                    title: 'Account',
                    subtitle: 'Personal information',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccountSettingsScreen(),
                      ),
                    ),
                  ),
                  _SettingTile(
                    icon: Icons.security_outlined,
                    title: 'Security',
                    subtitle: 'Password & sign-in options',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SecurityScreen()),
                    ),
                  ),
                  const _SectionDivider(),

                  // ── Preferences ───────────────────────────────────────────
                  _SettingTile(
                    icon: Icons.remove_red_eye_outlined,
                    title: 'Appearance',
                    subtitle: 'Themes & display',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppearanceSettingsScreen(),
                      ),
                    ),
                  ),
                  _SettingTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Message, app & email notifications',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    ),
                  ),
                  const _SectionDivider(),

                  // ── Activity ──────────────────────────────────────────────
                  _SettingTile(
                    icon: Icons.emoji_events_outlined,
                    title: 'Badges',
                    subtitle: 'View and track your achievements',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BadgesScreen()),
                    ),
                  ),
                  _SettingTile(
                    icon: Icons.archive_outlined,
                    title: 'Archived Bookings',
                    subtitle: 'View bookings you\'ve archived',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ArchivedBookingsScreen(),
                      ),
                    ),
                  ),
                  const _SectionDivider(),

                  // ── Information ───────────────────────────────────────────
                  _SettingTile(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'Help center & legal',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HelpAndSupportScreen(),
                      ),
                    ),
                  ),
                  _SettingTile(
                    icon: Icons.info_outline,
                    title: 'About',
                    subtitle: 'App information & version',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                  ),
                  const _SectionDivider(),

                  // ── Account actions ───────────────────────────────────────
                  _SettingTile(
                    icon: Icons.logout,
                    title: _vm.isLoggingOut ? 'Logging out…' : 'Logout',
                    subtitle: 'Sign out from your account',
                    onTap: _vm.isLoggingOut ? null : _handleLogout,
                  ),

                  // ── Hidden: App Tutorial ──────────────────────────────────
                  // Removed from production UI. Kept here for easy reintroduction.
                  // To restore: uncomment the block below and re-add OnboardingService import.
                  //
                  // _SettingTile(
                  //   icon: Icons.play_circle_outline,
                  //   title: 'App Tutorial',
                  //   subtitle: 'Replay the welcome tutorial',
                  //   onTap: () async {
                  //     final user = FirebaseAuth.instance.currentUser;
                  //     if (user != null) {
                  //       await OnboardingService.showOnboarding(context, user.uid);
                  //     }
                  //   },
                  //   // Long-press resets tutorial (dev helper):
                  //   // onLongPress: () => OnboardingService.resetOnboarding(),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      color: colors.primary,
      child: Row(
        children: [
          const SizedBox(width: 56),
          Expanded(
            child: Center(
              child: Text(
                'Settings',
                style: TextStyle(
                  color: SharedColors.white, // Always white on primary header
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }
}

// ── Extracted reusable tile ────────────────────────────────────────────────────

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors.shadowLight,
              blurRadius: 10,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colors.primary),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          trailing: onTap != null
              ? Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: colors.textSecondary,
                )
              : null,
        ),
      ),
    );
  }
}

// ── Visual group divider ───────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 8);
  }
}
