import 'package:flutter/material.dart';
import 'notification_screen.dart';
import '../../components/do_and_dont.dart';
import '../../components/event_calendar.dart';
import '../../components/connectivity_banner.dart';
import '../../models/calendar_model.dart';
import '../../theme/color.dart';
import '../../services/firebase_auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// booking service/model not required here; we query Firestore directly for calendar aggregation
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
  int _selectedSegmentIndex = 0;
  late List<TrekDay> _trekDays;
  User? _firebaseUser;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;

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
        .listen((snap) {
          // Map date -> booked slots. Count each booking as 1 + numberOfPorters
          final Map<String, int> slotsPerDay = {};
          for (final doc in snap.docs) {
            final data = doc.data();
            final Timestamp? t = data['trekDate'] as Timestamp?;
            if (t == null) continue;
            final d = t.toDate();
            final key = '${d.year}-${d.month}-${d.day}';
            final porters = (data['numberOfPorters'] as num?)?.toInt() ?? 0;
            final used =
                1 + porters; // each booking occupies the requester + porters
            slotsPerDay[key] = (slotsPerDay[key] ?? 0) + used;
          }

          // Rebuild trekDays for the month using a maxSlots of 30
          setState(() {
            final now = month;
            final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
            _trekDays = List.generate(daysInMonth, (index) {
              final date = DateTime(now.year, now.month, index + 1);
              final key = '${date.year}-${date.month}-${date.day}';
              final booked = slotsPerDay[key] ?? 0;
              const maxSlots = 30;
              TrekDayStatus status;
              if (booked >= maxSlots) {
                status = TrekDayStatus.full;
              } else if (booked >= (maxSlots - 5)) {
                status = TrekDayStatus.critical;
              } else {
                status = TrekDayStatus.available;
              }
              final isResearchDay = date.weekday == DateTime.wednesday;
              return TrekDay(
                date: date,
                status: status,
                isResearchDay: isResearchDay,
                bookedSlots: booked,
                maxSlots: maxSlots,
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
                      const SizedBox(height: 20),
                      _buildCalendar(),
                      const SizedBox(height: 20),
                      DoAndDont(
                        selectedIndex: _selectedSegmentIndex,
                        onSegmentTapped: (index) {
                          setState(() {
                            _selectedSegmentIndex = index;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  backgroundImage: _firebaseUser?.photoURL != null
                      ? NetworkImage(_firebaseUser!.photoURL!)
                      : null,
                  child: _firebaseUser?.photoURL == null
                      ? const Icon(Icons.person, color: AppColors.iconPrimary)
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
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
                      _firebaseUser?.displayName ??
                          _firebaseUser?.email?.split('@').first ??
                          'Grmpycrab!',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 24),
                tooltip: 'Refresh calendar',
                onPressed: () => _subscribeBookingsForMonth(DateTime.now()),
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 28),
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

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.only(top: 2, left: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10), // Shadow color with opacity
            blurRadius: 10, // How blurred/soft the shadow is
            offset: const Offset(2, 2), // Horizontal and vertical offset
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trek Schedule',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          EventCalendar(
            trekDays: _trekDays,
            onMonthChanged: (d) => _subscribeBookingsForMonth(d),
            onDaySelected: (date) {
              // Handle day selection
              if (_trekDays.any(
                (day) =>
                    day.date.year == date.year &&
                    day.date.month == date.month &&
                    day.date.day == date.day &&
                    day.isAvailable,
              )) {
                // Navigate to booking screen or show booking dialog
                print('Selected available date: $date');
              }
            },
          ),
        ],
      ),
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
      final Timestamp? t = data['trekDate'] as Timestamp?;
      if (t == null) continue;
      final d = t.toDate();
      final key = '${d.year}-${d.month}-${d.day}';
      final porters = (data['numberOfPorters'] as num?)?.toInt() ?? 0;
      final used = 1 + porters;
      slotsPerDay[key] = (slotsPerDay[key] ?? 0) + used;
    }

    if (!mounted) return;
    setState(() {
      final now = month;
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      _trekDays = List.generate(daysInMonth, (index) {
        final date = DateTime(now.year, now.month, index + 1);
        final key = '${date.year}-${date.month}-${date.day}';
        final booked = slotsPerDay[key] ?? 0;
        const maxSlots = 30;
        TrekDayStatus status;
        if (booked >= maxSlots) {
          status = TrekDayStatus.full;
        } else if (booked >= (maxSlots - 5)) {
          status = TrekDayStatus.critical;
        } else {
          status = TrekDayStatus.available;
        }
        final isResearchDay = date.weekday == DateTime.wednesday;
        return TrekDay(
          date: date,
          status: status,
          isResearchDay: isResearchDay,
          bookedSlots: booked,
          maxSlots: maxSlots,
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
            color: Colors.black.withOpacity(0.06),
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
}
