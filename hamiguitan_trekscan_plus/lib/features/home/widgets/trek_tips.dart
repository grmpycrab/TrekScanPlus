import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

// ─── Shared data (single source of truth for both widgets) ───────────────────

const Map<String, List<String>> _kSections = {
  'Best Time to Visit': [
    'Dry season is better. Months like November to April are recommended to avoid heavy rains.',
  ],
  'Pre-Trek Preparation': [
    'Check updates before going - Trail status, campsite condition, and permit processes may change.',
    'Let someone know your itinerary and expected return time.',
    'Train your legs and stamina beforehand with practice hikes and cardio.',
  ],
  'Essential Packing': [
    'Lightweight and quick-dry clothing',
    'Rain gear / waterproof jacket',
    'Good hiking boots with ankle support',
    'Water or water purification tools',
    'Sun protection (hat, sunglasses, sunscreen)',
    'Layers for cold/damp nights',
    'Headlamp with spare batteries',
    'First aid kit',
    'Insect repellent',
    'Energy snacks and food',
    'Small biodegradable soap (use away from water sources)',
  ],
  'Photography Tips': [
    'Bring a good camera or binoculars for birding',
    'Check rules on flash photography and drone use',
    'Protect equipment from moisture',
    'Best lighting is early morning or late afternoon',
  ],
  'Local Community Support': [
    'Hire local guides and porters',
    'Buy locally made food or souvenirs',
    "Respect indigenous peoples' customs",
    'Learn basic local phrases',
    'Support local conservation efforts',
  ],
  'Recovery Tips': [
    'Leave enough rest days after the trek',
    'Stay hydrated during and after the trek',
    'Do light stretches to prevent muscle stiffness',
    'Get adequate rest and nutrition',
  ],
  'Mental Preparation': [
    'Be patient with slow progress',
    'Enjoy the small things (birds, moss, silence)',
    'Accept that weather may force plan changes',
    'Stay positive and support fellow trekkers',
    'Practice mindfulness and appreciate nature',
  ],
};

IconData _kSectionIcon(String section) {
  switch (section) {
    case 'Best Time to Visit':
      return Icons.wb_sunny_outlined;
    case 'Pre-Trek Preparation':
      return Icons.checklist_rounded;
    case 'Essential Packing':
      return Icons.backpack_outlined;
    case 'Photography Tips':
      return Icons.camera_alt_outlined;
    case 'Local Community Support':
      return Icons.people_outline_rounded;
    case 'Recovery Tips':
      return Icons.self_improvement_rounded;
    case 'Mental Preparation':
      return Icons.spa_outlined;
    default:
      return Icons.info_outline_rounded;
  }
}

// ─── Main widget — used inside the drawer ────────────────────────────────────

class TrekTips extends StatefulWidget {
  const TrekTips({super.key});

  @override
  State<TrekTips> createState() => _TrekTipsState();
}

class _TrekTipsState extends State<TrekTips> {
  final Map<String, bool> _expanded = {
    for (final key in _kSections.keys) key: false,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isSmall = MediaQuery.of(context).size.width < 360;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      child: Column(
        children: [
          for (final entry in _kSections.entries) ...[
            _SectionTile(
              title: entry.key,
              icon: _kSectionIcon(entry.key),
              tips: entry.value,
              isExpanded: _expanded[entry.key]!,
              isSmall: isSmall,
              colors: colors,
              onTap: () => setState(
                () => _expanded[entry.key] = !_expanded[entry.key]!,
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

// ─── Custom expandable section tile ──────────────────────────────────────────

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.title,
    required this.icon,
    required this.tips,
    required this.isExpanded,
    required this.isSmall,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final List<String> tips;
  final bool isExpanded;
  final bool isSmall;
  final AppTheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // colors.primary is dark navy in dark mode — use iconSubtle instead for visibility
    final activeColor =
        context.isDarkMode ? colors.iconSubtle : colors.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isExpanded ? 0.07 : 0.04),
            blurRadius: isExpanded ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Header row
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 14 : 16,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        icon,
                        key: ValueKey(isExpanded),
                        color: isExpanded ? activeColor : colors.iconSubtle,
                        size: 19,
                      ),
                    ),
                    SizedBox(width: isSmall ? 10 : 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: isSmall ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          color: isExpanded ? activeColor : colors.text,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: colors.iconMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Animated body
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(
                          height: 1,
                          thickness: 0.8,
                          color: colors.borderLight,
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            isSmall ? 14 : 16,
                            12,
                            isSmall ? 14 : 16,
                            14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < tips.length; i++) ...[
                                _TipRow(
                                  tip: tips[i],
                                  colors: colors,
                                  isSmall: isSmall,
                                ),
                                if (i < tips.length - 1)
                                  const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tip bullet row ───────────────────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.tip,
    required this.colors,
    required this.isSmall,
  });

  final String tip;
  final AppTheme colors;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    final bulletColor = context.isDarkMode
        ? colors.iconSubtle.withValues(alpha: 0.75)
        : colors.primary.withValues(alpha: 0.55);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: bulletColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tip,
            style: TextStyle(
              fontSize: isSmall ? 12 : 13,
              color: colors.text,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Overlay / dialog version — all sections always expanded ──────────────────

class TrekTipsOverlay extends StatelessWidget {
  const TrekTipsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 360;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: size.height * 0.72,
          maxWidth: 560,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OverlayHeader(colors: colors),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  children: [
                    for (final entry in _kSections.entries) ...[
                      _ExpandedSectionCard(
                        title: entry.key,
                        icon: _kSectionIcon(entry.key),
                        tips: entry.value,
                        colors: colors,
                        isSmall: isSmall,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayHeader extends StatelessWidget {
  const _OverlayHeader({required this.colors});

  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.accent, const Color(0xFF053821)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFFFCC206),
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tips & Tricks',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.1,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _ExpandedSectionCard extends StatelessWidget {
  const _ExpandedSectionCard({
    required this.title,
    required this.icon,
    required this.tips,
    required this.colors,
    required this.isSmall,
  });

  final String title;
  final IconData icon;
  final List<String> tips;
  final AppTheme colors;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    final sectionIconColor =
        context.isDarkMode ? colors.iconSubtle : colors.accent;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(icon, color: sectionIconColor, size: 17),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.8, color: colors.borderLight),
          // Tips list
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              children: [
                for (int i = 0; i < tips.length; i++) ...[
                  _OverlayTipRow(
                    tip: tips[i],
                    colors: colors,
                    isSmall: isSmall,
                  ),
                  if (i < tips.length - 1) const SizedBox(height: 7),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayTipRow extends StatelessWidget {
  const _OverlayTipRow({
    required this.tip,
    required this.colors,
    required this.isSmall,
  });

  final String tip;
  final AppTheme colors;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    final bulletColor = context.isDarkMode
        ? colors.iconSubtle.withValues(alpha: 0.75)
        : colors.accent.withValues(alpha: 0.65);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: bulletColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tip,
            style: TextStyle(
              fontSize: isSmall ? 12 : 13,
              color: colors.text,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
