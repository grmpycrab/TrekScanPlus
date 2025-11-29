import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../models/badge.dart';
import '../../theme/color.dart';
import 'badge_display.dart';
import '../../components/badge_filter.dart';
import '../../services/achievement_service.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  late Future<List<UserBadge>> _badgesFuture;
  Set<String> _selectedRarities = {};
  Set<String> _selectedCategories = {};
  Set<String> _selectedDifficulties = {};
  late AchievementService _achievementService;
  Map<String, DateTime> _acquiredBadges = {};

  @override
  void initState() {
    super.initState();
    _achievementService = AchievementService();
    _badgesFuture = _loadBadgesAndAchievements();
  }

  Future<List<UserBadge>> _loadBadgesAndAchievements() async {
    // Initialize achievement service if not already done
    await _achievementService.init();

    // Load acquired achievements
    _updateAcquiredBadges();

    // Load badges
    return _loadAllBadges();
  }

  void _updateAcquiredBadges() {
    final unlockedAchievements = _achievementService.getUnlockedAchievements();
    _acquiredBadges = {};
    for (final achievement in unlockedAchievements) {
      _acquiredBadges[achievement.id] =
          achievement.unlockedAt ?? DateTime.now();
    }
  }

  Future<List<UserBadge>> _loadAllBadges() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/badge.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final badgesData = jsonData['badges'] as List<dynamic>? ?? [];
      return badgesData
          .map((badge) => UserBadge.fromJson(badge as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  List<UserBadge> _filterBadges(List<UserBadge> badges) {
    return badges.where((badge) {
      bool matchesRarity =
          _selectedRarities.isEmpty || _selectedRarities.contains(badge.rarity);
      bool matchesCategory =
          _selectedCategories.isEmpty ||
          _selectedCategories.contains(badge.category);
      bool matchesDifficulty =
          _selectedDifficulties.isEmpty ||
          _selectedDifficulties.contains(badge.difficulty);

      return matchesRarity && matchesCategory && matchesDifficulty;
    }).toList();
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FutureBuilder<List<UserBadge>>(
                future: _badgesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading badges: ${snapshot.error}'),
                    );
                  }

                  final allBadges = snapshot.data ?? [];
                  final filteredBadges = _filterBadges(allBadges);

                  if (allBadges.isEmpty) {
                    return Center(
                      child: Text(
                        'No badges available',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  if (filteredBadges.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter_none,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No badges match your filters',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 600
                          ? 4
                          : 3, // 4 columns on tablets, 3 on phones
                      childAspectRatio: 0.85,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: filteredBadges.length,
                    itemBuilder: (context, index) {
                      final badge = filteredBadges[index];
                      final isAcquired = _acquiredBadges.containsKey(badge.id);
                      final acquiredDate = _acquiredBadges[badge.id];

                      return BadgeCard(
                        badge: badge,
                        isAcquired: isAcquired,
                        acquiredDate: acquiredDate,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BadgeDetailScreen(
                                badge: badge,
                                isAcquired: isAcquired,
                                acquiredDate: acquiredDate,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Center(
              child: Text(
                'All Badges',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.white),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
    );
  }
}
