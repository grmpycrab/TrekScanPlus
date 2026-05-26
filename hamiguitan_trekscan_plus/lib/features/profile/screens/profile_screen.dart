// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hamiguitan_trekscan_plus/features/social/models/social_model.dart';
import 'package:hamiguitan_trekscan_plus/features/social/repositories/social_repository.dart';
import 'package:hamiguitan_trekscan_plus/features/social/screens/favorites_screen.dart';
import 'package:hamiguitan_trekscan_plus/features/social/widgets/social_card.dart';
import '../../../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../components/e_certificate_badge.dart';
import '../../../core/widgets/app_dialogue_handler.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';
import '../../settings/screens/settings_screen.dart';
import '../../../screens/settings/account_settings.dart';
import '../viewmodels/profile_view_model.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // If null, shows current user's profile

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _user;
  final UserService _userService = UserService.instance;
  final SocialSharingService _socialService = SocialSharingService.instance;
  late final Stream<List<SocialPost>> _userPostsStream;

  // Cached follow-state future — prevents a new Firestore read on every
  // outer StreamBuilder emit. Refreshed explicitly after follow/unfollow.
  Future<bool>? _isFollowingFuture;

  late final ProfileViewModel _vm;

  void _onVmChanged() => setState(() {});

  /// Get display name from user data, fallback to email if no first/last name
  String _getDisplayName(UserModel user) {
    return _vm.getDisplayName(user);
  }

  void _refreshFollowState() {
    if (_vm.firebaseUser != null && widget.userId != null) {
      setState(() {
        _isFollowingFuture = _userService.isFollowing(
          _vm.firebaseUser!.uid,
          widget.userId!,
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _vm = ProfileViewModel();
    _vm.addListener(_onVmChanged);
    _vm.initialize(widget.userId);
    _user = _vm.initialUser;

    final profileUserId = widget.userId ?? _vm.firebaseUser?.uid;
    _userPostsStream = profileUserId == null
        ? Stream<List<SocialPost>>.empty()
        : _socialService.streamUserPosts(profileUserId).asBroadcastStream();

    // Initialise follow-state once for other-user profiles.
    if (_vm.firebaseUser != null && widget.userId != null) {
      _isFollowingFuture = _userService.isFollowing(
        _vm.firebaseUser!.uid,
        widget.userId!,
      );
    }

    if (_vm.firebaseUser != null && _vm.isOwnProfile) {
      _userService.fixNegativeCounts(_vm.firebaseUser!.uid).catchError((e) {
        AppLogger.e('Error fixing negative counts: $e');
      });
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (_vm.firebaseUser == null) {
      return Scaffold(
        backgroundColor: colors.background,
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
      backgroundColor: colors.background,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userService.streamUser(widget.userId ?? _vm.firebaseUser!.uid),
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
                  (widget.userId == null ? _vm.firebaseUser!.photoURL : null),
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
                        if (_vm.isOwnProfile) _buildCertificatesBadge(),
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
    final colors = context.colors;
    if (_vm.achievementsLoading) {
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

    final unlockedAchievements = _vm.achievementService
        .getUnlockedAchievements();
    final totalAchievements = _vm.achievementService.getTotalCount();

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
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
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
              color: colors.background,
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
                    _vm.isOwnProfile
                        ? 'No achievements unlocked yet. Start scanning stations to earn achievements!'
                        : 'No achievements unlocked yet.',
                    style: TextStyle(fontSize: 14, color: colors.textSecondary),
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
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
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
                                    color: colors.textSecondary,
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
              }),
              if (unlockedAchievements.length > 3)
                GestureDetector(
                  onTap: () {
                    _showAllAchievementsSheet();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'View all ${unlockedAchievements.length} achievements',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.colors.primary,
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

  void _showAllAchievementsSheet() {
    final allAchievements = _vm.achievementService.getAllAchievements();
    final unlockedIds = _vm.achievementService
        .getUnlockedAchievements()
        .map((a) => a.id)
        .toSet();
    final total    = allAchievements.length;
    final unlocked = unlockedIds.length;
    final progress = total > 0 ? unlocked / total : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colors = context.colors;
        final tt = Theme.of(context).textTheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: colors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // ── Stats header ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'All Achievements',
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.text,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: colors.iconMuted),
                            onPressed: () => Navigator.pop(context),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            '$unlocked / $total unlocked',
                            style: tt.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(progress * 100).round()}%',
                            style: tt.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                            backgroundColor: colors.borderLight,
                            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 0.6, color: colors.borderLight),
                // ── Achievement list ───────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: allAchievements.length,
                    itemBuilder: (context, index) {
                      final achievement = allAchievements[index];
                      final isUnlocked = unlockedIds.contains(achievement.id);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? achievement.getColor().withValues(alpha: 0.08)
                                : colors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUnlocked
                                  ? achievement.getColor().withValues(alpha: 0.28)
                                  : colors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isUnlocked
                                      ? achievement.getColor().withValues(alpha: 0.18)
                                      : colors.borderLight,
                                ),
                                child: Icon(
                                  isUnlocked
                                      ? achievement.getIconData()
                                      : Icons.lock_outline_rounded,
                                  color: isUnlocked
                                      ? achievement.getColor()
                                      : colors.textSecondary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      achievement.name,
                                      style: tt.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isUnlocked
                                            ? colors.text
                                            : colors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isUnlocked && achievement.unlockedAt != null
                                          ? 'Unlocked ${_formatDate(achievement.unlockedAt!)}'
                                          : achievement.description,
                                      style: tt.bodySmall?.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isUnlocked
                                      ? achievement.getColor()
                                      : colors.borderLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  achievement.rarity.toUpperCase(),
                                  style: tt.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isUnlocked
                                        ? Colors.white
                                        : colors.textTertiary,
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
      },
    );
  }

  Widget _buildUserPostsSection() {
    final colors = context.colors;
    if (_vm.firebaseUser == null) {
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
                stream: _userPostsStream,
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Text(
                    '($count)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  );
                },
              ),
              // "My Posts" shortcut — own profile only
              if (_vm.isOwnProfile) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/my-posts'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.primary.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.manage_accounts_outlined,
                            size: 13, color: colors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Manage',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Posts list
        StreamBuilder<List<SocialPost>>(
          stream: _userPostsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              AppLogger.e(
                'Error loading posts for user ${widget.userId ?? _vm.firebaseUser!.uid}: ${snapshot.error}',
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
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
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
                        color: colors.textSecondary,
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

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return SocialCard(
                  key: ValueKey(post.id ?? 'profile_post_$index'),
                  post: post,
                  onDelete: () {
                    _handleDeletePost(post.id!);
                  },
                );
              },
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
    return ECertificateBadge(certificateService: _vm.certificateService);
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
    final colors = context.colors;
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
                color: colors.background,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border, width: 2),
              ),
              child: ClipOval(
                child: user.profileImage != null
                    ? CachedNetworkImage(
                    imageUrl: user.profileImage!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const CircularProgressIndicator(),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.person),
                  )
                    : CircleAvatar(
                        radius: 45,
                        backgroundColor: colors.background,
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 45,
                          color: Colors.grey.shade400,
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // User email under the name
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 14, color: colors.textTertiary),
                  ),
                  const SizedBox(height: 16),
                  // Stats row below the name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Posts count — reuses the same broadcast stream as
                      // the posts list section to avoid a third Firestore listener.
                      StreamBuilder<List<SocialPost>>(
                        stream: _userPostsStream,
                        builder: (context, snapshot) {
                          final postsCount = snapshot.data?.length ?? 0;
                          return _buildStatColumn(
                            postsCount.toString(),
                            'posts',
                            () {},
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
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final colors = context.colors;
    if (_vm.isOwnProfile) {
      return Row(
        children: [
          // Edit Profile button
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountSettingsScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.background,
                foregroundColor: colors.text,
                elevation: 0,
                side: BorderSide(color: colors.border),
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
                backgroundColor: colors.background,
                foregroundColor: colors.text,
                elevation: 0,
                side: BorderSide(color: colors.border),
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
          SizedBox(
            width: 48,
            child: ElevatedButton(
              onPressed: () => _navigateToSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.background,
                foregroundColor: colors.text,
                elevation: 0,
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Icon(Icons.more_vert, size: 18, color: colors.text),
            ),
          ),
        ],
      );
    } else {
      // Other user's profile: Follow button
      return FutureBuilder<bool>(
        future: _isFollowingFuture,
        builder: (context, snapshot) {
          final isFollowing = snapshot.data ?? false;
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showFollowOptionsModal(isFollowing),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing
                    ? colors.background
                    : colors.primary,
                foregroundColor: isFollowing ? colors.text : Colors.white,
                elevation: 0,
                side: BorderSide(
                  color: isFollowing ? colors.border : colors.primary,
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
      builder: (context) {
        final colors = context.colors;
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.only(
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
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Option
              ListTile(
                leading: Icon(
                  isCurrentlyFollowing ? Icons.person_remove : Icons.person_add,
                  color: isCurrentlyFollowing ? Colors.red : colors.primary,
                ),
                title: Text(
                  isCurrentlyFollowing ? 'Unfollow' : 'Follow',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isCurrentlyFollowing ? Colors.red : colors.text,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _handleFollowAction(isCurrentlyFollowing);
                },
              ),
              // Cancel option
              ListTile(
                leading: Icon(Icons.close, color: Colors.grey.shade600),
                title: Text(
                  'Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: colors.textTertiary,
                  ),
                ),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleFollowAction(bool isCurrentlyFollowing) async {
    try {
      if (isCurrentlyFollowing) {
        await _userService.unfollow(_vm.firebaseUser!.uid, widget.userId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unfollowed successfully')),
          );
        }
      } else {
        await _userService.toggleFollow(widget.userId!, _vm.firebaseUser!.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Following successfully')),
          );
        }
      }
      if (mounted) _refreshFollowState();
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
    if (_vm.firebaseUser == null) return;

    final profileUserId = widget.userId ?? _vm.firebaseUser!.uid;

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
            builder: (context, scrollController) {
              final colors = context.colors;
              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.only(
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
                        color: colors.border,
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
                                      color: colors.textSecondary,
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
                              return _buildFollowerListTile(
                                user,
                                setModalState,
                                colors,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showFollowingModal() async {
    if (_vm.firebaseUser == null) return;

    final profileUserId = widget.userId ?? _vm.firebaseUser!.uid;

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
            builder: (context, scrollController) {
              final colors = context.colors;
              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.only(
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
                        color: colors.border,
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
                                      color: colors.textSecondary,
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
                              return _buildFollowingListTile(
                                user,
                                setModalState,
                                colors,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getFollowersListForUser(
    String userId,
  ) async {
    if (_vm.firebaseUser == null) return [];

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
      AppLogger.e('Error fetching followers for user $userId: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getFollowingListForUser(
    String userId,
  ) async {
    if (_vm.firebaseUser == null) return [];

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
      AppLogger.e('Error fetching following for user $userId: $e');
      return [];
    }
  }

  // List tile for FOLLOWERS list - shows "Follow Back" button
  Widget _buildFollowerListTile(
    Map<String, dynamic> user,
    StateSetter setModalState,
    AppTheme colors,
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
        style: TextStyle(fontSize: 13, color: colors.textSecondary),
      ),
      trailing: uid != _vm.firebaseUser?.uid
          ? FutureBuilder<bool>(
              future: _userService.isFollowing(_vm.firebaseUser!.uid, uid),
              builder: (context, snapshot) {
                final isFollowingBack = snapshot.data ?? false;

                return OutlinedButton(
                  onPressed: () async {
                    if (isFollowingBack) {
                      await _userService.unfollow(_vm.firebaseUser!.uid, uid);
                    } else {
                      await _userService.toggleFollow(
                        uid,
                        _vm.firebaseUser!.uid,
                      );
                    }
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
                        ? colors.surface
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
    AppTheme colors,
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
        style: TextStyle(fontSize: 13, color: colors.textSecondary),
      ),
      trailing: uid != _vm.firebaseUser?.uid
          ? OutlinedButton(
              onPressed: () async {
                await _userService.unfollow(_vm.firebaseUser!.uid, uid);
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
                backgroundColor: colors.surface,
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
