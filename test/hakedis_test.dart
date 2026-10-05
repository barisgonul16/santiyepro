import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santiyepro/models/hakedis.dart';
import 'package:santiyepro/models/proje.dart';
import 'package:santiyepro/screens/hakedis_sekmesi.dart';

/// Hakediş sekmesinin uçtan uca davranışı: ekleme, düzenleme, silme ve
/// dosyaya yazılan veri. Depolama gerçek dosyalarla, geçici bir klasörde
/// çalışır; bulut kapalıdır (testte Firebase başlatılmaz).
void main() {
  group('Hakediş modeli', () {
    test('toJson -> fromJson kaydı bozmaz', () {
      final h = Hakedis(
        id: 'h1',
        projeId: 'p1',
        baslangic: DateTime(2026, 9, 1),
        bitis: DateTime(2026, 9, 30),
        kalemler: const [
          HakedisKalemi(ad: 'Kalıp', birim: 'm²', miktar: 1850.5, birimFiyat: 450, ekip: 'Kalıpçı'),
          HakedisKalemi(ad: 'Yevmiye', birim: 'yevmiye', miktar: 12, ekip: 'Ali Usta'),
        ],
        not: 'deneme',
      );
      final geri = Hakedis.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
      expect(geri.id, 'h1');
      expect(geri.projeId, 'p1');
      expect(geri.baslangic, DateTime(2026, 9, 1));
      expect(geri.bitis, DateTime(2026, 9, 30));
      expect(geri.kalemler.length, 2);
      expect(geri.kalemler[0].miktar, 1850.5);
      expect(geri.kalemler[0].tutar, 1850.5 * 450);
      expect(geri.kalemler[1].ekip, 'Ali Usta');
      expect(geri.toplamTutar, 1850.5 * 450);
      expect(geri.not, 'deneme');
    });

    test('Eksik alanlar varsayılana düşer, tarihi olmayan kayıt atlanır', () {
      final h = Hakedis.fromJson({
        'id': 'x',
        'projeId': 'p',
        'baslangic': '2026-09-01T00:00:00.000',
        'bitis': '2026-09-30T00:00:00.000',
        'kalemler': [
          {'ad': 'Demir', 'birim': 'ton', 'miktar': '42.5'},
          'bozuk satır',
        ],
      });
      expect(h.kalemler.length, 1);
      expect(h.kalemler.single.miktar, 42.5);
      expect(h.kalemler.single.birimFiyat, 0);
      expect(h.kalemler.single.ekip, '');
      expect(h.not, '');
      expect(() => Hakedis.fromJson({'id': 'y', 'projeId': 'p'}), throwsFormatException);
    });
  });

  group('Hakediş sekmesi', () {
    late Directory klasor;

    setUp(() {
      klasor = Directory.systemTemp.createTempSync('hakedis_test_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'), (cagri) async => klasor.path);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
      try {
        klasor.deleteSync(recursive: true);
      } catch (_) {}
    });

    /// Dosya işlemleri gerçek zamanda yürür; aranan öğe görünene kadar bekler.
    Future<void> bekle(WidgetTester tester, Finder aranan) async {
      for (int i = 0; i < 300; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
        if (aranan.evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();
      expect(aranan, findsWidgets);
    }

    List<dynamic> dosyadakiler() =>
        jsonDecode(File('${klasor.path}/hakedisler.json').readAsStringSync()) as List<dynamic>;

    testWidgets('ekle, düzenle, sil', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final proje = Proje(
        id: 'p1',
        ad: 'Deneme Şantiyesi',
        aciklama: '',
        baslangicTarihi: DateTime(2026, 1, 1),
        toplamGun: 100,
      );
      // Dönemde 20 kalıpçı, 10 demirci adam-günü olduğu varsayılır.
      HakedisDonemOzeti ozet(DateTime bas, DateTime bit) => const HakedisDonemOzeti(
            kayitGunu: 5,
            kalipci: 20,
            demirci: 10,
            diger: 0,
            vincSaat: 0,
            vincGun: 0,
            yevmiye: 0,
          );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HakedisSekmesi(proje: proje, ekipler: const ['Ali Usta'], donemOzeti: ozet),
        ),
      ));
      await bekle(tester, find.textContaining('Henüz hakediş yok'));

      // --- Ekle: binlik noktalı ve virgüllü yazımlar doğru okunmalı.
      await tester.tap(find.text('Yeni hakediş'));
      await tester.pumpAndSettle();
      // Hazır dört satırın ekibi sabittir: açılır kutu yalnızca eklenen satırda olur.
      expect(find.byType(DropdownButton<String>), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Metraj (m²)'), '1.000');
      await tester.enterText(find.widgetWithText(TextField, 'Metraj (ton)'), '2,5');
      await tester.tap(find.text('Yevmiye ekle'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButton<String>), findsNWidgets(2)); // ekip + birim
      await tester.enterText(find.widgetWithText(TextField, 'Metraj').last, '12');
      // Adı ve metrajı boş bırakılan satır kaydedilmemeli.
      await tester.tap(find.text('Satır ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await bekle(tester, find.text('Hakediş 1'));

      expect(find.text('1.000 m²'), findsOneWidget);
      expect(find.text('2,5 ton'), findsOneWidget);
      expect(find.text('12 yevmiye'), findsOneWidget);
      // Verim: 1000 m² / 20 kalıpçı; 2,5 ton / 10 demirci = 250 kg.
      expect(find.text('50 m² / adam-gün'), findsOneWidget);
      expect(find.text('250 kg / adam-gün'), findsOneWidget);

      var kayitlar = dosyadakiler();
      expect(kayitlar.length, 1);
      var kalemler = (kayitlar.single['kalemler'] as List).cast<Map<String, dynamic>>();
      expect(kalemler.map((k) => k['ad']).toList(), ['Kalıp', 'Demir', 'Beton', 'İskele', 'Yevmiye']);
      expect(kalemler[0]['miktar'], 1000.0);
      expect(kalemler[0]['ekip'], 'Kalıpçı');
      expect(kalemler[1]['miktar'], 2.5);
      expect(kalemler[3]['birim'], 'm³');
      expect(kalemler[4]['birim'], 'yevmiye');
      expect(kayitlar.single['projeId'], 'p1');

      // --- Düzenle: aynı kayıt güncellenmeli, yenisi oluşmamalı.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Düzenle'));
      await tester.pumpAndSettle();
      expect(find.text('Hakedişi düzenle'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Metraj (m²)'), '2000');
      await tester.tap(find.text('Kaydet'));
      await bekle(tester, find.text('2.000 m²'));
      expect(find.text('Hakediş 2'), findsNothing);
      kayitlar = dosyadakiler();
      expect(kayitlar.length, 1);
      kalemler = (kayitlar.single['kalemler'] as List).cast<Map<String, dynamic>>();
      expect(kalemler[0]['miktar'], 2000.0);

      // --- Yeni hakediş öncekinin ertesi gününden başlar, eklenen satır hazır gelir.
      final ilkBitis = DateTime.parse(kayitlar.single['bitis'] as String);
      final ertesi = DateTime(ilkBitis.year, ilkBitis.month, ilkBitis.day + 1);
      String iki(int n) => n.toString().padLeft(2, '0');
      await tester.tap(find.text('Yeni hakediş'));
      await tester.pumpAndSettle();
      expect(find.text('${iki(ertesi.day)}.${iki(ertesi.month)}.${ertesi.year}'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Yevmiye'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      // --- Sil.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil').last);
      await bekle(tester, find.textContaining('Henüz hakediş yok'));
      expect(dosyadakiler(), isEmpty);
    });

    testWidgets('başka projenin hakedişi görünmez ve kaydederken korunur', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      File('${klasor.path}/hakedisler.json').writeAsStringSync(jsonEncode([
        Hakedis(
          id: 'diger',
          projeId: 'p2',
          baslangic: DateTime(2026, 8, 1),
          bitis: DateTime(2026, 8, 31),
          kalemler: const [HakedisKalemi(ad: 'Kalıp', birim: 'm²', miktar: 777)],
        ).toJson(),
      ]));

      final proje = Proje(id: 'p1', ad: 'A', aciklama: '', baslangicTarihi: DateTime(2026, 1, 1), toplamGun: 10);
      HakedisDonemOzeti ozet(DateTime bas, DateTime bit) => const HakedisDonemOzeti(
          kayitGunu: 0, kalipci: 0, demirci: 0, diger: 0, vincSaat: 0, vincGun: 0, yevmiye: 0);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HakedisSekmesi(proje: proje, ekipler: const [], donemOzeti: ozet)),
      ));
      await bekle(tester, find.textContaining('Henüz hakediş yok'));
      expect(find.text('777 m²'), findsNothing);

      await tester.tap(find.text('Yeni hakediş'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Metraj (m²)'), '10');
      await tester.tap(find.text('Kaydet'));
      await bekle(tester, find.text('Hakediş 1'));

      final kayitlar = dosyadakiler();
      expect(kayitlar.length, 2);
      expect(kayitlar.map((k) => k['projeId']).toSet(), {'p1', 'p2'});
      // Adam-gün sıfırken verim satırı gösterilmez.
      expect(find.textContaining('adam-gün'), findsOneWidget); // yalnızca "Toplam 0 adam-gün"
    });
  });
}
