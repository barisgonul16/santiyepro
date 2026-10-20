import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:santiyepro/models/gunluk_kayit.dart';
import 'package:santiyepro/models/proje.dart';
import 'package:santiyepro/screens/sesli_kayit_sayfa.dart';
import 'package:santiyepro/services/ai_kayit_service.dart';
import 'package:santiyepro/services/hava_servisi.dart';

/// Ağa çıkmadan hava veren sahte servis.
class _SahteHava implements HavaServisi {
  final GunHavasi? sonuc;
  final List<DateTime> istekler = [];
  _SahteHava(this.sonuc);

  @override
  Future<GunHavasi?> gunHavasi(DateTime gun) async {
    istekler.add(gun);
    return sonuc;
  }
}

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

  group('Yemek', () {
    test('yapay zekâya yemek kuralı ve alanları gönderilir', () {
      final yonerge = AiKayitService.yonerge('x', projeler, bugun);
      expect(yonerge, contains('"yemek":0'));
      expect(yonerge, contains('"yemekKalipci":0'));
      expect(yonerge, contains('Yemek bilgisini ASLA "notlar" alanına yazma'));
    });

    test('yemek alanları taslağa okunur; yalnızca yemek söylenen kayıt boş sayılmaz', () {
      final (t, _) = AiKayitService.taslaklariCoz(
        jsonEncode({
          'kayitlar': [
            {'projeId': 'g', 'tarih': '2026-10-09', 'yemek': 12},
            {'projeId': 'k', 'tarih': '2026-10-09', 'yemekKalipci': 5, 'yemekDemirci': '3'},
          ],
        }),
        projeler,
        bugun,
      );
      expect(t.length, 2);
      expect((t[0].yemekToplam, t[0].yemekKalipci), (12, 0));
      expect((t[1].yemekKalipci, t[1].yemekDemirci, t[1].yemekToplam), (5, 3, 0));
    });

    SesliKayitTaslagi taslak({int toplam = 0, int k = 0, int d = 0, int g = 0}) => SesliKayitTaslagi(
          projeId: 'g',
          soylenenAd: '',
          tarih: DateTime(2026, 10, 9),
          yemekToplam: toplam,
          yemekKalipci: k,
          yemekDemirci: d,
          yemekDiger: g,
        );

    test('tek sayı söylenen yemek seçim bekler; ekip seçilince tamamı o ekibe yazılır', () {
      final t = taslak(toplam: 20);
      expect(t.ekipBekleyenOgunler, [YemekOgunu.ogle]);
      expect((t.yemekKalipci, t.yemekDemirci, t.yemekDiger), (0, 0, 0));
      t.ogunuEkibeYaz(YemekOgunu.ogle, YemekEkibi.demirci);
      expect((t.yemekKalipci, t.yemekDemirci, t.yemekDiger), (0, 20, 0));
      expect(t.ekipBekleyenOgunler, isEmpty);
    });

    test('çalışan sayısına göre dağıtılınca toplam korunur', () {
      for (final (toplam, kal, dem, dig) in [(10, 5, 2, 0), (11, 5, 4, 2), (7, 1, 1, 1), (3, 8, 0, 0), (1, 5, 5, 5)]) {
        final t = taslak(toplam: toplam)..ogunuDagit(YemekOgunu.ogle, kalipci: kal, demirci: dem, diger: dig);
        expect(t.yemekKalipci + t.yemekDemirci + t.yemekDiger, toplam, reason: '$toplam yemek, $kal/$dem/$dig kişi');
        expect(t.dagitilanOgunler, [YemekOgunu.ogle]);
      }
      final t = taslak(toplam: 10)..ogunuDagit(YemekOgunu.ogle, kalipci: 5, demirci: 2, diger: 0);
      expect((t.yemekKalipci, t.yemekDemirci, t.yemekDiger), (7, 3, 0));
      // Çalışan sayısı yoksa tamamı kalıpçıya yazılır.
      final bos = taslak(toplam: 6)..ogunuDagit(YemekOgunu.ogle, kalipci: 0, demirci: 0, diger: 0);
      expect((bos.yemekKalipci, bos.yemekDemirci, bos.yemekDiger), (6, 0, 0));
      // Şantiye değişince yeniden dağıtılabilir.
      final once = t.yemekSurumu;
      t.dagitilanlariYenile(kalipci: 1, demirci: 1, diger: 0);
      expect((t.yemekKalipci, t.yemekDemirci), (5, 5));
      expect(t.yemekSurumu, greaterThan(once));
    });

    test('ekip ekip söylenen yemek seçim beklemez; mevcut kaydın yemeği boşsa korunur', () {
      final t = taslak(toplam: 12, k: 5, d: 3);
      expect(t.ekipBekleyenOgunler, isEmpty);
      expect((t.yemekKalipci, t.yemekDemirci, t.yemekDiger), (5, 3, 0));
      expect(t.dagitilanOgunler, isEmpty);

      final mevcut = GunlukKayit(tarih: DateTime(2026, 10, 9), yemekKalipci: 4, yemekDemirci: 2, yemekDiger: 1);
      final sonuc = taslak(k: 6).kayda(mevcut);
      expect((sonuc.yemekKalipci, sonuc.yemekDemirci, sonuc.yemekDiger), (6, 2, 1));
    });

    /// "gerada 5 kalıpçı 2 demirci yemek 10" konuşmasını çözümleyip onay ekranına
    /// gelir; yapay zekâ yemeği ekip ayırmadan tek sayı olarak verir.
    Future<List<(String, GunlukKayit)>> onayEkraninaGel(WidgetTester tester, {HavaServisi? hava}) async {
      SharedPreferences.setMockInitialValues({'gemini_api_anahtari': 'deneme-anahtari'});
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final simdi = DateTime.now();
      final gun = '${simdi.year}-${simdi.month.toString().padLeft(2, '0')}-${simdi.day.toString().padLeft(2, '0')}';
      final eklenen = <(String, GunlukKayit)>[];
      final istemci = MockClient((istek) async {
        if (istek.method == 'GET') {
          return http.Response(
              jsonEncode({
                'models': [
                  {'name': 'models/gemini-9-flash', 'supportedGenerationMethods': ['generateContent']},
                ]
              }),
              200);
        }
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'kayitlar': [
                            {'projeId': 'g', 'soylenenAd': 'Gera', 'tarih': gun, 'kalipci': 5, 'demirci': 2, 'yemek': 10},
                          ],
                        })
                      }
                    ]
                  }
                }
              ]
            })),
            200);
      });

      await tester.pumpWidget(MaterialApp(
        home: SesliKayitSayfa(
          projeler: projeler,
          projeGunlukKayitlari: const {},
          onKayitEkle: (id, k) => eklenen.add((id, k)),
          onKayitGuncelle: (a, b, c) {},
          servis: AiKayitService(istemci: istemci),
          havaServisi: hava,
        ),
      ));
      await tester.enterText(find.byType(TextField), 'gerada 5 kalıpçı 2 demirci yemek 10');
      await tester.pump();
      await tester.tap(find.text('Kayıtlara çevir'));
      await tester.pumpAndSettle();
      return eklenen;
    }

    testWidgets('"yemek 10": notlara yazılmaz, hangi ekip olduğu sorulur, seçilmeden kaydedilmez', (tester) async {
      final eklenen = await onayEkraninaGel(tester);

      expect(find.textContaining('hangi ekip'), findsOneWidget);
      // Seçilmeden kayıt yapılmaz.
      await tester.tap(find.text('1 kaydı kaydet'));
      await tester.pumpAndSettle();
      expect(eklenen, isEmpty);
      expect(find.textContaining('hangi ekibe ait'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Demirci'));
      await tester.pumpAndSettle();
      expect(find.textContaining('hangi ekip'), findsNothing);
      await tester.tap(find.text('1 kaydı kaydet'));
      await tester.pumpAndSettle();

      final k = eklenen.single.$2;
      expect((k.yemekKalipci, k.yemekDemirci, k.yemekDiger), (0, 10, 0));
      expect(k.notlar, '');
    });

    testWidgets('yemek sayısı istenirse çalışan sayısına göre dağıtılır', (tester) async {
      final eklenen = await onayEkraninaGel(tester);

      await tester.tap(find.widgetWithText(ActionChip, 'Çalışan sayısına göre dağıt'));
      await tester.pumpAndSettle();
      expect(find.textContaining('çalışan sayısına göre ekiplere dağıtıldı'), findsOneWidget);
      await tester.tap(find.text('1 kaydı kaydet'));
      await tester.pumpAndSettle();

      final k = eklenen.single.$2;
      expect((k.yemekKalipci, k.yemekDemirci, k.yemekDiger), (7, 3, 0));
    });

    testWidgets('sesle kaydedilen kayda o günün havası eklenir; hava alınamazsa kayıt yine kaydedilir',
        (tester) async {
      final sahte = _SahteHava(const GunHavasi('kar', -3, 2));
      final eklenen = await onayEkraninaGel(tester, hava: sahte);
      await tester.tap(find.widgetWithText(ActionChip, 'Kalıpçı'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 kaydı kaydet'));
      await tester.pumpAndSettle();

      expect(sahte.istekler.length, 1);
      final k = eklenen.single.$2;
      expect((k.hava, k.havaMin, k.havaMax, k.havaDurdu), ('kar', -3, 2, false));
    });

    testWidgets('hava alınamazsa sesle kayıt havasız kaydedilir', (tester) async {
      final eklenen = await onayEkraninaGel(tester, hava: _SahteHava(null));
      await tester.tap(find.widgetWithText(ActionChip, 'Kalıpçı'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 kaydı kaydet'));
      await tester.pumpAndSettle();

      final k = eklenen.single.$2;
      expect((k.hava, k.havaMin, k.havaMax), ('', null, null));
      expect(k.kalipci, 5);
    });
  });

  group('Yapay zekâ bağlantısı: yedek model ve anahtar temizliği', () {
    const geciciJson = '{"kayitlar":[{"projeId":"g","tarih":"2026-10-09","kalipci":2}]}';

    http.Response gemini(String metin) => http.Response.bytes(
        utf8.encode(jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': metin}
                ]
              }
            }
          ]
        })),
        200);

    http.Response liste(List<String> adlar) => http.Response(
        jsonEncode({
          'models': [
            for (final a in adlar) {'name': 'models/$a', 'supportedGenerationMethods': ['generateContent']},
          ]
        }),
        200);

    http.Response hata(int kod, String durum, String ileti) => http.Response(
        jsonEncode({
          'error': {'code': kod, 'status': durum, 'message': ileti}
        }),
        kod);

    String modelAdi(http.BaseRequest r) => r.url.path.split('/').last.split(':').first;

    test('anahtardaki boşluk, satır sonu, görünmez ve Türkçe karakter, tırnak temizlenir', () {
      expect(AiKayitService.anahtariTemizle('AIza​ABC-def_12\n'), 'AIzaABC-def_12');
      expect(AiKayitService.anahtariTemizle('  "abc.DEF_9"  '), 'abc.DEF_9');
      expect(AiKayitService.anahtariTemizle('çAB 12ğ'), 'AB12');
    });

    test('kayıtlı anahtar temizlenmiş okunur', () async {
      SharedPreferences.setMockInitialValues({'gemini_api_anahtari': 'abc​123\n'});
      expect(await AiKayitService.anahtar(), 'abc123');
    });

    test('hızlı (lite) model önce denenir; yoğunsa sıradaki modele geçilir ve çalışan hatırlanır', () async {
      SharedPreferences.setMockInitialValues({'gemini_api_anahtari': 'k'});
      final denenen = <String>[];
      final servis = AiKayitService(
        istemci: MockClient((r) async {
          if (r.method == 'GET') {
            return liste(['gemini-flash-latest', 'gemini-3.5-flash-lite', 'gemini-flash-lite-latest', 'gemini-2.5-flash-image']);
          }
          denenen.add(modelAdi(r));
          return denenen.length == 1 ? hata(503, 'UNAVAILABLE', 'high demand') : gemini(geciciJson);
        }),
      );
      final (t, _) = await servis.cozumle('gerada 2 kalıpçı', projeler, bugun);
      expect(t.single.kalipci, 2);
      expect(denenen, ['gemini-flash-lite-latest', 'gemini-3.5-flash-lite']);
      expect((await SharedPreferences.getInstance()).getString('gemini_model'), 'gemini-3.5-flash-lite');
    });

    test('önceki başarılı model bir sonraki istekte ilk denenir', () async {
      SharedPreferences.setMockInitialValues({'gemini_api_anahtari': 'k', 'gemini_model': 'gemini-3.5-flash-lite'});
      final denenen = <String>[];
      final servis = AiKayitService(
        istemci: MockClient((r) async {
          if (r.method == 'GET') return liste(['gemini-flash-lite-latest', 'gemini-3.5-flash-lite']);
          denenen.add(modelAdi(r));
          return gemini(geciciJson);
        }),
      );
      await servis.cozumle('x', projeler, bugun);
      expect(denenen, ['gemini-3.5-flash-lite']);
    });

    test('yavaş büyük model hatırlanmaz: kayıtlıysa bile önce hızlı model denenir', () async {
      // Eski sürüm, yedek olarak bir kez çalışan büyük modeli kaydediyordu; her
      // istek 25-45 sn sürüyordu.
      SharedPreferences.setMockInitialValues({'gemini_api_anahtari': 'k', 'gemini_model': 'gemini-flash-latest'});
      final denenen = <String>[];
      var liteYogun = true;
      final servis = AiKayitService(
        istemci: MockClient((r) async {
          if (r.method == 'GET') return liste(['gemini-flash-lite-latest', 'gemini-flash-latest']);
          denenen.add(modelAdi(r));
          if (modelAdi(r).contains('lite') && liteYogun) return hata(503, 'UNAVAILABLE', 'high demand');
          return gemini(geciciJson);
        }),
      );
      await servis.cozumle('x', projeler, bugun);
      expect(denenen, ['gemini-flash-lite-latest', 'gemini-flash-latest']);
      // Büyük model çalıştı ama hatırlanmadı.
      expect((await SharedPreferences.getInstance()).getString('gemini_model'), isNull);

      liteYogun = false;
      denenen.clear();
      await servis.cozumle('x', projeler, bugun);
      expect(denenen, ['gemini-flash-lite-latest']);
    });

    test('hepsi yoğunsa "çok yoğun" der, ağ hatası gibi göstermez', () async {
      SharedPreferences.setMockInitialValues({'gemini_api_anahtari': 'k'});
      var istek = 0;
      final servis = AiKayitService(
        istemci: MockClient((r) async {
          if (r.method == 'GET') return liste(['gemini-flash-lite-latest', 'gemini-flash-latest']);
          istek++;
          return hata(503, 'UNAVAILABLE', 'high demand');
        }),
      );
      await expectLater(
        servis.cozumle('x', projeler, bugun),
        throwsA(isA<AiKayitHatasi>().having((e) => e.mesaj, 'mesaj', contains('çok yoğun'))),
      );
      expect(istek, 2);
    });

    test('yavaş model zaman aşımına düşünce sıradaki denenir', () async {
      SharedPreferences.setMockInitialValues({'gemini_api_anahtari': 'k'});
      final denenen = <String>[];
      final servis = AiKayitService(
        istekZamanAsimi: const Duration(milliseconds: 80),
        istemci: MockClient((r) async {
          if (r.method == 'GET') return liste(['gemini-flash-lite-latest', 'gemini-3.5-flash-lite']);
          denenen.add(modelAdi(r));
          if (denenen.length == 1) await Future<void>.delayed(const Duration(milliseconds: 400));
          return gemini(geciciJson);
        }),
      );
      final (t, _) = await servis.cozumle('x', projeler, bugun);
      expect(t.length, 1);
      expect(denenen.length, 2);
    });

    test('anahtar reddedilirse başka model denenmez', () async {
      SharedPreferences.setMockInitialValues({'gemini_api_anahtari': 'k'});
      var istek = 0;
      final servis = AiKayitService(
        istemci: MockClient((r) async {
          if (r.method == 'GET') return liste(['gemini-flash-lite-latest', 'gemini-3.5-flash-lite']);
          istek++;
          return hata(403, 'PERMISSION_DENIED', 'forbidden');
        }),
      );
      await expectLater(
        servis.cozumle('x', projeler, bugun),
        throwsA(isA<AiKayitHatasi>().having((e) => e.mesaj, 'mesaj', contains('anahtarı kabul edilmedi'))),
      );
      expect(istek, 1);
    });

    test('bağlantı yoksa ve başlıkta geçersiz karakter varsa anlaşılır ileti verir', () async {
      SharedPreferences.setMockInitialValues({'gemini_api_anahtari': 'k'});
      await expectLater(
        AiKayitService(istemci: MockClient((r) async => throw const SocketException('yok'))).cozumle('x', projeler, bugun),
        throwsA(isA<AiKayitHatasi>().having((e) => e.mesaj, 'mesaj', contains('bağlanılamadı'))),
      );
      await expectLater(
        AiKayitService(istemci: MockClient((r) async => throw const FormatException('Invalid HTTP header')))
            .cozumle('x', projeler, bugun),
        throwsA(isA<AiKayitHatasi>().having((e) => e.mesaj, 'mesaj', contains('geçersiz karakter'))),
      );
    });

    test('anahtar denemesi çalışan modelin adını döndürür', () async {
      SharedPreferences.setMockInitialValues({'gemini_api_anahtari': 'k'});
      final servis = AiKayitService(
        istemci: MockClient((r) async =>
            r.method == 'GET' ? liste(['gemini-flash-lite-latest']) : gemini('{"tamam":true}')),
      );
      expect(await servis.anahtariDene(), 'gemini-flash-lite-latest');
    });
  });
}
