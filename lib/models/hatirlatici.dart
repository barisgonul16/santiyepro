import 'package:flutter/material.dart';
import 'json_utils.dart';

class Hatirlatici {
  String id;
  String baslik;
  String aciklama;
  DateTime tarih;
  TimeOfDay saat;
  bool tamamlandi;

  Hatirlatici({
    required this.id,
    required this.baslik,
    required this.aciklama,
    required this.tarih,
    required this.saat,
    this.tamamlandi = false,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'baslik': baslik,
        'aciklama': aciklama,
        'tarih': tarih.toIso8601String(),
        'saat': '${saat.hour}:${saat.minute}',
        'tamamlandi': tamamlandi,
      };

  factory Hatirlatici.fromJson(Map<String, dynamic> json) {
    return Hatirlatici(
      id: jsonKimlik(json['id']),
      baslik: jsonMetin(json['baslik'], jsonMetin(json['mesaj'], 'Başlıksız')),
      aciklama: jsonMetin(json['aciklama']),
      tarih: jsonTarih(json['tarih'], 'tarih'),
      saat: jsonSaat(json['saat']),
      tamamlandi: jsonMantik(json['tamamlandi']),
    );
  }
}
