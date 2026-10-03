class AppSettings {
  final List<int> bottomNavIndexes;
  final bool isDarkMode;
  final String sehir;

  /// Alt çubuktaki kısayol sayısı.
  static const int kisayolSayisi = 4;

  /// Ana Sayfa, Projeler, Günlük Rapor, Haritalar
  static const List<int> varsayilanKisayollar = [0, 1, 13, 12];

  /// Kayıtlı kısayolları [kisayolSayisi] adede tamamlar. Eski sürümde 3
  /// kısayol vardı: eski varsayılan (Ana Sayfa, Projeler, Haritalar) yeni
  /// varsayılana çevrilir; kullanıcının değiştirdiği liste korunur ve eksik
  /// yer varsayılandan doldurulur.
  static List<int> kisayollariTamamla(List<int> kayitli) {
    if (kayitli.length == 3 && kayitli[0] == 0 && kayitli[1] == 1 && kayitli[2] == 12) {
      return List<int>.from(varsayilanKisayollar);
    }
    final sonuc = kayitli.take(kisayolSayisi).toList();
    for (final v in [...varsayilanKisayollar, 2, 8, 3]) {
      if (sonuc.length >= kisayolSayisi) break;
      if (!sonuc.contains(v)) sonuc.add(v);
    }
    return sonuc;
  }

  AppSettings({
    this.bottomNavIndexes = varsayilanKisayollar,
    this.isDarkMode = true,
    this.sehir = 'Bursa',
  });

  Map<String, dynamic> toJson() {
    return {
      'bottomNavIndexes': bottomNavIndexes,
      'isDarkMode': isDarkMode,
      'sehir': sehir,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      bottomNavIndexes: json['bottomNavIndexes'] != null
          ? kisayollariTamamla(List<int>.from(json['bottomNavIndexes']))
          : List<int>.from(varsayilanKisayollar),
      isDarkMode: json['isDarkMode'] ?? true,
      sehir: json['sehir'] ?? 'Bursa',
    );
  }

  AppSettings copyWith({
    List<int>? bottomNavIndexes,
    bool? isDarkMode,
    String? sehir,
  }) {
    return AppSettings(
      bottomNavIndexes: bottomNavIndexes ?? this.bottomNavIndexes,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      sehir: sehir ?? this.sehir,
    );
  }
}
