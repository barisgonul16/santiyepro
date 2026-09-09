import 'json_utils.dart';

class PratikBilgi {
  final String id;
  final String baslik;
  final String icerik;
  final int kategoriId; // 0: Genel, 1: Tahvil, 2: Beton, etc. or just custom

  PratikBilgi({
    required this.id,
    required this.baslik,
    required this.icerik,
    this.kategoriId = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'baslik': baslik,
        'icerik': icerik,
        'kategoriId': kategoriId,
      };

  factory PratikBilgi.fromJson(Map<String, dynamic> json) => PratikBilgi(
        id: jsonKimlik(json['id']),
        baslik: jsonMetin(json['baslik'], 'Başlıksız'),
        icerik: jsonMetin(json['icerik']),
        kategoriId: jsonTamsayi(json['kategoriId']),
      );
}
