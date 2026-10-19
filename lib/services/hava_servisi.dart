import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/gunluk_kayit.dart';
import 'app_log.dart';
import 'settings_service.dart';

/// Bir günün hava özeti: kayda yazılan kadarı (durum + en düşük/en yüksek °C).
class GunHavasi {
  /// [HavaGosterim.durumlar] içinden bir anahtar.
  final String durum;
  final int? enDusuk;
  final int? enYuksek;

  const GunHavasi(this.durum, this.enDusuk, this.enYuksek);
}

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

  /// Open-Meteo (WMO) hava kodunu uygulamadaki altı duruma çevirir.
  static String koddanDurum(int kod) {
    if (kod <= 1) return 'acik'; // 0 açık, 1 çoğunlukla açık
    if (kod <= 3) return 'bulutlu'; // 2 parçalı bulutlu, 3 kapalı
    if (kod == 45 || kod == 48) return 'sis';
    if (kod >= 95) return 'firtina'; // 95-99 gök gürültülü fırtına
    if ((kod >= 71 && kod <= 77) || kod == 85 || kod == 86) return 'kar';
    return 'yagmur'; // 51-67 çise/yağmur, 80-82 sağanak
  }

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

/// Seçili şehrin (Ayarlar > Şehir) bir güne ait hava durumunu Open-Meteo'dan
/// alır. Ücretsizdir, anahtar gerekmez; internete yalnızca şehir adı ve tarih
/// gider. Alınamazsa null döner, kayıt havasız kaydedilir.
class HavaServisi {
  static const Duration _zamanAsimi = Duration(seconds: 8);

  /// Tahmin servisi bu kadar günden yeni geçmişi, ilerisini 16 güne kadar verir;
  /// daha eski günler arşiv servisinden alınır.
  static const int _tahminGeriGun = 60;
  static const int _tahminIleriGun = 14;

  /// Şehir adı → enlem/boylam; uygulama açık kaldığı sürece yeniden sorulmaz.
  static final Map<String, (double, double)> _konumlar = {};

  @visibleForTesting
  static void konumOnbelleginiTemizle() => _konumlar.clear();

  final http.Client _istemci;
  final Future<String> Function() _sehirOkuyucu;

  HavaServisi({http.Client? istemci, Future<String> Function()? sehirOkuyucu})
      : _istemci = istemci ?? http.Client(),
        _sehirOkuyucu = sehirOkuyucu ?? _ayardakiSehir;

  static Future<String> _ayardakiSehir() async {
    final sehir = (await SettingsService().loadSettings()).sehir.trim();
    return sehir.isEmpty ? 'Bursa' : sehir;
  }

  static String _tarih(DateTime g) =>
      '${g.year.toString().padLeft(4, '0')}-${g.month.toString().padLeft(2, '0')}-${g.day.toString().padLeft(2, '0')}';

  Future<(double, double)?> _konum(String sehir) async {
    final onbellek = _konumlar[sehir];
    if (onbellek != null) return onbellek;
    final yanit = await _istemci
        .get(Uri.parse(
            'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(sehir)}&count=1&language=tr&format=json'))
        .timeout(_zamanAsimi);
    if (yanit.statusCode != 200) return null;
    final veri = jsonDecode(yanit.body);
    final sonuclar = veri is Map ? veri['results'] : null;
    if (sonuclar is! List || sonuclar.isEmpty || sonuclar.first is! Map) return null;
    final enlem = (sonuclar.first['latitude'] as num?)?.toDouble();
    final boylam = (sonuclar.first['longitude'] as num?)?.toDouble();
    if (enlem == null || boylam == null) return null;
    return _konumlar[sehir] = (enlem, boylam);
  }

  static num? _ilkSayi(dynamic liste) => liste is List && liste.isNotEmpty && liste.first is num ? liste.first as num : null;

  /// [gun]'ün hava özeti. Gelecekteki (14 günden ileri) günler için, internet
  /// yoksa ya da servis yanıt vermezse null döner; hiçbir zaman istisna fırlatmaz.
  Future<GunHavasi?> gunHavasi(DateTime gun) async {
    try {
      final simdi = DateTime.now();
      final bugun = DateTime(simdi.year, simdi.month, simdi.day);
      final hedef = DateTime(gun.year, gun.month, gun.day);
      final fark = hedef.difference(bugun).inDays;
      if (fark > _tahminIleriGun) return null;

      final konum = await _konum(await _sehirOkuyucu());
      if (konum == null) return null;

      final taban = fark >= -_tahminGeriGun
          ? 'https://api.open-meteo.com/v1/forecast'
          : 'https://archive-api.open-meteo.com/v1/archive';
      final t = _tarih(hedef);
      final yanit = await _istemci
          .get(Uri.parse('$taban?latitude=${konum.$1}&longitude=${konum.$2}'
              '&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&start_date=$t&end_date=$t'))
          .timeout(_zamanAsimi);
      if (yanit.statusCode != 200) return null;

      final veri = jsonDecode(yanit.body);
      final gunluk = veri is Map ? veri['daily'] : null;
      if (gunluk is! Map) return null;
      final kod = _ilkSayi(gunluk['weather_code']);
      if (kod == null) return null;
      return GunHavasi(
        HavaGosterim.koddanDurum(kod.round()),
        _ilkSayi(gunluk['temperature_2m_min'])?.round(),
        _ilkSayi(gunluk['temperature_2m_max'])?.round(),
      );
    } catch (e) {
      appLog('Hava bilgisi alınamadı: $e');
      return null;
    }
  }
}
