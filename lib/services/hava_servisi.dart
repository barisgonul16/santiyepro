import 'package:flutter/material.dart';

import '../models/gunluk_kayit.dart';

/// Hava elle girilir (internetten alınan hava zaman zaman yanlış çıkıyordu).
/// Hava durumu anahtarlarının adları, simgeleri ve kısa metin biçimleri.
class HavaGosterim {
  static const List<String> durumlar = ['acik', 'bulutlu', 'sis', 'yagmur', 'kar', 'firtina'];

  static String ad(String durum) => switch (durum) {
        'acik' => 'Açık',
        'bulutlu' => 'Bulutlu',
        'sis' => 'Sisli',
        'yagmur' => 'Yağmurlu',
        'kar' => 'Karlı',
        'firtina' => 'Fırtınalı',
        _ => '',
      };

  static IconData simge(String durum) => switch (durum) {
        'acik' => Icons.wb_sunny_outlined,
        'bulutlu' => Icons.cloud_outlined,
        'sis' => Icons.foggy,
        'yagmur' => Icons.water_drop_outlined,
        'kar' => Icons.ac_unit,
        'firtina' => Icons.thunderstorm_outlined,
        _ => Icons.cloud_queue,
      };

  /// "8°/14°" (en düşük/en yüksek) ya da tek değer "14°"; ikisi de yoksa boş.
  static String sicaklik(int? enDusuk, int? enYuksek) {
    if (enDusuk != null && enYuksek != null) {
      return enDusuk == enYuksek ? '$enYuksek°' : '$enDusuk°/$enYuksek°';
    }
    final tek = enYuksek ?? enDusuk;
    return tek == null ? '' : '$tek°';
  }

  /// Kayıt için tek satırlık özet: "Yağmurlu · 8°/14° · çalışılamadı". Havası
  /// girilmemişse boş döner.
  static String ozet(GunlukKayit k) {
    final sicak = sicaklik(k.havaMin, k.havaMax);
    return [
      if (ad(k.hava).isNotEmpty) ad(k.hava),
      if (sicak.isNotEmpty) sicak,
      if (k.havaDurdu) 'çalışılamadı',
    ].join(' · ');
  }
}
