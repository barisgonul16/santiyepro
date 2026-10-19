import 'dart:async';

import 'package:flutter/material.dart' show DateUtils;

import '../models/gunluk_kayit.dart';
import 'ai_kayit_service.dart';
import 'hava_servisi.dart';

/// Onaylanmış sesli kayıt taslaklarını günlük kayıtlara yazar (sesle kayıt ve
/// sesli görüşme ortak kullanır). O güne kayıt varsa üzerine işlenir, yoksa
/// yeni kayıt eklenir. Havası girilmemiş günlere o günün havası eklenir;
/// alınamazsa kayıt havasız yazılır. "1 yeni kayıt" gibi bir özet döner.
Future<String> taslaklariKaydet({
  required List<SesliKayitTaslagi> taslaklar,
  required Map<String, List<GunlukKayit>> projeGunlukKayitlari,
  required void Function(String projeId, GunlukKayit kayit) onKayitEkle,
  required void Function(String projeId, int index, GunlukKayit kayit) onKayitGuncelle,
  HavaServisi? havaServisi,
}) async {
  int sira(SesliKayitTaslagi t) =>
      (projeGunlukKayitlari[t.projeId] ?? const <GunlukKayit>[]).indexWhere((k) => DateUtils.isSameDay(k.tarih, t.tarih));

  // Havası olmayan günlerin havası (her gün için bir kez).
  final bugun = DateUtils.dateOnly(DateTime.now());
  final gunler = <DateTime>{};
  for (final t in taslaklar) {
    final gun = DateUtils.dateOnly(t.tarih);
    if (gun.isAfter(bugun)) continue;
    final i = t.projeId.isEmpty ? -1 : sira(t);
    if (i < 0 || projeGunlukKayitlari[t.projeId]![i].hava.isEmpty) gunler.add(gun);
  }
  final servis = havaServisi ?? HavaServisi();
  final havalar = <DateTime, GunHavasi>{};
  await Future.wait([
    for (final gun in gunler)
      servis.gunHavasi(gun).timeout(const Duration(seconds: 6), onTimeout: () => null).then((h) {
        if (h != null) havalar[gun] = h;
      }),
  ]);

  GunlukKayit hazirla(SesliKayitTaslagi t, GunlukKayit? mevcut) {
    final kayit = t.kayda(mevcut);
    final hava = havalar[DateUtils.dateOnly(t.tarih)];
    if (kayit.hava.isEmpty && hava != null) {
      kayit.hava = hava.durum;
      kayit.havaMin = hava.enDusuk;
      kayit.havaMax = hava.enYuksek;
    }
    return kayit;
  }

  // Sıra her taslakta yeniden aranır: aynı güne iki taslak varsa ikincisi
  // birincinin üzerine işlenir.
  int yeni = 0, guncel = 0;
  for (final t in taslaklar) {
    final i = sira(t);
    if (i >= 0) {
      onKayitGuncelle(t.projeId, i, hazirla(t, projeGunlukKayitlari[t.projeId]![i]));
      guncel++;
    } else {
      onKayitEkle(t.projeId, hazirla(t, null));
      yeni++;
    }
  }
  return [if (yeni > 0) '$yeni yeni kayıt', if (guncel > 0) '$guncel kayıt güncellendi'].join(', ');
}
