import 'package:flutter/material.dart';
import '../../components/station_card.dart';
import '../../services/station_service.dart';
import '../../services/climb_session_service.dart';
import '../../theme/color.dart';
import '../../models/climb_session.dart';
import '../../dialogs/new_climb_session_dialog.dart';
import 'station_detail_screen.dart';
import 'climb_session_detail_screen.dart';

class StationScreen extends StatefulWidget {
  const StationScreen({super.key});

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  ClimbSession? _activeSession;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Ensure stations are loaded
    if (!StationService.instance.isLoaded) {
      await StationService.instance.loadStations();
    }

    // Initialize climb session service if needed
    if (!ClimbSessionService.isInitialized) {
      await ClimbSessionService.init();
    }

    if (mounted) {
      _updateActiveSession();
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateActiveSession() {
    _activeSession = ClimbSessionService.instance.getActiveSession();
  }

  Future<void> _deleteClimbSession(ClimbSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Climb?'),
        content: Text(
          'Are you sure you want to delete "${session.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ClimbSessionService.instance.deleteSession(session.id);

        if (mounted) {
          setState(() {
            _updateActiveSession();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Climb "${session.name}" deleted'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting climb: $e')));
        }
      }
    }
  }

  Future<void> _showEditDialog(ClimbSession session) async {
    final result = await showDialog<ClimbSession>(
      context: context,
      builder: (context) => NewClimbSessionDialog(climbSession: session),
    );

    if (result != null && mounted) {
      setState(() {
        _updateActiveSession();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Climb "${session.name}" updated'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _createNewSession() {
    showDialog(
      context: context,
      builder: (context) => const NewClimbSessionDialog(),
    );
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
                  : _selectedTabIndex == 1
                  ? _buildNotVisitedStations()
                  : _buildClimbsTab(),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedTabIndex == 2
          ? FloatingActionButton.extended(
              onPressed: _createNewSession,
              icon: const Icon(Icons.add),
              label: const Text('New Climb'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: const Text(
                'Stations',
                style: TextStyle(
                  color: SharedColors.white,
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
          _buildTab(
            2,
            'Climbs (${ClimbSessionService.instance.getAllSessions().length})',
          ),
        ],
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
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: isSelected ? 3 : 0,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.primary : Colors.black54,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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

  Widget _buildClimbsTab() {
    final allSessions = ClimbSessionService.instance.getAllSessions();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Climbs (${allSessions.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_activeSession == null)
                FilledButton.tonal(
                  onPressed: _createNewSession,
                  child: const Text('+ New Climb'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: allSessions.isEmpty
                ? _buildEmptyClimbsState()
                : ListView.builder(
                    itemCount: allSessions.length,
                    itemBuilder: (context, index) {
                      final session = allSessions[index];
                      final duration = session.getElapsedDuration();
                      final stationCount = session.visitedStations.length;

                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ClimbSessionDetailScreen(session: session),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getStatusColor(
                                session.status,
                              ).withOpacity(0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _getStatusColor(
                                  session.status,
                                ).withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with name and menu
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.name,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            session.trekType
                                                .replaceAll('_', ' ')
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () {},
                                      child: PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showEditDialog(session);
                                          } else if (value == 'delete') {
                                            _deleteClimbSession(session);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          PopupMenuItem<String>(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit_outlined,
                                                  size: 18,
                                                  color: AppColors.primary,
                                                ),
                                                const SizedBox(width: 12),
                                                const Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                  color: Colors.red,
                                                ),
                                                const SizedBox(width: 12),
                                                const Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        icon: Icon(
                                          Icons.more_vert,
                                          size: 20,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Status badge and stats
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          session.status,
                                        ).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        session.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _getStatusColor(
                                            session.status,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$stationCount stations',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_outlined,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          duration != null
                                              ? '${duration.inMinutes}m'
                                              : 'Not started',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyClimbsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hiking, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No climbs yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Start your first climb session to begin tracking your adventures!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.tonal(
            onPressed: _createNewSession,
            child: const Text('Create First Climb'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ongoing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'abandoned':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
              color: AppColors.textSecondary,
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
                color: AppColors.textSecondary,
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
                color: AppColors.textSecondary,
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
