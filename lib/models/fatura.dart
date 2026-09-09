import 'json_utils.dart';

class Fatura {
  final String id;
  final String fotoYolu;
  final String firmaAdi;
  final String aciklama;
  final double tutar;
  final double kdv;
  final double toplamTutar;
  final DateTime tarih;

  Fatura({
    required this.id,
    required this.fotoYolu,
    required this.firmaAdi,
    required this.aciklama,
    required this.tutar,
    required this.kdv,
    required this.toplamTutar,
    required this.tarih,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fotoYolu': fotoYolu,
        'firmaAdi': firmaAdi,
        'aciklama': aciklama,
        'tutar': tutar,
        'kdv': kdv,
        'toplamTutar': toplamTutar,
        'tarih': tarih.toIso8601String(),
      };

  factory Fatura.fromJson(Map<String, dynamic> json) => Fatura(
        id: jsonKimlik(json['id']),
        fotoYolu: jsonMetin(json['fotoYolu']),
        firmaAdi: jsonMetin(json['firmaAdi'], jsonMetin(json['santiyeAdi'])),
        aciklama: jsonMetin(json['aciklama']),
        tutar: jsonOndalik(json['tutar']),
        kdv: jsonOndalik(json['kdv']),
        toplamTutar: jsonOndalik(json['toplamTutar']),
        tarih: jsonTarih(json['tarih'], 'tarih'),
      );
}
