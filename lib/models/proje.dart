class Proje {
  String id;
  String ad;
  String aciklama;
  DateTime baslangicTarihi;
  int toplamGun;
  String durum; // "Devam Ediyor" veya "Tamamlandı"
  DateTime? sonGuncelleme;

  Proje({
    required this.id,
    required this.ad,
    required this.aciklama,
    required this.baslangicTarihi,
    required this.toplamGun,
    this.durum = "Devam Ediyor",
    this.sonGuncelleme,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ad': ad,
        'aciklama': aciklama,
        'baslangicTarihi': baslangicTarihi.toIso8601String(),
        'toplamGun': toplamGun,
        'durum': durum,
        'sonGuncelleme': sonGuncelleme?.toIso8601String(),
      };

  factory Proje.fromJson(Map<String, dynamic> json) {
    return Proje(
      id: json['id'],
      ad: json['ad'],
      aciklama: json['aciklama'],
      baslangicTarihi: DateTime.parse(json['baslangicTarihi']),
      toplamGun: json['toplamGun'],
      durum: json['durum'] ?? "Devam Ediyor",
      sonGuncelleme: json['sonGuncelleme'] != null
          ? DateTime.parse(json['sonGuncelleme'])
          : null,
    );
  }
}

