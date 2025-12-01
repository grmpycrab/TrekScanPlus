import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notification_screen.dart';
import '../../components/event_calendar.dart';
import '../../components/connectivity_banner.dart';
import '../../components/social_card.dart';
import '../../components/app_dialogue_handler.dart';
import '../../components/create_post.dart';
import '../../components/comments_sheet.dart';
import '../../components/do_and_dont.dart';
import '../../components/trek_tips.dart';
import '../../components/banner_slideshow.dart';
import '../../components/profile_avatar_with_status.dart';
import '../../services/presence_service.dart';
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
import '../../utils/image_cache_manager.dart';

class HomeScreen extends StatefulWidget {
  final Function(DateTime)? onNavigateToBooking;

  const HomeScreen({super.key, this.onNavigateToBooking});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  //int _selectedNavIndex = 0;
  late ValueNotifier<List<TrekDay>> _trekDaysNotifier;
  User? _firebaseUser;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;
  final UserService _userService = UserService.instance;

  // Search functionality
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // FAB expansion
  bool _isFabExpanded = false;

  // Banner animation
  late AnimationController _bannerAnimationController;
  late Animation<double> _bannerSlideAnimation;

  // Collapsible sections
  bool _areSectionsVisible = true;

  @override
  void initState() {
    super.initState();
    _initializeTrekDays();
    _firebaseUser = FirebaseAuthService.instance.currentUser;

    // Initialize banner animation controller
    _bannerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bannerSlideAnimation = Tween<double>(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(
        parent: _bannerAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _authSubscription = FirebaseAuthService.instance.authStateChanges.listen((
      user,
    ) {
      setState(() {
        _firebaseUser = user;
      });
    });
    // Subscribe to bookings for the current month to update calendar availability
    _subscribeBookingsForMonth(DateTime.now());

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _bookingsSubscription?.cancel();
    _trekDaysNotifier.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _bannerAnimationController.dispose();

    super.dispose();
  }

  void _initializeTrekDays() {
    // Sample trek days for the current month
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    // Initialize with closed status; real statuses will be set when bookings
    // snapshot is received.
    final initialDays = List.generate(daysInMonth, (index) {
      final date = DateTime(now.year, now.month, index + 1);
      final isResearchDay = date.weekday == DateTime.wednesday;
      return TrekDay(
        date: date,
        status: TrekDayStatus.closed,
        isResearchDay: isResearchDay,
        bookedSlots: 0,
      );
    });
    _trekDaysNotifier = ValueNotifier(initialDays);
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
            final key =
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            // Only count trekker, not porters
            final used = 1;
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
          // Use ValueNotifier instead of setState to avoid rebuilding social feed
          final now = month;
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

          // Check if widget is still mounted before updating notifier
          if (!mounted) return;

          _trekDaysNotifier.value = List.generate(daysInMonth, (index) {
            final date = DateTime(now.year, now.month, index + 1);
            final key =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final booked = slotsPerDay[key] ?? 0;
            final dateConfig = dateConfigMap[key];

            // Get max slots for this date (date-specific or system default)
            final maxSlots = dateConfig?.maxSlots ?? defaultMaxSlots;
            var isClosed = dateConfig?.isClosed ?? false;
            var closureReason = dateConfig?.reason;

            // Buffer days are now stored directly in Firebase calendar_config
            // with isTrekDownDay flag, so they come through dateConfig

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
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar color to match header
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const ConnectivityBanner(),
            _buildHeader(),
            _buildCollapsibleSections(),
            _buildSectionToggle(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      _buildSocialFeed(),
                      const SizedBox(
                        height: 30,
                      ), // Bottom padding for comfortable scrolling
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _firebaseUser != null
          ? _buildExpandableFab()
          : null,
    );
  }

  Widget _buildExpandableFab() {
    return StatefulBuilder(
      builder: (context, setFabState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Calendar button (animated)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final offsetAnim = Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offsetAnim, child: child),
                );
              },
              child: _isFabExpanded
                  ? Container(
                      key: const ValueKey('calendar_row'),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSlide(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            offset: _isFabExpanded
                                ? Offset.zero
                                : const Offset(0.25, 0),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              opacity: _isFabExpanded ? 1 : 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'View Calendar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FloatingActionButton(
                            heroTag: 'calendar_fab',
                            onPressed: () {
                              setFabState(() {
                                _isFabExpanded = false;
                              });
                              _showCalendarOverlay();
                            },
                            backgroundColor: AppColors.primary,
                            child: Image.asset(
                              'assets/icons/calendar.png',
                              width: 24,
                              height: 24,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('calendar_row_empty')),
            ),
            // Create post button (animated)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final offsetAnim = Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offsetAnim, child: child),
                );
              },
              child: _isFabExpanded
                  ? Container(
                      key: const ValueKey('create_row'),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSlide(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            offset: _isFabExpanded
                                ? Offset.zero
                                : const Offset(0.25, 0),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              opacity: _isFabExpanded ? 1 : 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'Create Post',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FloatingActionButton(
                            heroTag: 'create_post_fab',
                            onPressed: () {
                              setFabState(() {
                                _isFabExpanded = false;
                              });
                              _showCreatePostDialog();
                            },
                            backgroundColor: AppColors.primary,
                            child: const Icon(Icons.edit, color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('create_row_empty')),
            ),
            // Main FAB
            FloatingActionButton(
              heroTag: 'main_fab',
              onPressed: () {
                setFabState(() {
                  _isFabExpanded = !_isFabExpanded;
                });
              },
              backgroundColor: AppColors.primary,
              child: AnimatedRotation(
                turns: _isFabExpanded ? 0.125 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isFabExpanded ? Icons.close : Icons.add,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return StatefulBuilder(
      builder: (context, setHeaderState) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!_isSearchExpanded)
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
                            ? StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: _userService.streamUser(
                                  _firebaseUser!.uid,
                                ),
                                builder: (context, snapshot) {
                                  String firstName = '';
                                  String lastName = '';

                                  if (snapshot.hasData &&
                                      snapshot.data != null) {
                                    final userData =
                                        snapshot.data!.data() ?? {};
                                    firstName = userData['firstName'] ?? '';
                                    lastName = userData['lastName'] ?? '';
                                  }

                                  // Fallback to Firebase displayName if no Firestore data
                                  if (firstName.isEmpty && lastName.isEmpty) {
                                    firstName =
                                        _firebaseUser!.displayName ??
                                        _firebaseUser!.email
                                            ?.split('@')
                                            .first ??
                                        'Traveler';
                                  }

                                  return Row(
                                    children: [
                                      ProfileAvatarWithStatus(
                                        userId: _firebaseUser!.uid,
                                        photoUrl: _firebaseUser?.photoURL,
                                        radius: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                            StreamBuilder<bool>(
                                              stream: PresenceService.instance
                                                  .userOnlineStatus(
                                                    _firebaseUser!.uid,
                                                  ),
                                              builder: (context, snapshot) {
                                                final isOnline =
                                                    snapshot.data ?? false;
                                                return Text(
                                                  isOnline
                                                      ? 'Online'
                                                      : 'Offline',
                                                  style: TextStyle(
                                                    color: isOnline
                                                        ? Colors.green
                                                        : Colors.red,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                );
                                              },
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                  if (_isSearchExpanded)
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Search posts and users...',
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: _isSearchExpanded
                            ? Icon(
                                Icons.close,
                                size: 24,
                                color: AppColors.primary,
                              )
                            : Image.asset(
                                'assets/icons/search.png',
                                width: 24,
                                height: 24,
                                color: _searchQuery.isNotEmpty
                                    ? AppColors.primary
                                    : Colors.black,
                              ),
                        tooltip: _isSearchExpanded
                            ? 'Close search'
                            : 'Search posts',
                        onPressed: _toggleSearch,
                      ),
                      if (!_isSearchExpanded)
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
                                    builder: (context) =>
                                        const NotificationScreen(),
                                  ),
                                );
                              },
                            ),
                            // Show red dot only when there are unread notifications for the signed-in user
                            if (_firebaseUser != null)
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
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
                                      snapshot.hasData &&
                                      snapshot.data!.docs.isNotEmpty;
                                  return hasUnread
                                      ? const Positioned(
                                          right: 12,
                                          top: 12,
                                          child: SizedBox(
                                            width: 8,
                                            height: 8,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color:
                                                    AppColors.notificationDot,
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
            ),
          ],
        );
      },
    );
  }

  void _toggleSearch() {
    _isSearchExpanded = !_isSearchExpanded;
    if (_isSearchExpanded) {
      // Hide banner with slide up animation (FAB remains independent)
      _bannerAnimationController.forward();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    } else {
      // Show banner with slide down animation (FAB remains independent)
      _bannerAnimationController.reverse();
      _searchController.clear();
      _searchFocusNode.unfocus();
    }
    // Force header rebuild only - FAB state remains unchanged
    if (mounted) {
      setState(() {});
    }
  }

  void _showCalendarOverlay() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return ValueListenableBuilder<List<TrekDay>>(
          valueListenable: _trekDaysNotifier,
          builder: (context, trekDays, _) {
            return EventCalendar(
              trekDays: trekDays,
              onDaySelected: (date) {
                // Close the calendar dialog
                Navigator.of(context).pop();

                // Switch to booking tab with selected date
                if (widget.onNavigateToBooking != null) {
                  widget.onNavigateToBooking!(date);
                }
              },
            );
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
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      // Only count trekker, not porters
      final used = 1;
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
    // Use ValueNotifier instead of setState to avoid rebuilding social feed
    final now = month;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    _trekDaysNotifier.value = List.generate(daysInMonth, (index) {
      final date = DateTime(now.year, now.month, index + 1);
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final booked = slotsPerDay[key] ?? 0;
      final dateConfig = dateConfigMap[key];

      // Get max slots for this date (date-specific or system default)
      final maxSlots = dateConfig?.maxSlots ?? defaultMaxSlots;
      var isClosed = dateConfig?.isClosed ?? false;
      var closureReason = dateConfig?.reason;

      // Buffer days are now stored directly in Firebase calendar_config
      // with isTrekDownDay flag, so they come through dateConfig

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

    // Re-subscribe to live updates for the month
    _subscribeBookingsForMonth(month);
  }

  Widget _buildCollapsibleSections() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: (_areSectionsVisible && !_isSearchExpanded) ? null : 0,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _bannerSlideAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _bannerSlideAnimation.value * 200),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: (_areSectionsVisible && !_isSearchExpanded)
                    ? 1.0
                    : 0.0,
                child: Column(
                  children: [const BannerSlideshow(), _buildInfoButtons()],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionToggle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _areSectionsVisible ? 40 : 24,
      color: AppColors.background,
      child: Center(
        child: InkWell(
          onTap: () =>
              setState(() => _areSectionsVisible = !_areSectionsVisible),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _areSectionsVisible
                ? Container(
                    key: const ValueKey('expanded_toggle'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  )
                : Container(
                    key: const ValueKey('collapsed_toggle'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[500],
                      size: 30,
                    ),
                  ),
          ),
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
        // Show existing data while loading new updates to prevent UI jumps
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Error loading posts',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
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

        // Filter posts based on search query
        final filteredPosts = _searchQuery.isEmpty
            ? posts
            : posts.where((post) {
                final captionMatch = post.caption.toLowerCase().contains(
                  _searchQuery,
                );
                final userNameMatch = post.userName.toLowerCase().contains(
                  _searchQuery,
                );
                return captionMatch || userNameMatch;
              }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Community Feed',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.hasData)
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.grey,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_searchQuery.isNotEmpty && filteredPosts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No posts found for "$_searchQuery"',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            // Use ListView.builder for better performance with large lists
            ...filteredPosts.asMap().entries.map((entry) {
              final post = entry.value;

              // Preload images for better UX (do this asynchronously for first 3 posts)
              if (post.imageUrls.isNotEmpty && entry.key < 3) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ImageCacheManager.preloadImages(post.imageUrls, context);
                });
              }

              return Padding(
                key: ValueKey(
                  post.id ?? entry.key,
                ), // Add key for better widget recycling
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SocialCard(
                  post: post,
                  onCommentTap: () => _showCommentsDialog(post),
                  onDelete: () => _handleDeletePost(post),
                ),
              );
            }),
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
