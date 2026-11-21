import 'package:flutter/material.dart' show DateUtils;

import '../models/gunluk_kayit.dart';
import 'ai_kayit_service.dart';

/// Onaylanmış sesli kayıt taslaklarını günlük kayıtlara yazar (sesle kayıt ve
/// sesli görüşme ortak kullanır). O güne kayıt varsa üzerine işlenir, yoksa
/// yeni kayıt eklenir; hava kendiliğinden eklenmez (elle girilir). "1 yeni
/// kayıt" gibi bir özet döner.
Future<String> taslaklariKaydet({
  required List<SesliKayitTaslagi> taslaklar,
  required Map<String, List<GunlukKayit>> projeGunlukKayitlari,
  required void Function(String projeId, GunlukKayit kayit) onKayitEkle,
  required void Function(String projeId, int index, GunlukKayit kayit) onKayitGuncelle,
}) async {
  int sira(SesliKayitTaslagi t) =>
      (projeGunlukKayitlari[t.projeId] ?? const <GunlukKayit>[]).indexWhere((k) => DateUtils.isSameDay(k.tarih, t.tarih));

  // Sıra her taslakta yeniden aranır: aynı güne iki taslak varsa ikincisi
  // birincinin üzerine işlenir.
  int yeni = 0, guncel = 0;
  for (final t in taslaklar) {
    final i = sira(t);
    if (i >= 0) {
      onKayitGuncelle(t.projeId, i, t.kayda(projeGunlukKayitlari[t.projeId]![i]));
      guncel++;
    } else {
      onKayitEkle(t.projeId, t.kayda(null));
      yeni++;
    }
  }
  return [if (yeni > 0) '$yeni yeni kayıt', if (guncel > 0) '$guncel kayıt güncellendi'].join(', ');
}
