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

  Map<String, dynamic> toJson() => {
        'firmaAdi': firmaAdi,
        'baslangic': baslangic,
        'bitis': bitis,
        'mola': mola,
      };

  factory VincBilgisi.fromJson(Map<String, dynamic> json) {
    return VincBilgisi(
      firmaAdi: json['firmaAdi'] ?? '',
      baslangic: json['baslangic'] ?? '',
      bitis: json['bitis'] ?? '',
      mola: json['mola'] ?? 0,
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
      ekipAdi: json['ekipAdi'] ?? '',
      miktar: (json['miktar'] ?? 0.0).toDouble(),
      aciklama: json['aciklama'] ?? '',
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
    final vinclerJson = json['vincler'] as List?;
    final List<VincBilgisi> parsedVincler = vinclerJson != null
        ? vinclerJson.map((v) => VincBilgisi.fromJson(v as Map<String, dynamic>)).toList()
        : [];

    final yevmiyelerJson = json['yevmiyeler'] as List?;
    final List<YevmiyeBilgisi> parsedYevmiyeler = yevmiyelerJson != null
        ? yevmiyelerJson.map((y) => YevmiyeBilgisi.fromJson(y as Map<String, dynamic>)).toList()
        : [];

    return GunlukKayit(
      tarih: DateTime.parse(json['tarih']),
      kalipci: json['kalipci'] ?? 0,
      demirci: json['demirci'] ?? 0,
      diger: json['diger'] ?? 0,
      yemekKalipci: json['yemekKalipci'] ?? 0,
      yemekDemirci: json['yemekDemirci'] ?? 0,
      yemekDiger: json['yemekDiger'] ?? 0,
      kalipciYapilanIs: json['kalipciYapilanIs'] ?? '',
      demirciYapilanIs: json['demirciYapilanIs'] ?? '',
      notlar: json['notlar'] ?? '',
      beton: json['beton'] ?? '',
      fotografYollari: List<String>.from(json['fotografYollari'] ?? []),
      vincFirmaAdi: json['vincFirmaAdi'] ?? '',
      vincBaslangic: json['vincBaslangic'] ?? '',
      vincBitis: json['vincBitis'] ?? '',
      vincMola: json['vincMola'] ?? 0,
      yevmiyeEkipAdi: json['yevmiyeEkipAdi'] ?? '',
      yevmiyeMiktari: (json['yevmiyeMiktari'] ?? 0).toDouble(),
      yevmiyeAciklama: json['yevmiyeAciklama'] ?? '',
      vincler: parsedVincler,
      yevmiyeler: parsedYevmiyeler,
    );
  }
}
