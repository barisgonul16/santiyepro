import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santiyepro/models/gunluk_kayit.dart';
import 'package:santiyepro/models/proje.dart';
import 'package:santiyepro/screens/proje_detay_sayfa.dart';
import 'package:santiyepro/screens/yemek_sayfa.dart';
import 'package:santiyepro/services/ai_kayit_service.dart';

Proje _proje(String id, String ad, {bool kahvalti = false, bool aksam = false}) => Proje(
      id: id,
      ad: ad,
      aciklama: '',
      baslangicTarihi: DateTime(2026, 1, 1),
      toplamGun: 100,
      kahvaltiVar: kahvalti,
      aksamVar: aksam,
    );

void main() {
  group('Veri modeli', () {
    test('kahvaltı ve akşam yemeği kayıtta saklanır, toplamlar doğru hesaplanır', () {
      final k = GunlukKayit(
        tarih: DateTime(2026, 10, 9),
        yemekKalipci: 5,
        yemekDemirci: 2,
        kahvaltiKalipci: 4,
        kahvaltiDiger: 1,
        aksamDemirci: 3,
      );
      expect((k.ogleYemegi, k.kahvaltiYemegi, k.aksamYemegi, k.toplamYemek), (7, 5, 3, 15));

      final geri = GunlukKayit.fromJson(jsonDecode(jsonEncode(k.toJson())) as Map<String, dynamic>);
      expect((geri.kahvaltiKalipci, geri.kahvaltiDemirci, geri.kahvaltiDiger), (4, 0, 1));
      expect((geri.aksamKalipci, geri.aksamDemirci, geri.aksamDiger), (0, 3, 0));
      expect((geri.yemekKalipci, geri.yemekDemirci), (5, 2));
    });

    test('eski kayıtta (öğün alanı yok) kahvaltı ve akşam sıfır okunur', () {
      final k = GunlukKayit.fromJson({'tarih': '2026-10-01T00:00:00.000', 'yemekKalipci': 6, 'yemekDiger': 1});
      expect((k.kahvaltiYemegi, k.aksamYemegi, k.ogleYemegi, k.toplamYemek), (0, 0, 7, 7));
    });

    test('projede öğün seçenekleri saklanır; eski projede kapalıdır', () {
      final p = _proje('a', 'A', kahvalti: true, aksam: false);
      final geri = Proje.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect((geri.kahvaltiVar, geri.aksamVar), (true, false));

      final eski = Proje.fromJson({'id': 'x', 'ad': 'Eski', 'baslangicTarihi': '2026-01-01T00:00:00.000', 'toplamGun': 10});
      expect((eski.kahvaltiVar, eski.aksamVar), (false, false));
    });
  });

  group('Sesle kayıt: öğünler', () {
    final projeler = [_proje('g', 'Gera makina')];

    test('kahvaltı ve akşam alanları taslağa okunur', () {
      final (t, _) = AiKayitService.taslaklariCoz(
        jsonEncode({
          'kayitlar': [
            {
              'projeId': 'g', 'tarih': '2026-10-09', 'kalipci': 5, 'demirci': 2,
              'kahvalti': 7, 'aksamKalipci': 3, 'aksamDemirci': 1, 'yemek': 6,
            },
          ],
        }),
        projeler,
        DateTime(2026, 10, 9, 18),
      );
      final x = t.single;
      expect((x.kahvaltiToplam, x.aksamKalipci, x.aksamDemirci, x.yemekToplam), (7, 3, 1, 6));
    });

    test('toplam olarak söylenen öğünler çalışan sayısına göre paylaştırılır; ekip ekip söylenene dokunulmaz', () {
      final t = SesliKayitTaslagi(
        projeId: 'g',
        soylenenAd: '',
        tarih: DateTime(2026, 10, 9),
        kahvaltiToplam: 7,
        yemekToplam: 10,
        aksamKalipci: 4,
        aksamDemirci: 2,
        aksamToplam: 99, // ekip ekip söylendiği için yok sayılır
      )..yemegiDagit(kalipci: 5, demirci: 2, diger: 0);

      expect(t.kahvaltiKalipci + t.kahvaltiDemirci + t.kahvaltiDiger, 7);
      expect(t.yemekKalipci + t.yemekDemirci + t.yemekDiger, 10);
      expect((t.yemekKalipci, t.yemekDemirci), (7, 3));
      expect((t.aksamKalipci, t.aksamDemirci, t.aksamDiger), (4, 2, 0));
      expect(t.yemekDagitildi, isTrue);
    });

    test('mevcut kaydın kahvaltı ve akşam sayıları taslakta yoksa KORUNUR (veri kaybı olmaz)', () {
      final mevcut = GunlukKayit(
        tarih: DateTime(2026, 10, 9),
        kahvaltiKalipci: 4,
        kahvaltiDemirci: 2,
        aksamDiger: 1,
        yemekKalipci: 5,
      );
      final t = SesliKayitTaslagi(projeId: 'g', soylenenAd: '', tarih: DateTime(2026, 10, 9), kalipci: 6, aksamDiger: 3);
      final sonuc = t.kayda(mevcut);
      expect((sonuc.kahvaltiKalipci, sonuc.kahvaltiDemirci), (4, 2));
      expect(sonuc.aksamDiger, 3); // söylenen değer eskisinin yerine geçer
      expect(sonuc.yemekKalipci, 5);
      expect(sonuc.kalipci, 6);
    });

    test('yapay zekâya öğün alanları ve kuralı gönderilir', () {
      final y = AiKayitService.yonerge('x', projeler, DateTime(2026, 10, 9));
      expect(y, contains('"kahvalti":0'));
      expect(y, contains('"aksamKalipci":0'));
      expect(y, contains('Yemek bilgisini ASLA "notlar" alanına yazma'));
    });
  });

  group('Ekranlar', () {
    testWidgets('Yemek sayfası: öğün seçici yalnızca kahvaltı/akşam kullanılıyorsa görünür', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final bugun = DateTime.now();
      final gun = DateTime(bugun.year, bugun.month, 1);

      Future<void> ciz(List<Proje> projeler, Map<String, List<GunlukKayit>> kayitlar) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: YemekSayfaPage(projeler: projeler, projeGunlukKayitlari: kayitlar)),
        ));
        await tester.pumpAndSettle();
      }

      // Yalnızca öğle yemeği: sayfa eskisi gibi, seçici yok.
      await ciz([
        _proje('a', 'Eski Şantiye')
      ], {
        'a': [GunlukKayit(tarih: gun, yemekKalipci: 5, yemekDemirci: 3)],
      });
      expect(find.text('Kahvaltı'), findsNothing);
      expect(find.text('Eski Şantiye'), findsOneWidget);

      // Kahvaltısı açık proje: seçici ve öğün dökümü görünür.
      await ciz([
        _proje('b', 'Yeni Şantiye', kahvalti: true)
      ], {
        'b': [GunlukKayit(tarih: gun, yemekKalipci: 5, yemekDemirci: 3, kahvaltiKalipci: 4, kahvaltiDiger: 2)],
      });
      expect(find.text('Kahvaltı'), findsOneWidget); // seçici
      expect(find.text('Kah. 6 · Öğle 8'), findsOneWidget); // döküm
      // Tümü: 8 + 6 = 14.
      expect(find.text('14'), findsWidgets);

      await tester.tap(find.text('Kahvaltı'));
      await tester.pumpAndSettle();
      expect(find.text('6'), findsWidgets); // yalnızca kahvaltı toplamı
      expect(find.text('Kah. 6 · Öğle 8'), findsNothing);
    });

    testWidgets('Giriş formu: kahvaltı ve akşam alanları projede açıksa görünür ve kaydedilir', (tester) async {
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final kaydedilen = <GunlukKayit>[];
      Future<void> ciz(Proje p) async {
        await tester.pumpWidget(MaterialApp(
          home: ProjeDetaySayfa(
            proje: p,
            gunlukKayitlar: const [],
            onKayitEkle: kaydedilen.add,
            onKayitGuncelle: (_, k) => kaydedilen.add(k),
            projeGunlukKayitlari: const {},
            ekipler: const [],
            baslangicSekmesi: 1,
          ),
        ));
        await tester.pumpAndSettle();
      }

      await ciz(_proje('a', 'Kapalı'));
      expect(find.text('Yemek Sayıları'), findsOneWidget);
      expect(find.text('Kahvaltı'), findsNothing);
      expect(find.text('Akşam yemeği'), findsNothing);
      expect(find.text('Öğle yemeği'), findsNothing);

      await ciz(_proje('b', 'Açık', kahvalti: true, aksam: true));
      // Varsayılan: yalnızca öğle yemeği; sağdaki ok kahvaltı/akşamı açar.
      expect(find.text('Kahvaltı'), findsNothing);
      expect(find.text('Akşam yemeği'), findsNothing);
      await tester.ensureVisible(find.byIcon(Icons.keyboard_arrow_down));
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      expect(find.text('Kahvaltı'), findsOneWidget);
      expect(find.text('Öğle yemeği'), findsOneWidget);
      expect(find.text('Akşam yemeği'), findsOneWidget);

      // Her başlığın altındaki ilk (en soldaki) sayı kutusu "Kalıpçı Y."dır.
      Finder kalipciKutusu(String baslik) {
        final ust = tester.getTopLeft(find.text(baslik)).dy;
        final adaylar = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList()
            .asMap()
            .entries
            .where((e) {
              final yer = tester.getTopLeft(find.byWidget(e.value));
              return yer.dy > ust && yer.dy < ust + 120;
            })
            .map((e) => e.value)
            .toList();
        adaylar.sort((x, y) => tester.getTopLeft(find.byWidget(x)).dx.compareTo(tester.getTopLeft(find.byWidget(y)).dx));
        return find.byWidget(adaylar.first);
      }

      await tester.enterText(kalipciKutusu('Kahvaltı'), '4');
      await tester.enterText(kalipciKutusu('Öğle yemeği'), '6');
      await tester.enterText(kalipciKutusu('Akşam yemeği'), '3');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(kaydedilen.length, 1);
      final k = kaydedilen.single;
      expect((k.kahvaltiKalipci, k.yemekKalipci, k.aksamKalipci), (4, 6, 3));
      expect(k.toplamYemek, 13);
    });
  });
}
