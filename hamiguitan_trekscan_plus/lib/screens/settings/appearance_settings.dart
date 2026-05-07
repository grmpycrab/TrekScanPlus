import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/theme_service.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Appearance Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Theme Selection Card
              _buildThemeSelectionCard(context, themeService, colors),
              const SizedBox(height: 16),

              // Dark Mode Setting
              _buildDarkModeCard(context, themeService, colors),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeSelectionCard(
    BuildContext context,
    ThemeService themeService,
    AppTheme colors,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.palette,
                    color: SharedColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Selection',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Choose your preferred app theme',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildThemeButton(
                    label: 'Original Theme',
                    isSelected:
                        themeService.selectedTheme == ThemeType.original,
                    colors: colors,
                    onTap: () async {
                      await themeService.setTheme(ThemeType.original);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThemeButton(
                    label: 'New Theme',
                    isSelected:
                        themeService.selectedTheme == ThemeType.new_theme,
                    colors: colors,
                    onTap: () async {
                      await themeService.setTheme(ThemeType.new_theme);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDarkModeCard(
    BuildContext context,
    ThemeService themeService,
    AppTheme colors,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.dark_mode,
                    color: SharedColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${themeService.selectedTheme == ThemeType.original ? 'Original' : 'New'} Dark Mode',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Enable dark mode for the app',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    label: 'Light',
                    isSelected: themeService.selectedMode == AppThemeMode.light,
                    icon: Icons.light_mode,
                    colors: colors,
                    onTap: () async {
                      await themeService.setThemeMode(AppThemeMode.light);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModeButton(
                    label: 'Dark',
                    isSelected: themeService.selectedMode == AppThemeMode.dark,
                    icon: Icons.dark_mode,
                    colors: colors,
                    onTap: () async {
                      await themeService.setThemeMode(AppThemeMode.dark);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.borderLight),
              ),
              child: Text(
                'Currently using: ${themeService.selectedTheme == ThemeType.original ? 'Original' : 'New'} Theme (${themeService.selectedMode == AppThemeMode.light ? 'Light' : 'Dark'} Mode)',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppTheme colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isSelected ? SharedColors.white : colors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    required AppTheme colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? SharedColors.white : colors.text,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isSelected ? SharedColors.white : colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
