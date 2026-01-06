import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/achievement_service.dart';
import '../../services/user_service.dart';
import '../../services/social_sharing_service.dart';
import '../../services/e_certificate_service.dart';
import '../../services/station_service.dart';
import '../../models/social_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../components/social_card.dart';
import '../../components/e_certificate_badge.dart';
import '../../components/app_dialogue_handler.dart';
import '../../theme/color.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import '../settings/account_settings.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // If null, shows current user's profile

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _user;
  User? _firebaseUser;
  bool _isOwnProfile = true; // Track if viewing own profile or someone else's
  late AchievementService achievementService;
  final UserService _userService = UserService.instance;
  final SocialSharingService _socialService = SocialSharingService.instance;
  final ECertificateService _certificateService = ECertificateService.instance;
  bool _achievementsLoading = true;

  /// Get display name from user data, fallback to email if no first/last name
  String _getDisplayName(UserModel user) {
    if (user.firstName.isNotEmpty || user.lastName.isNotEmpty) {
      return '${user.firstName} ${user.lastName}'.trim();
    }
    // Fallback to email username if no name provided
    return user.email.split('@').first;
  }

  Future<void> _initializeAchievements({String? userId}) async {
    try {
      debugPrint(
        '👤 ProfileScreen: Initializing achievements for userId: $userId',
      );

      // Determine if viewing own profile or someone else's
      final isOwnProfile = userId == _firebaseUser?.uid || userId == null;

      // Create appropriate instance based on profile type
      if (isOwnProfile) {
        // Use singleton for own profile to maintain consistency
        achievementService = AchievementService();
      } else {
        // Create new instance for other profiles to avoid conflicts
        achievementService = AchievementService.forUser();
      }

      // Initialize with the specific userId - this will load their achievements from Firebase
      await achievementService.init(userId: userId);

      final unlockedCount = achievementService.getUnlockedAchievements().length;
      final totalCount = achievementService.getAllAchievements().length;
      debugPrint(
        '✅ ProfileScreen: Loaded $unlockedCount/$totalCount achievements for userId: $userId',
      );

      if (mounted) {
        setState(() {
          _achievementsLoading = false;
        });
      }
    } catch (e) {
      debugPrint(
        'Error initializing AchievementService for userId $userId: $e',
      );
      if (mounted) {
        setState(() {
          _achievementsLoading = false;
        });
      }
    }
  }

  Future<void> _initializeCertificates() async {
    try {
      if (_firebaseUser != null) {
        await _certificateService.init(userId: _firebaseUser!.uid);

        // Use singleton instance and ensure loaded
        StationService.instance.setCurrentUser(_firebaseUser!.uid);
        if (!StationService.instance.isLoaded) {
          await StationService.instance.loadStations();
        }
        final visitedStations = StationService.instance.getVisitedStations();

        if (visitedStations.isNotEmpty) {
          final totalDistance = StationService.instance.getTotalDistance();
          final totalTimeMinutes = StationService.instance
              .getTotalTimeMinutes();
          final trekStartDate = StationService.instance.getTrekStartDate();
          final trekEndDate = StationService.instance.getTrekEndDate();

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
    _firebaseUser = FirebaseAuthService.instance.currentUser;

    // Determine if viewing own profile or someone else's
    _isOwnProfile =
        widget.userId == null || widget.userId == _firebaseUser?.uid;

    // Get the userId to display (either provided userId or current user)
    final displayUserId = widget.userId ?? _firebaseUser?.uid;

    // Initialize achievements for the profile being viewed
    if (displayUserId != null) {
      _initializeAchievements(userId: displayUserId);
    }

    // Only initialize certificates for own profile
    if (_isOwnProfile) {
      _initializeCertificates();
    }

    if (_firebaseUser != null && _isOwnProfile) {
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
        firstName: 'Loading',
        lastName: '...',
        email: '',
        birthDate: '01/01/1990',
        gender: 'Not specified',
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
        stream: _userService.streamUser(widget.userId ?? _firebaseUser!.uid),
        builder: (context, snapshot) {
          UserModel displayUser = _user;

          if (snapshot.hasData && snapshot.data != null) {
            final userData = snapshot.data!.data() ?? {};

            // Handle users who only have displayName (Gmail users)
            String firstName = userData['firstName'] as String? ?? '';
            String lastName = userData['lastName'] as String? ?? '';

            if (firstName.isEmpty && lastName.isEmpty) {
              // Try to extract from displayName
              final displayName = userData['displayName'] as String? ?? '';
              if (displayName.isNotEmpty) {
                final nameParts = displayName.split(' ');
                firstName = nameParts.first;
                if (nameParts.length > 1) {
                  lastName = nameParts.skip(1).join(' ');
                }
              }
            }

            displayUser = UserModel(
              firstName: firstName,
              lastName: lastName,
              email: userData['email'] ?? _user.email,
              birthDate: userData['birthDate'] ?? _user.birthDate,
              gender: userData['gender'] ?? _user.gender,
              profileImage:
                  userData['photoURL'] ??
                  (widget.userId == null ? _firebaseUser!.photoURL : null),
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
                        // E-Certificates on the right (only show for own profile)
                        if (_isOwnProfile) _buildCertificatesBadge(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Profile info section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        _buildNewProfileLayout(displayUser),
                        const SizedBox(height: 20),
                        _buildActionButtons(),
                        const SizedBox(height: 24),
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

  Widget _buildBadgesSection(UserModel user) {
    if (_achievementsLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Achievements',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
              ),
            ),
          ),
        ],
      );
    }

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
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
          Container(
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.grey[400],
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isOwnProfile
                        ? 'No achievements unlocked yet. Start scanning stations to earn achievements!'
                        : 'No achievements unlocked yet.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
              ],
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
                                    color: AppColors.textSecondary,
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
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isUnlocked
                              ? achievement.getColor().withValues(alpha: 0.3)
                              : AppColors.border,
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
                                  : AppColors.border,
                            ),
                            child: isUnlocked
                                ? Icon(
                                    achievement.getIconData(),
                                    color: achievement.getColor(),
                                    size: 24,
                                  )
                                : Icon(
                                    Icons.lock,
                                    color: AppColors.textSecondary,
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
                                        : AppColors.textSecondary,
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
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                else if (!isUnlocked)
                                  Text(
                                    achievement.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
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
                stream: _socialService.streamUserPosts(
                  widget.userId ?? _firebaseUser!.uid,
                ),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Text(
                    '($count)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
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
          stream: _socialService.streamUserPosts(
            widget.userId ?? _firebaseUser!.uid,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              debugPrint(
                'Error loading posts for user ${widget.userId ?? _firebaseUser!.uid}: ${snapshot.error}',
              );
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Error loading posts',
                      style: TextStyle(color: Colors.red[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
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
                        color: AppColors.textSecondary,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete post: $e')));
      }
    }
  }

  Widget _buildCertificatesBadge() {
    return ECertificateBadge(certificateService: _certificateService);
  }

  void _navigateToUserProfile(BuildContext context, String targetUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    // Don't navigate if clicking own profile
    if (currentUser?.uid == targetUserId) {
      return;
    }

    // Check if current user follows this person
    if (currentUser?.uid != null) {
      try {
        final isFollowing = await _userService.isFollowing(
          currentUser!.uid,
          targetUserId,
        );

        if (!isFollowing) {
          // Show dialogue if not following
          if (mounted) {
            AppDialogueHandler.showAlert(
              context: context,
              title: 'Profile Access Restricted',
              message:
                  'You and this person don\'t follow each other. You can only view profiles of people you follow.',
              buttonText: 'OK',
            );
          }
          return;
        }

        // Navigate to profile if following
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: targetUserId),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          AppDialogueHandler.showAlert(
            context: context,
            title: 'Error',
            message: 'Unable to verify follow status. Please try again.',
            buttonText: 'OK',
          );
        }
      }
    }
  }

  Widget _buildNewProfileLayout(UserModel user) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile picture
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderColor, width: 2),
              ),
              child: ClipOval(
                child: user.profileImage != null
                    ? Image.network(user.profileImage!, fit: BoxFit.cover)
                    : CircleAvatar(
                        radius: 45,
                        backgroundColor: AppColors.background,
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 45,
                          color: AppColors.iconGrey400,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 24),
            // Right side: Name and stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User name at the top
                  Text(
                    _getDisplayName(user),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // User email under the name
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats row below the name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Posts count
                      StreamBuilder<List<SocialPost>>(
                        stream: _socialService.streamUserPosts(
                          widget.userId ?? _firebaseUser!.uid,
                        ),
                        builder: (context, snapshot) {
                          final postsCount = snapshot.data?.length ?? 0;
                          return _buildStatColumn(
                            postsCount.toString(),
                            'posts',
                            () {}, // No action for posts
                          );
                        },
                      ),
                      // Followers count
                      _buildStatColumn(
                        user.followersCount.toString(),
                        'followers',
                        () => _showFollowersModal(),
                      ),
                      // Following count
                      _buildStatColumn(
                        user.followingCount.toString(),
                        'following',
                        () => _showFollowingModal(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatColumn(String count, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isOwnProfile) {
      // Own profile: Edit Profile and Logout buttons
      return Row(
        children: [
          // Edit Profile button
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Navigate to account settings
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountSettingsScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.text,
                elevation: 0,
                side: BorderSide(color: AppColors.borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Edit profile',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Favorites button
          Expanded(
            child: ElevatedButton(
              onPressed: () => _navigateToFavorites(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.text,
                elevation: 0,
                side: BorderSide(color: AppColors.borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Favorites',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Settings button (three dots)
          Container(
            width: 48,
            child: ElevatedButton(
              onPressed: () => _navigateToSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.text,
                elevation: 0,
                side: BorderSide(color: AppColors.borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Icon(
                Icons.more_vert,
                size: 18,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      );
    } else {
      // Other user's profile: Follow button
      return FutureBuilder<bool>(
        future: _userService.isFollowing(_firebaseUser!.uid, widget.userId!),
        builder: (context, snapshot) {
          final isFollowing = snapshot.data ?? false;
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showFollowOptionsModal(isFollowing),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing
                    ? AppColors.background
                    : AppColors.primary,
                foregroundColor: isFollowing
                    ? AppColors.text
                    : Colors.white,
                elevation: 0,
                side: BorderSide(
                  color: isFollowing
                      ? AppColors.borderColor
                      : AppColors.primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(
                isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      );
    }
  }

  void _showFollowOptionsModal(bool isCurrentlyFollowing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Option
            ListTile(
              leading: Icon(
                isCurrentlyFollowing ? Icons.person_remove : Icons.person_add,
                color: isCurrentlyFollowing ? Colors.red : AppColors.primary,
              ),
              title: Text(
                isCurrentlyFollowing ? 'Unfollow' : 'Follow',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isCurrentlyFollowing
                      ? Colors.red
                      : AppColors.text,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _handleFollowAction(isCurrentlyFollowing);
              },
            ),
            // Cancel option
            ListTile(
              leading: Icon(Icons.close, color: AppColors.iconGrey600),
              title: Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFollowAction(bool isCurrentlyFollowing) async {
    try {
      if (isCurrentlyFollowing) {
        await _userService.unfollow(_firebaseUser!.uid, widget.userId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unfollowed successfully')),
          );
        }
      } else {
        await _userService.toggleFollow(widget.userId!, _firebaseUser!.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Following successfully')),
          );
        }
      }
      // Trigger UI update
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow status: $e')),
        );
      }
    }
  }

  void _navigateToFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FavoritesScreen()),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _showFollowersModal() async {
    if (_firebaseUser == null) return;

    // Get the correct user ID for the profile being viewed
    final profileUserId = widget.userId ?? _firebaseUser!.uid;

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
                      color: AppColors.border,
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
                      future: _getFollowersListForUser(profileUserId),
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
                                    color: AppColors.textSecondary,
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

    // Get the correct user ID for the profile being viewed
    final profileUserId = widget.userId ?? _firebaseUser!.uid;

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
                      color: AppColors.border,
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
                      future: _getFollowingListForUser(profileUserId),
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
                                    color: AppColors.textSecondary,
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

  Future<List<Map<String, dynamic>>> _getFollowersListForUser(
    String userId,
  ) async {
    if (_firebaseUser == null) return [];

    try {
      final userData = await _userService.getUserOnce(userId);
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
      debugPrint('Error fetching followers for user $userId: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getFollowingListForUser(
    String userId,
  ) async {
    if (_firebaseUser == null) return [];

    try {
      final userData = await _userService.getUserOnce(userId);
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
      debugPrint('Error fetching following for user $userId: $e');
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
      onTap: () => _navigateToUserProfile(context, uid),
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
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
      onTap: () => _navigateToUserProfile(context, uid),
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
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
