import 'package:flutter/material.dart';
import '../theme/new_color.dart';
import 'theme_service.dart';

class AppThemeBuilder {
  /// Get the theme data based on selected theme and mode
  static ThemeData getThemeData(ThemeType themeType, AppThemeMode themeMode) {
    if (themeType == ThemeType.original) {
      return _buildOriginalTheme(themeMode);
    } else {
      return _buildNewTheme(themeMode);
    }
  }

  /// Build original theme (light/dark)
  static ThemeData _buildOriginalTheme(AppThemeMode themeMode) {
    final isDark = themeMode == AppThemeMode.dark;

    final primaryColor = isDark
        ? OriginalColorsDark.primary
        : OriginalColors.primary;
    final backgroundColor = isDark
        ? OriginalColorsDark.background
        : OriginalColors.background;
    final textColor = isDark ? OriginalColorsDark.text : OriginalColors.text;
    final accentColor = isDark
        ? OriginalColorsDark.accent
        : OriginalColors.accent;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primaryColor,
        secondary: accentColor,
        surface: backgroundColor,
        error: Colors.red,
        onPrimary: SharedColors.white,
        onSecondary: SharedColors.white,
        onSurface: textColor,
        onError: SharedColors.white,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
        bodySmall: TextStyle(color: textColor),
        displayLarge: TextStyle(color: textColor),
        displayMedium: TextStyle(color: textColor),
        displaySmall: TextStyle(color: textColor),
        headlineLarge: TextStyle(color: textColor),
        headlineMedium: TextStyle(color: textColor),
        headlineSmall: TextStyle(color: textColor),
        titleLarge: TextStyle(color: textColor),
        titleMedium: TextStyle(color: textColor),
        titleSmall: TextStyle(color: textColor),
        labelLarge: TextStyle(color: textColor),
        labelMedium: TextStyle(color: textColor),
        labelSmall: TextStyle(color: textColor),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: SharedColors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: backgroundColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: isDark ? Colors.grey[600] : Colors.grey[400],
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: SharedColors.white,
      ),
      cardTheme: CardThemeData(
        color: isDark ? Color(0xFF1E1E1E) : Colors.white,
        elevation: 1,
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: primaryColor,
        textTheme: ButtonTextTheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: SharedColors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      iconTheme: IconThemeData(color: primaryColor),
      chipTheme: ChipThemeData(
        backgroundColor: accentColor.withValues(alpha: 0.1),
        selectedColor: accentColor,
        labelStyle: TextStyle(color: textColor),
        secondaryLabelStyle: TextStyle(color: SharedColors.white),
      ),
    );
  }

  /// Build new simplified theme (light/dark)
  static ThemeData _buildNewTheme(AppThemeMode themeMode) {
    final isDark = themeMode == AppThemeMode.dark;

    final primaryColor = isDark ? AppColorsDark.primary : AppColors.primary;
    final backgroundColor = isDark
        ? AppColorsDark.background
        : AppColors.background;
    final textColor = isDark ? AppColorsDark.text : AppColors.text;
    final accentColor = isDark ? AppColorsDark.accent : AppColors.accent;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primaryColor,
        secondary: accentColor,
        surface: backgroundColor,
        error: Colors.red,
        onPrimary: SharedColors.white,
        onSecondary: SharedColors.white,
        onSurface: textColor,
        onError: SharedColors.white,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
        bodySmall: TextStyle(color: textColor),
        displayLarge: TextStyle(color: textColor),
        displayMedium: TextStyle(color: textColor),
        displaySmall: TextStyle(color: textColor),
        headlineLarge: TextStyle(color: textColor),
        headlineMedium: TextStyle(color: textColor),
        headlineSmall: TextStyle(color: textColor),
        titleLarge: TextStyle(color: textColor),
        titleMedium: TextStyle(color: textColor),
        titleSmall: TextStyle(color: textColor),
        labelLarge: TextStyle(color: textColor),
        labelMedium: TextStyle(color: textColor),
        labelSmall: TextStyle(color: textColor),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: SharedColors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: backgroundColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: isDark ? Colors.grey[600] : Colors.grey[400],
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: SharedColors.white,
      ),
      cardTheme: CardThemeData(
        color: isDark ? Color(0xFF1E1E1E) : Colors.white,
        elevation: 1,
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: primaryColor,
        textTheme: ButtonTextTheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: SharedColors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      iconTheme: IconThemeData(color: primaryColor),
      chipTheme: ChipThemeData(
        backgroundColor: accentColor.withValues(alpha: 0.1),
        selectedColor: accentColor,
        labelStyle: TextStyle(color: textColor),
        secondaryLabelStyle: TextStyle(color: SharedColors.white),
      ),
    );
  }
}
