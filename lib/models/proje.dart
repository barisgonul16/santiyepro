import 'json_utils.dart';

class Proje {
  String id;
  String ad;
  String aciklama;
  DateTime baslangicTarihi;
  int toplamGun;
  String durum; // "Devam Ediyor" veya "Tamamlandı"
  DateTime? sonGuncelleme;
  /// Ana sayfadaki "kayıt girilmedi" uyarısına dahil edilsin mi. Ara sıra
  /// iş girilen projelerde (ör. ilave işler) kapatılır.
  bool kayitHatirlatma;
  /// Günlük kayıtta kahvaltı / akşam yemeği sayı kutuları gösterilsin mi.
  /// Varsayılan kapalı; öğle yemeği her projede vardır.
  bool kahvaltiAcik;
  bool aksamAcik;

  Proje({
    required this.id,
    required this.ad,
    required this.aciklama,
    required this.baslangicTarihi,
    required this.toplamGun,
    this.durum = "Devam Ediyor",
    this.sonGuncelleme,
    this.kayitHatirlatma = true,
    this.kahvaltiAcik = false,
    this.aksamAcik = false,
  });

  /// Başlangıçtan bugüne geçen gün (başlangıç günü 1. gün sayılır).
  int get gecenGun {
    final bugun = DateTime.now();
    final fark = DateTime(bugun.year, bugun.month, bugun.day)
        .difference(DateTime(baslangicTarihi.year, baslangicTarihi.month, baslangicTarihi.day))
        .inDays;
    return fark < 0 ? 0 : fark + 1;
  }

  /// "178 / 250 gün" biçiminde süre metni. Bu iş ilerlemesi değil, takvim
  /// süresidir.
  String get sureMetni => '$gecenGun / $toplamGun gün';

  bool get sureAsildi => toplamGun > 0 && gecenGun > toplamGun;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ad': ad,
        'aciklama': aciklama,
        'baslangicTarihi': baslangicTarihi.toIso8601String(),
        'toplamGun': toplamGun,
        'durum': durum,
        'sonGuncelleme': sonGuncelleme?.toIso8601String(),
        'kayitHatirlatma': kayitHatirlatma,
        'kahvaltiAcik': kahvaltiAcik,
        'aksamAcik': aksamAcik,
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
      // Eski kayıtlarda alan yok: hatırlatma açık kabul edilir.
      kayitHatirlatma: jsonMantik(json['kayitHatirlatma'], true),
      kahvaltiAcik: jsonMantik(json['kahvaltiAcik'], false),
      aksamAcik: jsonMantik(json['aksamAcik'], false),
    );
  }
}

