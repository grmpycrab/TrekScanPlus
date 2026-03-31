// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeType { original, new_theme }

enum AppThemeMode { light, dark }

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();

  factory ThemeService() {
    return _instance;
  }

  ThemeService._internal();

  late SharedPreferences _prefs;
  late ThemeType _selectedTheme = ThemeType.original;
  late AppThemeMode _selectedMode = AppThemeMode.light;
  bool _initialized = false;

  ThemeType get selectedTheme => _selectedTheme;
  AppThemeMode get selectedMode => _selectedMode;
  bool get isDarkMode => _selectedMode == AppThemeMode.dark;

  /// Initialize the theme service and load saved preferences
  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();

    // Load saved theme preference (default: original theme)
    final themeString = _prefs.getString('selectedTheme') ?? 'original';
    _selectedTheme = themeString == 'original'
        ? ThemeType.original
        : ThemeType.new_theme;

    // Load saved mode preference (default: light)
    final modeString = _prefs.getString('selectedMode') ?? 'light';
    _selectedMode = modeString == 'dark'
        ? AppThemeMode.dark
        : AppThemeMode.light;

    _initialized = true;
    notifyListeners();
  }

  /// Set the theme type
  Future<void> setTheme(ThemeType theme) async {
    if (_selectedTheme != theme) {
      _selectedTheme = theme;
      await _prefs.setString(
        'selectedTheme',
        theme == ThemeType.original ? 'original' : 'new_theme',
      );
      notifyListeners();
    }
  }

  /// Set the theme mode
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_selectedMode != mode) {
      _selectedMode = mode;
      await _prefs.setString(
        'selectedMode',
        mode == AppThemeMode.dark ? 'dark' : 'light',
      );
      notifyListeners();
    }
  }

  /// Toggle dark mode
  Future<void> toggleDarkMode() async {
    await setThemeMode(isDarkMode ? AppThemeMode.light : AppThemeMode.dark);
  }
}
