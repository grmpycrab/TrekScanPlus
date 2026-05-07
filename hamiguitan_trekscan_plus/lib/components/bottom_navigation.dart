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
    final bgColor = isDark ? Colors.black : Colors.white;
    final activeColor = colors.primary;
    final inactiveColor = colors.textSecondary;

    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: colors.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: colors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, -2),
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
