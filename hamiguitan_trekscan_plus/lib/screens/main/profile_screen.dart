import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/achievement_service.dart';
import '../../services/user_service.dart';
import '../../services/social_sharing_service.dart';
import '../../services/e_certificate_service.dart';
import '../../services/station_service.dart';
import '../../services/certificate_pdf_service.dart';
import '../../models/social_model.dart';
import '../../models/e_certificate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../components/social_card.dart';

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
  final SocialSharingService _socialService = SocialSharingService.instance;
  final ECertificateService _certificateService = ECertificateService.instance;

  Future<void> _initializeAchievements() async {
    try {
      await achievementService.init();
      setState(() {});
    } catch (e) {
      debugPrint('Error initializing AchievementService: $e');
    }
  }

  Future<void> _initializeCertificates() async {
    try {
      if (_firebaseUser != null) {
        await _certificateService.init(userId: _firebaseUser!.uid);

        final stationService = await StationService.init(
          userId: _firebaseUser!.uid,
        );
        await stationService.loadStations();
        final visitedStations = stationService.getVisitedStations();

        if (visitedStations.isNotEmpty) {
          final totalDistance = stationService.getTotalDistance();
          final totalTimeMinutes = stationService.getTotalTimeMinutes();
          final trekStartDate = stationService.getTrekStartDate();
          final trekEndDate = stationService.getTrekEndDate();

          await _certificateService.checkAndAwardCertificate(
            visitedStations,
            totalDistance: totalDistance,
            totalTimeMinutes: totalTimeMinutes,
            trekStartDate: trekStartDate,
            trekEndDate: trekEndDate,
          );
        }

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing ECertificateService: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  void initState() {
    super.initState();
    achievementService = AchievementService();
    _initializeAchievements();
    _firebaseUser = FirebaseAuthService.instance.currentUser;
    _initializeCertificates();

    if (_firebaseUser != null) {
      _userService.fixNegativeCounts(_firebaseUser!.uid).catchError((e) {
        debugPrint('Error fixing negative counts: $e');
      });

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
                        // E-Certificates on the right
                        _buildCertificatesBadge(),
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
                  const SizedBox(height: 32),
                  // User's posts section
                  _buildUserPostsSection(),
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
    final unlockedCount = achievementService.getUnlockedCount();
    final totalCount = achievementService.getTotalCount();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        GestureDetector(
          onTap: () => _showFollowingModal(),
          child: Column(
            children: [
              Text(
                user.followingCount.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Following',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _showFollowersModal(),
          child: Column(
            children: [
              Text(
                user.followersCount.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Followers',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
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
        Column(
          children: [
            Text(
              '$unlockedCount/$totalCount',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Achievements',
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
                      color: achievement.getColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: achievement.getColor().withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: achievement.getColor().withValues(
                              alpha: 0.2,
                            ),
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
                            ? achievement.getColor().withValues(alpha: 0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isUnlocked
                              ? achievement.getColor().withValues(alpha: 0.3)
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
                                  ? achievement.getColor().withValues(
                                      alpha: 0.2,
                                    )
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

  Widget _buildUserPostsSection() {
    if (_firebaseUser == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Posts header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text(
                'Posts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              StreamBuilder<List<SocialPost>>(
                stream: _socialService.streamUserPosts(_firebaseUser!.uid),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Text(
                    '($count)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Posts list
        StreamBuilder<List<SocialPost>>(
          stream: _socialService.streamUserPosts(_firebaseUser!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading posts',
                  style: TextStyle(color: Colors.red[600]),
                ),
              );
            }

            final posts = snapshot.data ?? [];

            if (posts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No posts yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share your first post to get started!',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return SocialCard(
                    post: post,
                    onDelete: () {
                      _handleDeletePost(post.id!);
                    },
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _handleDeletePost(String postId) async {
    try {
      await _socialService.deletePost(postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete post: $e')));
      }
    }
  }

  Widget _buildCertificatesBadge() {
    final certificates = _certificateService.getAllCertificates();

    if (certificates.isEmpty) {
      return const SizedBox(width: 48);
    }

    return GestureDetector(
      onTap: () => _showCertificatesModal(certificates),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade400, Colors.amber.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              certificates.length.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCertificatesModal(List<ECertificate> certificates) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 16),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Certificates',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Certificates list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: certificates.length,
                itemBuilder: (context, index) {
                  final cert = certificates[index];
                  return _buildCertificateCard(cert, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateCard(ECertificate certificate, int index) {
    final colors = _getCertificateColors(certificate.certificateType);

    return GestureDetector(
      onTap: () => _showCertificateDetail(certificate),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors['light']!, colors['main']!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors['main']!.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Certificate type and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          certificate.getTitle(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Earned ${_formatCertificateDate(certificate.dateEarned)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _getCertificateIcon(certificate.certificateType),
                    color: Colors.white,
                    size: 32,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCertificateStat(
                    'Stations',
                    certificate.stationsVisited.toString(),
                  ),
                  _buildCertificateStat(
                    'Distance',
                    '${certificate.totalDistance.toStringAsFixed(1)} km',
                  ),
                  _buildCertificateStat(
                    'Time',
                    '${certificate.totalTimeMinutes} min',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCertificateStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  void _showCertificateDetail(ECertificate certificate) {
    Navigator.pop(context); // Close the modal
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _getCertificateColors(
                        certificate.certificateType,
                      )['light']!,
                      _getCertificateColors(
                        certificate.certificateType,
                      )['main']!,
                    ],
                  ),
                ),
                child: Icon(
                  _getCertificateIcon(certificate.certificateType),
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                certificate.getTitle(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                certificate.getDescription(),
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Trekker Name', certificate.trekkerName),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Date Earned',
                      _formatCertificateDate(certificate.dateEarned),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Stations Visited',
                      certificate.stationsVisited.toString(),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Total Distance',
                      '${certificate.totalDistance.toStringAsFixed(1)} km',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Total Time',
                      '${certificate.totalTimeMinutes} minutes',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Verification Code',
                      certificate.verificationCode,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Action buttons row
              Row(
                children: [
                  // Download PDF button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadCertificatePdf(certificate),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Share button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareCertificate(certificate),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Email button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _emailCertificate(certificate),
                      icon: const Icon(Icons.email, size: 18),
                      label: const Text('Email'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Close button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Map<String, Color> _getCertificateColors(CertificateType type) {
    switch (type) {
      case CertificateType.camp3:
        return {
          'main': const Color(0xFF8B4513),
          'light': const Color(0xFFD2691E),
        };
      case CertificateType.fullTrek:
        return {
          'main': const Color(0xFF4169E1),
          'light': const Color(0xFF6495ED),
        };
      case CertificateType.peakConqueror:
        return {
          'main': const Color(0xFFFFD700),
          'light': const Color(0xFFFFA500),
        };
    }
  }

  IconData _getCertificateIcon(CertificateType type) {
    switch (type) {
      case CertificateType.camp3:
        return Icons.location_on;
      case CertificateType.fullTrek:
        return Icons.terrain;
      case CertificateType.peakConqueror:
        return Icons.emoji_events;
    }
  }

  String _formatCertificateDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  // PDF and Email Action Handlers
  Future<void> _downloadCertificatePdf(ECertificate certificate) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF...'),
          duration: Duration(seconds: 1),
        ),
      );

      final pdfService = CertificatePdfService.instance;
      final file = await pdfService.saveCertificateToDownloads(certificate);

      if (!mounted) return;

      if (file != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Certificate saved to ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to save certificate. Please check storage permissions.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _shareCertificate(ECertificate certificate) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing to share...'),
          duration: Duration(seconds: 1),
        ),
      );

      final pdfService = CertificatePdfService.instance;
      await pdfService.shareCertificate(certificate);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing certificate: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _emailCertificate(ECertificate certificate) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sending email...'),
          duration: Duration(seconds: 2),
        ),
      );

      final success = await _certificateService.sendCertificateEmail(
        certificate,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate email sent successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to send email. Please check your internet connection.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showFollowersModal() async {
    if (_firebaseUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Followers',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Followers list
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _getFollowersList(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        final followers = snapshot.data ?? [];

                        if (followers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No followers yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: followers.length,
                          itemBuilder: (context, index) {
                            final user = followers[index];
                            return _buildFollowerListTile(user, setModalState);
                          },
                        );
                      },
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

  void _showFollowingModal() async {
    if (_firebaseUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Following',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Following list
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _getFollowingList(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        final following = snapshot.data ?? [];

                        if (following.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_add_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Not following anyone yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: following.length,
                          itemBuilder: (context, index) {
                            final user = following[index];
                            return _buildFollowingListTile(user, setModalState);
                          },
                        );
                      },
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

  Future<List<Map<String, dynamic>>> _getFollowersList() async {
    if (_firebaseUser == null) return [];

    try {
      final userData = await _userService.getUserOnce(_firebaseUser!.uid);
      final followerIds =
          (userData?['followers'] as List<dynamic>?)?.cast<String>() ?? [];

      final List<Map<String, dynamic>> followers = [];
      for (final uid in followerIds) {
        try {
          final user = await _userService.getUserOnce(uid);
          if (user != null) {
            followers.add({...user, 'uid': uid});
          }
        } catch (e) {
          continue;
        }
      }

      return followers;
    } catch (e) {
      debugPrint('Error fetching followers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getFollowingList() async {
    if (_firebaseUser == null) return [];

    try {
      final userData = await _userService.getUserOnce(_firebaseUser!.uid);
      final followingIds =
          (userData?['following'] as List<dynamic>?)?.cast<String>() ?? [];

      final List<Map<String, dynamic>> following = [];
      for (final uid in followingIds) {
        try {
          final user = await _userService.getUserOnce(uid);
          if (user != null) {
            following.add({...user, 'uid': uid});
          }
        } catch (e) {
          continue;
        }
      }

      return following;
    } catch (e) {
      debugPrint('Error fetching following: $e');
      return [];
    }
  }

  // List tile for FOLLOWERS list - shows "Follow Back" button
  Widget _buildFollowerListTile(
    Map<String, dynamic> user,
    StateSetter setModalState,
  ) {
    final firstName = user['firstName'] as String? ?? '';
    final lastName = user['lastName'] as String? ?? '';
    final email = user['email'] as String? ?? '';
    final photoURL = user['photoURL'] as String?;
    final uid = user['uid'] as String;

    final displayName = firstName.isNotEmpty || lastName.isNotEmpty
        ? '$firstName $lastName'.trim()
        : email.split('@').first;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.blueGrey[100],
        backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
        child: photoURL == null
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[700],
                ),
              )
            : null,
      ),
      title: Text(
        displayName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        email,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      trailing: uid != _firebaseUser?.uid
          ? FutureBuilder<bool>(
              future: _userService.isFollowing(_firebaseUser!.uid, uid),
              builder: (context, snapshot) {
                final isFollowingBack = snapshot.data ?? false;

                return OutlinedButton(
                  onPressed: () async {
                    if (isFollowingBack) {
                      // Current user unfollows them (but they still follow you)
                      await _userService.unfollow(_firebaseUser!.uid, uid);
                    } else {
                      // Current user follows them back
                      await _userService.toggleFollow(uid, _firebaseUser!.uid);
                    }
                    // Update both modal and parent screen
                    setModalState(() {});
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    backgroundColor: isFollowingBack
                        ? Colors.white
                        : Colors.blueGrey[700],
                    foregroundColor: isFollowingBack
                        ? Colors.blueGrey[700]
                        : Colors.white,
                    side: BorderSide(color: Colors.blueGrey[700]!, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isFollowingBack ? 'Following' : 'Follow Back',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }

  // List tile for FOLLOWING list - shows "Unfollow" button
  Widget _buildFollowingListTile(
    Map<String, dynamic> user,
    StateSetter setModalState,
  ) {
    final firstName = user['firstName'] as String? ?? '';
    final lastName = user['lastName'] as String? ?? '';
    final email = user['email'] as String? ?? '';
    final photoURL = user['photoURL'] as String?;
    final uid = user['uid'] as String;

    final displayName = firstName.isNotEmpty || lastName.isNotEmpty
        ? '$firstName $lastName'.trim()
        : email.split('@').first;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.blueGrey[100],
        backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
        child: photoURL == null
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[700],
                ),
              )
            : null,
      ),
      title: Text(
        displayName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        email,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      trailing: uid != _firebaseUser?.uid
          ? OutlinedButton(
              onPressed: () async {
                // Unfollow this user (remove from your following list)
                await _userService.unfollow(_firebaseUser!.uid, uid);
                // Update both modal and parent screen
                setModalState(() {});
                if (mounted) {
                  setState(() {});
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueGrey[700],
                side: BorderSide(color: Colors.blueGrey[700]!, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Unfollow',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }
}
