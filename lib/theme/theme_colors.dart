import 'package:flutter/material.dart';

/// Uygulamanın renk paleti. Ekranlar renkleri buradan okur; görünümü
/// değiştirmek için yalnızca bu dosyadaki değerler değiştirilir.
///
/// Koyu tema: koyu yeşil tonlu zemin, üç kademe (zemin -> kart -> kutu) ve
/// tek ana renk. Ana rengi değiştirmek için [_anaKoyu] / [_anaAcik] yeter
/// (ör. turuncu vurgu için 0xFFF59E3B ve üstündeki yazı için 0xFF231300).
class ThemeColors {
  // --- Koyu palet ---
  static const Color _zeminKoyu = Color(0xFF0C1512);
  static const Color _kartKoyu = Color(0xFF14211C);
  static const Color _kutuKoyu = Color(0xFF1C2D26);
  static const Color _yaziKoyu = Color(0xFFE6EFEA);
  static const Color _yazi2Koyu = Color(0xFF8FA39A);
  static const Color _yazi3Koyu = Color(0xFF6E8279);
  static const Color _cizgiKoyu = Color(0x14FFFFFF); // %8 beyaz
  static const Color _anaKoyu = Color(0xFF34C27B);
  static const Color _anaUstuKoyu = Color(0xFF04200F);

  // --- Açık palet ---
  static const Color _zeminAcik = Color(0xFFF4F7F5);
  static const Color _kartAcik = Colors.white;
  static const Color _kutuAcik = Color(0xFFECF1EE);
  static const Color _yaziAcik = Color(0xFF17201C);
  static const Color _yazi2Acik = Color(0xFF4C5A53);
  static const Color _yazi3Acik = Color(0xFF6F7C75);
  static const Color _cizgiAcik = Color(0x1F000000); // %12 siyah
  static const Color _anaAcik = Color(0xFF1B8A5A);
  static const Color _anaUstuAcik = Colors.white;

  // Tema nesnesi (AppTheme) için sabit erişim
  static const Color zeminKoyu = _zeminKoyu;
  static const Color kartKoyu = _kartKoyu;
  static const Color yaziKoyu = _yaziKoyu;
  static const Color yazi2Koyu = _yazi2Koyu;
  static const Color anaKoyu = _anaKoyu;
  static const Color anaUstuKoyu = _anaUstuKoyu;
  static const Color zeminAcik = _zeminAcik;
  static const Color kartAcik = _kartAcik;
  static const Color yaziAcik = _yaziAcik;
  static const Color yazi2Acik = _yazi2Acik;
  static const Color anaAcik = _anaAcik;
  static const Color anaUstuAcik = _anaUstuAcik;

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Arka plan rengi
  static Color background(BuildContext context) {
    return isDark(context) ? _zeminKoyu : _zeminAcik;
  }

  /// Kart arka plan rengi
  static Color cardBackground(BuildContext context) {
    return isDark(context) ? _kartKoyu : _kartAcik;
  }

  /// AppBar / yan menü / alt çubuk zemini (sayfa zeminiyle aynı ton)
  static Color headerBackground(BuildContext context) {
    return isDark(context) ? _zeminKoyu : _kartAcik;
  }

  /// Yazı kutusu ve kart içi küçük kutuların zemini
  static Color field(BuildContext context) {
    return isDark(context) ? _kutuKoyu : _kutuAcik;
  }

  /// Ana renk: birincil düğmeler, seçili sekme/menü, bağlantılar
  static Color accent(BuildContext context) {
    return isDark(context) ? _anaKoyu : _anaAcik;
  }

  /// Ana rengin üstündeki yazı/simge rengi
  static Color onAccent(BuildContext context) {
    return isDark(context) ? _anaUstuKoyu : _anaUstuAcik;
  }

  /// Birincil metin rengi
  static Color textPrimary(BuildContext context) {
    return isDark(context) ? _yaziKoyu : _yaziAcik;
  }

  /// İkincil metin rengi
  static Color textSecondary(BuildContext context) {
    return isDark(context) ? _yazi2Koyu : _yazi2Acik;
  }

  /// Üçüncül metin rengi (soluk)
  static Color textTertiary(BuildContext context) {
    return isDark(context) ? _yazi3Koyu : _yazi3Acik;
  }

  /// Kenarlık rengi
  static Color border(BuildContext context) {
    return isDark(context) ? _cizgiKoyu : _cizgiAcik;
  }

  /// Divider rengi
  static Color divider(BuildContext context) {
    return isDark(context) ? _cizgiKoyu : _cizgiAcik;
  }

  /// İkon rengi
  static Color icon(BuildContext context) {
    return isDark(context) ? _yazi2Koyu : _yazi2Acik;
  }

  /// Gölge opaklığı
  static double shadowOpacity(BuildContext context) {
    return isDark(context) ? 0.3 : 0.1;
  }

  /// "Yolunda" rengi (son kayıt güncel, bulut eşit).
  static Color iyi(BuildContext context) {
    return isDark(context) ? const Color(0xFF5ED39B) : Colors.green.shade700;
  }

  /// "Dikkat" rengi (kayıt gecikmiş, eşitleme eksik).
  static Color uyari(BuildContext context) {
    return isDark(context) ? const Color(0xFFF0B24A) : Colors.orange.shade900;
  }
}
