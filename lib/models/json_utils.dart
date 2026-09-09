/// JSON okurken tip/null hatalarına karşı koruma sağlayan yardımcılar.
///
/// Kural: ikincil alanlar (açıklama, durum, foto yolu…) eksikse güvenli bir
/// varsayılana düşer; kaydın anlamını taşıyan alanlar (tarih gibi) okunamazsa
/// istisna fırlatılır. Böylece bozuk tek kayıt atlanır, uydurma veri üretilmez.
/// Atlanan kayıtları StorageService sayar ve kullanıcıya bildirir.
library;

import 'package:flutter/material.dart';

String jsonMetin(dynamic deger, [String varsayilan = '']) {
  if (deger == null) return varsayilan;
  if (deger is String) return deger;
  return deger.toString();
}

int jsonTamsayi(dynamic deger, [int varsayilan = 0]) {
  if (deger is int) return deger;
  if (deger is num) return deger.toInt();
  if (deger is String) return int.tryParse(deger) ?? varsayilan;
  return varsayilan;
}

double jsonOndalik(dynamic deger, [double varsayilan = 0]) {
  if (deger is double) return deger;
  if (deger is num) return deger.toDouble();
  if (deger is String) return double.tryParse(deger) ?? varsayilan;
  return varsayilan;
}

bool jsonMantik(dynamic deger, [bool varsayilan = false]) {
  if (deger is bool) return deger;
  if (deger is num) return deger != 0;
  if (deger is String) {
    final k = deger.toLowerCase();
    if (k == 'true' || k == '1') return true;
    if (k == 'false' || k == '0') return false;
  }
  return varsayilan;
}

List<String> jsonMetinListesi(dynamic deger) {
  if (deger is! List) return <String>[];
  return deger.where((e) => e != null).map((e) => e.toString()).toList();
}

/// Zorunlu tarih alanı. Okunamazsa istisna fırlatır; çağıran katman kaydı atlar.
DateTime jsonTarih(dynamic deger, String alanAdi) {
  if (deger is String) {
    final ayrisan = DateTime.tryParse(deger);
    if (ayrisan != null) return ayrisan;
  }
  if (deger is int) {
    return DateTime.fromMillisecondsSinceEpoch(deger);
  }
  throw FormatException('$alanAdi alanı okunamadı: $deger');
}

/// İsteğe bağlı tarih alanı. Okunamazsa null döner.
DateTime? jsonTarihOpsiyonel(dynamic deger) {
  if (deger is String) return DateTime.tryParse(deger);
  if (deger is int) return DateTime.fromMillisecondsSinceEpoch(deger);
  return null;
}

/// "9:30" biçimindeki saat alanı. Okunamazsa 00:00 döner.
TimeOfDay jsonSaat(dynamic deger) {
  if (deger is String) {
    final parcalar = deger.split(':');
    if (parcalar.length >= 2) {
      final saat = int.tryParse(parcalar[0].trim());
      final dakika = int.tryParse(parcalar[1].trim());
      if (saat != null && dakika != null) {
        return TimeOfDay(hour: saat.clamp(0, 23), minute: dakika.clamp(0, 59));
      }
    }
  }
  return const TimeOfDay(hour: 0, minute: 0);
}

/// Kimlik alanı. Eksikse kaydı düşürmek yerine benzersiz bir kimlik üretilir.
String jsonKimlik(dynamic deger) {
  final metin = jsonMetin(deger);
  if (metin.isNotEmpty) return metin;
  return 'auto_${DateTime.now().microsecondsSinceEpoch}';
}
