// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../widgets/station_card.dart';
import '../../../theme/app_theme.dart';
import '../../../models/climb_session.dart';
import '../../../dialogs/new_climb_session_dialog.dart';
import '../../../utils/status_helpers.dart';
import '../../stations/viewmodels/station_view_model.dart';
import 'station_detail_screen.dart';
import '../../../screens/main/climb_session_detail_screen.dart';

class StationScreen extends StatefulWidget {
  const StationScreen({super.key});

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  late final StationViewModel _vm;
  int _selectedTabIndex = 0;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _vm = StationViewModel();
    _vm.addListener(_onVmChanged);
    _vm.initialize();
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted) return;

    // Surface delete errors immediately.
    if (_vm.deleteError != null) {
      final err = _vm.deleteError!;
      _vm.clearDeleteError();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }

    setState(() {});
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

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
      final success = await _vm.deleteSession(session.id, session.name);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Climb "${session.name}" deleted'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      // Failure SnackBar is shown via _onVmChanged (deleteError).
    }
  }

  Future<void> _showEditDialog(ClimbSession session) async {
    final result = await showDialog<ClimbSession>(
      context: context,
      builder: (context) => NewClimbSessionDialog(climbSession: session),
    );

    if (result != null && mounted) {
      _vm.refreshAfterEdit();
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

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (_vm.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: colors.background,
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
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildAppBar() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: context.isDarkMode ? Colors.black : Colors.white,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Text(
                'Stations',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
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
          _buildTab(0, 'Visited (${_vm.visitedStations.length})'),
          _buildTab(1, 'Not Visited (${_vm.unvisitedStations.length})'),
          _buildTab(2, 'Climbs (${_vm.allSessions.length})'),
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
                color: isSelected ? context.colors.primary : Colors.transparent,
                width: isSelected ? 3 : 0,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? context.colors.primary
                  : context.colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisitedStations() {
    final visitedStations = _vm.visitedStations;

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
    final unvisitedStations = _vm.unvisitedStations;

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
    final colors = context.colors;
    if (!_vm.climbServiceReady) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Initializing Climbs feature...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'This should only take a moment',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _vm.retry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final allSessions = _vm.allSessions;

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
              if (_vm.activeSession == null)
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
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ClimbSessionStatusHelper.color(
                                session.status,
                              ).withOpacity(0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ClimbSessionStatusHelper.color(
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
                                                  color: context.colors.primary,
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
                                        color: ClimbSessionStatusHelper.color(
                                          session.status,
                                        ).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        session.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: ClimbSessionStatusHelper.color(
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
                                              : _vm.formatTime(
                                                  session.startedAt ??
                                                      session.createdAt,
                                                ),
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

  // -------------------------------------------------------------------------
  // Empty-state widgets
  // -------------------------------------------------------------------------

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
              color: context.colors.textSecondary,
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
                color: context.colors.textSecondary,
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
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "You haven't visited any stations yet. Start your adventure by scanning QR codes at the trail stations!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: context.colors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  color: context.colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Use Scanner to get started',
                  style: TextStyle(
                    color: context.colors.primary,
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
              "Amazing! You've completed your journey and visited all the stations on the trail. Well done, explorer!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: context.colors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
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
