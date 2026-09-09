import 'json_utils.dart';

class Not {
  String baslik;
  String icerik;
  DateTime olusturmaTarihi;
  DateTime? guncellenmeTarihi;

  Not({
    required this.baslik,
    required this.icerik,
    required this.olusturmaTarihi,
    this.guncellenmeTarihi,
  });
  Map<String, dynamic> toJson() => {
        'baslik': baslik,
        'icerik': icerik,
        'olusturmaTarihi': olusturmaTarihi.toIso8601String(),
        'guncellenmeTarihi': guncellenmeTarihi?.toIso8601String(),
      };

  factory Not.fromJson(Map<String, dynamic> json) {
    return Not(
      baslik: jsonMetin(json['baslik'], 'Başlıksız'),
      icerik: jsonMetin(json['icerik']),
      olusturmaTarihi: jsonTarih(json['olusturmaTarihi'], 'olusturmaTarihi'),
      guncellenmeTarihi: jsonTarihOpsiyonel(json['guncellenmeTarihi']),
    );
  }
}
