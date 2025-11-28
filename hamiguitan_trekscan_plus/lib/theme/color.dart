import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF252B30);
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // Background Colors
  static Color background = Colors.grey[100]!;
  static const Color cardBackground = Colors.white;
  static const Color transparent = Colors.transparent;

  // Text Colors
  static const Color textPrimary = Color(0xFF252B30);
  static const Color textSecondary = Colors.grey;
  static Color textTertiary = Colors.grey[600]!;
  static const Color textLight = Colors.white70;
  static Color textGrey700 = Colors.grey[700]!;
  static const Color textBlack87 = Colors.black87;
  static const Color textBlack54 = Colors.black54;
  static const Color textBlack38 = Colors.black38;
  static const Color textBlack45 = Colors.black45;

  // Station Difficulty Colors
  static const Color difficultyEasy = Colors.green;
  static const Color difficultyModerate = Colors.orange;
  static const Color difficultyHard = Colors.red;

  // Icon Colors
  static const Color iconPrimary = Colors.white;
  static const Color iconSecondary = Colors.grey;
  static Color iconGrey400 = Colors.grey[400]!;
  static Color iconGrey600 = Colors.grey[600]!;
  static Color iconGrey700 = Colors.grey[700]!;

  // Border Colors
  static Color borderColor = Colors.grey[300]!;
  static Color borderGrey200 = Colors.grey[200]!;
  static const Color borderBlack12 = Colors.black12;
  static const Color borderBlack26 = Colors.black26;
  static const Color inputBorder = Color(0xFF252B30);

  // Shadow Colors
  static Color shadowLight = Colors.black.withValues(alpha: 0.05);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.1);
  static Color shadowDark = Colors.black.withValues(alpha: 0.2);
  static Color shadowOverlay = Colors.black.withValues(alpha: 0.7);
  static Color shadowBlack06 = Colors.black.withValues(alpha: 0.06);
  static Color shadowBlack08 = Colors.black.withValues(alpha: 0.08);
  static Color shadowBlack15 = Colors.black.withValues(alpha: 0.15);
  static Color shadowBlack3 = Colors.black.withValues(alpha: 0.3);
  static Color shadowBlack4 = Colors.black.withValues(alpha: 0.4);
  static Color shadowBlack5 = Colors.black.withValues(alpha: 0.5);
  static Color shadowBlack6 = Colors.black.withValues(alpha: 0.6);

  // Notification Colors
  static const Color notificationDot = Colors.red;
  static const Color notificationBooking = primary;
  static const Color notificationToggle = Color(0xFF06402B);

  // Segment Colors
  static Color segmentBackground = Colors.grey[200]!;

  // Button Colors
  static const Color buttonPrimary = Color(0xFF252B30);
  static const Color buttonText = Colors.white;

  // Blue Grey Variants
  static Color blueGrey = Colors.blueGrey;
  static Color blueGrey50 = Colors.blueGrey[50]!;
  static Color blueGrey700 = Colors.blueGrey[700]!;
  static Color blueGrey800 = Colors.blueGrey[800]!;

  // Grey Variants
  static Color grey = Colors.grey;
  static Color grey50 = Colors.grey[50]!;
  static Color grey100 = Colors.grey[100]!;
  static Color grey200 = Colors.grey[200]!;
  static Color grey300 = Colors.grey[300]!;
  static Color grey400 = Colors.grey[400]!;
  static Color grey500 = Colors.grey[500]!;
  static Color grey600 = Colors.grey[600]!;
  static Color grey700 = Colors.grey[700]!;
  static Color greyShade300 = Colors.grey.shade300;
  static Color greyShade400 = Colors.grey.shade400;
  static Color greyShade600 = Colors.grey.shade600;
  static Color greyShade700 = Colors.grey.shade700;

  // Red Variants
  static const Color red = Colors.red;
  static Color red50 = Colors.red[50]!;
  static Color red100 = Colors.red[100]!;
  static Color red300 = Colors.red[300]!;
  static Color red700 = Colors.red[700]!;
  static Color red800 = Colors.red[800]!;
  static Color red900 = Colors.red[900]!;
  static Color redShade200 = Colors.red.shade200;
  static Color redShade300 = Colors.red.shade300;
  static Color redShade700 = Colors.red.shade700;
  static const Color redAccent = Colors.redAccent;

  // Orange Variants
  static const Color orange = Colors.orange;
  static Color orange50 = Colors.orange[50]!;
  static Color orange100 = Colors.orange[100]!;
  static Color orange300 = Colors.orange[300]!;
  static Color orange700 = Colors.orange[700]!;
  static Color orange800 = Colors.orange[800]!;
  static Color orange900 = Colors.orange[900]!;
  static Color orangeShade50 = Colors.orange.shade50;
  static Color orangeShade200 = Colors.orange.shade200;
  static Color orangeShade300 = Colors.orange.shade300;
  static Color orangeShade700 = Colors.orange.shade700;
  static Color orangeShade800 = Colors.orange.shade800;
  static Color orangeShade900 = Colors.orange.shade900;

  // Green Variants
  static const Color green = Colors.green;
  static Color green50 = Colors.green[50]!;
  static Color green100 = Colors.green[100]!;
  static Color green300 = Colors.green[300]!;
  static Color green700 = Colors.green[700]!;
  static Color green800 = Colors.green[800]!;
  static Color greenShade50 = Colors.green.shade50;
  static Color greenShade200 = Colors.green.shade200;
  static Color greenShade700 = Colors.green.shade700;

  // Blue Variants
  static const Color blue = Colors.blue;
  static Color blue50 = Colors.blue[50]!;
  static Color blue700 = Colors.blue[700]!;
  static Color blue900 = Colors.blue[900]!;
  static Color blueShade50 = Colors.blue.shade50;
  static Color blueShade200 = Colors.blue.shade200;
  static const Color blueAccent = Colors.blueAccent;

  // Status Colors (for booking states, notifications, etc.)
  static const Color statusApproved = Colors.green;
  static const Color statusPending = Colors.orange;
  static const Color statusRejected = Colors.red;
  static const Color statusChangesRequired = Colors.orange;

  // Overlay Colors
  static Color overlayLight = Colors.white.withValues(alpha: 0.1);
  static Color overlayMedium = Colors.white.withValues(alpha: 0.2);
  static Color overlayDark = Colors.white.withValues(alpha: 0.3);

  // Info/Warning/Error Colors
  static const Color info = Colors.blue;
  static const Color warning = Colors.orange;
  static const Color error = Colors.red;
  static const Color success = Colors.green;
}
