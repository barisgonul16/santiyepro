import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:santiyepro/models/gunluk_kayit.dart';
import 'package:santiyepro/models/proje.dart';
import 'package:santiyepro/screens/sesli_kayit_sayfa.dart';
import 'package:santiyepro/services/ai_kayit_service.dart';

Proje _proje(String id, String ad) =>
    Proje(id: id, ad: ad, aciklama: '', baslangicTarihi: DateTime(2026, 1, 1), toplamGun: 100);

void main() {
  final projeler = [_proje('g', 'Gera makina'), _proje('k', 'KA Otomotiv')];
  final bugun = DateTime(2026, 10, 9, 15, 30);

  group('Yapay zekâ yanıtının çözülmesi', () {
    test('kayıtlar taslağa çevrilir; bilinmeyen şantiye boş kalır, gelecek tarih bugüne çekilir', () {
      final (taslaklar, anlasilmayan) = AiKayitService.taslaklariCoz(
        jsonEncode({
          'kayitlar': [
            {
              'projeId': 'g', 'soylenenAd': 'gera', 'tarih': '2026-10-08', 'kalipci': 5, 'demirci': '2',
              'kalipciIs': ' perde kalıbı ', 'beton': '40 m³',
              'vincler': [
                {'firma': 'Akın', 'baslangic': '8:00', 'bitis': '12.30', 'mola': 30, 'aciklama': ''},
                {'firma': '', 'baslangic': '', 'bitis': '', 'mola': 0, 'aciklama': ''},
              ],
              'yevmiyeler': [
                {'ekip': 'Ali', 'miktar': 0.5, 'aciklama': 'temizlik'},
                {'ekip': '', 'miktar': 0, 'aciklama': ''},
              ],
            },
            {'projeId': 'yok', 'soylenenAd': 'bilinmeyen', 'tarih': '2026-12-01', 'kalipci': 3},
            {'projeId': 'k', 'tarih': '2026-10-09'}, // boş kayıt: atılır
          ],
          'anlasilmayan': 'bir şey',
        }),
        projeler,
        bugun,
      );
      expect(taslaklar.length, 2);
      expect(anlasilmayan, 'bir şey');

      final a = taslaklar[0];
      expect(a.projeId, 'g');
      expect(a.tarih, DateTime(2026, 10, 8));
      expect((a.kalipci, a.demirci, a.diger), (5, 2, 0));
      expect(a.kalipciIs, 'perde kalıbı');
      expect(a.vincler.length, 1);
      expect((a.vincler.single.baslangic, a.vincler.single.bitis, a.vincler.single.mola), ('08:00', '12:30', 30));
      expect(a.yevmiyeler.length, 1);
      expect(a.yevmiyeler.single.miktar, 0.5);

      final b = taslaklar[1];
      expect(b.projeId, '');
      expect(b.soylenenAd, 'bilinmeyen');
      expect(b.tarih, DateTime(2026, 10, 9));
    });

    test('``` içine alınmış JSON da okunur; bozuk yanıt anlaşılır hata verir', () {
      final (t, _) = AiKayitService.taslaklariCoz(
          '```json\n{"kayitlar":[{"projeId":"k","tarih":"2026-10-09","diger":1}]}\n```', projeler, bugun);
      expect(t.single.diger, 1);
      expect(() => AiKayitService.taslaklariCoz('merhaba', projeler, bugun), throwsA(isA<AiKayitHatasi>()));
    });

    test('mevcut kayda işlenince sayılar güncellenir, yazılar eklenir, fotoğraf ve yemek korunur', () {
      final mevcut = GunlukKayit(
        tarih: DateTime(2026, 10, 9),
        kalipci: 4,
        demirci: 1,
        yemekKalipci: 4,
        kalipciYapilanIs: 'kolon kalıbı',
        fotografYollari: ['a.jpg'],
        vincler: [VincBilgisi(firmaAdi: 'Eski')],
      );
      final t = SesliKayitTaslagi(
        projeId: 'g',
        soylenenAd: '',
        tarih: DateTime(2026, 10, 9),
        kalipci: 6,
        kalipciIs: 'perde kalıbı',
        beton: '40 m³',
        vincler: [VincBilgisi(firmaAdi: 'Yeni')],
      );
      final sonuc = t.kayda(mevcut);
      expect((sonuc.kalipci, sonuc.demirci), (6, 1));
      expect(sonuc.kalipciYapilanIs, 'kolon kalıbı, perde kalıbı');
      expect(sonuc.beton, '40 m³');
      expect(sonuc.yemekKalipci, 4);
      expect(sonuc.fotografYollari, ['a.jpg']);
      expect(sonuc.vincler.map((v) => v.firmaAdi).toList(), ['Eski', 'Yeni']);
      // Aynı metin ikinci kez eklenmez.
      expect(t.kayda(sonuc).kalipciYapilanIs, 'kolon kalıbı, perde kalıbı');
    });
  });

  group('Sesle kayıt sayfası', () {
    http.Client sahteGemini(String yanitJson, {List<String>? gidenMetinler}) => MockClient((istek) async {
          expect(istek.headers['x-goog-api-key'], 'deneme-anahtari');
          if (istek.method == 'GET') {
            return http.Response(
                jsonEncode({
                  'models': [
                    {'name': 'models/gemini-embedding', 'supportedGenerationMethods': ['embedContent']},
                    {'name': 'models/gemini-9-flash', 'supportedGenerationMethods': ['generateContent']},
                  ]
                }),
                200);
          }
          expect(istek.url.path, endsWith('/models/gemini-9-flash:generateContent'));
          gidenMetinler?.add(jsonDecode(istek.body)['contents'][0]['parts'][0]['text'] as String);
          return http.Response.bytes(
              utf8.encode(jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': yanitJson}
                      ]
                    }
                  }
                ]
              })),
              200);
        });

    testWidgets('metin taslaklara çevrilir; onaydan sonra yeni kayıt eklenir, mevcut kayıt güncellenir',
        (tester) async {
      SharedPreferences.setMockInitialValues({'gemini_api_anahtari': 'deneme-anahtari'});
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final simdi = DateTime.now();
      final bugunGun = DateTime(simdi.year, simdi.month, simdi.day);
      String g(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
      final giden = <String>[];
      final eklenen = <(String, GunlukKayit)>[];
      final guncellenen = <(String, int, GunlukKayit)>[];
      final kayitlar = {
        'k': [GunlukKayit(tarih: bugunGun, kalipci: 2, kalipciYapilanIs: 'söküm')],
      };

      await tester.pumpWidget(MaterialApp(
        home: SesliKayitSayfa(
          projeler: projeler,
          projeGunlukKayitlari: kayitlar,
          onKayitEkle: (id, k) => eklenen.add((id, k)),
          onKayitGuncelle: (id, i, k) => guncellenen.add((id, i, k)),
          servis: AiKayitService(
            istemci: sahteGemini(
              jsonEncode({
                'kayitlar': [
                  {'projeId': 'g', 'soylenenAd': 'Gera', 'tarih': g(bugunGun), 'kalipci': 5, 'demirci': 2, 'kalipciIs': 'perde kalıbı'},
                  {'projeId': 'k', 'soylenenAd': 'KA', 'tarih': g(bugunGun), 'kalipci': 3, 'kalipciIs': 'döşeme sökümü'},
                  {'projeId': '', 'soylenenAd': 'Vatan', 'tarih': g(bugunGun), 'diger': 1},
                ],
                'anlasilmayan': '',
              }),
              gidenMetinler: giden,
            ),
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), 'Gerada 5 kalıpçı 2 demirci perde kalıbı, KA da 3 kalıpçı döşeme söküyor');
      await tester.pump();
      await tester.tap(find.text('Kayıtlara çevir'));
      await tester.pumpAndSettle();

      // Yapay zekâya yalnızca metin ve şantiye adları gider.
      expect(giden.single, contains('Gerada 5 kalıpçı'));
      expect(giden.single, contains('Gera makina'));

      expect(find.text('Kayıtları onayla'), findsOneWidget);
      expect(find.text('3 kaydı kaydet'), findsOneWidget);
      expect(find.textContaining('Bu güne kayıt var'), findsOneWidget); // KA Otomotiv
      expect(find.textContaining('"Vatan" bulunamadı'), findsOneWidget);

      // Şantiyesi belli olmayan kayıt varken kaydetmez.
      await tester.tap(find.text('3 kaydı kaydet'));
      await tester.pump();
      expect(find.textContaining('Şantiyesi seçilmemiş kayıt var'), findsOneWidget);
      expect(eklenen, isEmpty);
      expect(guncellenen, isEmpty);

      // O kaydı kaldırıp kaydet.
      await tester.tap(find.byTooltip('Bu kaydı kaldır').last);
      await tester.pump();
      await tester.tap(find.text('2 kaydı kaydet'));
      await tester.pumpAndSettle();

      expect(eklenen.length, 1);
      expect(eklenen.single.$1, 'g');
      expect((eklenen.single.$2.kalipci, eklenen.single.$2.demirci), (5, 2));
      expect(eklenen.single.$2.kalipciYapilanIs, 'perde kalıbı');
      expect(guncellenen.length, 1);
      expect((guncellenen.single.$1, guncellenen.single.$2), ('k', 0));
      expect(guncellenen.single.$3.kalipci, 3);
      expect(guncellenen.single.$3.kalipciYapilanIs, 'söküm, döşeme sökümü');
    });

    testWidgets('anahtar yokken anlaşılır uyarı verir, hiçbir şey kaydetmez', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var cagri = 0;
      await tester.pumpWidget(MaterialApp(
        home: SesliKayitSayfa(
          projeler: projeler,
          projeGunlukKayitlari: const {},
          onKayitEkle: (a, b) => cagri++,
          onKayitGuncelle: (a, b, c) => cagri++,
          servis: AiKayitService(istemci: MockClient((_) async => fail('istek gitmemeli'))),
        ),
      ));
      await tester.enterText(find.byType(TextField), 'gerada 3 kalıpçı');
      await tester.pump();
      await tester.tap(find.text('Kayıtlara çevir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('anahtarı girilmemiş'), findsOneWidget);
      expect(cagri, 0);
    });
  });
}
