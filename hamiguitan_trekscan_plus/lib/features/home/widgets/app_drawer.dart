import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../notification/viewmodels/notification_view_model.dart';
import '../../notification/models/notification_model.dart';
import 'trek_tips.dart';

enum _DrawerPage { main, notifications, guidelines, tips }

class _GuidelineItem {
  final String title;
  final String description;
  const _GuidelineItem(this.title, this.description);
}

class AppDrawer extends StatefulWidget {
  final String? userId;
  final String currentSearchQuery;
  final ValueChanged<String> onSearchSubmitted;

  const AppDrawer({
    super.key,
    this.userId,
    required this.currentSearchQuery,
    required this.onSearchSubmitted,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  _DrawerPage _page = _DrawerPage.main;
  bool _isForward = true;

  late final TextEditingController _searchController;
  final List<String> _recentSearches = [];
  late final NotificationViewModel _notifVm;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.currentSearchQuery);
    _notifVm = NotificationViewModel();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notifVm.dispose();
    super.dispose();
  }

  void _push(_DrawerPage page) {
    setState(() {
      _isForward = true;
      _page = page;
    });
  }

  void _pop() {
    setState(() {
      _isForward = false;
      _page = _DrawerPage.main;
    });
  }

  void _submitSearch(BuildContext context) {
    final query = _searchController.text.trim();
    if (query.isNotEmpty && !_recentSearches.contains(query)) {
      setState(() {
        _recentSearches.insert(0, query);
        if (_recentSearches.length > 5) _recentSearches.removeLast();
      });
    }
    widget.onSearchSubmitted(query);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.topLeft,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          transitionBuilder: (child, animation) {
            final begin = _isForward
                ? const Offset(0.2, 0.0)
                : const Offset(-0.2, 0.0);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_page),
            child: _buildCurrentPage(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage(BuildContext context) {
    switch (_page) {
      case _DrawerPage.main:
        return _buildMainPage(context);
      case _DrawerPage.notifications:
        return _buildNotificationsPage(context);
      case _DrawerPage.guidelines:
        return _buildGuidelinesPage(context);
      case _DrawerPage.tips:
        return _buildTipsPage(context);
    }
  }

  // ── Main page ──────────────────────────────────────────────────────────────

  Widget _buildMainPage(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(
              children: [
                Text(
                  'Menu',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(context),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search posts and users...',
                hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search,
                  color: colors.textSecondary,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          color: colors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          widget.onSearchSubmitted('');
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.borderLight, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Recent searches
          if (_recentSearches.isNotEmpty && _searchController.text.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    'RECENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _recentSearches.clear()),
                    child: Text(
                      'Clear',
                      style: TextStyle(fontSize: 12, color: colors.primary),
                    ),
                  ),
                ],
              ),
            ),
            ..._recentSearches.map(
              (query) => InkWell(
                onTap: () {
                  _searchController.text = query;
                  _submitSearch(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          query,
                          style: TextStyle(fontSize: 14, color: colors.text),
                        ),
                      ),
                      Icon(
                        Icons.north_west,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          Divider(height: 20, color: colors.borderLight),

          // Notifications
          _buildNavTile(
            context,
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            trailing: _buildNotifBadge(context),
            onTap: () => _push(_DrawerPage.notifications),
          ),

          Divider(height: 1, indent: 56, color: colors.borderLight),

          // Community Guidelines
          _buildNavTile(
            context,
            icon: Icons.shield_outlined,
            label: 'Community Guidelines',
            onTap: () => _push(_DrawerPage.guidelines),
          ),

          // Tips & Tricks
          _buildNavTile(
            context,
            icon: Icons.lightbulb_outline,
            label: 'Tips & Tricks',
            onTap: () => _push(_DrawerPage.tips),
          ),

          Divider(height: 20, color: colors.borderLight),

          // Support / Help
          _buildNavTile(
            context,
            icon: Icons.help_outline,
            label: 'Support / Help',
            showChevron: false,
            onTap: () => _showSupportSheet(context),
          ),

          // About / Updates
          _buildNavTile(
            context,
            icon: Icons.info_outline,
            label: 'About / Updates',
            showChevron: false,
            onTap: () => _showAboutSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
    bool showChevron = true,
  }) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: context.isDarkMode ? colors.iconSubtle : colors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.text,
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else if (showChevron)
              Icon(Icons.chevron_right, color: colors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifBadge(BuildContext context) {
    final colors = context.colors;
    final userId = widget.userId;
    if (userId == null) {
      return Icon(Icons.chevron_right, color: colors.textSecondary, size: 20);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.data?.docs.length ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
        Icon(Icons.chevron_right, color: colors.textSecondary, size: 20),
      ],
    );
  }

  // ── Shared sub-page header ─────────────────────────────────────────────────

  Widget _buildSubPageHeader(
    BuildContext context,
    String title, {
    Widget? action,
  }) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(color: colors.borderLight, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: colors.text, size: 22),
            onPressed: _pop,
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  // ── Notifications page ─────────────────────────────────────────────────────

  Widget _buildNotificationsPage(BuildContext context) {
    final colors = context.colors;
    final userId = widget.userId;

    return Column(
      children: [
        _buildSubPageHeader(
          context,
          'Notifications',
          action: userId != null
              ? TextButton(
                  onPressed: () async {
                    await _notifVm.markAllAsRead(userId);
                    if (mounted) setState(() {});
                  },
                  child: Text(
                    'Mark all read',
                    style: TextStyle(color: colors.primary, fontSize: 12),
                  ),
                )
              : null,
        ),
        Expanded(
          child: userId == null
              ? Center(
                  child: Text(
                    'Sign in to see notifications',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                )
              : StreamBuilder<List<NotificationModel>>(
                  stream: _notifVm.notificationsStream(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No notifications',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "You're all caught up!",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: colors.borderLight,
                      ),
                      itemBuilder: (context, i) =>
                          _buildNotifItem(context, items[i], userId),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNotifItem(
    BuildContext context,
    NotificationModel notification,
    String userId,
  ) {
    final colors = context.colors;
    IconData icon;
    Color iconColor;
    switch (notification.type) {
      case NotificationType.success:
        icon = Icons.check_circle_outline;
        iconColor = Colors.green;
        break;
      case NotificationType.warning:
        icon = Icons.warning_amber_outlined;
        iconColor = Colors.orange;
        break;
      case NotificationType.alert:
        icon = Icons.notification_important_outlined;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.info_outline;
        iconColor = Colors.blue;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red.withValues(alpha: 0.08),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
      ),
      onDismissed: (_) => _notifVm.deleteNotification(userId, notification.id),
      child: InkWell(
        onTap: () async {
          final nav = Navigator.of(context);
          await _notifVm.markAsRead(userId, notification.id);
          if (mounted) setState(() => notification.isRead = true);
          nav.pop();
          _navigateForNotification(nav, notification);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: notification.isRead
              ? Colors.transparent
              : colors.primary.withValues(alpha: 0.05),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              fontSize: 13,
                              color: colors.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _notifVm.formatTimestamp(notification.timestamp),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateForNotification(
    NavigatorState nav,
    NotificationModel notification,
  ) {
    if (notification.actionType == 'post' && notification.actionData != null) {
      nav.pushNamed('/post-detail', arguments: notification.actionData);
    }
  }

  // ── Community Guidelines page ──────────────────────────────────────────────

  Widget _buildGuidelinesPage(BuildContext context) {
    final colors = context.colors;

    const doItems = [
      _GuidelineItem(
        'Secure a permit ahead of time',
        'Coordinate with the MHRWS Protected Area Management Office (PAMO).',
      ),
      _GuidelineItem(
        'Submit required documentation',
        'Medical certificate, valid ID, and signed waiver are required.',
      ),
      _GuidelineItem(
        'Hire a local guide',
        'Guided treks are mandatory — guides support safety and local livelihoods.',
      ),
      _GuidelineItem(
        'Follow trail regulations',
        'Stay on approved trails and use designated campsites only.',
      ),
      _GuidelineItem(
        'Leave no trace',
        'What you bring up, bring down. Leave nothing behind.',
      ),
      _GuidelineItem(
        'Respect wildlife and plants',
        "Do not feed animals or disturb nesting and breeding areas.",
      ),
    ];

    const avoidItems = [
      _GuidelineItem(
        'Walking in without a permit',
        'Walk-in trekkers are generally not allowed.',
      ),
      _GuidelineItem(
        'Straying off the trail',
        'Some trails are permanently closed or restricted.',
      ),
      _GuidelineItem(
        'Littering, burning, or polluting',
        'No waste dumping, no soap in streams, no cigarette butts.',
      ),
      _GuidelineItem(
        'Disturbing wildlife or picking plants',
        "Protected area with endemic species — leave everything in place.",
      ),
      _GuidelineItem(
        'Ignoring physical fitness requirements',
        'Trails are demanding; be properly prepared in fitness and gear.',
      ),
      _GuidelineItem(
        'Disruptive noise',
        'Respect the quietness of the forest and other trekkers.',
      ),
    ];

    const safetyItems = [
      _GuidelineItem(
        'Check weather before going',
        'Mountain conditions can change rapidly — always check forecasts.',
      ),
      _GuidelineItem(
        'Inform someone of your itinerary',
        'Share your plan and expected return time with a contact.',
      ),
      _GuidelineItem(
        'Carry a first aid kit',
        'Be prepared for minor injuries on the trail.',
      ),
      _GuidelineItem(
        'Know emergency contacts',
        'Keep PAMO and local rescue service numbers accessible.',
      ),
    ];

    return Column(
      children: [
        _buildSubPageHeader(context, 'Community Guidelines'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildGuidelinesSection(
                  context,
                  title: 'Recommended',
                  color: Colors.green,
                  items: doItems,
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildGuidelinesSection(
                  context,
                  title: 'Avoid',
                  color: Colors.red,
                  items: avoidItems,
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildGuidelinesSection(
                  context,
                  title: 'Safety Notes',
                  color: Colors.orange,
                  items: safetyItems,
                  colors: colors,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuidelinesSection(
    BuildContext context, {
    required String title,
    required Color color,
    required List<_GuidelineItem> items,
    required AppTheme colors,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: items
                  .map(
                    (item) => _buildGuidelineCard(
                      item.title,
                      item.description,
                      color,
                      colors,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineCard(
    String title,
    String desc,
    Color color,
    AppTheme colors,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tips & Tricks page ─────────────────────────────────────────────────────

  Widget _buildTipsPage(BuildContext context) {
    return Column(
      children: [
        _buildSubPageHeader(context, 'Tips & Tricks'),
        // TrekTips already wraps content in SingleChildScrollView,
        // so we expand it directly to fill the remaining drawer height.
        const Expanded(child: TrekTips()),
      ],
    );
  }

  // ── Support & About sheets ─────────────────────────────────────────────────

  void _showSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UtilitySheet(
        icon: Icons.help_outline,
        title: 'Support / Help',
        content:
            'For assistance, please contact our support team or visit our help center.',
        primaryAction: 'Contact Support',
        onPrimaryTap: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UtilitySheet(
        icon: Icons.info_outline,
        title: 'About TrekScanPlus',
        content:
            'TrekScanPlus — Your companion for Mt. Hamiguitan trekking.\n\nVersion 1.0.0',
        primaryAction: 'Close',
        onPrimaryTap: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

// ── Utility bottom sheet ───────────────────────────────────────────────────────

class _UtilitySheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final String primaryAction;
  final VoidCallback onPrimaryTap;

  const _UtilitySheet({
    required this.icon,
    required this.title,
    required this.content,
    required this.primaryAction,
    required this.onPrimaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: context.isDarkMode ? colors.iconSubtle : colors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimaryTap,
              style: FilledButton.styleFrom(backgroundColor: colors.primary),
              child: Text(primaryAction),
            ),
          ),
        ],
      ),
    );
  }
}
