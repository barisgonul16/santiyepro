import 'package:flutter/material.dart';

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
    var timeParts = (json['saat'] as String).split(':');
    return Hatirlatici(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      baslik: json['baslik'] ?? json['mesaj'] ?? 'Başlıksız',
      aciklama: json['aciklama'] ?? '',
      tarih: DateTime.parse(json['tarih']),
      saat: TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1])),
      tamamlandi: json['tamamlandi'],
    );
  }
}
