import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../models/badge.dart';
import '../../theme/color.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Sample badges for demo; replace with real data source later.
  late List<UserBadge> _badges;

  @override
  void initState() {
    super.initState();
    // initialize with an empty list; we'll load JSON or fallback later
    _badges = [];
    _loadBadgesFromAsset();
  }

  Future<void> _loadBadgesFromAsset() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/badge.json');
      if (jsonStr.trim().isEmpty) throw Exception('badge.json empty');
      final data = json.decode(jsonStr);
      if (data is Map<String, dynamic> && data.containsKey('badges')) {
        final badgesList = data['badges'] as List;
        final list = badgesList
            .map((e) => UserBadge.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        setState(() {
          _badges = List<UserBadge>.from(list);
        });
        return;
      }
    } catch (e) {
      print('Error loading badges: $e');
      // ignore and fallback to sample badges below
    }

    // fallback samples
    setState(() {
      _badges = [
        UserBadge(
          id: 'first_steps',
          name: 'First Steps',
          description: 'Complete your first trail',
          category: 'trail_completion',
          icon: 'footprints',
          requirement: {'type': 'trails_completed', 'value': 1},
          rarity: 'common',
          earned: true,
        ),
        UserBadge(
          id: 'summit_seeker',
          name: 'Summit Seeker',
          description: 'Reach the peak of Mt. Hamiguitan',
          category: 'trail_completion',
          icon: 'mountain',
          requirement: {'type': 'reach_summit', 'value': true},
          rarity: 'rare',
          earned: false,
        ),
      ];
    });
  }

  void _toggleEarned(int index) {
    setState(() {
      final badge = _badges[index];
      _badges[index] = badge.copyWith(earned: !badge.earned);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopProfile(),
              const SizedBox(height: 18),
              _buildInputFields(),
              const SizedBox(height: 18),
              const Text(
                'Badges',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBadgesGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopProfile() {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/DOrSU_logo.png',
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                    ),
                  ),
                ),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: GestureDetector(
                    onTap: () {
                      // pick image or edit
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Name', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Enter your name',
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Phone number',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: const Text(
                'PH',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Enter phone number',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadgesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _badges.length,
      itemBuilder: (context, index) {
        final badge = _badges[index];
        return GestureDetector(
          onTap: () => _toggleEarned(index),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: badge.getColor().withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 24, // Reduced from 28
                          backgroundColor: badge.earned
                              ? badge.getColor()
                              : Colors.grey[300],
                          child: Icon(
                            badge.getIconData(),
                            color: badge.earned
                                ? Colors.white
                                : Colors.grey[700],
                            size: 24, // Reduced from 28
                          ),
                        ),
                        if (!badge.earned)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(255, 255, 255, 0.9),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: const Icon(
                                Icons.lock,
                                size: 10,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: badge.earned ? badge.getColor() : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Text(
                        badge.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.black45,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: badge.getColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        badge.rarity.toUpperCase(),
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w600,
                          color: badge.getColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
