import 'package:flutter/material.dart';
import '../../components/do_and_dont.dart';
import '../../components/event_calendar.dart';
import '../../models/calendar_model.dart';
import '../../theme/color.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeTrekDays();
  }

  void _initializeTrekDays() {
    // Sample trek days for the current month
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    _trekDays = List.generate(daysInMonth, (index) {
      final date = DateTime(now.year, now.month, index + 1);
      final isWeekend =
          date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

      // Sample logic for research days (e.g., every Wednesday)
      final isResearchDay = date.weekday == DateTime.wednesday;

      // Sample status assignment
      var status = TrekDayStatus.closed;
      if (isWeekend || isResearchDay) {
        final random = index % 3; // Just for demo
        status = random == 0
            ? TrekDayStatus.available
            : random == 1
            ? TrekDayStatus.critical
            : TrekDayStatus.full;
      }

      return TrekDay(
        date: date,
        status: status,
        isResearchDay: isResearchDay,
        bookedSlots: isWeekend ? (index % 20) : 0, // Sample booking data
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: AppColors.iconPrimary),
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
                      'Grmpycrab!',
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
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 28),
                onPressed: () {},
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.notificationDot,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildWelcomeBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.landscape, color: AppColors.iconPrimary),
              SizedBox(width: 8),
              Text(
                'Mt. Hamiguitan',
                style: TextStyle(
                  color: AppColors.buttonText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore the unique beauty and biodiversity of Mt. Hamiguitan, a UNESCO World Heritage Site.',
            style: TextStyle(color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
