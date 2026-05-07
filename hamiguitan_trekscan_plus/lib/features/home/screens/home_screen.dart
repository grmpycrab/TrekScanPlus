import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamiguitan_trekscan_plus/features/social/models/social_model.dart';
import 'package:hamiguitan_trekscan_plus/features/social/repositories/social_repository.dart';
import 'package:hamiguitan_trekscan_plus/features/social/widgets/comments_sheet.dart';
import 'package:hamiguitan_trekscan_plus/features/social/widgets/create_post_sheet.dart';
import '../widgets/event_calendar.dart';
import '../../../core/widgets/connectivity_banner.dart';
import '../../../core/widgets/app_dialogue_handler.dart';
import '../widgets/do_and_dont.dart';
import '../widgets/trek_tips.dart';
import '../widgets/banner_slideshow.dart';
import '../../../theme/app_theme.dart';
import 'dart:async';
import '../../profile/screens/profile_screen.dart';
import '../../../utils/app_logger.dart';
import '../../../utils/image_cache_manager.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/home_header.dart';
import '../widgets/home_social_feed.dart';
import '../widgets/home_action_buttons.dart';

class HomeScreen extends StatefulWidget {
  final Function(DateTime)? onNavigateToBooking;

  const HomeScreen({super.key, this.onNavigateToBooking});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final HomeViewModel _viewModel;

  // Search
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // Banner animation
  late AnimationController _bannerAnimationController;
  late Animation<double> _bannerSlideAnimation;

  // Collapsible sections toggle
  bool _areSectionsVisible = true;

  @override
  void initState() {
    super.initState();

    _viewModel = HomeViewModel();

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

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.initialize();
    // Load first page and preload images in the widget layer where
    // a valid BuildContext is available.
    _viewModel.loadFirstPage().then((_) {
      if (!mounted) return;
      for (int i = 0; i < _viewModel.loadedPosts.length && i < 3; i++) {
        final urls = _viewModel.loadedPosts[i].imageUrls;
        if (urls.isNotEmpty) {
          ImageCacheManager.preloadImages(urls, context);
        }
      }
    });
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _bannerAnimationController.dispose();
    super.dispose();
  }

  // -- Helpers --------------------------------------------------------------

  void _toggleSearch() {
    _isSearchExpanded = !_isSearchExpanded;
    if (_isSearchExpanded) {
      _bannerAnimationController.forward();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _searchFocusNode.requestFocus();
      });
    } else {
      _bannerAnimationController.reverse();
      _searchController.clear();
      _searchFocusNode.unfocus();
    }
    if (mounted) setState(() {});
  }

  void _showCalendarOverlay() {
    _viewModel.trackCalendarViewed();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return ValueListenableBuilder(
          valueListenable: _viewModel.trekDaysNotifier,
          builder: (context, trekDays, _) {
            return EventCalendar(
              trekDays: trekDays,
              onDaySelected: (date) {
                Navigator.of(context).pop();
                widget.onNavigateToBooking?.call(date);
              },
            );
          },
        );
      },
    );
  }

  void _showCreatePostDialog() {
    _viewModel.trackPostCreated();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatePostSheet(
        onPostCreated: () => AppLogger.i('Post created successfully'),
      ),
    );
  }

  void _showCommentsDialog(SocialPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: post.id!, post: post),
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

  Future<void> _refreshAll() async {
    try {
      await _viewModel.refreshAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error refreshing: $e')));
      }
    }
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.isDarkMode
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: context.isDarkMode
            ? Brightness.dark
            : Brightness.light,
      ),
    );

    final user = _viewModel.firebaseUser;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const ConnectivityBanner(),
            HomeHeader(
              userId: user?.uid,
              userPhotoUrl: user?.photoURL,
              isSearchExpanded: _isSearchExpanded,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              searchQuery: _searchQuery,
              onToggleSearch: _toggleSearch,
              onProfileTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
            _buildCollapsibleSections(),
            _buildSectionToggle(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                child: HomeSocialFeed(
                  viewModel: _viewModel,
                  searchQuery: _searchQuery,
                  onShowComments: _showCommentsDialog,
                  onDeletePost: _handleDeletePost,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: user != null
          ? HomeActionButtons(
              onCreatePost: _showCreatePostDialog,
              onShowCalendar: _showCalendarOverlay,
            )
          : null,
    );
  }

  // -- Collapsible banner + info buttons -------------------------------------

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
    final colors = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _areSectionsVisible ? 40 : 24,
      color: colors.background,
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
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.borderLight, width: 1),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: colors.textSecondary,
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
                      color: colors.background,
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
    final colors = context.colors;
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
                colors: [colors.primary, colors.primary.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => showDialog(
                context: context,
                barrierDismissible: true,
                builder: (_) => const DoAndDontOverlay(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildInfoButton(
              title: 'Tips & Tricks',
              icon: Icons.lightbulb_outline,
              gradient: LinearGradient(
                colors: [colors.accent, const Color(0xFF053821)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => showDialog(
                context: context,
                barrierDismissible: true,
                builder: (_) => const TrekTipsOverlay(),
              ),
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
}
