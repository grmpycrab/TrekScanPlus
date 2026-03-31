// ignore_for_file: unnecessary_brace_in_string_interps
// ignore_for_file: use_key_in_widget_constructors, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../services/climb_session_service.dart';
import '../../models/climb_session.dart';
import '../../theme/color.dart';
import 'climb_session_detail_screen.dart';

class ClimbSessionsListScreen extends StatefulWidget {
  const ClimbSessionsListScreen({super.key});

  @override
  State<ClimbSessionsListScreen> createState() =>
      _ClimbSessionsListScreenState();
}

class _ClimbSessionsListScreenState extends State<ClimbSessionsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Guard against uninitialized service
    if (!ClimbSessionService.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Climbs'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Climbs'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      backgroundColor: AppColors.background,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSessionsList(
            ClimbSessionService.instance.getOngoingSessions(),
            'ongoing',
          ),
          _buildSessionsList(
            ClimbSessionService.instance.getCompletedSessions(),
            'completed',
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(List<ClimbSession> sessions, String type) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'ongoing' ? Icons.hiking : Icons.done_all,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              type == 'ongoing'
                  ? 'No ongoing climbs'
                  : 'No completed climbs yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              type == 'ongoing'
                  ? 'Start a new climb to track your adventure!'
                  : 'Complete a climb session to see it here',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
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
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(session.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        session.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(session.status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatChip(
                      icon: Icons.location_on,
                      label: 'Stations',
                      value: '$stationCount',
                    ),
                    _buildStatChip(
                      icon: Icons.timer,
                      label: 'Duration',
                      value: duration != null
                          ? _formatDuration(duration)
                          : '--:--',
                    ),
                    _buildStatChip(
                      icon: Icons.terrain,
                      label: 'Distance',
                      value: session.totalDistance != null
                          ? '${session.totalDistance!.toStringAsFixed(1)} km'
                          : '--',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Created: ${_formatDate(session.createdAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
}
