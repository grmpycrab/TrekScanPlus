// Original Color Theme
// Blue (#003f5a)
// Orange (#e2663e)
// Shadow (#e5e5e5)
// Text: (#000000)
// Other Text (if darker background): (#ffffff)
// App Background: (#ffffff)

// Dark Mode Theme (Maintaining the pastele aesthetic)
// Dark Blue (#1a374d)
// Dark Orange (#d35400)
// Dark Shadow (#2e2e2e)
// Light Text: (#f0f0f0)
// Other Light Text (if darker background): (#ffffff)
// Dark App Background: (#121212)

// Other Theme Colors

/*
═══════════════════════════════════════════════════════════════════════════════
SIMPLIFIED OTHER COLOR THEME (LIGHT MODE)
═══════════════════════════════════════════════════════════════════════════════

Core Colors (Mandatory):
  - primary: Color(0xFF252B30) - Main brand/button color
  - accent: Color(0xFF06402B) - Secondary accent
  - background: Colors.grey[100] - Light background
  - cardBackground: Colors.white - Card/container background
  - text: Color(0xFF252B30) - Primary text
  
Text Colors:
  - textSecondary: Colors.grey - Secondary text
  - textLight: Colors.white70 - Light text on dark backgrounds

Status & Semantic Colors (Keep these):
  - statusApproved: Colors.green
  - statusPending: Colors.orange
  - statusRejected: Colors.red
  - difficultyEasy: Colors.green
  - difficultyModerate: Colors.orange
  - difficultyHard: Colors.red

Utility Colors:
  - white: Colors.white
  - black: Colors.black
  - transparent: Colors.transparent

Remove all variants (grey50, grey100, etc.) and replace with single instances.
Remove redundant icons colors (use primary/secondary instead).
Remove redundant border variants (use single borderColor).
Keep shadow definitions but remove unnecessary variants.
*/

/*
═══════════════════════════════════════════════════════════════════════════════
SIMPLIFIED COLOR THEME (DARK MODE)
═══════════════════════════════════════════════════════════════════════════════

Core Colors (Dark):
  - primary: Color(0xFF1a374d) - Dark blue brand color
  - accent: Color(0xFF06402B) - Dark green accent
  - background: Color(0xFF121212) - Dark background
  - cardBackground: Color(0xFF1E1E1E) - Dark card background
  - text: Color(0xFFF0F0F0) - Light text on dark
  
Text Colors (Dark):
  - textSecondary: Color(0xFFB0B0B0) - Muted light text
  - textLight: Colors.white70 - Light text on dark backgrounds

Status & Semantic Colors (Same as Light):
  - statusApproved: Colors.green
  - statusPending: Colors.orange
  - statusRejected: Colors.red
  - difficultyEasy: Colors.green
  - difficultyModerate: Colors.orange
  - difficultyHard: Colors.red

Utility Colors (Same):
  - white: Colors.white
  - black: Colors.black
  - transparent: Colors.transparent

Dark Mode Specifics:
  - Shadow: Enhanced opacity for dark backgrounds
  - Border: Color(0xFF333333) - Dark border
  - Overlay: Lower opacity values for dark mode (0.05-0.15)
  - Notification: Colors.red (same as light)
*/

import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// SHARED COLORS (Used across all themes)
// ═════════════════════════════════════════════════════════════════════════════
class SharedColors {
  // Status Colors (used in all themes)
  static const Color statusApproved = Colors.green;
  static const Color statusPending = Colors.orange;
  static const Color statusRejected = Colors.red;

  // Difficulty Colors (used in all themes)
  static const Color difficultyEasy = Colors.green;
  static const Color difficultyModerate = Colors.orange;
  static const Color difficultyHard = Colors.red;

  // Utility Colors (used in all themes)
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color transparent = Colors.transparent;

  // Notification Colors (used in all themes)
  static const Color notificationDot = Colors.red;
}

// ═════════════════════════════════════════════════════════════════════════════
// ORIGINAL COLOR THEME (LIGHT MODE)
// ═════════════════════════════════════════════════════════════════════════════
class OriginalColors {
  static const Color primary = Color(0xFF003f5a); // Blue
  static const Color accent = Color(0xFFe2663e); // Orange
  static const Color background = Colors.white;
  static const Color shadow = Color(0xFFe5e5e5);
  static const Color text = Colors.black;
  static const Color textLight = Colors.white;
}

// ═════════════════════════════════════════════════════════════════════════════
// ORIGINAL COLOR THEME (DARK MODE)
// ═════════════════════════════════════════════════════════════════════════════
class OriginalColorsDark {
  static const Color primary = Color(0xFF1a374d); // Dark Blue
  static const Color accent = Color(0xFFd35400); // Dark Orange
  static const Color background = Color(0xFF121212);
  static const Color shadow = Color(0xFF2e2e2e);
  static const Color text = Color(0xFFF0F0F0);
  static const Color textLight = Colors.white;
}

// ═════════════════════════════════════════════════════════════════════════════
// NEW SIMPLIFIED COLOR THEME (LIGHT MODE)
// ═════════════════════════════════════════════════════════════════════════════
class AppColors {
  // Core Colors
  static const Color primary = Color(0xFF252B30);
  static const Color accent = Color(0xFF06402B);
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;

  // Text Colors
  static const Color text = Color(0xFF252B30);
  static const Color textSecondary = Colors.grey;
  static const Color textLight = Colors.white70;
  
  // Legacy Text Color Variants (for backwards compatibility)
  static Color textBlack87 = Colors.black87;
  static Color textBlack54 = Colors.black54;

  // Shadow Colors
  static Color shadowLight = Colors.black.withValues(alpha: 0.05);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.1);
  static Color shadowDark = Colors.black.withValues(alpha: 0.2);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFF0F0F0);
  
  // Legacy Border Variants (for backwards compatibility)
  static Color borderBlack12 = Colors.black12;
  static Color borderBlack26 = Colors.black26;

  // Overlay Colors
  static Color overlayLight = Colors.white.withValues(alpha: 0.1);
  static Color overlayMedium = Colors.white.withValues(alpha: 0.2);
  
  // Color Variants (for backwards compatibility)
  static const Color green50 = Color(0xFFF1F8E9);
  static const Color green200 = Color(0xFFC8E6C9);
  static const Color green700 = Color(0xFF558B2F);
  static const Color green = Colors.green;
  
  static const Color red200 = Color(0xFFEF9A9A);
  
  // Notification Colors
  static const Color notificationToggle = Color(0xFFFF9800); // Orange
  static const Color notificationBooking = Color(0xFF2196F3); // Blue
  static const Color notificationDot = Colors.red;
  
  // Additional Text Variant
  static const Color textTertiary = Color(0xFF999999);
  static const Color textGrey700 = Color(0xFF616161);
  
  // Icon Colors
  static const Color iconGrey400 = Color(0xFFBDBDBD);
  static const Color iconGrey600 = Color(0xFF757575);
  
  // Border Colors (aliases)
  static const Color borderColor = Color(0xFFE0E0E0);
  
  // Segment Background
  static const Color segmentBackground = Color(0xFFF5F5F5);
  
  // Shadow Overlay (for dialogs/overlays)
  static Color shadowOverlay = Colors.black.withValues(alpha: 0.3);
  
  // Status Colors (should come from SharedColors but mapped here for compatibility)
  static const Color statusApproved = Colors.green;
  static const Color statusPending = Colors.orange;
  static const Color statusRejected = Colors.red;
  
  // Difficulty Colors (should come from SharedColors but mapped here for compatibility)
  static const Color difficultyEasy = Colors.green;
  static const Color difficultyModerate = Colors.orange;
  static const Color difficultyHard = Colors.red;
}

// ═════════════════════════════════════════════════════════════════════════════
// NEW SIMPLIFIED COLOR THEME (DARK MODE)
// ═════════════════════════════════════════════════════════════════════════════
class AppColorsDark {
  // Core Colors
  static const Color primary = Color(0xFF1a374d);
  static const Color accent = Color(0xFF06402B);
  static const Color background = Color(0xFF121212);
  static const Color cardBackground = Color(0xFF1E1E1E);

  // Text Colors
  static const Color text = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textLight = Colors.white70;
  
  // Legacy Text Color Variants (for backwards compatibility)
  static Color textBlack87 = Colors.white;
  static Color textBlack54 = Color(0xFFC0C0C0);

  // Shadow Colors (enhanced for dark)
  static Color shadowLight = Colors.black.withValues(alpha: 0.1);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.2);
  static Color shadowDark = Colors.black.withValues(alpha: 0.4);

  // Border Colors
  static const Color border = Color(0xFF333333);
  static const Color borderLight = Color(0xFF2A2A2A);
  
  // Legacy Border Variants (for backwards compatibility)
  static Color borderBlack12 = Color(0xFF424242);
  static Color borderBlack26 = Color(0xFF616161);

  // Overlay Colors (lower opacity for dark)
  static Color overlayLight = Colors.white.withValues(alpha: 0.05);
  static Color overlayMedium = Colors.white.withValues(alpha: 0.1);
  
  // Color Variants (for backwards compatibility)
  static const Color green50 = Color(0xFF1B5E20);
  static const Color green200 = Color(0xFF81C784);
  static const Color green700 = Color(0xFF388E3C);
  static const Color green = Colors.green;
  
  static const Color red200 = Color(0xFFEF9A9A);
  
  // Notification Colors
  static const Color notificationToggle = Color(0xFFFF9800); // Orange
  static const Color notificationBooking = Color(0xFF2196F3); // Blue
  static const Color notificationDot = Colors.red;
  
  // Additional Text Variant
  static const Color textTertiary = Color(0xFF999999);
  static const Color textGrey700 = Color(0xFF9E9E9E);
  
  // Icon Colors
  static const Color iconGrey400 = Color(0xFF424242);
  static const Color iconGrey600 = Color(0xFF212121);
  
  // Border Colors (aliases)
  static const Color borderColor = Color(0xFF333333);
  
  // Segment Background
  static const Color segmentBackground = Color(0xFF1E1E1E);
  
  // Shadow Overlay (for dialogs/overlays)
  static Color shadowOverlay = Colors.black.withValues(alpha: 0.5);
  
  // Status Colors (should come from SharedColors but mapped here for compatibility)
  static const Color statusApproved = Colors.green;
  static const Color statusPending = Colors.orange;
  static const Color statusRejected = Colors.red;
  
  // Difficulty Colors (should come from SharedColors but mapped here for compatibility)
  static const Color difficultyEasy = Colors.green;
  static const Color difficultyModerate = Colors.orange;
  static const Color difficultyHard = Colors.red;
}
