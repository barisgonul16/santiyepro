import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:santiyepro/models/gunluk_kayit.dart';
import 'package:santiyepro/models/proje.dart';
import 'package:santiyepro/screens/proje_detay_sayfa.dart';
import 'package:santiyepro/services/hava_servisi.dart';

/// Ağa çıkmadan hava veren sahte servis; kaç kez sorulduğunu sayar.
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

final _proje = Proje(
  id: 'a',
  ad: 'Gera makina',
  aciklama: '',
  baslangicTarihi: DateTime(2026, 1, 1),
  toplamGun: 100,
);

Widget _sayfa({
  required HavaServisi hava,
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
        havaServisi: hava,
      ),
    );

void main() {
  group('Hava servisi', () {
    setUp(HavaServisi.konumOnbelleginiTemizle);

    MockClient sunucu(List<Uri> istekler, {int durum = 200, Object? gunluk}) => MockClient((istek) async {
          istekler.add(istek.url);
          if (istek.url.host.startsWith('geocoding')) {
            return http.Response(
                jsonEncode({
                  'results': [
                    {'latitude': 40.2, 'longitude': 29.1},
                  ]
                }),
                200);
          }
          return http.Response(
              jsonEncode({
                'daily': gunluk ??
                    {
                      'weather_code': [63],
                      'temperature_2m_max': [14.4],
                      'temperature_2m_min': [7.6],
                    }
              }),
              durum);
        });

    String iso(DateTime g) =>
        '${g.year}-${g.month.toString().padLeft(2, '0')}-${g.day.toString().padLeft(2, '0')}';

    test('yakın gün tahmin servisinden alınır; sıcaklıklar yuvarlanır, kod duruma çevrilir', () async {
      final istekler = <Uri>[];
      final servis = HavaServisi(istemci: sunucu(istekler), sehirOkuyucu: () async => 'Bursa');
      final dun = DateTime.now().subtract(const Duration(days: 1));

      final h = await servis.gunHavasi(dun);

      expect((h!.durum, h.enDusuk, h.enYuksek), ('yagmur', 8, 14));
      expect(istekler.last.host, 'api.open-meteo.com');
      expect(istekler.last.path, '/v1/forecast');
      expect(istekler.last.queryParameters['start_date'], iso(dun));
      expect(istekler.last.queryParameters['end_date'], iso(dun));
    });

    test('eski gün arşiv servisinden alınır', () async {
      final istekler = <Uri>[];
      final servis = HavaServisi(istemci: sunucu(istekler), sehirOkuyucu: () async => 'Bursa');

      final h = await servis.gunHavasi(DateTime.now().subtract(const Duration(days: 200)));

      expect(h, isNotNull);
      expect(istekler.last.host, 'archive-api.open-meteo.com');
      expect(istekler.last.path, '/v1/archive');
    });

    test('şehrin konumu bir kez sorulur', () async {
      final istekler = <Uri>[];
      final servis = HavaServisi(istemci: sunucu(istekler), sehirOkuyucu: () async => 'Bursa');
      await servis.gunHavasi(DateTime.now());
      await servis.gunHavasi(DateTime.now().subtract(const Duration(days: 3)));
      expect(istekler.where((u) => u.host.startsWith('geocoding')).length, 1);
    });

    test('14 günden ileri tarih için hiç istek yapılmaz', () async {
      final istekler = <Uri>[];
      final servis = HavaServisi(istemci: sunucu(istekler), sehirOkuyucu: () async => 'Bursa');
      expect(await servis.gunHavasi(DateTime.now().add(const Duration(days: 30))), isNull);
      expect(istekler, isEmpty);
    });

    test('sunucu hatası, bozuk yanıt ve internetsizlik null döner; istisna fırlatmaz', () async {
      final hatali = HavaServisi(istemci: sunucu([], durum: 500), sehirOkuyucu: () async => 'Bursa');
      expect(await hatali.gunHavasi(DateTime.now()), isNull);

      final bozuk = HavaServisi(istemci: sunucu([], gunluk: 'saçma'), sehirOkuyucu: () async => 'Bursa');
      expect(await bozuk.gunHavasi(DateTime.now()), isNull);

      final bos = HavaServisi(istemci: sunucu([], gunluk: {'weather_code': []}), sehirOkuyucu: () async => 'Bursa');
      expect(await bos.gunHavasi(DateTime.now()), isNull);

      final internetsiz = HavaServisi(
        istemci: MockClient((_) async => throw const FormatException('bağlantı yok')),
        sehirOkuyucu: () async => 'Bursa',
      );
      expect(await internetsiz.gunHavasi(DateTime.now()), isNull);
    });

    test('hava kodları altı duruma çevrilir', () {
      expect(HavaGosterim.koddanDurum(0), 'acik');
      expect(HavaGosterim.koddanDurum(1), 'acik');
      expect(HavaGosterim.koddanDurum(2), 'bulutlu');
      expect(HavaGosterim.koddanDurum(3), 'bulutlu');
      expect(HavaGosterim.koddanDurum(45), 'sis');
      expect(HavaGosterim.koddanDurum(53), 'yagmur');
      expect(HavaGosterim.koddanDurum(65), 'yagmur');
      expect(HavaGosterim.koddanDurum(81), 'yagmur');
      expect(HavaGosterim.koddanDurum(73), 'kar');
      expect(HavaGosterim.koddanDurum(86), 'kar');
      expect(HavaGosterim.koddanDurum(95), 'firtina');
      expect(HavaGosterim.koddanDurum(99), 'firtina');
    });
  });

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

    testWidgets('hava kendiliğinden gelir; elle değiştirilir, "çalışılamadı" işaretlenir ve kayda yazılır',
        (tester) async {
      genisPencere(tester);
      final kaydedilen = <GunlukKayit>[];
      final sahte = _SahteHava(const GunHavasi('yagmur', 8, 14));
      await tester.pumpWidget(_sayfa(hava: sahte, kaydedilen: kaydedilen));
      await tester.pumpAndSettle();

      expect(sahte.istekler.length, 1);
      expect(find.text('8°/14°'), findsOneWidget);
      expect(find.text('· durdu'), findsNothing);

      await tester.tap(find.byKey(const Key('hava_satiri')));
      await tester.pumpAndSettle();
      expect(find.text('Hava durumu · 8°/14°'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Açık'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20)); // pencereyi kapat
      await tester.pumpAndSettle();
      expect(find.text('· durdu'), findsOneWidget);

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      final k = kaydedilen.single;
      expect((k.hava, k.havaMin, k.havaMax, k.havaDurdu), ('acik', 8, 14, true));
    });

    testWidgets('kendiliğinden gelen hava "kaydedilmemiş değişiklik" sayılmaz', (tester) async {
      genisPencere(tester);
      final sahte = _SahteHava(const GunHavasi('bulutlu', 10, 18));
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ProjeDetaySayfa(
                  proje: _proje,
                  gunlukKayitlar: const [],
                  onKayitEkle: (_) {},
                  onKayitGuncelle: (_, _) {},
                  projeGunlukKayitlari: const {},
                  ekipler: const [],
                  baslangicSekmesi: 1,
                  havaServisi: sahte,
                ),
              ),
            ),
            child: const Text('ac'),
          ),
        ),
      ));
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();
      expect(find.text('10°/18°'), findsOneWidget); // hava geldi

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Kaydedilmemiş değişiklik var'), findsNothing);
      expect(find.text('ac'), findsOneWidget); // sayfa soru sormadan kapandı
    });

    testWidgets('havası kayıtlı günde yeniden sorulmaz, kayıttaki hava gösterilir', (tester) async {
      genisPencere(tester);
      final sahte = _SahteHava(const GunHavasi('kar', -2, 1));
      await tester.pumpWidget(_sayfa(
        hava: sahte,
        kayitlar: [GunlukKayit(tarih: DateTime.now(), hava: 'bulutlu', havaMin: 3, havaMax: 9)],
      ));
      await tester.pumpAndSettle();

      expect(sahte.istekler, isEmpty);
      expect(find.text('3°/9°'), findsOneWidget);
    });

    testWidgets('hava alınamazsa form olduğu gibi kalır; havayı elle seçmek için "Hava" yazısı görünür',
        (tester) async {
      genisPencere(tester);
      await tester.pumpWidget(_sayfa(hava: _SahteHava(null)));
      await tester.pumpAndSettle();

      expect(find.text('Hava'), findsOneWidget);
      expect(find.text('Kaydedilmemiş değişiklik var'), findsNothing);
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
        hava: _SahteHava(null),
        sekme: 0,
        kayitlar: [GunlukKayit(tarih: ay, kalipci: 3), GunlukKayit(tarih: ay.add(const Duration(days: 1)), kalipci: 4)],
      ));
      await tester.pumpAndSettle();
      expect(find.text('hava nedeniyle'), findsNothing);

      await tester.pumpWidget(_sayfa(
        hava: _SahteHava(null),
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
