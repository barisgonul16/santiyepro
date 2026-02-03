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
        id: json['id'],
        fotoYolu: json['fotoYolu'] ?? '',
        firmaAdi: json['firmaAdi'] ?? json['santiyeAdi'] ?? '',
        aciklama: json['aciklama'] ?? '',
        tutar: (json['tutar'] ?? 0).toDouble(),
        kdv: (json['kdv'] ?? 0).toDouble(),
        toplamTutar: (json['toplamTutar'] ?? 0).toDouble(),
        tarih: DateTime.parse(json['tarih']),
      );
}
