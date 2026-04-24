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

  // Vinç bilgileri
  String vincFirmaAdi;
  String vincBaslangic; // "HH:mm" formatında
  String vincBitis;     // "HH:mm" formatında
  int vincMola;         // Dakika cinsinden

  GunlukKayit({
    required this.tarih,
    this.kalipci = 0,
    this.demirci = 0,
    this.diger = 0,
    this.kalipciYapilanIs = '',
    this.demirciYapilanIs = '',
    this.notlar = '',
    this.beton = '',
    this.fotografYollari = const [],
    this.vincFirmaAdi = '',
    this.vincBaslangic = '',
    this.vincBitis = '',
    this.vincMola = 0,
  });
  Map<String, dynamic> toJson() => {
        'tarih': tarih.toIso8601String(),
        'kalipci': kalipci,
        'demirci': demirci,
        'diger': diger,
        'kalipciYapilanIs': kalipciYapilanIs,
        'demirciYapilanIs': demirciYapilanIs,
        'notlar': notlar,
        'beton': beton,
        'fotografYollari': fotografYollari,
        'vincFirmaAdi': vincFirmaAdi,
        'vincBaslangic': vincBaslangic,
        'vincBitis': vincBitis,
        'vincMola': vincMola,
      };

  factory GunlukKayit.fromJson(Map<String, dynamic> json) {
    return GunlukKayit(
      tarih: DateTime.parse(json['tarih']),
      kalipci: json['kalipci'],
      demirci: json['demirci'],
      diger: json['diger'],
      kalipciYapilanIs: json['kalipciYapilanIs'],
      demirciYapilanIs: json['demirciYapilanIs'],
      notlar: json['notlar'],
      beton: json['beton'] ?? '',
      fotografYollari: List<String>.from(json['fotografYollari'] ?? []),
      vincFirmaAdi: json['vincFirmaAdi'] ?? '',
      vincBaslangic: json['vincBaslangic'] ?? '',
      vincBitis: json['vincBitis'] ?? '',
      vincMola: json['vincMola'] ?? 0,
    );
  }
}

