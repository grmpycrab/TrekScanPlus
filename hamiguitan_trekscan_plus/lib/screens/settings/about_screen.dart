import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero block ──────────────────────────────────────────
                    _HeroBlock(colors: colors, isDark: isDark),
                    const SizedBox(height: 24),

                    // ── About This Project ──────────────────────────────────
                    _SectionCard(
                      icon: Icons.info_outline_rounded,
                      title: 'About This Project',
                      colors: colors,
                      isDark: isDark,
                      child: const Text(
                        'Trek Scan+ is a capstone project developed by BSIT students at Davao Oriental State University (DOrSU). This innovative mobile application combines technology and sustainable tourism to enhance the trekking experience on Mt. Hamiguitan, a UNESCO World Heritage Site.\n\n'
                        'Our mission is to create a seamless bridge between technology and nature, empowering trekkers to explore responsibly while celebrating the unique biodiversity and cultural richness of Mt. Hamiguitan. Through this application, we aim to promote conservation awareness, sustainable trekking practices, and educational engagement with one of the Philippines\' most treasured natural landmarks.',
                        style: TextStyle(fontSize: 13, height: 1.65),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Key Features ────────────────────────────────────────
                    _SectionCard(
                      icon: Icons.star_outline_rounded,
                      title: 'Key Features',
                      colors: colors,
                      isDark: isDark,
                      child: Column(
                        children: const [
                          _FeatureRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Trek Scheduling',
                            description: 'Real-time booking & schedule management',
                          ),
                          _FeatureRow(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'QR Code Scanner',
                            description:
                                'Interactive educational insights along the route',
                          ),
                          _FeatureRow(
                            icon: Icons.emoji_events_outlined,
                            label: 'Badge System',
                            description: 'Achievement tracking & milestone rewards',
                          ),
                          _FeatureRow(
                            icon: Icons.workspace_premium_outlined,
                            label: 'E-Certificates',
                            description: 'Digital trek completion certificates',
                          ),
                          _FeatureRow(
                            icon: Icons.people_outline_rounded,
                            label: 'Social Feed',
                            description: 'Share trek moments with the community',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── About Mt. Hamiguitan ────────────────────────────────
                    _SectionCard(
                      icon: Icons.terrain_rounded,
                      title: 'About Mt. Hamiguitan',
                      colors: colors,
                      isDark: isDark,
                      child: const Text(
                        'Mt. Hamiguitan stands as a testament to nature\'s grandeur and biodiversity. As a UNESCO World Heritage Site, it represents a unique ecosystem that deserves our respect, protection, and appreciation. Every trek contributes to our understanding and preservation of this natural wonder.',
                        style: TextStyle(fontSize: 13, height: 1.65),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Development Team ────────────────────────────────────
                    _SectionCard(
                      icon: Icons.groups_outlined,
                      title: 'Development Team',
                      colors: colors,
                      isDark: isDark,
                      child: const Text(
                        'Developed with passion and dedication by BSIT students at Davao Oriental State University.',
                        style: TextStyle(fontSize: 13, height: 1.65),
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
              'About',
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

// ── Hero block ──────────────────────────────────────────────────────────────

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({required this.colors, required this.isDark});

  final AppTheme colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.accent,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: isDark ? 0.25 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.landscape_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Mt. Hamiguitan TrekScan+',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Discover · Trek · Experience',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.colors,
    required this.isDark,
    required this.child,
  });

  final IconData icon;
  final String title;
  final AppTheme colors;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? colors.iconSubtle : colors.primary;
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : colors.primary.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
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
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 11),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.6, color: colors.borderLight),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: DefaultTextStyle(
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.65,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature row ─────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.description,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isDark ? colors.iconSubtle : colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 0.5, color: colors.borderLight),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
