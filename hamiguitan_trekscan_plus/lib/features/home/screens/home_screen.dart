import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamiguitan_trekscan_plus/features/social/models/social_model.dart';
import 'package:hamiguitan_trekscan_plus/features/social/repositories/social_repository.dart';
import 'package:hamiguitan_trekscan_plus/features/social/widgets/comments_sheet.dart';
import 'package:hamiguitan_trekscan_plus/features/social/widgets/create_post_sheet.dart';
import '../widgets/event_calendar.dart';
import '../../../core/widgets/connectivity_banner.dart';
import '../../../core/widgets/app_dialogue_handler.dart';
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
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  final Function(DateTime)? onNavigateToBooking;

  const HomeScreen({super.key, this.onNavigateToBooking});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _viewModel;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Shared FAB expanded state — HomeScreen owns it, HomeActionButtons syncs it
  final ValueNotifier<bool> _fabExpanded = ValueNotifier(false);

  // Feed filtering (set by the drawer's search)
  String _searchQuery = '';

  // Collapsible banner toggle
  bool _areSectionsVisible = true;

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.initialize();
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
    _fabExpanded.dispose();
    super.dispose();
  }

  // ── Action handlers ────────────────────────────────────────────────────────

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

  // ── Build ──────────────────────────────────────────────────────────────────

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
      key: _scaffoldKey,
      backgroundColor: colors.background,
      endDrawer: AppDrawer(
        userId: user?.uid,
        currentSearchQuery: _searchQuery,
        onSearchSubmitted: (query) {
          setState(() => _searchQuery = query.toLowerCase());
        },
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const ConnectivityBanner(),
                // ── Unified header + banner surface block ────────────────
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: colors.border,
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      HomeHeader(
                        userId: user?.uid,
                        userPhotoUrl: user?.photoURL,
                        onProfileTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        ),
                        onMenuTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                      ),
                      BannerSlideshow(
                        isCollapsed: !_areSectionsVisible,
                        onToggle: () => setState(
                          () => _areSectionsVisible = !_areSectionsVisible,
                        ),
                      ),
                    ],
                  ),
                ),
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
          // FAB backdrop — dims content when FAB is expanded; tap to dismiss
          ValueListenableBuilder<bool>(
            valueListenable: _fabExpanded,
            builder: (context, isExpanded, _) => IgnorePointer(
              ignoring: !isExpanded,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _fabExpanded.value = false,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: isExpanded ? 1.0 : 0.0,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: user != null
          ? HomeActionButtons(
              onCreatePost: _showCreatePostDialog,
              onShowCalendar: _showCalendarOverlay,
              expandedNotifier: _fabExpanded,
            )
          : null,
    );
  }


}
