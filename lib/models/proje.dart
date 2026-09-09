import 'json_utils.dart';

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
      id: jsonKimlik(json['id']),
      ad: jsonMetin(json['ad'], 'İsimsiz Proje'),
      aciklama: jsonMetin(json['aciklama']),
      baslangicTarihi: jsonTarih(json['baslangicTarihi'], 'baslangicTarihi'),
      toplamGun: jsonTamsayi(json['toplamGun']),
      durum: jsonMetin(json['durum'], 'Devam Ediyor'),
      sonGuncelleme: jsonTarihOpsiyonel(json['sonGuncelleme']),
    );
  }
}

