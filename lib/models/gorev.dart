import 'package:flutter/material.dart';
import 'json_utils.dart';

class Gorev {
  String ad;
  DateTime tarih;
  TimeOfDay saat;
  bool tamamlandi;

  Gorev({
    required this.ad,
    required this.tarih,
    required this.saat,
    this.tamamlandi = false,
  });
  Map<String, dynamic> toJson() => {
        'ad': ad,
        'tarih': tarih.toIso8601String(),
        'saat': '${saat.hour}:${saat.minute}',
        'tamamlandi': tamamlandi,
      };

  factory Gorev.fromJson(Map<String, dynamic> json) {
    return Gorev(
      ad: jsonMetin(json['ad'], 'İsimsiz Görev'),
      tarih: jsonTarih(json['tarih'], 'tarih'),
      saat: jsonSaat(json['saat']),
      tamamlandi: jsonMantik(json['tamamlandi']),
    );
  }
}
