import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';
import '../utils/station_image_path.dart';

class StationCard extends StatelessWidget {
  final String imagePath;
  final String stationName;
  final String difficulty;
  final int elevation;
  final bool isVisited;
  final VoidCallback? onTap;

  const StationCard({
    super.key,
    required this.imagePath,
    required this.stationName,
    required this.difficulty,
    required this.elevation,
    required this.isVisited,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: isVisited
          ? onTap
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: AssetImage(stationImageAssetPath(imagePath)),
            fit: BoxFit.cover,
            colorFilter: isVisited
                ? null
                : ColorFilter.mode(Colors.grey, BlendMode.saturation),
            onError: (_, __) {
              AppLogger.e('Error loading image: $imagePath');
            },
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadowMedium,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, colors.shadowOverlay],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildDifficultyTag(), _buildStationInfo(colors)],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getDifficultyColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        difficulty,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStationInfo(AppTheme colors) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stationName,
            style: const TextStyle(
              color: SharedColors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.height, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                '$elevation MASL',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor() {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'difficult':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
