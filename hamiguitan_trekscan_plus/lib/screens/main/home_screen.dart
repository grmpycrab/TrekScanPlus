import 'package:flutter/material.dart';
import 'notification_screen.dart';
import '../../components/event_calendar.dart';
import '../../components/connectivity_banner.dart';
import '../../components/social_card.dart';
import '../../components/app_dialogue_handler.dart';
import '../../components/create_post.dart';
import '../../components/comments_sheet.dart';
import '../../components/do_and_dont.dart';
import '../../components/trek_tips.dart';
import '../../models/calendar_model.dart';
import '../../models/social_model.dart';
import '../../theme/color.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/user_service.dart';
import '../../services/social_sharing_service.dart';
import '../../services/calendar_config_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  //int _selectedNavIndex = 0;
  late List<TrekDay> _trekDays;
  User? _firebaseUser;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;
  final UserService _userService = UserService.instance;

  @override
  void initState() {
    super.initState();
    _initializeTrekDays();
    _firebaseUser = FirebaseAuthService.instance.currentUser;
    _authSubscription = FirebaseAuthService.instance.authStateChanges.listen((
      user,
    ) {
      setState(() {
        _firebaseUser = user;
      });
    });
    // Subscribe to bookings for the current month to update calendar availability
    _subscribeBookingsForMonth(DateTime.now());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  void _initializeTrekDays() {
    // Sample trek days for the current month
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    // Initialize with closed status; real statuses will be set when bookings
    // snapshot is received.
    _trekDays = List.generate(daysInMonth, (index) {
      final date = DateTime(now.year, now.month, index + 1);
      final isResearchDay = date.weekday == DateTime.wednesday;
      return TrekDay(
        date: date,
        status: TrekDayStatus.closed,
        isResearchDay: isResearchDay,
        bookedSlots: 0,
      );
    });
  }

  void _subscribeBookingsForMonth(DateTime month) {
    _bookingsSubscription?.cancel();
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final startTs = Timestamp.fromDate(
      DateTime(firstDay.year, firstDay.month, firstDay.day),
    );
    final endTs = Timestamp.fromDate(lastDay);

    _bookingsSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .where('trekDate', isGreaterThanOrEqualTo: startTs)
        .where('trekDate', isLessThanOrEqualTo: endTs)
        .snapshots()
        .listen((snap) async {
          // Map date -> booked slots. Count each booking as 1 + numberOfPorters
          // Only count approved bookings - pending bookings don't reserve slots
          final Map<String, int> slotsPerDay = {};
          for (final doc in snap.docs) {
            final data = doc.data();
            final status = (data['status'] as String?)?.toLowerCase() ?? '';

            // Only count approved bookings toward the slot limit
            if (status != 'approved') continue;

            final Timestamp? t = data['trekDate'] as Timestamp?;
            if (t == null) continue;
            final d = t.toDate();
            final key = '${d.year}-${d.month}-${d.day}';
            final porters = (data['numberOfPorters'] as num?)?.toInt() ?? 0;
            final used =
                1 + porters; // each booking occupies the requester + porters
            slotsPerDay[key] = (slotsPerDay[key] ?? 0) + used;
          }

          // Get calendar configuration for the month
          final calendarService = CalendarConfigService();
          final systemSettings = await calendarService.getSystemSettings();
          final defaultMaxSlots =
              systemSettings['defaultMaxSlots'] as int? ?? 30;
          final criticalThreshold =
              systemSettings['criticalThreshold'] as int? ?? 5;

          // Get date configs for the month
          final dateConfigMap = await calendarService.getDateRangeConfig(
            firstDay,
            lastDay,
          );

          // Rebuild trekDays for the month using calendar config
          setState(() {
            final now = month;
            final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
            _trekDays = List.generate(daysInMonth, (index) {
              final date = DateTime(now.year, now.month, index + 1);
              final key = '${date.year}-${date.month}-${date.day}';
              final booked = slotsPerDay[key] ?? 0;
              final dateConfig = dateConfigMap[key];

              // Get max slots for this date (date-specific or system default)
              final maxSlots = dateConfig?.maxSlots ?? defaultMaxSlots;
              final isClosed = dateConfig?.isClosed ?? false;
              final closureReason = dateConfig?.reason;

              final isResearchDay = date.weekday == DateTime.wednesday;

              // Use factory method to create TrekDay with proper status
              return TrekDay.fromBookingData(
                date: date,
                bookedSlots: booked,
                maxSlots: maxSlots,
                criticalThreshold: criticalThreshold,
                isClosed: isClosed,
                closureReason: closureReason,
                isResearchDay: isResearchDay,
              );
            });
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const ConnectivityBanner(),
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWelcomeBanner(),
                      const SizedBox(height: 8),
                      _buildInfoButtons(),
                      const SizedBox(height: 20),
                      _buildSocialFeed(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _firebaseUser != null
          ? FloatingActionButton(
              onPressed: _showCreatePostDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              child: _firebaseUser != null
                  ? StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _userService.streamUser(_firebaseUser!.uid),
                      builder: (context, snapshot) {
                        String firstName = '';
                        String lastName = '';

                        if (snapshot.hasData && snapshot.data != null) {
                          final userData = snapshot.data!.data() ?? {};
                          firstName = userData['firstName'] ?? '';
                          lastName = userData['lastName'] ?? '';
                        }

                        // Fallback to Firebase displayName if no Firestore data
                        if (firstName.isEmpty && lastName.isEmpty) {
                          firstName =
                              _firebaseUser!.displayName ??
                              _firebaseUser!.email?.split('@').first ??
                              'Traveler';
                        }

                        return Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary,
                              backgroundImage: _firebaseUser?.photoURL != null
                                  ? NetworkImage(_firebaseUser!.photoURL!)
                                  : null,
                              child: _firebaseUser?.photoURL == null
                                  ? const Icon(
                                      Icons.person,
                                      color: AppColors.iconPrimary,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Welcome,',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    firstName.isNotEmpty
                                        ? '$firstName ${lastName.isNotEmpty ? lastName : ''}'
                                              .trim()
                                        : 'Traveler!',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: const Icon(
                            Icons.person,
                            color: AppColors.iconPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Welcome,',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Traveler!',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.calendar_today, size: 24),
                tooltip: 'View calendar',
                onPressed: _showCalendarOverlay,
              ),
              Stack(
                children: [
                  IconButton(
                    icon: Image.asset(
                      'assets/icons/bell.png',
                      width: 28,
                      height: 28,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationScreen(),
                        ),
                      );
                    },
                  ),
                  // Show red dot only when there are unread notifications for the signed-in user
                  if (_firebaseUser != null)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(_firebaseUser!.uid)
                          .collection('notifications')
                          .where('isRead', isEqualTo: false)
                          .limit(1)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (_firebaseUser == null) {
                          return const SizedBox.shrink();
                        }
                        final hasUnread =
                            snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                        return hasUnread
                            ? const Positioned(
                                right: 12,
                                top: 12,
                                child: SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppColors.notificationDot,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCalendarOverlay() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return EventCalendar(
          trekDays: _trekDays,
          onDaySelected: (date) {
            if (_trekDays.any(
              (day) =>
                  day.date.year == date.year &&
                  day.date.month == date.month &&
                  day.date.day == date.day &&
                  day.isAvailable,
            )) {}
          },
        );
      },
    );
  }

  /// Pull-to-refresh handler for the Home screen. Performs a one-time
  /// query for the current month and updates the calendar immediately.
  Future<void> _refreshAll() async {
    final month = DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final startTs = Timestamp.fromDate(
      DateTime(firstDay.year, firstDay.month, firstDay.day),
    );
    final endTs = Timestamp.fromDate(lastDay);

    // Cancel current subscription to avoid stale data
    _bookingsSubscription?.cancel();

    final snap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('trekDate', isGreaterThanOrEqualTo: startTs)
        .where('trekDate', isLessThanOrEqualTo: endTs)
        .get();

    final Map<String, int> slotsPerDay = {};
    for (final doc in snap.docs) {
      final data = doc.data();
      final status = (data['status'] as String?)?.toLowerCase() ?? '';

      // Only count approved bookings - pending bookings don't reserve slots
      if (status != 'approved') continue;

      final Timestamp? t = data['trekDate'] as Timestamp?;
      if (t == null) continue;
      final d = t.toDate();
      final key = '${d.year}-${d.month}-${d.day}';
      final porters = (data['numberOfPorters'] as num?)?.toInt() ?? 0;
      final used = 1 + porters;
      slotsPerDay[key] = (slotsPerDay[key] ?? 0) + used;
    }

    // Get calendar configuration for the month
    final calendarService = CalendarConfigService();
    final systemSettings = await calendarService.getSystemSettings();
    final defaultMaxSlots = systemSettings['defaultMaxSlots'] as int? ?? 30;
    final criticalThreshold = systemSettings['criticalThreshold'] as int? ?? 5;

    // Get date configs for the month
    final dateConfigMap = await calendarService.getDateRangeConfig(
      firstDay,
      lastDay,
    );

    if (!mounted) return;
    setState(() {
      final now = month;
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      _trekDays = List.generate(daysInMonth, (index) {
        final date = DateTime(now.year, now.month, index + 1);
        final key = '${date.year}-${date.month}-${date.day}';
        final booked = slotsPerDay[key] ?? 0;
        final dateConfig = dateConfigMap[key];

        // Get max slots for this date (date-specific or system default)
        final maxSlots = dateConfig?.maxSlots ?? defaultMaxSlots;
        final isClosed = dateConfig?.isClosed ?? false;
        final closureReason = dateConfig?.reason;

        final isResearchDay = date.weekday == DateTime.wednesday;

        // Use factory method to create TrekDay with proper status
        return TrekDay.fromBookingData(
          date: date,
          bookedSlots: booked,
          maxSlots: maxSlots,
          criticalThreshold: criticalThreshold,
          isClosed: isClosed,
          closureReason: closureReason,
          isResearchDay: isResearchDay,
        );
      });
    });

    // Re-subscribe to live updates for the month
    _subscribeBookingsForMonth(month);
  }

  Widget _buildWelcomeBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      clipBehavior: Clip.none,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252B30),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 160,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Mt. Hamiguitan Trek Scan Plus',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Explore the unique beauty and biodiversity of Mt. Hamiguitan, a UNESCO World Heritage Site.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // Illustration on the right. use an OverflowBox so the image can extend outside the card
            SizedBox(
              width: 140,
              child: Transform.translate(
                offset: const Offset(6, 0),
                child: Image.asset(
                  'assets/images/Trekking.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      Icon(Icons.landscape, size: 72, color: Colors.brown[300]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoButtons() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12.0 : 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoButton(
              title: "Do's & Dont's",
              icon: Icons.rule,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => _showDosAndDontsOverlay(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildInfoButton(
              title: 'Tips & Tricks',
              icon: Icons.lightbulb_outline,
              gradient: LinearGradient(
                colors: [const Color(0xFF06402B), const Color(0xFF053821)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => _showTipsAndTricksOverlay(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoButton({
    required String title,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDosAndDontsOverlay() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const DoAndDontOverlay(),
    );
  }

  void _showTipsAndTricksOverlay() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const TrekTipsOverlay(),
    );
  }

  Widget _buildSocialFeed() {
    if (_firebaseUser == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Sign in to view posts')),
      );
    }

    return StreamBuilder<List<SocialPost>>(
      stream: SocialSharingService.instance.streamPublicPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is FirebaseException && error.message != null) {
            debugPrint('Firestore index error: ${error.message}');
          }
          return Text('Error loading posts');
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'No posts yet. Be the first to share your experience!',
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Community Feed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...posts.map(
              (post) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SocialCard(
                  post: post,
                  onCommentTap: () => _showCommentsDialog(post),
                  onDelete: () => _handleDeletePost(post),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePostDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePostSheet(
        onPostCreated: () {
          // Optionally refresh the feed or show a notification
          debugPrint('Post created successfully');
        },
      ),
    );
  }

  void _showCommentsDialog(SocialPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(postId: post.id!, post: post),
    );
  }

  Future<void> _handleDeletePost(SocialPost post) async {
    if (post.id == null) return;

    final confirmed = await AppDialogueHandler.showConfirmation(
      context: context,
      title: 'Delete Post',
      message: 'Are you sure you want to delete this post?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await SocialSharingService.instance.deletePost(post.id!);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Post deleted')));
        }
      } catch (e) {
        if (mounted) {
          await AppDialogueHandler.showError(
            context: context,
            title: 'Delete Failed',
            message: 'Unable to delete post. Please try again.',
          );
        }
      }
    }
  }
}
