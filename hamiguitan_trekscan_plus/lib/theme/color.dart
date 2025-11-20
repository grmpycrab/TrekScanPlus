import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF252B30);
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // Background Colors
  static Color background = Colors.grey[100]!;
  static const Color cardBackground = Colors.white;

  // Text Colors
  static const Color textPrimary = Color(0xFF252B30);
  static const Color textSecondary = Colors.grey;
  static Color textTertiary = Colors.grey[600]!;
  static const Color textLight = Colors.white70;

  // Station Difficulty Colors
  static const Color difficultyEasy = Colors.green;
  static const Color difficultyModerate = Colors.orange;
  static const Color difficultyHard = Colors.red;

  // Icon Colors
  static const Color iconPrimary = Colors.white;
  static const Color iconSecondary = Colors.grey;

  // Border Colors
  static Color borderColor = Colors.grey[300]!;
  static const Color inputBorder = Color(0xFF252B30);

  // Shadow Colors
  static Color shadowLight = Colors.black.withValues(alpha: 0.05);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.1);
  static Color shadowDark = Colors.black.withValues(alpha: 0.2);
  static Color shadowOverlay = Colors.black.withValues(alpha: 0.7);

  // Notification Colors
  static const Color notificationDot = Colors.red;

  // Segment Colors
  static Color segmentBackground = Colors.grey[200]!;

  // Button Colors
  static const Color buttonPrimary = Color(0xFF252B30);
  static const Color buttonText = Colors.white;
}
