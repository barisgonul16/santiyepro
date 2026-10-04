import 'json_utils.dart';

/// Hakedişteki tek iş kalemi (kalıp, demir, beton, iskele...).
class HakedisKalemi {
  final String ad;
  final String birim;
  final double miktar;
  final double birimFiyat;
  /// İşi yapan ekip: "Kalıpçı", "Demirci", "Diğer" ya da kayıtlı bir ekip adı.
  final String ekip;

  const HakedisKalemi({
    required this.ad,
    required this.birim,
    this.miktar = 0,
    this.birimFiyat = 0,
    this.ekip = '',
  });

  double get tutar => miktar * birimFiyat;

  Map<String, dynamic> toJson() => {
        'ad': ad,
        'birim': birim,
        'miktar': miktar,
        'birimFiyat': birimFiyat,
        'ekip': ekip,
      };

  factory HakedisKalemi.fromJson(Map<String, dynamic> json) => HakedisKalemi(
        ad: jsonMetin(json['ad']),
        birim: jsonMetin(json['birim']),
        miktar: jsonOndalik(json['miktar']),
        birimFiyat: jsonOndalik(json['birimFiyat']),
        ekip: jsonMetin(json['ekip']),
      );
}

/// Bir projenin belirli bir dönemine ait hakediş: yapılan işin metrajı ve
/// (girildiyse) birim fiyatları. O dönemin adam-günü burada saklanmaz,
/// günlük kayıtlardan hesaplanır.
class Hakedis {
  /// Yeni hakedişte hazır gelen kalemler.
  static const List<HakedisKalemi> varsayilanKalemler = [
    HakedisKalemi(ad: 'Kalıp', birim: 'm²', ekip: 'Kalıpçı'),
    HakedisKalemi(ad: 'Demir', birim: 'ton', ekip: 'Demirci'),
    HakedisKalemi(ad: 'Beton', birim: 'm³', ekip: 'Kalıpçı'),
    HakedisKalemi(ad: 'İskele', birim: 'm³', ekip: 'Kalıpçı'),
  ];

  /// Elle eklenen satırlarda seçilebilen birimler.
  static const List<String> birimler = ['m²', 'm³', 'ton', 'kg', 'm', 'adet', 'yevmiye', 'saat'];

  /// Her projede bulunan ekip türleri; kayıtlı ekip adları bunlara eklenir.
  static const List<String> ekipTurleri = ['Kalıpçı', 'Demirci', 'Diğer'];

  final String id;
  final String projeId;
  final DateTime baslangic;
  final DateTime bitis;
  final List<HakedisKalemi> kalemler;
  final String not;

  const Hakedis({
    required this.id,
    required this.projeId,
    required this.baslangic,
    required this.bitis,
    required this.kalemler,
    this.not = '',
  });

  double get toplamTutar => kalemler.fold(0.0, (t, k) => t + k.tutar);

  Map<String, dynamic> toJson() => {
        'id': id,
        'projeId': projeId,
        'baslangic': baslangic.toIso8601String(),
        'bitis': bitis.toIso8601String(),
        'kalemler': kalemler.map((k) => k.toJson()).toList(),
        'not': not,
      };

  factory Hakedis.fromJson(Map<String, dynamic> json) => Hakedis(
        id: jsonKimlik(json['id']),
        projeId: jsonMetin(json['projeId']),
        baslangic: jsonTarih(json['baslangic'], 'baslangic'),
        bitis: jsonTarih(json['bitis'], 'bitis'),
        kalemler: [
          if (json['kalemler'] is List)
            for (final k in json['kalemler'])
              if (k is Map) HakedisKalemi.fromJson(Map<String, dynamic>.from(k)),
        ],
        not: jsonMetin(json['not']),
      );
}
