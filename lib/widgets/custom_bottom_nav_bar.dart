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
    // Açık sayfa kısayollarda yoksa (currentIndex -1) hiçbiri seçili
    // görünmemeli; BottomNavigationBar seçimsiz olamadığı için seçili renk
    // seçilmemiş renge eşitlenir.
    final secimVar = currentIndex >= 0 && currentIndex < items.length;
    return BottomNavigationBar(
      currentIndex: secimVar ? currentIndex : 0,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: ThemeColors.headerBackground(context),
      selectedItemColor: secimVar ? Colors.orange : ThemeColors.textSecondary(context),
      unselectedItemColor: ThemeColors.textSecondary(context),
      showUnselectedLabels: true,
      selectedFontSize: secimVar ? 12.5 : 12,
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

