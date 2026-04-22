// ignore_for_file: unnecessary_brace_in_string_interps
// ignore_for_file: use_key_in_widget_constructors, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../models/climb_session.dart';
import '../../theme/color.dart';
import '../../utils/status_helpers.dart';

class ClimbSessionDetailScreen extends StatefulWidget {
  final ClimbSession session;

  const ClimbSessionDetailScreen({super.key, required this.session});

  @override
  State<ClimbSessionDetailScreen> createState() =>
      _ClimbSessionDetailScreenState();
}

class _ClimbSessionDetailScreenState extends State<ClimbSessionDetailScreen> {
  late ClimbSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours}h ${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final elapsedDuration = _session.getElapsedDuration();
    final visitCount = _session.visitedStations.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_session.name),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card with Status
            Container(
              color: AppColors.primary.withOpacity(0.1),
              padding: const EdgeInsets.all(20),
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
                              _session.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _session.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ClimbSessionStatusHelper.color(
                            _session.status,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _session.status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Statistics Section
            if (elapsedDuration != null || visitCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildStatCard(
                          icon: Icons.timeline,
                          label: 'Duration',
                          value: elapsedDuration != null
                              ? _formatDuration(elapsedDuration)
                              : '--',
                          color: Colors.blue,
                        ),
                        _buildStatCard(
                          icon: Icons.location_on,
                          label: 'Stations',
                          value: '$visitCount',
                          color: Colors.green,
                        ),
                        _buildStatCard(
                          icon: Icons.terrain,
                          label: 'Distance',
                          value: _session.totalDistance != null
                              ? '${_session.totalDistance!.toStringAsFixed(2)} km'
                              : '--',
                          color: Colors.orange,
                        ),
                        _buildStatCard(
                          icon: Icons.height,
                          label: 'Avg Elevation',
                          value: visitCount > 0
                              ? '${(_session.visitedStations.fold<int>(0, (sum, v) => sum + v.elevation) / visitCount).toStringAsFixed(0)} m'
                              : '--',
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Timeline Section
            if (_session.visitedStations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visited Stations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _session.visitedStations.length,
                      itemBuilder: (context, index) {
                        final visit = _session.visitedStations[index];
                        final nextVisit =
                            index < _session.visitedStations.length - 1
                            ? _session.visitedStations[index + 1]
                            : null;
                        final duration = nextVisit?.scannedAt.difference(
                          visit.scannedAt,
                        );

                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (index <
                                        _session.visitedStations.length - 1)
                                      SizedBox(
                                        width: 2,
                                        height: 50,
                                        child: Container(
                                          color: AppColors.primary.withOpacity(
                                            0.3,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        visit.stationName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Elevation: ${visit.elevation}m',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        'Scanned: ${_formatDateTime(visit.scannedAt)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (duration != null)
                                        Text(
                                          'Time to next: ${_formatDuration(duration)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      if (visit.distanceFromPrevious != null &&
                                          visit.distanceFromPrevious! > 0)
                                        Text(
                                          'Distance: ${visit.distanceFromPrevious!.toStringAsFixed(2)} km',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Info Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.segmentBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Created',
                      _formatDateTime(_session.createdAt),
                    ),
                    if (_session.startedAt != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Started',
                        _formatDateTime(_session.startedAt!),
                      ),
                    ],
                    if (_session.completedAt != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Completed',
                        _formatDateTime(_session.completedAt!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
