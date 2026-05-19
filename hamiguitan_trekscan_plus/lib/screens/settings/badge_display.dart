import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/badge.dart';
import '../../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// BADGE CARD — supports both Grid and List layouts
// ═══════════════════════════════════════════════════════════════════════════════

class BadgeCard extends StatelessWidget {
  final UserBadge badge;
  final bool isAcquired;
  final DateTime? acquiredDate;
  final VoidCallback? onTap;
  final bool isListView;

  const BadgeCard({
    super.key,
    required this.badge,
    this.isAcquired = false,
    this.acquiredDate,
    this.onTap,
    this.isListView = false,
  });

  @override
  Widget build(BuildContext context) {
    return isListView
        ? _ListCard(
            badge: badge,
            isAcquired: isAcquired,
            acquiredDate: acquiredDate,
            onTap: onTap,
          )
        : _GridCard(
            badge: badge,
            isAcquired: isAcquired,
            onTap: onTap,
          );
  }
}

// ── Grid card ────────────────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.badge,
    required this.isAcquired,
    this.onTap,
  });

  final UserBadge badge;
  final bool isAcquired;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final rarityColor = badge.getColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Rarity accent strip at top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: isAcquired
                        ? rarityColor
                        : colors.borderLight,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Badge icon
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isAcquired
                            ? rarityColor.withValues(alpha: 0.15)
                            : colors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        badge.getIconData(),
                        color: isAcquired ? rarityColor : colors.iconMuted,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Badge name
                    Text(
                      badge.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isAcquired ? colors.text : colors.textSecondary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Rarity chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAcquired
                            ? rarityColor.withValues(alpha: 0.12)
                            : colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge.rarity,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isAcquired ? rarityColor : colors.textTertiary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Lock overlay
              if (!isAcquired)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.lock_rounded,
                        color: colors.iconMuted,
                        size: 22,
                      ),
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

// ── List card ────────────────────────────────────────────────────────────────

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.badge,
    required this.isAcquired,
    this.acquiredDate,
    this.onTap,
  });

  final UserBadge badge;
  final bool isAcquired;
  final DateTime? acquiredDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final rarityColor = badge.getColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isAcquired
                        ? rarityColor.withValues(alpha: 0.15)
                        : colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    badge.getIconData(),
                    color: isAcquired ? rarityColor : colors.iconMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 13),
                // Name + rarity
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isAcquired ? colors.text : colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAcquired
                                  ? rarityColor.withValues(alpha: 0.12)
                                  : colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge.rarity,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isAcquired
                                    ? rarityColor
                                    : colors.textTertiary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            badge.category
                                .replaceAll('_', ' '),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status + chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isAcquired)
                      Icon(Icons.check_circle_rounded,
                          color: Colors.green.shade400, size: 18)
                    else
                      Icon(Icons.lock_rounded,
                          color: colors.iconMuted, size: 16),
                    if (isAcquired && acquiredDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d').format(acquiredDate!),
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: colors.iconMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BADGE DETAIL SCREEN — immersive sliver hero design
// ═══════════════════════════════════════════════════════════════════════════════

class BadgeDetailScreen extends StatelessWidget {
  final UserBadge badge;
  final DateTime? acquiredDate;
  final bool isAcquired;

  const BadgeDetailScreen({
    super.key,
    required this.badge,
    this.acquiredDate,
    this.isAcquired = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final rarityColor = badge.getColor();

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          // ── Sliver hero header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: rarityColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Badge Detail',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _HeroHeader(
                badge: badge,
                isAcquired: isAcquired,
                rarityColor: rarityColor,
                isDark: isDark,
              ),
            ),
          ),

          // ── Body content ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status bar
                  _StatusRow(
                    isAcquired: isAcquired,
                    acquiredDate: acquiredDate,
                    badge: badge,
                    colors: colors,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  _DetailCard(
                    icon: Icons.info_outline_rounded,
                    title: 'Description',
                    colors: colors,
                    isDark: isDark,
                    child: Text(
                      badge.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.65,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Details row (category + difficulty)
                  Row(
                    children: [
                      Expanded(
                        child: _MetaChip(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: badge.category.replaceAll('_', ' '),
                          colors: colors,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetaChip(
                          icon: Icons.bar_chart_rounded,
                          label: 'Difficulty',
                          value: badge.difficulty,
                          colors: colors,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Requirement
                  _DetailCard(
                    icon: Icons.task_alt_rounded,
                    title: 'Requirement',
                    colors: colors,
                    isDark: isDark,
                    child: _RequirementContent(
                      badge: badge,
                      isAcquired: isAcquired,
                      colors: colors,
                    ),
                  ),

                  // Acquired date (only when earned)
                  if (isAcquired && acquiredDate != null) ...[
                    const SizedBox(height: 12),
                    _DetailCard(
                      icon: Icons.celebration_outlined,
                      title: 'Achievement Unlocked',
                      colors: colors,
                      isDark: isDark,
                      accentColor: Colors.green.shade400,
                      child: _AcquiredContent(
                        acquiredDate: acquiredDate!,
                        colors: colors,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero header content ──────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.badge,
    required this.isAcquired,
    required this.rarityColor,
    required this.isDark,
  });

  final UserBadge badge;
  final bool isAcquired;
  final Color rarityColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            rarityColor,
            rarityColor.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            // Badge icon ring
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    badge.getIconData(),
                    color: Colors.white,
                    size: 46,
                  ),
                  if (!isAcquired)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white70,
                        size: 36,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Badge name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                badge.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 8),
            // Rarity pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge.rarity.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status row ───────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.isAcquired,
    required this.acquiredDate,
    required this.badge,
    required this.colors,
    required this.isDark,
  });

  final bool isAcquired;
  final DateTime? acquiredDate;
  final UserBadge badge;
  final AppTheme colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isAcquired
            ? Colors.green.withValues(alpha: isDark ? 0.15 : 0.08)
            : colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAcquired
              ? Colors.green.withValues(alpha: 0.3)
              : colors.borderLight,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAcquired
                ? Icons.check_circle_rounded
                : Icons.lock_outline_rounded,
            color: isAcquired ? Colors.green.shade500 : colors.iconMuted,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAcquired ? 'Badge Acquired' : 'Not Yet Unlocked',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isAcquired
                        ? Colors.green.shade600
                        : colors.textSecondary,
                  ),
                ),
                if (isAcquired && acquiredDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Earned on ${DateFormat('MMMM d, yyyy').format(acquiredDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade500,
                    ),
                  ),
                ] else if (!isAcquired) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Complete the requirement to unlock this badge',
                    style: TextStyle(fontSize: 11, color: colors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail card ──────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.colors,
    required this.isDark,
    required this.child,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final AppTheme colors;
  final bool isDark;
  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        accentColor ?? (isDark ? colors.iconSubtle : colors.primary);
    final iconBg = accentColor != null
        ? accentColor!.withValues(alpha: 0.1)
        : (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : colors.primary.withValues(alpha: 0.08));

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: colors.borderLight),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Meta chip ────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final AppTheme colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? colors.iconSubtle : colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textTertiary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                  maxLines: 1,
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

// ── Requirement content ──────────────────────────────────────────────────────

class _RequirementContent extends StatelessWidget {
  const _RequirementContent({
    required this.badge,
    required this.isAcquired,
    required this.colors,
  });

  final UserBadge badge;
  final bool isAcquired;
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    final reqType = badge.requirement['type']?.toString() ?? '';
    final reqValue = badge.requirement['value']?.toString() ?? '';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reqType.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.textTertiary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                reqValue,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isAcquired
                ? Colors.green.withValues(alpha: 0.1)
                : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAcquired ? Icons.check_rounded : Icons.hourglass_empty_rounded,
                size: 14,
                color: isAcquired ? Colors.green.shade500 : colors.iconMuted,
              ),
              const SizedBox(width: 4),
              Text(
                isAcquired ? 'Completed' : 'Incomplete',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isAcquired ? Colors.green.shade500 : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Acquired content ─────────────────────────────────────────────────────────

class _AcquiredContent extends StatelessWidget {
  const _AcquiredContent({
    required this.acquiredDate,
    required this.colors,
  });

  final DateTime acquiredDate;
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DateBlock(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: DateFormat('MMMM d, yyyy').format(acquiredDate),
            colors: colors,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DateBlock(
            icon: Icons.access_time_rounded,
            label: 'Time',
            value: DateFormat('h:mm a').format(acquiredDate),
            colors: colors,
          ),
        ),
      ],
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final String value;
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.green.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.textTertiary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
