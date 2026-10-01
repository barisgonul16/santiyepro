import 'json_utils.dart';

class VincBilgisi {
  String firmaAdi;
  String baslangic; // "HH:mm" formatında
  String bitis;     // "HH:mm" formatında
  int mola;         // Dakika cinsinden

  VincBilgisi({
    this.firmaAdi = '',
    this.baslangic = '',
    this.bitis = '',
    this.mola = 0,
  });

  /// Mola düşülmüş çalışma süresi (saat). Bitiş başlangıçtan önceyse ertesi
  /// güne sarktığı kabul edilir. Saat okunamazsa 0.
  double get netSaat {
    try {
      final b = baslangic.split(':');
      final s = bitis.split(':');
      int fark = (int.parse(s[0]) * 60 + int.parse(s[1])) - (int.parse(b[0]) * 60 + int.parse(b[1]));
      if (fark < 0) fark += 24 * 60;
      final net = fark - mola;
      return net <= 0 ? 0 : net / 60.0;
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic> toJson() => {
        'firmaAdi': firmaAdi,
        'baslangic': baslangic,
        'bitis': bitis,
        'mola': mola,
      };

  factory VincBilgisi.fromJson(Map<String, dynamic> json) {
    return VincBilgisi(
      firmaAdi: jsonMetin(json['firmaAdi']),
      baslangic: jsonMetin(json['baslangic']),
      bitis: jsonMetin(json['bitis']),
      mola: jsonTamsayi(json['mola']),
    );
  }
}

class YevmiyeBilgisi {
  String ekipAdi;
  double miktar;
  String aciklama;

  YevmiyeBilgisi({
    this.ekipAdi = '',
    this.miktar = 0.0,
    this.aciklama = '',
  });

  Map<String, dynamic> toJson() => {
        'ekipAdi': ekipAdi,
        'miktar': miktar,
        'aciklama': aciklama,
      };

  factory YevmiyeBilgisi.fromJson(Map<String, dynamic> json) {
    return YevmiyeBilgisi(
      ekipAdi: jsonMetin(json['ekipAdi']),
      miktar: jsonOndalik(json['miktar']),
      aciklama: jsonMetin(json['aciklama']),
    );
  }
}

class GunlukKayit {
  DateTime tarih;
  int kalipci;
  int demirci;
  int diger;
  String kalipciYapilanIs;
  String demirciYapilanIs;
  String notlar;
  String beton;
  List<String> fotografYollari; // Fotoğrafların yolları

  // Yemek bilgileri
  int yemekKalipci;
  int yemekDemirci;
  int yemekDiger;

  // Vinç bilgileri (Legacy)
  String vincFirmaAdi;
  String vincBaslangic; // "HH:mm" formatında
  String vincBitis;     // "HH:mm" formatında
  int vincMola;         // Dakika cinsinden

  // Yevmiye bilgileri (Legacy)
  String yevmiyeEkipAdi;
  double yevmiyeMiktari;
  String yevmiyeAciklama;

  // Çoklu kayıt listeleri
  List<VincBilgisi> vincler;
  List<YevmiyeBilgisi> yevmiyeler;

  GunlukKayit({
    required this.tarih,
    this.kalipci = 0,
    this.demirci = 0,
    this.diger = 0,
    this.yemekKalipci = 0,
    this.yemekDemirci = 0,
    this.yemekDiger = 0,
    this.kalipciYapilanIs = '',
    this.demirciYapilanIs = '',
    this.notlar = '',
    this.beton = '',
    this.fotografYollari = const [],
    this.vincFirmaAdi = '',
    this.vincBaslangic = '',
    this.vincBitis = '',
    this.vincMola = 0,
    this.yevmiyeEkipAdi = '',
    this.yevmiyeMiktari = 0,
    this.yevmiyeAciklama = '',
    List<VincBilgisi>? vincler,
    List<YevmiyeBilgisi>? yevmiyeler,
  }) : vincler = vincler ?? [],
       yevmiyeler = yevmiyeler ?? [] {
    // Listeleri eski alanlarla senkronize et (Eğer listeler boşsa ama eski alanlar doluysa)
    if (this.vincler.isEmpty && (vincFirmaAdi.isNotEmpty || vincBaslangic.isNotEmpty || vincBitis.isNotEmpty)) {
      this.vincler.add(VincBilgisi(
        firmaAdi: vincFirmaAdi,
        baslangic: vincBaslangic,
        bitis: vincBitis,
        mola: vincMola,
      ));
    }
    if (this.yevmiyeler.isEmpty && (yevmiyeEkipAdi.isNotEmpty || yevmiyeMiktari > 0)) {
      this.yevmiyeler.add(YevmiyeBilgisi(
        ekipAdi: yevmiyeEkipAdi,
        miktar: yevmiyeMiktari,
        aciklama: yevmiyeAciklama,
      ));
    }

    // Eski alanları listelerin ilk elemanıyla doldur (Geriye dönük uyumluluk için)
    if (this.vincler.isNotEmpty) {
      vincFirmaAdi = this.vincler.first.firmaAdi;
      vincBaslangic = this.vincler.first.baslangic;
      vincBitis = this.vincler.first.bitis;
      vincMola = this.vincler.first.mola;
    }
    if (this.yevmiyeler.isNotEmpty) {
      yevmiyeEkipAdi = this.yevmiyeler.first.ekipAdi;
      yevmiyeMiktari = this.yevmiyeler.first.miktar;
      yevmiyeAciklama = this.yevmiyeler.first.aciklama;
    }
  }

  Map<String, dynamic> toJson() => {
        'tarih': tarih.toIso8601String(),
        'kalipci': kalipci,
        'demirci': demirci,
        'diger': diger,
        'yemekKalipci': yemekKalipci,
        'yemekDemirci': yemekDemirci,
        'yemekDiger': yemekDiger,
        'kalipciYapilanIs': kalipciYapilanIs,
        'demirciYapilanIs': demirciYapilanIs,
        'notlar': notlar,
        'beton': beton,
        'fotografYollari': fotografYollari,
        'vincler': vincler.map((v) => v.toJson()).toList(),
        'yevmiyeler': yevmiyeler.map((y) => y.toJson()).toList(),
        // Eski alanları da serileştiriyoruz ki eski versiyon uygulamalar okuyabilsin
        'vincFirmaAdi': vincler.isNotEmpty ? vincler.first.firmaAdi : '',
        'vincBaslangic': vincler.isNotEmpty ? vincler.first.baslangic : '',
        'vincBitis': vincler.isNotEmpty ? vincler.first.bitis : '',
        'vincMola': vincler.isNotEmpty ? vincler.first.mola : 0,
        'yevmiyeEkipAdi': yevmiyeler.isNotEmpty ? yevmiyeler.first.ekipAdi : '',
        'yevmiyeMiktari': yevmiyeler.isNotEmpty ? yevmiyeler.first.miktar : 0.0,
        'yevmiyeAciklama': yevmiyeler.isNotEmpty ? yevmiyeler.first.aciklama : '',
      };

  factory GunlukKayit.fromJson(Map<String, dynamic> json) {
    // Alt kayıtlardaki bozukluk tüm günü düşürmemeli: bozuk vinç/yevmiye
    // satırı atlanır, günün geri kalanı korunur.
    final vinclerJson = json['vincler'];
    final List<VincBilgisi> parsedVincler = [];
    if (vinclerJson is List) {
      for (final v in vinclerJson) {
        try {
          parsedVincler.add(VincBilgisi.fromJson(Map<String, dynamic>.from(v as Map)));
        } catch (_) {
          // bozuk satır atlanır
        }
      }
    }

    final yevmiyelerJson = json['yevmiyeler'];
    final List<YevmiyeBilgisi> parsedYevmiyeler = [];
    if (yevmiyelerJson is List) {
      for (final y in yevmiyelerJson) {
        try {
          parsedYevmiyeler.add(YevmiyeBilgisi.fromJson(Map<String, dynamic>.from(y as Map)));
        } catch (_) {
          // bozuk satır atlanır
        }
      }
    }

    return GunlukKayit(
      tarih: jsonTarih(json['tarih'], 'tarih'),
      kalipci: jsonTamsayi(json['kalipci']),
      demirci: jsonTamsayi(json['demirci']),
      diger: jsonTamsayi(json['diger']),
      yemekKalipci: jsonTamsayi(json['yemekKalipci']),
      yemekDemirci: jsonTamsayi(json['yemekDemirci']),
      yemekDiger: jsonTamsayi(json['yemekDiger']),
      kalipciYapilanIs: jsonMetin(json['kalipciYapilanIs']),
      demirciYapilanIs: jsonMetin(json['demirciYapilanIs']),
      notlar: jsonMetin(json['notlar']),
      beton: jsonMetin(json['beton']),
      fotografYollari: jsonMetinListesi(json['fotografYollari']),
      vincFirmaAdi: jsonMetin(json['vincFirmaAdi']),
      vincBaslangic: jsonMetin(json['vincBaslangic']),
      vincBitis: jsonMetin(json['vincBitis']),
      vincMola: jsonTamsayi(json['vincMola']),
      yevmiyeEkipAdi: jsonMetin(json['yevmiyeEkipAdi']),
      yevmiyeMiktari: jsonOndalik(json['yevmiyeMiktari']),
      yevmiyeAciklama: jsonMetin(json['yevmiyeAciklama']),
      vincler: parsedVincler,
      yevmiyeler: parsedYevmiyeler,
    );
  }
}
