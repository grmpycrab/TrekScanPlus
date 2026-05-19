// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/onboarding_service.dart';
import '../../theme/app_theme.dart';

class HelpAndSupportScreen extends StatelessWidget {
  const HelpAndSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

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
                    // ── Quick Help card ───────────────────────────────────────
                    _QuickHelpCard(colors: colors),
                    const SizedBox(height: 24),

                    // ── FAQ section ───────────────────────────────────────────
                    _sectionLabel('Frequently Asked Questions', colors),
                    const SizedBox(height: 10),
                    _FaqGroup(
                      faqs: const [
                        _FaqItem(
                          question: 'How do I book a trek?',
                          answer:
                              'Navigate to the Trek Schedule section, select your preferred date, and follow the booking process. Check the calendar for available slots.',
                        ),
                        _FaqItem(
                          question: 'What is the badge system?',
                          answer:
                              'The badge system rewards your trekking achievements and engagement. Earn badges by reaching different stations, scanning QR codes, and practicing sustainable trekking habits.',
                        ),
                        _FaqItem(
                          question: 'How do I scan QR codes?',
                          answer:
                              'Use the Scanner feature in the bottom navigation menu. Point your camera at QR codes along the trekking route to learn interesting facts about Mt. Hamiguitan.',
                        ),
                        _FaqItem(
                          question: 'Is my booking data secure?',
                          answer:
                              'Yes! Trek Scan+ uses Firebase security protocols to protect your personal and booking information with industry-standard encryption.',
                        ),
                        _FaqItem(
                          question: 'Can I cancel or modify my booking?',
                          answer:
                              'You can manage your bookings through your profile. For assistance with cancellations or modifications, please contact our support team.',
                        ),
                      ],
                      colors: colors,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),

                    // ── Contact section ───────────────────────────────────────
                    _sectionLabel('Contact Us', colors),
                    const SizedBox(height: 10),
                    _ContactGroup(
                      contacts: const [
                        _ContactItem(
                          icon: Icons.email_outlined,
                          label: 'Developer Email',
                          value: 'keyntharly@gmail.com',
                        ),
                        _ContactItem(
                          icon: Icons.email_outlined,
                          label: 'Developer Email',
                          value: 'shannenmendoza.310@gmail.com',
                        ),
                        _ContactItem(
                          icon: Icons.school_outlined,
                          label: 'University',
                          value: 'dorsuunacom@gmail.com',
                        ),
                      ],
                      colors: colors,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),

                    // ── Support hours ─────────────────────────────────────────
                    _sectionLabel('Support Hours', colors),
                    const SizedBox(height: 10),
                    _InfoCard(
                      colors: colors,
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SupportHourRow(
                            label: 'Monday – Friday',
                            value: '9:00 AM – 5:00 PM (PST)',
                            colors: colors,
                          ),
                          const SizedBox(height: 8),
                          _SupportHourRow(
                            label: 'Weekends',
                            value: '10:00 AM – 3:00 PM (PST)',
                            colors: colors,
                          ),
                          const SizedBox(height: 12),
                          Divider(height: 1, color: colors.borderLight),
                          const SizedBox(height: 12),
                          Text(
                            'We typically respond within 24 business hours.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
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

  Widget _sectionLabel(String text, AppTheme colors) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: colors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      );

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
              'Help & Support',
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

// ── Quick Help gradient card ─────────────────────────────────────────────────

class _QuickHelpCard extends StatelessWidget {
  const _QuickHelpCard({required this.colors});

  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.accent],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null && context.mounted) {
              await OnboardingService.showOnboarding(context, user.uid);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.play_circle_outline_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Tutorial',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Replay the welcome tutorial to learn app features',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── FAQ expandable group ─────────────────────────────────────────────────────

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}

class _FaqGroup extends StatefulWidget {
  const _FaqGroup({
    required this.faqs,
    required this.colors,
    required this.isDark,
  });

  final List<_FaqItem> faqs;
  final AppTheme colors;
  final bool isDark;

  @override
  State<_FaqGroup> createState() => _FaqGroupState();
}

class _FaqGroupState extends State<_FaqGroup> {
  int _openIndex = -1;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final rows = <Widget>[];
    for (int i = 0; i < widget.faqs.length; i++) {
      rows.add(_FaqTile(
        faq: widget.faqs[i],
        isExpanded: _openIndex == i,
        colors: colors,
        isDark: widget.isDark,
        onTap: () => setState(() => _openIndex = _openIndex == i ? -1 : i),
      ));
      if (i < widget.faqs.length - 1) {
        rows.add(Divider(
          height: 1,
          thickness: 0.6,
          indent: 16,
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

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.faq,
    required this.isExpanded,
    required this.colors,
    required this.isDark,
    required this.onTap,
  });

  final _FaqItem faq;
  final bool isExpanded;
  final AppTheme colors;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? colors.iconSubtle : colors.primary;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      faq.question,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isExpanded ? activeColor : colors.text,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
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
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          child: isExpanded
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
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Text(
                          faq.answer,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Contact group ────────────────────────────────────────────────────────────

class _ContactItem {
  final IconData icon;
  final String label;
  final String value;
  const _ContactItem(
      {required this.icon, required this.label, required this.value});
}

class _ContactGroup extends StatelessWidget {
  const _ContactGroup({
    required this.contacts,
    required this.colors,
    required this.isDark,
  });

  final List<_ContactItem> contacts;
  final AppTheme colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < contacts.length; i++) {
      final c = contacts[i];
      rows.add(_ContactRow(item: c, colors: colors, isDark: isDark));
      if (i < contacts.length - 1) {
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

class _ContactRow extends StatelessWidget {
  const _ContactRow(
      {required this.item, required this.colors, required this.isDark});

  final _ContactItem item;
  final AppTheme colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? colors.iconSubtle : colors.primary;
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : colors.primary.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Icon(item.icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textTertiary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Generic info card ────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.colors,
    required this.isDark,
    required this.child,
  });

  final AppTheme colors;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }
}

class _SupportHourRow extends StatelessWidget {
  const _SupportHourRow({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.text,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
