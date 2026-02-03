import 'package:flutter/material.dart';

class PratikBilgi {
  final String id;
  final String baslik;
  final String icerik;
  final int kategoriId; // 0: Genel, 1: Tahvil, 2: Beton, etc. or just custom

  PratikBilgi({
    required this.id,
    required this.baslik,
    required this.icerik,
    this.kategoriId = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'baslik': baslik,
        'icerik': icerik,
        'kategoriId': kategoriId,
      };

  factory PratikBilgi.fromJson(Map<String, dynamic> json) => PratikBilgi(
        id: json['id'],
        baslik: json['baslik'],
        icerik: json['icerik'],
        kategoriId: json['kategoriId'] ?? 0,
      );
}
