import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    // Dark: slightly lifted surface so it reads as a distinct layer above 0xFF121212 bg
    final bgColor = isDark ? const Color(0xFF1C1C1C) : Colors.white;
    // Dark: white active icon is clearly visible on dark nav surface
    final activeColor = isDark ? Colors.white : colors.primary;
    final inactiveColor = colors.textSecondary;

    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            // Dark: visible separator line; light: hairline border
            color: isDark ? const Color(0xFF2E2E2E) : colors.borderLight,
            width: isDark ? 0.8 : 0.5,
          ),
        ),
        boxShadow: isDark
            ? const [] // shadows are invisible on dark bg — border handles separation
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, -3),
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            0,
            'assets/icons/home_icon.png',
            'Home',
            activeColor,
            inactiveColor,
          ),
          _buildNavItem(
            1,
            'assets/icons/station.png',
            'Stations',
            activeColor,
            inactiveColor,
          ),
          _buildNavItem(
            2,
            'assets/icons/qr-code.png',
            'Scanner',
            activeColor,
            inactiveColor,
          ),
          _buildNavItem(
            3,
            'assets/icons/appointment.png',
            'Book',
            activeColor,
            inactiveColor,
          ),
          _buildNavItem(
            4,
            'assets/icons/setting.png',
            'Settings',
            activeColor,
            inactiveColor,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String iconPath,
    String label,
    Color activeColor,
    Color inactiveColor,
  ) {
    final isSelected = currentIndex == index;
    final itemColor = isSelected ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(iconPath, width: 24, height: 24, color: itemColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: itemColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
