import 'package:flutter/material.dart';

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
    var timeParts = (json['saat'] as String).split(':');
    return Gorev(
      ad: json['ad'],
      tarih: DateTime.parse(json['tarih']),
      saat: TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1])),
      tamamlandi: json['tamamlandi'],
    );
  }
}
