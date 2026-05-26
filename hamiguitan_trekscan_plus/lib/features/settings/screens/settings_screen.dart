// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../theme/app_theme.dart';
import '../../../core/widgets/app_dialogue_handler.dart';
import '../../../core/services/user_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/permission_service.dart';
import '../../../utils/app_logger.dart';
import '../../../screens/settings/about_screen.dart';
import '../../../screens/settings/archived_bookings_screen.dart';
import '../../../screens/settings/badges_screen.dart';
import '../../../screens/settings/help_and_support_screen.dart';
import '../../../services/badge_claim_service.dart';
import '../../../services/badge_sync_engine.dart';
import '../../../screens/settings/account_settings.dart';
import '../viewmodels/settings_view_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// Expandable inline: Security · Appearance · Notifications
// Navigates to screen: Account · Badges · Archived Bookings · Help & Support · About
// ═══════════════════════════════════════════════════════════════════════════════

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
    if (confirmed == true) await _vm.logout();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colors),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                children: [
                  // ── Account ──────────────────────────────────────────────
                  const _SectionLabel('Account'),
                  _SettingGroup(
                    children: [
                      _SettingItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Account',
                        subtitle: 'Personal information',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountSettingsScreen(),
                          ),
                        ),
                      ),
                      _ExpandableSection(
                        icon: Icons.shield_outlined,
                        label: 'Security',
                        subtitle: 'Password & sign-in options',
                        content: const _SecurityPanel(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Preferences ───────────────────────────────────────────
                  const _SectionLabel('Preferences'),
                  _SettingGroup(
                    children: [
                      _ExpandableSection(
                        icon: Icons.palette_outlined,
                        label: 'Appearance',
                        subtitle: 'Themes & display',
                        content: const _AppearancePanel(),
                      ),
                      _ExpandableSection(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        subtitle: 'Message, app & email',
                        content: const _NotificationsPanel(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Activity ──────────────────────────────────────────────
                  const _SectionLabel('Activity'),
                  _SettingGroup(
                    children: [
                      _SettingItem(
                        icon: Icons.emoji_events_outlined,
                        label: 'Badges',
                        subtitle: 'View and track achievements',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BadgesScreen()),
                        ),
                      ),
                      _SettingItem(
                        icon: Icons.inventory_2_outlined,
                        label: 'Archived Bookings',
                        subtitle: 'View archived bookings',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ArchivedBookingsScreen(),
                          ),
                        ),
                      ),
                      const _SyncItem(),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Information ───────────────────────────────────────────
                  const _SectionLabel('Information'),
                  _SettingGroup(
                    children: [
                      _SettingItem(
                        icon: Icons.help_outline_rounded,
                        label: 'Help & Support',
                        subtitle: 'Help center & legal',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HelpAndSupportScreen(),
                          ),
                        ),
                      ),
                      _SettingItem(
                        icon: Icons.info_outline_rounded,
                        label: 'About',
                        subtitle: 'App information & version',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Logout ────────────────────────────────────────────────
                  _SettingGroup(
                    children: [
                      _SettingItem(
                        icon: Icons.logout_rounded,
                        label: _vm.isLoggingOut ? 'Logging out…' : 'Logout',
                        subtitle: 'Sign out from your account',
                        onTap: _vm.isLoggingOut ? null : _handleLogout,
                        isDestructive: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppTheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.border, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(
            child: Center(
              child: Text(
                'Settings',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SYNC ITEM
// ═══════════════════════════════════════════════════════════════════════════════

class _SyncItem extends StatefulWidget {
  const _SyncItem();

  @override
  State<_SyncItem> createState() => _SyncItemState();
}

class _SyncItemState extends State<_SyncItem> {
  bool _syncing = false;
  int _pendingCount = 0;
  bool _justSynced = false;

  @override
  void initState() {
    super.initState();
    _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    final staged = await BadgeClaimService.getStagedClaims();
    if (mounted) setState(() => _pendingCount = staged.length);
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _justSynced = false;
    });
    // triggerSync() is best-effort and never throws.
    await BadgeSyncEngine.instance.triggerSync();
    await _refreshPendingCount();
    if (!mounted) return;
    setState(() => _justSynced = true);
    final msg = _pendingCount == 0
        ? 'All items synced'
        : '$_pendingCount item${_pendingCount == 1 ? '' : 's'} still pending — will retry automatically';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _justSynced = false;
        _syncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final iconColor = isDark ? colors.iconSubtle : colors.primary;
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : colors.primary.withValues(alpha: 0.08);

    final String subtitle = _syncing
        ? 'Syncing…'
        : _justSynced
            ? 'All synced'
            : _pendingCount > 0
                ? '$_pendingCount item${_pendingCount == 1 ? '' : 's'} pending'
                : 'Everything is up to date';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _syncing ? null : _sync,
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
                child: _syncing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      )
                    : Icon(
                        _justSynced
                            ? Icons.check_circle_outline_rounded
                            : Icons.sync_rounded,
                        color: _justSynced ? Colors.green : iconColor,
                        size: 18,
                      ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync Data',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _pendingCount > 0 && !_syncing && !_justSynced
                            ? colors.primary
                            : colors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_pendingCount > 0 && !_syncing && !_justSynced)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_pendingCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED LAYOUT WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

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
            color: Colors.black.withValues(alpha: 0.05),
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

// Expandable row — chevron rotates, content slides in with AnimatedSize.
class _ExpandableSection extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Widget content;

  const _ExpandableSection({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.content,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final iconColor = isDark ? colors.iconSubtle : colors.primary;
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : colors.primary.withValues(alpha: 0.08);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
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
                    child: Icon(widget.icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.iconMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          child: _isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(
                      height: 1,
                      thickness: 0.6,
                      color: colors.borderLight,
                    ),
                    ColoredBox(
                      color: colors.surfaceVariant,
                      child: widget.content,
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// Navigation / destructive row (chevron always points right, no rotation).
class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _SettingItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final iconColor = isDestructive
        ? Colors.red.shade400
        : (isDark ? colors.iconSubtle : colors.primary);
    final iconBg = isDestructive
        ? Colors.red.withValues(alpha: isDark ? 0.15 : 0.08)
        : (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : colors.primary.withValues(alpha: 0.08));
    final labelColor = isDestructive ? Colors.red.shade400 : colors.text;

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
                child: Icon(icon, color: iconColor, size: 18),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDestructive ? Colors.red.shade300 : colors.iconMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECURITY PANEL
// ═══════════════════════════════════════════════════════════════════════════════

class _SecurityPanel extends StatefulWidget {
  const _SecurityPanel();

  @override
  State<_SecurityPanel> createState() => _SecurityPanelState();
}

class _SecurityPanelState extends State<_SecurityPanel> {
  bool _isGoogleUser = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _isGoogleUser =
          user.providerData.any((p) => p.providerId == 'google.com');
    }
  }

  Widget _comingSoon() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'Soon',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.orange,
          ),
        ),
      );

  Divider _div(AppTheme colors) =>
      Divider(height: 1, thickness: 0.6, indent: 47, color: colors.borderLight);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        _PanelRow(
          icon: Icons.password_rounded,
          label: 'Change Password',
          subtitle:
              _isGoogleUser ? 'Managed by Google' : 'Update your password',
          onTap: _isGoogleUser ? null : () => _changePassword(context),
          trailing: _isGoogleUser
              ? Text(
                  'N/A',
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: 12),
                )
              : null,
        ),
        _div(colors),
        _PanelRow(
          icon: Icons.fingerprint,
          label: 'Touch ID',
          subtitle: 'Use fingerprint to unlock',
          trailing: _comingSoon(),
        ),
        _div(colors),
        _PanelRow(
          icon: Icons.face_rounded,
          label: 'Face ID',
          subtitle: 'Use face recognition',
          trailing: _comingSoon(),
        ),
        _div(colors),
        _PanelRow(
          icon: Icons.visibility_off_outlined,
          label: 'Private Account',
          subtitle: 'Require approval for followers',
          trailing: _comingSoon(),
        ),
        _div(colors),
        _PanelRow(
          icon: Icons.delete_forever_rounded,
          label: 'Delete Account',
          subtitle: 'Permanently delete all your data',
          onTap: () => _deleteAccount(context),
          isDestructive: true,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final colors = context.colors;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentPw = TextEditingController();
    final newPw = TextEditingController();
    final confirmPw = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: colors.primary),
            const SizedBox(width: 8),
            const Text('Change Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pwField(currentPw, 'Current Password', Icons.lock),
            const SizedBox(height: 12),
            _pwField(newPw, 'New Password', Icons.lock_open),
            const SizedBox(height: 12),
            _pwField(confirmPw, 'Confirm New Password', Icons.lock_reset),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: colors.primary),
            onPressed: () async {
              if (currentPw.text.isEmpty ||
                  newPw.text.isEmpty ||
                  confirmPw.text.isEmpty) {
                _snack(ctx, 'Please fill in all fields', Colors.red);
                return;
              }
              if (newPw.text != confirmPw.text) {
                _snack(ctx, 'Passwords do not match', Colors.red);
                return;
              }
              if (newPw.text.length < 6) {
                _snack(ctx, 'Minimum 6 characters', Colors.red);
                return;
              }
              try {
                final cred = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPw.text,
                );
                await user.reauthenticateWithCredential(cred);
                await user.updatePassword(newPw.text);
                Navigator.pop(ctx, true);
              } catch (e) {
                _snack(ctx, 'Error: $e', Colors.red);
              }
            },
            child: const Text(
              'Change',
              style: TextStyle(color: SharedColors.white),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      _snack(context, 'Password changed successfully', Colors.green);
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final passwordCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
              'This cannot be undone. All data will be permanently deleted.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            if (!_isGoogleUser) ...[
              const Text('Enter your password to confirm:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
            ] else
              const Text(
                'You will need to sign in with Google again to confirm.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                final cur = FirebaseAuth.instance.currentUser;
                if (cur == null) return;
                if (_isGoogleUser) {
                  try {
                    final gs = GoogleSignIn();
                    final gu = await gs.signIn();
                    if (gu == null) throw Exception('Cancelled');
                    final ga = await gu.authentication;
                    final cred = GoogleAuthProvider.credential(
                      accessToken: ga.accessToken,
                      idToken: ga.idToken,
                    );
                    await cur.reauthenticateWithCredential(cred);
                  } catch (e) {
                    if (!e.toString().contains('PigeonUserDetails')) rethrow;
                    AppLogger.i('Ignoring Pigeon error: $e');
                  }
                } else {
                  try {
                    final cred = EmailAuthProvider.credential(
                      email: cur.email!,
                      password: passwordCtrl.text,
                    );
                    await cur.reauthenticateWithCredential(cred);
                  } catch (e) {
                    if (!e.toString().contains('PigeonUserDetails')) rethrow;
                    AppLogger.i('Ignoring Pigeon error: $e');
                  }
                }
                await UserService.instance.deleteUser(cur.uid);
                try {
                  await cur.delete();
                } catch (e) {
                  if (!e.toString().contains('PigeonUserDetails')) rethrow;
                  AppLogger.i('Ignoring Pigeon error: $e');
                }
                Navigator.pop(ctx, true);
              } catch (e) {
                AppLogger.i('Delete account error: $e');
                if (ctx.mounted) {
                  _snack(ctx, 'Error: $e', Colors.red);
                }
              }
            },
            child: const Text(
              'Delete Account',
              style: TextStyle(color: SharedColors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Widget _pwField(
          TextEditingController ctrl, String label, IconData icon) =>
      TextField(
        controller: ctrl,
        obscureText: true,
        decoration: InputDecoration(
          labelText: label,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: Icon(icon),
        ),
      );

  void _snack(BuildContext ctx, String msg, Color bg) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// APPEARANCE PANEL
// ═══════════════════════════════════════════════════════════════════════════════

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        final colors = context.colors;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panelLabel('Theme', colors),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SelectButton(
                      label: 'Original',
                      isSelected:
                          themeService.selectedTheme == ThemeType.original,
                      colors: colors,
                      onTap: () => themeService.setTheme(ThemeType.original),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SelectButton(
                      label: 'New Theme',
                      isSelected: themeService.selectedTheme ==
                          ThemeType.new_theme,
                      colors: colors,
                      onTap: () =>
                          themeService.setTheme(ThemeType.new_theme),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _panelLabel('Mode', colors),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SelectButton(
                      label: 'Light',
                      icon: Icons.light_mode_outlined,
                      isSelected:
                          themeService.selectedMode == AppThemeMode.light,
                      colors: colors,
                      onTap: () =>
                          themeService.setThemeMode(AppThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SelectButton(
                      label: 'Dark',
                      icon: Icons.dark_mode_outlined,
                      isSelected:
                          themeService.selectedMode == AppThemeMode.dark,
                      colors: colors,
                      onTap: () =>
                          themeService.setThemeMode(AppThemeMode.dark),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _panelLabel(String text, AppTheme colors) => Text(
        text,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );
}

class _SelectButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final AppTheme colors;
  final VoidCallback onTap;

  const _SelectButton({
    required this.label,
    required this.isSelected,
    required this.colors,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 17,
                color: isSelected ? Colors.white : colors.text,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFICATIONS PANEL
// ═══════════════════════════════════════════════════════════════════════════════

class _NotificationsPanel extends StatefulWidget {
  const _NotificationsPanel();

  @override
  State<_NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<_NotificationsPanel> {
  bool _pushEnabled = true;
  bool _booking = true;
  bool _social = true;
  bool _followRequest = true;
  bool _achievement = true;
  bool _certificate = true;
  bool _system = true;
  bool _sound = true;
  bool _vibration = true;
  bool _systemPermission = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => _systemPermission = status.isGranted);
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pushEnabled = p.getBool('push_notifications_enabled') ?? true;
      _booking = p.getBool('booking_notifications') ?? true;
      _social = p.getBool('social_notifications') ?? true;
      _followRequest = p.getBool('follow_request_notifications') ?? true;
      _achievement = p.getBool('achievement_notifications') ?? true;
      _certificate = p.getBool('certificate_notifications') ?? true;
      _system = p.getBool('system_notifications') ?? true;
      _sound = p.getBool('notification_sound') ?? true;
      _vibration = p.getBool('notification_vibration') ?? true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // System permission warning
        if (!_systemPermission)
          _PermissionWarning(
            onOpenSettings: () async {
              await openAppSettings();
              await Future.delayed(const Duration(milliseconds: 500));
              await _checkPermission();
            },
          ),

        // Master toggle
        _SwitchRow(
          icon: Icons.notifications_outlined,
          label: 'Push Notifications',
          subtitle: _pushEnabled ? 'All notifications on' : 'All notifications off',
          value: _pushEnabled,
          onChanged: (v) async {
            if (v && !_systemPermission) {
              final granted = await PermissionService.instance
                  .requestNotificationPermission(context);
              if (granted) {
                setState(() {
                  _systemPermission = true;
                  _pushEnabled = v;
                });
                _save('push_notifications_enabled', v);
              }
            } else {
              setState(() => _pushEnabled = v);
              _save('push_notifications_enabled', v);
            }
          },
        ),

        Divider(height: 1, thickness: 0.6, color: colors.borderLight),

        // Types sub-label
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            'NOTIFICATION TYPES',
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),

        _SwitchRow(
          icon: Icons.calendar_today_outlined,
          label: 'Bookings',
          subtitle: 'Approvals, declines & updates',
          value: _booking,
          enabled: _pushEnabled,
          onChanged: (v) {
            setState(() => _booking = v);
            _save('booking_notifications', v);
          },
        ),
        _SwitchRow(
          icon: Icons.people_outline_rounded,
          label: 'Social',
          subtitle: 'Likes, comments & mentions',
          value: _social,
          enabled: _pushEnabled,
          onChanged: (v) {
            setState(() => _social = v);
            _save('social_notifications', v);
          },
        ),
        _SwitchRow(
          icon: Icons.person_add_outlined,
          label: 'Follow Requests',
          subtitle: 'New requests & acceptances',
          value: _followRequest,
          enabled: _pushEnabled,
          onChanged: (v) {
            setState(() => _followRequest = v);
            _save('follow_request_notifications', v);
          },
        ),
        _SwitchRow(
          icon: Icons.emoji_events_outlined,
          label: 'Achievements',
          subtitle: 'Badges & milestones',
          value: _achievement,
          enabled: _pushEnabled,
          onChanged: (v) {
            setState(() => _achievement = v);
            _save('achievement_notifications', v);
          },
        ),
        _SwitchRow(
          icon: Icons.workspace_premium_outlined,
          label: 'Certificates',
          subtitle: 'E-certificates & trek completions',
          value: _certificate,
          enabled: _pushEnabled,
          onChanged: (v) {
            setState(() => _certificate = v);
            _save('certificate_notifications', v);
          },
        ),
        _SwitchRow(
          icon: Icons.campaign_outlined,
          label: 'System',
          subtitle: 'App updates & announcements',
          value: _system,
          enabled: _pushEnabled,
          onChanged: (v) {
            setState(() => _system = v);
            _save('system_notifications', v);
          },
        ),

        Divider(height: 1, thickness: 0.6, color: colors.borderLight),

        // Alert preferences sub-label
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            'ALERT PREFERENCES',
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),

        _SwitchRow(
          icon: Icons.volume_up_outlined,
          label: 'Sound',
          subtitle: 'Play sound for notifications',
          value: _sound,
          enabled: _pushEnabled,
          onChanged: (v) {
            setState(() => _sound = v);
            _save('notification_sound', v);
          },
        ),
        _SwitchRow(
          icon: Icons.vibration_rounded,
          label: 'Vibration',
          subtitle: 'Vibrate for notifications',
          value: _vibration,
          enabled: _pushEnabled,
          onChanged: (v) {
            setState(() => _vibration = v);
            _save('notification_vibration', v);
          },
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PANEL HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _PanelRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  const _PanelRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color iconColor = isDestructive
        ? Colors.red.shade400
        : onTap != null
            ? (context.isDarkMode ? colors.iconSubtle : colors.primary)
            : colors.iconMuted;
    final Color labelColor =
        isDestructive ? Colors.red.shade400 : colors.text;
    final Color subtitleColor =
        isDestructive ? Colors.red.shade300 : colors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
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

class _SwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final bool enabled;
  final IconData? icon;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    this.enabled = true,
    this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final effectiveEnabled = enabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: effectiveEnabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: effectiveEnabled
                      ? (isDark ? colors.iconSubtle : colors.primary)
                      : colors.iconMuted,
                ),
                const SizedBox(width: 13),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: effectiveEnabled ? colors.text : colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.82,
                alignment: Alignment.centerRight,
                child: Switch(
                  value: value,
                  onChanged: effectiveEnabled ? onChanged : null,
                  activeColor: Colors.white,
                  activeTrackColor: colors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.14),
                  trackOutlineColor:
                      WidgetStateProperty.all(Colors.transparent),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionWarning extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _PermissionWarning({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Enable notification permission in system settings.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onOpenSettings,
            style: TextButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child:
                const Text('Open', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
