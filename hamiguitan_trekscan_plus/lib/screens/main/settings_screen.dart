import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../models/badge.dart';
import '../settings/badge_display.dart';
import '../settings/about_screen.dart';
import '../settings/help_and_support_screen.dart';
import '../../components/badge_filter.dart';

class SettingsScreen extends StatefulWidget {
  final bool showBadgesOnly;

  const SettingsScreen({super.key, this.showBadgesOnly = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<UserBadge>> _badgesFuture;
  Set<String> _selectedRarities = {};
  Set<String> _selectedCategories = {};
  Set<String> _selectedDifficulties = {};

  @override
  void initState() {
    super.initState();
    if (widget.showBadgesOnly) {
      _badgesFuture = _loadAllBadges();
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
      print('Failed to load badges: $e');
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
      backgroundColor: Colors.transparent,
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
    if (widget.showBadgesOnly) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
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
                          style: TextStyle(color: Colors.grey[600]),
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
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No badges match your filters',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.9,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                      itemCount: filteredBadges.length,
                      itemBuilder: (context, index) {
                        final badge = filteredBadges[index];
                        return BadgeCard(
                          badge: badge,
                          isAcquired:
                              false, // TODO: Load from user's acquired badges list
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BadgeDetailScreen(
                                  badge: badge,
                                  isAcquired:
                                      false, // TODO: Load from user's acquired badges list
                                  acquiredDate:
                                      null, // TODO: Load from user's badge acquisition data
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

    // Default settings screen
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSettingItem(
                    icon: Icons.person_outline,
                    title: 'Account',
                    subtitle: 'Personal information',
                  ),
                  _buildSettingItem(
                    icon: Icons.emoji_events_outlined,
                    title: 'Badges',
                    subtitle: 'View and track your achievements',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const SettingsScreen(showBadgesOnly: true),
                        ),
                      );
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Message, app & email notifications',
                  ),
                  _buildSettingItem(
                    icon: Icons.security_outlined,
                    title: 'Security',
                    subtitle: 'Password, Face ID & Touch ID',
                  ),
                  _buildSettingItem(
                    icon: Icons.remove_red_eye_outlined,
                    title: 'Appearance',
                    subtitle: 'Themes, wallpapers & app icon',
                  ),
                  _buildSettingItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'Help center & legal',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpAndSupportScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    subtitle: 'App information & version',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutScreen(),
                        ),
                      );
                    },
                  ),
                ],
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
      color: const Color(0xFF252B30),
      child: Row(
        children: [
          if (widget.showBadgesOnly)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Text(
                widget.showBadgesOnly ? 'All Badges' : 'Settings',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (widget.showBadgesOnly)
            IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: _showFilterBottomSheet,
            ),
          if (!widget.showBadgesOnly) const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
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
              color: const Color(0xFF252B30).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF252B30)),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
