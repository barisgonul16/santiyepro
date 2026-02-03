import 'package:flutter/material.dart';

/// Tema renklerini döndüren yardımcı fonksiyonlar
class ThemeColors {
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Arka plan rengi
  static Color background(BuildContext context) {
    return isDark(context) ? const Color(0xFF101010) : const Color(0xFFF8F9FA);
  }

  /// Kart arka plan rengi
  static Color cardBackground(BuildContext context) {
    return isDark(context) ? const Color(0xFF2d2d2d) : Colors.white;
  }

  /// AppBar / Header arka plan
  static Color headerBackground(BuildContext context) {
    return isDark(context) ? const Color(0xFF0d0d0d) : Colors.white;
  }

  /// Birincil metin rengi
  static Color textPrimary(BuildContext context) {
    return isDark(context) ? Colors.white : const Color(0xFF1A1A1A);
  }

  /// İkincil metin rengi
  static Color textSecondary(BuildContext context) {
    return isDark(context) ? Colors.white70 : const Color(0xFF4A4A4A);
  }

  /// Üçüncül metin rengi (soluk)
  static Color textTertiary(BuildContext context) {
    return isDark(context) ? Colors.white54 : const Color(0xFF6A6A6A);
  }

  /// Kenarlık rengi
  static Color border(BuildContext context) {
    return isDark(context) ? Colors.white10 : Colors.black12;
  }

  /// Divider rengi
  static Color divider(BuildContext context) {
    return isDark(context) ? Colors.white10 : Colors.black12;
  }

  /// İkon rengi
  static Color icon(BuildContext context) {
    return isDark(context) ? Colors.white70 : Colors.black54;
  }

  /// Gölge opaklığı
  static double shadowOpacity(BuildContext context) {
    return isDark(context) ? 0.3 : 0.1;
  }
}
