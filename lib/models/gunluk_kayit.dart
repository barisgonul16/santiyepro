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
    );
  }
}
