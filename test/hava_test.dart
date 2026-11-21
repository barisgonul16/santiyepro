import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santiyepro/models/gunluk_kayit.dart';
import 'package:santiyepro/models/proje.dart';
import 'package:santiyepro/screens/proje_detay_sayfa.dart';
import 'package:santiyepro/services/hava_servisi.dart';

final _proje = Proje(
  id: 'a',
  ad: 'Gera makina',
  aciklama: '',
  baslangicTarihi: DateTime(2026, 1, 1),
  toplamGun: 100,
);

Widget _sayfa({
  List<GunlukKayit> kayitlar = const [],
  List<GunlukKayit>? kaydedilen,
  int sekme = 1,
}) =>
    MaterialApp(
      home: ProjeDetaySayfa(
        proje: _proje,
        gunlukKayitlar: kayitlar,
        onKayitEkle: (k) => kaydedilen?.add(k),
        onKayitGuncelle: (_, k) => kaydedilen?.add(k),
        projeGunlukKayitlari: const {},
        ekipler: const [],
        baslangicSekmesi: sekme,
      ),
    );

void main() {
  group('Kayıt modeli', () {
    test('hava alanları saklanır ve geri okunur', () {
      final k = GunlukKayit(
        tarih: DateTime(2026, 10, 12),
        hava: 'kar',
        havaMin: -3,
        havaMax: 2,
        havaDurdu: true,
      );
      final geri = GunlukKayit.fromJson(jsonDecode(jsonEncode(k.toJson())) as Map<String, dynamic>);
      expect((geri.hava, geri.havaMin, geri.havaMax, geri.havaDurdu), ('kar', -3, 2, true));
    });

    test('hava girilmemişse dosyaya hava alanı yazılmaz (kayıtlar şişmez)', () {
      final json = GunlukKayit(tarih: DateTime(2026, 10, 12), kalipci: 4).toJson();
      expect(json.keys.where((a) => a.startsWith('hava')), isEmpty);
    });

    test('eski kayıt (hava alanı yok) havasız okunur', () {
      final k = GunlukKayit.fromJson({'tarih': '2026-10-01T00:00:00.000', 'kalipci': 3});
      expect((k.hava, k.havaMin, k.havaMax, k.havaDurdu), ('', null, null, false));
    });

    test('bozuk hava alanları kaydı düşürmez', () {
      final k = GunlukKayit.fromJson({
        'tarih': '2026-10-01T00:00:00.000',
        'hava': 7,
        'havaMin': 'soğuk',
        'havaMax': '12',
        'havaDurdu': 'true',
      });
      expect((k.hava, k.havaMin, k.havaMax, k.havaDurdu), ('7', null, 12, true));
    });

    test('kısa metinler', () {
      expect(HavaGosterim.sicaklik(8, 14), '8°/14°');
      expect(HavaGosterim.sicaklik(14, 14), '14°');
      expect(HavaGosterim.sicaklik(null, 9), '9°');
      expect(HavaGosterim.sicaklik(null, null), '');
      final k = GunlukKayit(tarih: DateTime(2026, 10, 12), hava: 'yagmur', havaMin: 8, havaMax: 14, havaDurdu: true);
      expect(HavaGosterim.ozet(k), 'Yağmurlu · 8°/14° · çalışılamadı');
      expect(HavaGosterim.ozet(GunlukKayit(tarih: DateTime(2026, 10, 12))), '');
    });
  });

  group('Giriş formu', () {
    void genisPencere(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('hava kendiliğinden gelmez; durum, sıcaklık ve "çalışılamadı" elle girilip kayda yazılır',
        (tester) async {
      genisPencere(tester);
      final kaydedilen = <GunlukKayit>[];
      await tester.pumpWidget(_sayfa(kaydedilen: kaydedilen));
      await tester.pumpAndSettle();

      expect(find.text('Hava'), findsOneWidget); // boş, elle girilmeyi bekliyor
      expect(find.text('Kaydedilmemiş değişiklik var'), findsNothing);

      await tester.tap(find.byKey(const Key('hava_satiri')));
      await tester.pumpAndSettle();
      expect(find.text('Otomatik al'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Yağmurlu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('hava_min')), '-3');
      await tester.enterText(find.byKey(const Key('hava_max')), '12');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20)); // pencereyi kapat
      await tester.pumpAndSettle();
      expect(find.text('-3°/12°'), findsOneWidget);
      expect(find.text('· durdu'), findsOneWidget);

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      final k = kaydedilen.single;
      expect((k.hava, k.havaMin, k.havaMax, k.havaDurdu), ('yagmur', -3, 12, true));
    });

    testWidgets('kayıtlı hava gösterilir; sıcaklık silinince kayıttan da kalkar', (tester) async {
      genisPencere(tester);
      final kaydedilen = <GunlukKayit>[];
      await tester.pumpWidget(_sayfa(
        kaydedilen: kaydedilen,
        kayitlar: [GunlukKayit(tarih: DateTime.now(), kalipci: 3, hava: 'bulutlu', havaMin: 3, havaMax: 9)],
      ));
      await tester.pumpAndSettle();
      expect(find.text('3°/9°'), findsOneWidget);

      await tester.tap(find.byKey(const Key('hava_satiri')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('hava_min')), '');
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('9°'), findsOneWidget);

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      final k = kaydedilen.single;
      expect((k.hava, k.havaMin, k.havaMax), ('bulutlu', null, 9));
    });
  });

  group('Özet', () {
    testWidgets('havadan dolayı durulan gün sayısı yalnızca varsa görünür', (tester) async {
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final simdi = DateTime.now();
      final ay = DateTime(simdi.year, simdi.month);

      await tester.pumpWidget(_sayfa(
        sekme: 0,
        kayitlar: [GunlukKayit(tarih: ay, kalipci: 3), GunlukKayit(tarih: ay.add(const Duration(days: 1)), kalipci: 4)],
      ));
      await tester.pumpAndSettle();
      expect(find.text('hava nedeniyle'), findsNothing);

      await tester.pumpWidget(_sayfa(
        sekme: 0,
        kayitlar: [
          GunlukKayit(tarih: ay, kalipci: 3, hava: 'yagmur', havaDurdu: true),
          GunlukKayit(tarih: ay.add(const Duration(days: 1)), kalipci: 4, hava: 'kar', havaDurdu: true),
          GunlukKayit(tarih: ay.add(const Duration(days: 2)), kalipci: 4, hava: 'acik'),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('hava nedeniyle'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
    });
  });
}
