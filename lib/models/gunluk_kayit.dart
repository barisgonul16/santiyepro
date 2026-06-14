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

  // Vinç bilgileri
  String vincFirmaAdi;
  String vincBaslangic; // "HH:mm" formatında
  String vincBitis;     // "HH:mm" formatında
  int vincMola;         // Dakika cinsinden

  // Yevmiye bilgileri
  String yevmiyeEkipAdi;
  double yevmiyeMiktari;
  String yevmiyeAciklama;

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
  });
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
        'vincFirmaAdi': vincFirmaAdi,
        'vincBaslangic': vincBaslangic,
        'vincBitis': vincBitis,
        'vincMola': vincMola,
        'yevmiyeEkipAdi': yevmiyeEkipAdi,
        'yevmiyeMiktari': yevmiyeMiktari,
        'yevmiyeAciklama': yevmiyeAciklama,
      };

  factory GunlukKayit.fromJson(Map<String, dynamic> json) {
    return GunlukKayit(
      tarih: DateTime.parse(json['tarih']),
      kalipci: json['kalipci'],
      demirci: json['demirci'],
      diger: json['diger'],
      yemekKalipci: json['yemekKalipci'] ?? 0,
      yemekDemirci: json['yemekDemirci'] ?? 0,
      yemekDiger: json['yemekDiger'] ?? 0,
      kalipciYapilanIs: json['kalipciYapilanIs'],
      demirciYapilanIs: json['demirciYapilanIs'],
      notlar: json['notlar'],
      beton: json['beton'] ?? '',
      fotografYollari: List<String>.from(json['fotografYollari'] ?? []),
      vincFirmaAdi: json['vincFirmaAdi'] ?? '',
      vincBaslangic: json['vincBaslangic'] ?? '',
      vincBitis: json['vincBitis'] ?? '',
      vincMola: json['vincMola'] ?? 0,
      yevmiyeEkipAdi: json['yevmiyeEkipAdi'] ?? '',
      yevmiyeMiktari: (json['yevmiyeMiktari'] ?? 0).toDouble(),
      yevmiyeAciklama: json['yevmiyeAciklama'] ?? '',
    );
  }
}

