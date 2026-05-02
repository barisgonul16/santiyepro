class Yevmiye {
  String id;
  String projeId;
  String ekipAdi;
  double yevmiyeMiktari;
  String aciklama;
  DateTime tarih;

  Yevmiye({
    required this.id,
    required this.projeId,
    required this.ekipAdi,
    required this.yevmiyeMiktari,
    required this.aciklama,
    required this.tarih,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'projeId': projeId,
        'ekipAdi': ekipAdi,
        'yevmiyeMiktari': yevmiyeMiktari,
        'aciklama': aciklama,
        'tarih': tarih.toIso8601String(),
      };

  factory Yevmiye.fromJson(Map<String, dynamic> json) {
    return Yevmiye(
      id: json['id'] ?? '',
      projeId: json['projeId'] ?? '',
      ekipAdi: json['ekipAdi'] ?? '',
      yevmiyeMiktari: (json['yevmiyeMiktari'] ?? 0).toDouble(),
      aciklama: json['aciklama'] ?? '',
      tarih: json['tarih'] != null ? DateTime.parse(json['tarih']) : DateTime.now(),
    );
  }
}
