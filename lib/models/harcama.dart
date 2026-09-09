import 'json_utils.dart';

class Harcama {
  final String id;
  final String fisYolu;
  final double tutar;
  final String aciklama;
  final String kategori;
  final DateTime tarih;
  final bool isReimbursement;

  Harcama({
    required this.id,
    this.fisYolu = '',
    required this.tutar,
    required this.aciklama,
    required this.kategori,
    required this.tarih,
    this.isReimbursement = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fisYolu': fisYolu,
        'tutar': tutar,
        'aciklama': aciklama,
        'kategori': kategori,
        'tarih': tarih.toIso8601String(),
        'isReimbursement': isReimbursement,
      };

  factory Harcama.fromJson(Map<String, dynamic> json) => Harcama(
        id: jsonKimlik(json['id']),
        fisYolu: jsonMetin(json['fisYolu']),
        tutar: jsonOndalik(json['tutar'] ?? json['miktar']),
        aciklama: jsonMetin(json['aciklama']),
        kategori: jsonMetin(json['kategori'], 'Genel'),
        tarih: jsonTarih(json['tarih'], 'tarih'),
        isReimbursement: jsonMantik(json['isReimbursement']),
      );
}
