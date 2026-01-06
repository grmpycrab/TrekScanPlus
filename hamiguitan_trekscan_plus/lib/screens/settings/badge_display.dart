import 'package:flutter/material.dart';
import '../../models/badge.dart';
import '../../theme/color.dart';

class BadgeCard extends StatelessWidget {
  final UserBadge badge;
  final bool isAcquired;
  final DateTime? acquiredDate;
  final VoidCallback? onTap;

  const BadgeCard({
    super.key,
    required this.badge,
    this.isAcquired = false,
    this.acquiredDate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizes based on available width
        final cardWidth = constraints.maxWidth;
        final iconSize = (cardWidth * 0.35).clamp(40.0, 70.0);
        final lockIconSize = (cardWidth * 0.25).clamp(30.0, 50.0);
        final nameFontSize = (cardWidth * 0.11).clamp(11.0, 14.0);
        final rarityFontSize = (cardWidth * 0.09).clamp(9.0, 12.0);
        final spacing = (cardWidth * 0.08).clamp(6.0, 12.0);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowLight,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Badge content
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: badge.getColor().withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        badge.getIconData(),
                        color: badge.getColor(),
                        size: iconSize * 0.5,
                      ),
                    ),
                    SizedBox(height: spacing),
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: cardWidth * 0.06,
                        ),
                        child: Text(
                          badge.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: nameFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing * 0.5),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: cardWidth * 0.06,
                      ),
                      child: Text(
                        badge.rarity,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: rarityFontSize,
                          color: badge.getColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                // Lock overlay if not acquired
                if (!isAcquired)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.shadowOverlay,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.lock,
                        color: SharedColors.white,
                        size: lockIconSize,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildBadgeDisplay(),
                      const SizedBox(height: 32),
                      _buildBadgeInfo(),
                      if (isAcquired && acquiredDate != null) ...[
                        const SizedBox(height: 32),
                        _buildAcquiredInfo(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: SharedColors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Badge Details',
                style: TextStyle(
                  color: SharedColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBadgeDisplay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final badgeSize = (screenWidth * 0.3).clamp(100.0, 150.0);
        final iconSize = badgeSize * 0.5;
        final lockIconSize = badgeSize * 0.33;
        final titleFontSize = (screenWidth * 0.06).clamp(20.0, 28.0);

        return Column(
          children: [
            Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: badge.getColor().withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: badge.getColor(), width: 3),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    badge.getIconData(),
                    color: badge.getColor(),
                    size: iconSize,
                  ),
                  if (!isAcquired)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.shadowOverlay,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock,
                        color: SharedColors.white,
                        size: lockIconSize,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: badge.getColor().withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge.rarity.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: badge.getColor(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isAcquired
                    ? AppColors.statusApproved.withValues(alpha: 0.2)
                    : AppColors.borderLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isAcquired ? AppColors.statusApproved : Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAcquired ? Icons.check_circle : Icons.lock_outline,
                    color: isAcquired
                        ? AppColors.statusApproved
                        : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isAcquired ? 'ACQUIRED' : 'NOT ACQUIRED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isAcquired
                          ? AppColors.statusApproved
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadgeInfo() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Description',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              badge.description,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textGrey700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              badge.category.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Requirement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '${badge.requirement['type']}: ${badge.requirement['value']}',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcquiredInfo() {
    final date = acquiredDate!;
    final formattedDate = '${date.month}/${date.day}/${date.year}';
    final formattedTime =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Badge Acquired',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  formattedTime,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
