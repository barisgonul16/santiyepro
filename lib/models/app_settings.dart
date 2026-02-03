class AppSettings {
  final List<int> bottomNavIndexes;
  final bool isDarkMode;

  AppSettings({
    this.bottomNavIndexes = const [0, 1, 10], // Ana Sayfa, Projeler, Haritalar
    this.isDarkMode = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'bottomNavIndexes': bottomNavIndexes,
      'isDarkMode': isDarkMode,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      bottomNavIndexes: json['bottomNavIndexes'] != null
          ? List<int>.from(json['bottomNavIndexes'])
          : [0, 1, 10],
      isDarkMode: json['isDarkMode'] ?? true,
    );
  }

  AppSettings copyWith({
    List<int>? bottomNavIndexes,
    bool? isDarkMode,
  }) {
    return AppSettings(
      bottomNavIndexes: bottomNavIndexes ?? this.bottomNavIndexes,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}
