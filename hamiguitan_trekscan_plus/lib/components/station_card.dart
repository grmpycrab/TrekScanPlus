import 'package:flutter/material.dart';

class StationCard extends StatelessWidget {
  final String imagePath;
  final String stationName;
  final String difficulty;
  final int elevation;

  const StationCard({
    super.key,
    required this.imagePath,
    required this.stationName,
    required this.difficulty,
    required this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildDifficultyTag(), _buildStationInfo()],
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

  Widget _buildStationInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stationName,
          style: const TextStyle(
            color: Colors.white,
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
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ],
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
