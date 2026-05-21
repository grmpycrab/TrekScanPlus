import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../models/calendar_model.dart';
import '../../../services/calendar_config_service.dart';
import '../../../services/feed_pagination_service.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../utils/app_logger.dart';
import 'package:hamiguitan_trekscan_plus/features/social/models/social_model.dart';
import '../../../core/services/analytics_service.dart';

class HomeViewModel extends ChangeNotifier {
  bool _disposed = false;
  bool _initialized = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── Auth ─────────────────────────────────────────────────────────────────
  User? _firebaseUser;
  StreamSubscription<User?>? _authSubscription;

  User? get firebaseUser => _firebaseUser;

  // ── Calendar ──────────────────────────────────────────────────────────────
  late ValueNotifier<List<TrekDay>> trekDaysNotifier;
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;

  // ── Feed pagination ───────────────────────────────────────────────────────
  final List<SocialPost> _loadedPosts = [];
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  final FeedPaginationService _paginationService =
      FeedPaginationService.instance;

  List<SocialPost> get loadedPosts => List.unmodifiable(_loadedPosts);
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMorePosts => _hasMorePosts;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _initializeTrekDays();
    _firebaseUser = FirebaseAuthService.instance.currentUser;

    _authSubscription = FirebaseAuthService.instance.authStateChanges.listen((
      user,
    ) {
      _firebaseUser = user;
      _notify();
    });

    _subscribeBookingsForMonth(DateTime.now());
    AnalyticsService.instance.logEvent('home_screen_opened');
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    _bookingsSubscription?.cancel();
    trekDaysNotifier.dispose();
    super.dispose();
  }

  // ── Trek-days / calendar ──────────────────────────────────────────────────

  void _initializeTrekDays() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final initialDays = List.generate(daysInMonth, (index) {
      final date = DateTime(now.year, now.month, index + 1);
      return TrekDay(
        date: date,
        status: TrekDayStatus.closed,
        isResearchDay: date.weekday == DateTime.wednesday,
        bookedSlots: 0,
      );
    });
    trekDaysNotifier = ValueNotifier(initialDays);
  }

  void subscribeBookingsForMonth(DateTime month) =>
      _subscribeBookingsForMonth(month);

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
        .where('status', isEqualTo: 'approved')
        .where('trekDate', isGreaterThanOrEqualTo: startTs)
        .where('trekDate', isLessThanOrEqualTo: endTs)
        .snapshots()
        .listen(
          (snap) async {
            await _updateTrekDaysFromSnap(snap.docs, month);
          },
          onError: (e) => AppLogger.w('Bookings stream error: $e'),
          cancelOnError: true,
        );
  }

  Future<void> _updateTrekDaysFromSnap(
    List<QueryDocumentSnapshot> docs,
    DateTime month,
  ) async {
    final Map<String, int> slotsPerDay = {};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] as String?)?.toLowerCase() ?? '';
      if (status != 'approved') continue;

      final Timestamp? t = data['trekDate'] as Timestamp?;
      if (t == null) continue;
      final d = t.toDate();
      final key = _dateKey(d);
      slotsPerDay[key] = (slotsPerDay[key] ?? 0) + 1;
    }

    final calendarService = CalendarConfigService();
    final systemSettings = await calendarService.getSystemSettings();
    final defaultMaxSlots = systemSettings['defaultMaxSlots'] as int? ?? 30;
    final criticalThreshold = systemSettings['criticalThreshold'] as int? ?? 5;

    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final dateConfigMap = await calendarService.getDateRangeConfig(
      firstDay,
      lastDay,
    );

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    trekDaysNotifier.value = List.generate(daysInMonth, (index) {
      final date = DateTime(month.year, month.month, index + 1);
      final key = _dateKey(date);
      final booked = slotsPerDay[key] ?? 0;
      final dateConfig = dateConfigMap[key];
      final maxSlots = dateConfig?.maxSlots ?? defaultMaxSlots;
      final isClosed = dateConfig?.isClosed ?? false;
      final closureReason = dateConfig?.reason;
      final isResearchDay = date.weekday == DateTime.wednesday;

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
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Refresh all ───────────────────────────────────────────────────────────

  Future<void> refreshAll() async {
    final month = DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final startTs = Timestamp.fromDate(
      DateTime(firstDay.year, firstDay.month, firstDay.day),
    );
    final endTs = Timestamp.fromDate(lastDay);

    _bookingsSubscription?.cancel();

    final snap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('status', isEqualTo: 'approved')
        .where('trekDate', isGreaterThanOrEqualTo: startTs)
        .where('trekDate', isLessThanOrEqualTo: endTs)
        .get();

    await _updateTrekDaysFromSnap(snap.docs, month);

    _subscribeBookingsForMonth(month);

    await loadFirstPage();

    AnalyticsService.instance.logEvent('calendar_viewed');
  }

  // ── Feed pagination ───────────────────────────────────────────────────────

  Future<void> loadFirstPage() async {
    try {
      AppLogger.i('Loading first page of posts...');
      final (posts, hasMore) = await _paginationService
          .loadPublicPostsFirstPage();

      _loadedPosts
        ..clear()
        ..addAll(posts);
      _hasMorePosts = hasMore;
      _isLoadingMore = false;
      _notify();

      // Image pre-loading is handled by the widget layer (HomeSocialFeed/HomeScreen)
      // where a valid BuildContext is available.

      AppLogger.i('  First page loaded: ${posts.length} posts');
    } catch (e) {
      AppLogger.e('Error loading first page: $e');
      _isLoadingMore = false;
      _notify();
      rethrow;
    }
  }

  Future<void> loadNextPage() async {
    if (_isLoadingMore || !_hasMorePosts) return;

    _isLoadingMore = true;
    _notify();

    try {
      AppLogger.i('Loading next page of posts...');
      final (posts, hasMore) = await _paginationService
          .loadPublicPostsNextPage();

      _loadedPosts.addAll(posts);
      _hasMorePosts = hasMore;
      _isLoadingMore = false;
      _notify();

      AppLogger.i('  Next page loaded: ${posts.length} new posts');
    } catch (e) {
      AppLogger.e('Error loading next page: $e');
      _isLoadingMore = false;
      _notify();
      rethrow;
    }
  }

  /// Called by the scroll controller listener in HomeSocialFeed.
  void onFeedScroll(ScrollController controller) {
    if (controller.position.pixels >
        controller.position.maxScrollExtent - 500) {
      loadNextPage();
    }
  }

  // ── Analytics helpers ─────────────────────────────────────────────────────

  void trackPostLiked(String postId) => AnalyticsService.instance.logEvent(
    'post_liked',
    params: {'post_id': postId},
  );

  void trackPostCreated() => AnalyticsService.instance.logEvent('post_created');

  void trackCalendarViewed() =>
      AnalyticsService.instance.logEvent('calendar_viewed');

  void trackScanTriggered() =>
      AnalyticsService.instance.logEvent('scan_triggered');
}
