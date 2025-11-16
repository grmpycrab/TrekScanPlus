import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/achievement_service.dart';
import '../../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _user;
  User? _firebaseUser;
  late AchievementService achievementService;
  final UserService _userService = UserService.instance;

  @override
  void initState() {
    super.initState();
    achievementService = AchievementService();
    _firebaseUser = FirebaseAuthService.instance.currentUser;

    if (_firebaseUser != null) {
      final display = _firebaseUser!.displayName ?? '';
      final parts = display.isNotEmpty ? display.split(' ') : [];
      final first = parts.isNotEmpty
          ? parts.first
          : (_firebaseUser!.email?.split('@').first ?? '');
      final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      _user = UserModel(
        firstName: first,
        lastName: last,
        email: _firebaseUser!.email ?? '',
        birthDate: '01/01/1990',
        gender: 'Not specified',
        profileImage: _firebaseUser!.photoURL,
      );
    } else {
      _user = UserModel(
        firstName: 'John',
        lastName: 'Doe',
        email: 'john.doe@example.com',
        birthDate: '01/01/1990',
        gender: 'Male',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_firebaseUser == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('User not authenticated'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userService.streamUser(_firebaseUser!.uid),
        builder: (context, snapshot) {
          UserModel displayUser = _user;

          if (snapshot.hasData && snapshot.data != null) {
            final userData = snapshot.data!.data() ?? {};
            displayUser = UserModel(
              firstName: userData['firstName'] ?? _user.firstName,
              lastName: userData['lastName'] ?? _user.lastName,
              email: userData['email'] ?? _user.email,
              birthDate: userData['birthDate'] ?? _user.birthDate,
              gender: userData['gender'] ?? _user.gender,
              profileImage: userData['photoURL'] ?? _firebaseUser!.photoURL,
              badges:
                  (userData['badges'] as List<dynamic>?)
                      ?.whereType<String>()
                      .toList() ??
                  _user.badges,
              followingCount: userData['followingCount'] as int? ?? 0,
              followersCount: userData['followersCount'] as int? ?? 0,
              postsCount: userData['postsCount'] as int? ?? 0,
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header with back button and title
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 16.0,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                            size: 24,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Profile info section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        _buildProfileSection(displayUser),
                        const SizedBox(height: 24),
                        _buildStatsSection(displayUser),
                        const SizedBox(height: 32),
                        if (displayUser.badges.isNotEmpty)
                          _buildBadgesSection(displayUser),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileSection(UserModel user) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: ClipOval(
            child: user.profileImage != null
                ? Image.network(user.profileImage!, fit: BoxFit.cover)
                : CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[100],
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 40,
                      color: Colors.grey[400],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "${user.firstName} ${user.lastName}",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStatsSection(UserModel user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            Text(
              user.followingCount.toString().padLeft(2, '0'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Following',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        Column(
          children: [
            Text(
              user.followersCount.toString().padLeft(2, '0'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Followers',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        Column(
          children: [
            Text(
              user.postsCount.toString().padLeft(2, '0'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Posts',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadgesSection(UserModel user) {
    final unlockedAchievements = achievementService.getUnlockedAchievements();
    final totalAchievements = achievementService.getTotalCount();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Achievements',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${unlockedAchievements.length} of $totalAchievements unlocked',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (unlockedAchievements.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  '${(unlockedAchievements.length / totalAchievements * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (unlockedAchievements.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'No achievements unlocked yet. Start scanning stations to earn achievements!',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          )
        else
          Column(
            children: [
              // Show first 3 unlocked achievements
              ...unlockedAchievements.take(3).map((achievement) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: achievement.getColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: achievement.getColor().withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: achievement.getColor().withOpacity(0.2),
                          ),
                          child: Icon(
                            achievement.getIconData(),
                            color: achievement.getColor(),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                achievement.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              if (achievement.unlockedAt != null)
                                Text(
                                  'Unlocked ${_formatDate(achievement.unlockedAt!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: achievement.getColor(),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            achievement.rarity.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              if (unlockedAchievements.length > 3)
                GestureDetector(
                  onTap: () {
                    _showAllAchievementsDialog();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'View all ${unlockedAchievements.length} achievements',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[600],
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  void _showAllAchievementsDialog() {
    final allAchievements = achievementService.getAllAchievements();
    final unlockedIds = achievementService
        .getUnlockedAchievements()
        .map((a) => a.id)
        .toSet();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Achievements',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: allAchievements.length,
                itemBuilder: (context, index) {
                  final achievement = allAchievements[index];
                  final isUnlocked = unlockedIds.contains(achievement.id);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? achievement.getColor().withOpacity(0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isUnlocked
                              ? achievement.getColor().withOpacity(0.3)
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isUnlocked
                                  ? achievement.getColor().withOpacity(0.2)
                                  : Colors.grey[300],
                            ),
                            child: isUnlocked
                                ? Icon(
                                    achievement.getIconData(),
                                    color: achievement.getColor(),
                                    size: 24,
                                  )
                                : Icon(
                                    Icons.lock,
                                    color: Colors.grey[600],
                                    size: 24,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  achievement.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isUnlocked
                                        ? Colors.black
                                        : Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                if (isUnlocked &&
                                    achievement.unlockedAt != null)
                                  Text(
                                    'Unlocked ${_formatDate(achievement.unlockedAt!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  )
                                else if (!isUnlocked)
                                  Text(
                                    achievement.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isUnlocked
                                  ? achievement.getColor()
                                  : Colors.grey[400],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              achievement.rarity.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
