import 'package:flutter/material.dart';
import '../../models/badge.dart';
import '../../theme/app_theme.dart';
import 'badge_display.dart';
import '../../components/badge_filter.dart';
import '../../services/achievement_service.dart';
import '../../services/badge_repository.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<UserBadge>> _badgesFuture;
  Set<String> _selectedRarities = {};
  Set<String> _selectedCategories = {};
  Set<String> _selectedDifficulties = {};
  late AchievementService _achievementService;
  Map<String, DateTime> _acquiredBadges = {};

  // Grid / list view toggle
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _achievementService = AchievementService();
    _badgesFuture = _loadBadgesAndAchievements();
  }

  Future<List<UserBadge>> _loadBadgesAndAchievements() async {
    await _achievementService.init();
    _updateAcquiredBadges();
    // When the background Firestore hydration finishes, refresh the grid so
    // admin-created badges materialise without requiring a screen re-open.
    _achievementService.hydrationFuture.then((_) {
      if (!mounted) return;
      setState(() {
        _badgesFuture = Future.value(BadgeRepository.instance.all);
        _updateAcquiredBadges();
      });
    });
    return BadgeRepository.instance.all;
  }

  void _updateAcquiredBadges() {
    final unlockedAchievements = _achievementService.getUnlockedAchievements();
    _acquiredBadges = {};
    for (final achievement in unlockedAchievements) {
      _acquiredBadges[achievement.id] =
          achievement.unlockedAt ?? DateTime.now();
    }
  }

  List<UserBadge> _filterBadges(List<UserBadge> badges) {
    return badges.where((badge) {
      final matchesRarity = _selectedRarities.isEmpty ||
          _selectedRarities.contains(badge.rarity);
      final matchesCategory = _selectedCategories.isEmpty ||
          _selectedCategories.contains(badge.category);
      final matchesDifficulty = _selectedDifficulties.isEmpty ||
          _selectedDifficulties.contains(badge.difficulty);
      return matchesRarity && matchesCategory && matchesDifficulty;
    }).toList();
  }

  void _showFilterBottomSheet() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      builder: (context) => BadgeFilterBottomSheet(
        selectedRarities: _selectedRarities,
        selectedCategories: _selectedCategories,
        selectedDifficulties: _selectedDifficulties,
        onFiltersChanged: (rarities, categories, difficulties) {
          setState(() {
            _selectedRarities = rarities;
            _selectedCategories = categories;
            _selectedDifficulties = difficulties;
          });
        },
      ),
    );
  }

  void _navigateToDetail(UserBadge badge) {
    final isAcquired = _acquiredBadges.containsKey(badge.id);
    final acquiredDate = _acquiredBadges[badge.id];
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            BadgeDetailScreen(
          badge: badge,
          isAcquired: isAcquired,
          acquiredDate: acquiredDate,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      // Re-check Firebase when returning so admin approvals are reflected
      // immediately without requiring an app restart.
      if (!mounted) return;
      _achievementService.refreshFromFirebase().then((_) {
        if (!mounted) return;
        setState(() => _updateAcquiredBadges());
      });
    });
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
              child: FutureBuilder<List<UserBadge>>(
                future: _badgesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(error: '${snapshot.error}', colors: colors);
                  }

                  final allBadges = snapshot.data ?? [];
                  if (allBadges.isEmpty) {
                    return _EmptyState(
                      icon: Icons.emoji_events_outlined,
                      message: 'No badges available',
                      colors: colors,
                    );
                  }

                  final filteredBadges = _filterBadges(allBadges);
                  if (filteredBadges.isEmpty) {
                    return _EmptyState(
                      icon: Icons.filter_list_off_rounded,
                      message: 'No badges match your filters',
                      colors: colors,
                    );
                  }

                  // Stats bar
                  final acquiredCount = filteredBadges
                      .where((b) => _acquiredBadges.containsKey(b.id))
                      .length;

                  return Column(
                    children: [
                      _StatsBar(
                        total: filteredBadges.length,
                        acquired: acquiredCount,
                        colors: colors,
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                            child: child,
                          ),
                          child: _isGridView
                              ? _GridView(
                                  key: const ValueKey('grid'),
                                  badges: filteredBadges,
                                  acquiredBadges: _acquiredBadges,
                                  onTap: _navigateToDetail,
                                )
                              : _ListView(
                                  key: const ValueKey('list'),
                                  badges: filteredBadges,
                                  acquiredBadges: _acquiredBadges,
                                  onTap: _navigateToDetail,
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppTheme colors) {
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
              'All Badges',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
          // View toggle
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              key: ValueKey(_isGridView),
              icon: Icon(
                _isGridView
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                color: colors.text,
                size: 22,
              ),
              onPressed: () => setState(() => _isGridView = !_isGridView),
              tooltip: _isGridView ? 'Switch to list' : 'Switch to grid',
            ),
          ),
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: colors.text, size: 22),
            onPressed: _showFilterBottomSheet,
            tooltip: 'Filter badges',
          ),
        ],
      ),
    );
  }
}

// ── Stats bar ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.total,
    required this.acquired,
    required this.colors,
  });

  final int total;
  final int acquired;
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? acquired / total : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.borderLight, width: 0.6),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$acquired / $total badges',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: colors.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grid view ────────────────────────────────────────────────────────────────

class _GridView extends StatelessWidget {
  const _GridView({
    super.key,
    required this.badges,
    required this.acquiredBadges,
    required this.onTap,
  });

  final List<UserBadge> badges;
  final Map<String, DateTime> acquiredBadges;
  final ValueChanged<UserBadge> onTap;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount =
        MediaQuery.of(context).size.width > 600 ? 4 : 3;
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.82,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        final isAcquired = acquiredBadges.containsKey(badge.id);
        final acquiredDate = acquiredBadges[badge.id];
        return RepaintBoundary(
          child: BadgeCard(
            key: ValueKey(badge.id),
            badge: badge,
            isAcquired: isAcquired,
            acquiredDate: acquiredDate,
            isListView: false,
            onTap: () => onTap(badge),
          ),
        );
      },
    );
  }
}

// ── List view ────────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  const _ListView({
    super.key,
    required this.badges,
    required this.acquiredBadges,
    required this.onTap,
  });

  final List<UserBadge> badges;
  final Map<String, DateTime> acquiredBadges;
  final ValueChanged<UserBadge> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: badges.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final badge = badges[index];
        final isAcquired = acquiredBadges.containsKey(badge.id);
        final acquiredDate = acquiredBadges[badge.id];
        return RepaintBoundary(
          child: BadgeCard(
            key: ValueKey(badge.id),
            badge: badge,
            isAcquired: isAcquired,
            acquiredDate: acquiredDate,
            isListView: true,
            onTap: () => onTap(badge),
          ),
        );
      },
    );
  }
}

// ── Empty / error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.colors,
  });

  final IconData icon;
  final String message;
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: colors.iconMuted),
          const SizedBox(height: 14),
          Text(
            message,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.colors});

  final String error;
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Error loading badges: $error',
          style: TextStyle(color: colors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
