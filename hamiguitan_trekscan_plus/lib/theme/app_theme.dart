// ─────────────────────────────────────────────────────────────────────────────
// lib/theme/app_theme.dart
//
// Single access point for all theme colors.
//
// Usage in any widget:
//   final colors = context.colors;
//   colors.primary
//   colors.surface
//   context.isDarkMode
//
// Raw palettes (AppColors / AppColorsDark) remain in new_color.dart and must
// NOT be imported directly from widgets. Import this file instead.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'new_color.dart';

export 'new_color.dart'
    show SharedColors; // SharedColors stays accessible (status/utility)

// ─── BuildContext helpers ─────────────────────────────────────────────────────

extension AppThemeExtension on BuildContext {
  /// Resolve all semantic colors for the current brightness.
  AppTheme get colors => AppTheme(Theme.of(this).brightness == Brightness.dark);

  /// True when the app is in dark mode.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

// ─── Semantic color resolver ──────────────────────────────────────────────────

class AppTheme {
  final bool isDark;

  const AppTheme(this.isDark);

  // ── Page / structure ────────────────────────────────────────────────────────

  /// Full-page scaffold background.
  Color get background =>
      isDark ? AppColorsDark.background : AppColors.background;

  /// Card, dialog, bottom-sheet, and container background.
  Color get surface =>
      isDark ? AppColorsDark.cardBackground : AppColors.cardBackground;

  /// Very-light surface variant — chips, input fills, subtle tiles.
  Color get surfaceVariant =>
      isDark ? const Color(0xFF2A2A2A) : AppColors.surfaceVariant;

  /// Text-field / input fill color.
  Color get inputFill =>
      isDark ? const Color(0xFF1E1E1E) : AppColors.surfaceVariant;

  // ── Brand ───────────────────────────────────────────────────────────────────

  /// Primary brand color — buttons, headers, active states.
  Color get primary => isDark ? AppColorsDark.primary : AppColors.primary;

  /// Secondary brand accent.
  Color get accent => isDark ? AppColorsDark.accent : AppColors.accent;

  // ── Text ────────────────────────────────────────────────────────────────────

  /// Dominant body / heading text color.
  Color get text => isDark ? AppColorsDark.text : AppColors.text;

  /// Muted secondary text (captions, subtitles).
  Color get textSecondary =>
      isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

  /// Tertiary / placeholder text.
  Color get textTertiary =>
      isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;

  /// Near-black text (adapts to white in dark mode).
  Color get textBlack87 =>
      isDark ? AppColorsDark.textBlack87 : AppColors.textBlack87;

  /// Mid-opacity text (adapts in dark mode).
  Color get textBlack54 =>
      isDark ? AppColorsDark.textBlack54 : AppColors.textBlack54;

  /// Grey-700-equivalent text.
  Color get textGrey700 =>
      isDark ? AppColorsDark.textGrey700 : AppColors.textGrey700;

  // ── Borders ─────────────────────────────────────────────────────────────────

  /// Standard border / divider.
  Color get border => isDark ? AppColorsDark.border : AppColors.border;

  /// Subtle inner border.
  Color get borderLight =>
      isDark ? AppColorsDark.borderLight : AppColors.borderLight;

  /// Very light divider (≈ Colors.black12 equivalent).
  Color get borderSubtle =>
      isDark ? AppColorsDark.borderBlack12 : AppColors.borderBlack12;

  // ── Shadows ─────────────────────────────────────────────────────────────────

  /// Light elevation shadow (cards).
  Color get shadowLight =>
      isDark ? AppColorsDark.shadowLight : AppColors.shadowLight;

  /// Medium elevation shadow.
  Color get shadowMedium =>
      isDark ? AppColorsDark.shadowMedium : AppColors.shadowMedium;

  /// Heavy shadow (modals, sheets).
  Color get shadowDark =>
      isDark ? AppColorsDark.shadowDark : AppColors.shadowDark;

  /// Full-screen overlay / scrim.
  Color get shadowOverlay =>
      isDark ? AppColorsDark.shadowOverlay : AppColors.shadowOverlay;

  // ── Overlays ─────────────────────────────────────────────────────────────────

  Color get overlayLight =>
      isDark ? AppColorsDark.overlayLight : AppColors.overlayLight;

  Color get overlayMedium =>
      isDark ? AppColorsDark.overlayMedium : AppColors.overlayMedium;

  // ── UI controls ──────────────────────────────────────────────────────────────

  /// Segment / tab control background.
  Color get segmentBackground =>
      isDark ? AppColorsDark.segmentBackground : AppColors.segmentBackground;

  // ── Icons ────────────────────────────────────────────────────────────────────

  Color get iconMuted =>
      isDark ? AppColorsDark.iconGrey400 : AppColors.iconGrey400;

  Color get iconSubtle =>
      isDark ? AppColorsDark.iconGrey600 : AppColors.iconGrey600;

  // ── Semantic status ──────────────────────────────────────────────────────────

  Color get error => Colors.red;

  Color get success => Colors.green;

  Color get warning => isDark ? Colors.orange : AppColors.warning;

  Color get info => isDark ? const Color(0xFF42A5F5) : AppColors.info;

  // ── Status shades (booking / trekking status chips) ──────────────────────────

  Color get statusPendingLight =>
      isDark ? const Color(0xFF3E2723) : AppColors.statusPendingLight;

  Color get statusPendingBorder =>
      isDark ? const Color(0xFFFF8F00) : AppColors.statusPendingBorder;

  Color get statusPendingDark => AppColors.statusPendingDark;

  Color get statusRejectedLight =>
      isDark ? const Color(0xFF3E0000) : AppColors.statusRejectedLight;

  Color get statusRejectedDark => AppColors.statusRejectedDark;

  Color get statusCancelled => AppColors.statusCancelled;

  // ── Info shades ───────────────────────────────────────────────────────────────

  Color get infoLight => isDark ? const Color(0xFF0D2137) : AppColors.infoLight;

  Color get infoBorder =>
      isDark ? const Color(0xFF1565C0) : AppColors.infoBorder;

  // ── Warning shades ────────────────────────────────────────────────────────────

  Color get warningLight =>
      isDark ? const Color(0xFF3E2200) : AppColors.warningLight;

  Color get warningBorder =>
      isDark ? const Color(0xFFF57F17) : AppColors.warningBorder;

  // ── Notifications ─────────────────────────────────────────────────────────────

  Color get notificationToggle =>
      isDark ? AppColorsDark.notificationToggle : AppColors.notificationToggle;

  Color get notificationBooking => isDark
      ? AppColorsDark.notificationBooking
      : AppColors.notificationBooking;

  // ── Difficulty (trekking) ─────────────────────────────────────────────────────

  Color get difficultyEasy => SharedColors.difficultyEasy;

  Color get difficultyModerate => SharedColors.difficultyModerate;

  Color get difficultyHard => SharedColors.difficultyHard;

  // ── Green palette (achievement / certificate chips) ───────────────────────────

  Color get green50 => isDark ? AppColorsDark.green50 : AppColors.green50;

  Color get green200 => isDark ? AppColorsDark.green200 : AppColors.green200;

  Color get green700 => isDark ? AppColorsDark.green700 : AppColors.green700;
}
