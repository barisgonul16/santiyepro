class Malzeme {
  final String id;
  final String ad;
  final String konum;
  final String durum; // e.g., "Şantiyede", "Tamirde", "Depoda"
  final String fotoYolu;

  Malzeme({
    required this.id,
    required this.ad,
    required this.konum,
    required this.durum,
    this.fotoYolu = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ad': ad,
        'konum': konum,
        'durum': durum,
        'fotoYolu': fotoYolu,
      };

  factory Malzeme.fromJson(Map<String, dynamic> json) => Malzeme(
        id: json['id'],
        ad: json['ad'],
        konum: json['konum'],
        durum: json['durum'],
        fotoYolu: json['fotoYolu'] ?? '',
      );
}
