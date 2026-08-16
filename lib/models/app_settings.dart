class AppSettings {
  final List<int> bottomNavIndexes;
  final bool isDarkMode;
  final String sehir;

  AppSettings({
    this.bottomNavIndexes = const [0, 1, 12], // Ana Sayfa, Projeler, Haritalar
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
          ? List<int>.from(json['bottomNavIndexes'])
          : [0, 1, 12],
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
