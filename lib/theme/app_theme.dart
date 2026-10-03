import 'package:flutter/material.dart';
import 'theme_colors.dart';

/// Material bileşenlerinin (düğme, sekme, seçim düğmesi, kart...) varsayılan
/// görünümü. Renkler ThemeColors paletinden gelir.
class AppTheme {
  static ThemeData _olustur({
    required Brightness parlaklik,
    required Color zemin,
    required Color kart,
    required Color yazi,
    required Color yazi2,
    required Color ana,
    required Color anaUstu,
    required Color cizgi,
  }) {
    final sema = ColorScheme(
      brightness: parlaklik,
      primary: ana,
      onPrimary: anaUstu,
      secondary: ana,
      onSecondary: anaUstu,
      secondaryContainer: ana,
      onSecondaryContainer: anaUstu,
      error: Colors.redAccent,
      onError: Colors.white,
      surface: kart,
      onSurface: yazi,
      onSurfaceVariant: yazi2,
      outline: yazi2,
      outlineVariant: cizgi,
      surfaceTint: Colors.transparent,
    );
    return ThemeData(
      brightness: parlaklik,
      colorScheme: sema,
      scaffoldBackgroundColor: zemin,
      primaryColor: ana,
      dividerColor: cizgi,
      appBarTheme: AppBarTheme(
        backgroundColor: parlaklik == Brightness.dark ? zemin : kart,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: yazi),
        titleTextStyle: TextStyle(color: yazi, fontSize: 19, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: kart,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cizgi),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: kart, surfaceTintColor: Colors.transparent),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: kart, surfaceTintColor: Colors.transparent),
      popupMenuTheme: PopupMenuThemeData(color: kart, surfaceTintColor: Colors.transparent),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ana,
          foregroundColor: anaUstu,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ana,
          side: BorderSide(color: ana),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: ana)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: ana, foregroundColor: anaUstu),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: ana),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: ana,
        checkmarkColor: anaUstu,
        side: BorderSide(color: yazi2),
        labelStyle: TextStyle(color: yazi),
        secondaryLabelStyle: TextStyle(color: anaUstu),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((d) => d.contains(WidgetState.selected) ? anaUstu : yazi2),
        trackColor: WidgetStateProperty.resolveWith((d) => d.contains(WidgetState.selected) ? ana : cizgi),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: yazi),
        bodyMedium: TextStyle(color: yazi2),
        titleLarge: TextStyle(color: yazi, fontWeight: FontWeight.bold),
      ),
    );
  }

  static ThemeData darkTheme = _olustur(
    parlaklik: Brightness.dark,
    zemin: ThemeColors.zeminKoyu,
    kart: ThemeColors.kartKoyu,
    yazi: ThemeColors.yaziKoyu,
    yazi2: ThemeColors.yazi2Koyu,
    ana: ThemeColors.anaKoyu,
    anaUstu: ThemeColors.anaUstuKoyu,
    cizgi: const Color(0x14FFFFFF),
  );

  static ThemeData lightTheme = _olustur(
    parlaklik: Brightness.light,
    zemin: ThemeColors.zeminAcik,
    kart: ThemeColors.kartAcik,
    yazi: ThemeColors.yaziAcik,
    yazi2: ThemeColors.yazi2Acik,
    ana: ThemeColors.anaAcik,
    anaUstu: ThemeColors.anaUstuAcik,
    cizgi: const Color(0x1F000000),
  );
}
