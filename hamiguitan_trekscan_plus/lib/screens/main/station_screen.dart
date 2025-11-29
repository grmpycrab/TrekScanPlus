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
            child: ListView.builder(
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
            child: ListView.builder(
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
}
