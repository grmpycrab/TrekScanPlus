import 'package:flutter/material.dart';
import '../../components/station_card.dart';
import '../../services/station_service.dart';
import '../../theme/color.dart';
import 'station_detail_screen.dart';

class StationScreen extends StatefulWidget {
  const StationScreen({super.key});

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  int _selectedTabIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeStationService();
  }

  Future<void> _initializeStationService() async {
    // Ensure stations are loaded
    if (!StationService.instance.isLoaded) {
      await StationService.instance.loadStations();
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            const SizedBox(height: 16),
            _buildTabs(),
            const SizedBox(height: 16),
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildVisitedStations()
                  : _buildNotVisitedStations(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary,
      child: Row(
        children: [
          // Left spacer to keep consistent horizontal padding
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: const Text(
                'Stations',
                style: TextStyle(
                  color: AppColors.buttonText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.segmentBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _buildTab(
              0,
              'Visited (${StationService.instance.getVisitedStations().length})',
            ),
            _buildTab(
              1,
              'Not Visited (${StationService.instance.getUnvisitedStations().length})',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String text) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisitedStations() {
    final visitedStations = StationService.instance.getVisitedStations();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You visited these (${visitedStations.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: visitedStations.isEmpty
                ? _buildEmptyVisitedState()
                : ListView.builder(
                    itemCount: visitedStations.length,
                    itemBuilder: (context, index) {
                      final station = visitedStations[index];
                      // Only allow navigation if the station is actually visited
                      return GestureDetector(
                        onTap: station.isVisited
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        StationDetailScreen(station: station),
                                  ),
                                );
                              }
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Scan the QR code at this station to unlock its details',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                        child: StationCard(
                          imagePath: station.images.first,
                          stationName: station.name,
                          difficulty: station.difficulty,
                          elevation: station.elevation,
                          isVisited: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotVisitedStations() {
    final unvisitedStations = StationService.instance.getUnvisitedStations();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not Visited (${unvisitedStations.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: unvisitedStations.isEmpty
                ? _buildEmptyNotVisitedState()
                : ListView.builder(
                    itemCount: unvisitedStations.length,
                    itemBuilder: (context, index) {
                      final station = unvisitedStations[index];
                      return GestureDetector(
                        onTap: () {
                          // Always show message for unvisited stations
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Scan the QR code at this station to unlock its details',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: StationCard(
                          imagePath: station.images.first,
                          stationName: station.name,
                          difficulty: station.difficulty,
                          elevation: station.elevation,
                          isVisited: false,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyVisitedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'Oops! No adventures yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'You haven\'t visited any stations yet. Start your adventure by scanning QR codes at the trail stations!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Use Scanner to get started',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyNotVisitedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration_outlined, size: 80, color: Colors.amber[600]),
          const SizedBox(height: 24),
          Text(
            'Congratulations!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.amber[700],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Amazing! You\'ve completed your journey and visited all the stations on the trail. Well done, explorer!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, color: Colors.amber[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Trail Master Achievement Unlocked!',
                  style: TextStyle(
                    color: Colors.amber[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
