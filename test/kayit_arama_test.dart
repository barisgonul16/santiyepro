import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santiyepro/models/gunluk_kayit.dart';
import 'package:santiyepro/models/proje.dart';
import 'package:santiyepro/screens/kayit_arama_sayfa.dart';

GunlukKayit _kayit(DateTime tarih, {String kalipci = '', String beton = '', String not = ''}) =>
    GunlukKayit.fromJson({
      'tarih': tarih.toIso8601String(),
      'kalipciYapilanIs': kalipci,
      'beton': beton,
      'notlar': not,
    });

void main() {
  test('sade: büyük/küçük ve Türkçe harf farkı yok sayılır', () {
    expect(KayitAramaSayfa.sade('DÖŞEME Betonu'), 'doseme betonu');
    expect(KayitAramaSayfa.sade('IŞIK İğne çöğür'), 'isik igne cogur');
  });

  testWidgets('kelimeler kaydın farklı alanlarında aranır, en yeni üstte', (tester) async {
    final a = Proje(id: 'a', ad: 'A Şantiyesi', aciklama: '', baslangicTarihi: DateTime(2026, 1, 1), toplamGun: 10);
    final b = Proje(id: 'b', ad: 'B Şantiyesi', aciklama: '', baslangicTarihi: DateTime(2026, 1, 1), toplamGun: 10);
    (Proje, DateTime)? secilen;

    await tester.pumpWidget(MaterialApp(
      home: KayitAramaSayfa(
        projeler: [a, b],
        projeGunlukKayitlari: {
          'a': [
            _kayit(DateTime(2026, 9, 1), kalipci: 'Bodrum kat DÖŞEME kalıbı', beton: 'döşeme betonu 110m3'),
            _kayit(DateTime(2026, 9, 2), kalipci: 'perde kalıbı'),
          ],
          'b': [_kayit(DateTime(2026, 9, 5), not: 'Döşeme betonu ertelendi')],
          // Projesi silinmiş kayıtlar aranmaz.
          'silinmis': [_kayit(DateTime(2026, 9, 9), beton: 'döşeme betonu')],
        },
        onSec: (p, t) => secilen = (p, t),
      ),
    ));

    expect(find.textContaining('En az 2 harf'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'doseme beton');
    await tester.pump();
    expect(find.text('2 kayıt bulundu.'), findsOneWidget);
    expect(find.text('B Şantiyesi'), findsOneWidget);
    expect(find.text('A Şantiyesi'), findsOneWidget);
    // En yeni kayıt (B, 05.09) üstte.
    expect(tester.getTopLeft(find.text('05.09.2026')).dy, lessThan(tester.getTopLeft(find.text('01.09.2026')).dy));

    await tester.tap(find.text('01.09.2026'));
    expect(secilen?.$1.id, 'a');
    expect(secilen?.$2, DateTime(2026, 9, 1));

    await tester.enterText(find.byType(TextField), 'asansör');
    await tester.pump();
    expect(find.text('Sonuç bulunamadı.'), findsOneWidget);
  });
}
