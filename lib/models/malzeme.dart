import 'json_utils.dart';

class Malzeme {
  final String id;
  final String ad;
  final String konum;
  final String durum; // e.g., "Şantiyede", "Tamirde", "Depoda"
  final String fotoYolu;
  /// Aletin şu an bulunduğu şantiye (boş: depoda / şantiyede değil). Her
  /// değişiklik malzeme hareketi olarak da kaydedilir (aletId ile).
  final String projeId;

  Malzeme({
    required this.id,
    required this.ad,
    required this.konum,
    required this.durum,
    this.fotoYolu = '',
    this.projeId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ad': ad,
        'konum': konum,
        'durum': durum,
        'fotoYolu': fotoYolu,
        'projeId': projeId,
      };

  factory Malzeme.fromJson(Map<String, dynamic> json) => Malzeme(
        id: jsonKimlik(json['id']),
        ad: jsonMetin(json['ad'], 'İsimsiz Malzeme'),
        konum: jsonMetin(json['konum']),
        durum: jsonMetin(json['durum'], 'Depoda'),
        fotoYolu: jsonMetin(json['fotoYolu']),
        projeId: jsonMetin(json['projeId']),
      );
}
