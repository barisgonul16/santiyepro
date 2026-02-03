import 'package:flutter/material.dart';
import '../theme/theme_colors.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavItem> items;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return BottomNavigationBar(
      currentIndex: currentIndex >= 0 && currentIndex < items.length ? currentIndex : 0,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: ThemeColors.headerBackground(context),
      selectedItemColor: Colors.orange,
      unselectedItemColor: ThemeColors.textSecondary(context),
      showUnselectedLabels: true,
      selectedFontSize: 13,
      unselectedFontSize: 12,
      elevation: 10,
      items: items.map((item) => BottomNavigationBarItem(
        icon: Icon(item.icon),
        label: item.label,
      )).toList(),
    );
  }
}

class BottomNavItem {
  final IconData icon;
  final String label;
  final Color color;

  const BottomNavItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}

