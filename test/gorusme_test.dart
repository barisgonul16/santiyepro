import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:santiyepro/models/gunluk_kayit.dart';
import 'package:santiyepro/models/proje.dart';
import 'package:santiyepro/screens/sesli_gorusme_sayfa.dart';
import 'package:santiyepro/services/ai_kayit_service.dart';
import 'package:santiyepro/services/gorusme_motoru.dart';
import 'package:santiyepro/services/hava_servisi.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sırayla verilen cevapları "duyan", söylenenleri kaydeden sahte ses.
class _SahteSes extends SesArayuzu {
  final List<String?> cevaplar;
  final List<String> soylenenler = [];
  _SahteSes(List<String?> cevaplar) : cevaplar = List.of(cevaplar);

  @override
  Future<void> konus(String metin) async => soylenenler.add(metin);

  @override
  Future<String?> dinle() async => cevaplar.isEmpty ? null : cevaplar.removeAt(0);

  @override
  Future<void> durdur() async {}
}

class _HavasizServis implements HavaServisi {
  @override
  Future<GunHavasi?> gunHavasi(DateTime gun) async => null;
}

Proje _proje(String id, String ad, {bool kahvalti = false}) => Proje(
      id: id,
      ad: ad,
      aciklama: '',
      baslangicTarihi: DateTime(2026, 1, 1),
      toplamGun: 100,
      kahvaltiVar: kahvalti,
    );

final _gera = _proje('g', 'Gera makina');
final _ka = _proje('k', 'KA Otomotiv');
final _bugun = DateTime(2026, 10, 19, 17);

SesliKayitTaslagi _taslak({
  String projeId = 'g',
  String soylenenAd = 'gera',
  int kalipci = 4,
  int demirci = 5,
  int yemekToplam = 0,
  int yemekKalipci = 10,
  int yemekDemirci = 10,
  int yemekDiger = 1,
}) =>
    SesliKayitTaslagi(
      projeId: projeId,
      soylenenAd: soylenenAd,
      tarih: DateTime(2026, 10, 19),
      kalipci: kalipci,
      demirci: demirci,
      kalipciIs: 'döşeme kalıbı çakıldı',
      demirciIs: 'temel bağlandı',
      yemekToplam: yemekToplam,
      yemekKalipci: yemekKalipci,
      yemekDemirci: yemekDemirci,
      yemekDiger: yemekDiger,
    );

/// Görüşmeyi sahte ses ve sahte yapay zekâyla kurar.
({GorusmeMotoru motor, _SahteSes ses, List<String> dokumler, List<List<SesliKayitTaslagi>> kaydedilen}) _kur(
  List<String?> cevaplar, {
  List<Proje>? projeler,
  List<List<SesliKayitTaslagi>>? yapayZekaCevaplari,
  Object? hata,
}) {
  final ses = _SahteSes(cevaplar);
  final dokumler = <String>[];
  final kaydedilen = <List<SesliKayitTaslagi>>[];
  final cevapSirasi = List.of(yapayZekaCevaplari ?? [[_taslak()]]);
  final motor = GorusmeMotoru(
    ses: ses,
    projeler: projeler ?? [_gera, _ka],
    projeGunlukKayitlari: const {},
    simdi: () => _bugun,
    cozumle: (dokum) async {
      dokumler.add(dokum);
      if (hata != null) throw hata;
      return (cevapSirasi.removeAt(0), '');
    },
    kaydet: (t) async {
      kaydedilen.add(t);
      return '1 yeni kayıt';
    },
  );
  return (motor: motor, ses: ses, dokumler: dokumler, kaydedilen: kaydedilen);
}

void main() {
  group('Görüşme dili', () {
    test('olumsuz cevaplar', () {
      for (final m in ['yok', 'Hayır.', 'yok yok', 'hayır, başka kimse yoktu', 'hiç yok abi', 'Beton yok']) {
        expect(GorusmeDili.olumsuz(m), isTrue, reason: m);
      }
      for (final m in ['2 kişi vardı', 'beton yok ama vinç vardı', 'demirci 3 yok', 'var', '']) {
        expect(GorusmeDili.olumsuz(m), isFalse, reason: m);
      }
    });

    test('ayrıntısız olumlu cevaplar', () {
      expect(GorusmeDili.sadeceOlumlu('var'), isTrue);
      expect(GorusmeDili.sadeceOlumlu('evet var'), isTrue);
      expect(GorusmeDili.sadeceOlumlu('2 kişi var'), isFalse);
      expect(GorusmeDili.sadeceOlumlu('var, malzeme taşıdılar'), isFalse);
    });

    test('onay', () {
      expect(GorusmeDili.onay('Evet'), isTrue);
      expect(GorusmeDili.onay('tamam kaydet'), isTrue);
      expect(GorusmeDili.onay('hayır'), isFalse);
      expect(GorusmeDili.onay('yanlış, düzelt'), isFalse);
      expect(GorusmeDili.onay('evet ama demirci altı olacak sonra bakarız'), isNull);
      expect(GorusmeDili.onay(''), isNull);
    });

    test('komutlar yalnızca kısa cevaplarda', () {
      expect(GorusmeDili.komut('Tekrarla'), GorusmeKomutu.tekrarla);
      expect(GorusmeDili.komut('bir daha'), GorusmeKomutu.tekrarla);
      expect(GorusmeDili.komut('geri dön'), GorusmeKomutu.geri);
      expect(GorusmeDili.komut('iptal et'), GorusmeKomutu.iptal);
      expect(GorusmeDili.komut('vazgeç'), GorusmeKomutu.iptal);
      expect(GorusmeDili.komut('kalıpçılar geri kalan kalıbı söktü'), isNull);
      expect(GorusmeDili.komut('4 kalıpçı'), isNull);
    });

    test('yemek ekibi seçimi', () {
      expect(GorusmeDili.yemekSecimi('kalıpçı'), YemekSecimi.kalipci);
      expect(GorusmeDili.yemekSecimi('Demircilerin'), YemekSecimi.demirci);
      expect(GorusmeDili.yemekSecimi('diğer'), YemekSecimi.diger);
      expect(GorusmeDili.yemekSecimi('dağıt'), YemekSecimi.dagit);
      expect(GorusmeDili.yemekSecimi('kalıpçı ve demirci'), isNull);
      expect(GorusmeDili.yemekSecimi('bilmiyorum'), isNull);
    });

    test('şantiye adı bulunur; belirsizse bulunmaz', () {
      final projeler = [_gera, _ka, _proje('d', 'Gera depo')];
      expect(GorusmeDili.santiyeBul('KA otomotivde', projeler)?.id, 'k');
      expect(GorusmeDili.santiyeBul('gera makinada', projeler)?.id, 'g');
      expect(GorusmeDili.santiyeBul('gerada', projeler), isNull); // iki Gera var
      expect(GorusmeDili.santiyeBul('gerada', [_gera, _ka])?.id, 'g');
      expect(GorusmeDili.santiyeBul('başka yer', projeler), isNull);
    });
  });

  group('Görüşme', () {
    test('örnek görüşme: sorular sırayla sorulur, "yok" cevapları işlenir, "evet" denince kaydedilir', () async {
      final k = _kur([
        'bugün gerada 4 kalıpçı 5 demirci vardı',
        'kalıpçı döşeme kalıbını çaktı demirci temel bağladı',
        'yok',
        '10 kalıpçı 10 demirci 1 diğer öğle yemeği',
        'evet',
        'hayır',
      ]);

      final sonuc = await k.motor.calistir();

      expect(sonuc, GorusmeSonucu.tamamlandi);
      final soylenen = k.ses.soylenenler.join('\n');
      expect(k.ses.soylenenler.first, 'Hangi şantiye? Kaç kalıpçı, kaç demirci?'); // açılış konuşması yok
      expect(soylenen, contains('Tamam. Ne iş yaptılar?'));
      expect(soylenen, contains('Tamam. Başka çalışan, beton, vinç, yevmiye ya da not var mı?'));
      expect(soylenen, contains('Tamam. Yemek kaç kişi, ekip ekip?'));
      expect(soylenen, contains('Gera makina: 4 kalıpçı, 5 demirci.'));
      expect(soylenen, contains('Yemek 21 kişi (kalıpçı 10, demirci 10, diğer 1).'));
      expect(soylenen, contains('Kaydedeyim mi?'));
      expect(soylenen, contains('Kaydettim. Başka şantiye var mı?'));

      final dokum = k.dokumler.single;
      expect(dokum, contains('Şantiye ve çalışan sayıları: bugün gerada 4 kalıpçı 5 demirci vardı'));
      expect(dokum, contains('Yapılan işler: kalıpçı döşeme kalıbını çaktı demirci temel bağladı'));
      expect(dokum, contains('Diğer çalışanlar, beton, vinç, yevmiye ve notlar: yok'));
      expect(dokum, contains('Yemek sayıları: 10 kalıpçı 10 demirci 1 diğer öğle yemeği'));
      expect(k.kaydedilen.single.single.projeId, 'g');
      expect(k.motor.kaydedilenler, ['1 yeni kayıt']);
    });

    test('"var" denince ayrıntısı sorulur', () async {
      final k = _kur(['gerada 4 kalıpçı', 'kalıp çaktılar', 'var', '2 düz işçi malzeme taşıdı', 'yok', 'evet', 'yok']);
      await k.motor.calistir();
      expect(k.ses.soylenenler, contains('Anlat.'));
      expect(k.dokumler.single, contains('Diğer çalışanlar, beton, vinç, yevmiye ve notlar: 2 düz işçi malzeme taşıdı'));
    });

    test('"tekrarla" soruyu yeniden okur, "geri" önceki soruya döner', () async {
      final k = _kur(['gerada 4 kalıpçı', 'tekrarla', 'kalıp çaktılar', 'geri', 'kalıp ve demir', 'yok', 'yok', 'evet', 'yok']);
      await k.motor.calistir();
      final isSorusu = k.ses.soylenenler.where((s) => s.endsWith('Ne iş yaptılar?')).length;
      expect(isSorusu, 3); // ilk soru, "tekrarla", "geri" sonrası
      expect(k.dokumler.single, contains('Yapılan işler: kalıp ve demir'));
    });

    test('"iptal" görüşmeyi bitirir, hiçbir şey kaydedilmez', () async {
      final k = _kur(['gerada 4 kalıpçı', 'iptal']);
      expect(await k.motor.calistir(), GorusmeSonucu.iptal);
      expect(k.dokumler, isEmpty);
      expect(k.kaydedilen, isEmpty);
      expect(k.ses.soylenenler.last, 'İptal ettim.');
    });

    test('üç kez cevap duyulmazsa durur; yeniden başlatınca kalınan sorudan devam eder', () async {
      final k = _kur(['gerada 4 kalıpçı', null, null, null]);
      expect(await k.motor.calistir(), GorusmeSonucu.durduruldu);
      expect(k.ses.soylenenler.where((s) => s.startsWith('Duyamadım.')).length, 2);

      k.ses.cevaplar.addAll(['kalıp çaktılar', 'yok', 'yok', 'evet', 'yok']);
      final soylenenOnce = k.ses.soylenenler.length;
      expect(await k.motor.calistir(), GorusmeSonucu.tamamlandi);
      expect(k.ses.soylenenler[soylenenOnce], 'Ne iş yaptılar?');
      expect(k.dokumler.single, contains('Şantiye ve çalışan sayıları: gerada 4 kalıpçı'));
    });

    test('şantiye bulunamadıysa sorulur', () async {
      final k = _kur(
        ['gerrada 4 kalıpçı', 'iş yok', 'yok', 'yok', 'gera makina', 'evet', 'yok'],
        yapayZekaCevaplari: [
          [_taslak(projeId: '', soylenenAd: 'gerra')]
        ],
      );
      await k.motor.calistir();
      expect(k.ses.soylenenler.join('\n'), contains('"gerra" şantiyesini bulamadım. Hangi şantiye? Gera makina, KA Otomotiv.'));
      expect(k.kaydedilen.single.single.projeId, 'g');
    });

    test('ekip söylenmeyen yemek sorulur: ekip seçilir ya da dağıtılır', () async {
      final k = _kur(
        ['gerada 4 kalıpçı 5 demirci', 'iş', 'yok', 'yemek 20', 'kalıpçı', 'evet', 'yok'],
        yapayZekaCevaplari: [
          [_taslak(yemekToplam: 20, yemekKalipci: 0, yemekDemirci: 0, yemekDiger: 0)]
        ],
      );
      await k.motor.calistir();
      expect(k.ses.soylenenler.join('\n'), contains('Öğle yemeği 20 kişi dedin. Kalıpçı mı, demirci mi, diğer mi?'));
      final t = k.kaydedilen.single.single;
      expect((t.yemekKalipci, t.yemekDemirci, t.yemekDiger), (20, 0, 0));

      final d = _kur(
        ['gerada 4 kalıpçı 5 demirci', 'iş', 'yok', 'yemek 20', 'dağıt', 'evet', 'yok'],
        yapayZekaCevaplari: [
          [_taslak(yemekToplam: 20, yemekKalipci: 0, yemekDemirci: 0, yemekDiger: 0)]
        ],
      );
      await d.motor.calistir();
      final u = d.kaydedilen.single.single;
      expect((u.yemekKalipci, u.yemekDemirci, u.yemekDiger), (9, 11, 0));
    });

    test('"hayır" denince tabloya geçilir, kaydedilmez', () async {
      final k = _kur(['gerada 4 kalıpçı', 'iş', 'yok', 'yok', 'hayır düzelt']);
      expect(await k.motor.calistir(), GorusmeSonucu.tabloyaGecildi);
      expect(k.kaydedilen, isEmpty);
      expect(k.motor.tabloTaslaklari.single.projeId, 'g');
    });

    test('"Başka şantiye var mı?" sorusuna doğrudan anlatılırsa yeni tur o cevapla başlar', () async {
      final k = _kur(
        ['gerada 4 kalıpçı', 'iş', 'yok', 'yok', 'evet', 'KA otomotivde 3 kalıpçı vardı', 'söküm', 'yok', 'yok', 'evet', 'yok'],
        yapayZekaCevaplari: [
          [_taslak()],
          [_taslak(projeId: 'k', soylenenAd: 'KA', kalipci: 3, demirci: 0)],
        ],
      );
      expect(await k.motor.calistir(), GorusmeSonucu.tamamlandi);
      expect(k.dokumler.length, 2);
      expect(k.dokumler[1], contains('Şantiye ve çalışan sayıları: KA otomotivde 3 kalıpçı vardı'));
      expect(k.dokumler[1], contains('Yapılan işler: söküm'));
      expect(k.kaydedilen.map((t) => t.single.projeId), ['g', 'k']);
    });

    test('yapay zekâya ulaşılamazsa durur ve nedeni söylenir', () async {
      final k = _kur(['gerada 4 kalıpçı', 'iş', 'yok', 'yok'], hata: const AiKayitHatasi('Yapay zekâya ulaşılamadı.'));
      expect(await k.motor.calistir(), GorusmeSonucu.durduruldu);
      expect(k.motor.hata, 'Yapay zekâya ulaşılamadı.');
      expect(k.ses.soylenenler.last, contains('Yapay zekâya ulaşılamadı.'));
    });

    test('tek şantiye varsa adı sorulmaz; kahvaltısı açık projede kahvaltı da sorulur', () async {
      final k = _kur(['4 kalıpçı', 'iş', 'yok', 'kahvaltı 5 öğle 10', 'evet', 'yok'],
          projeler: [_proje('g', 'Gera makina', kahvalti: true)]);
      await k.motor.calistir();
      final soylenen = k.ses.soylenenler.join('\n');
      expect(soylenen, contains('Gera makina: kaç kalıpçı, kaç demirci?'));
      expect(soylenen, contains('Kahvaltı ve öğle yemeği kaç kişi, ekip ekip?'));
      expect(k.dokumler.single, contains('Şantiye (Gera makina) ve çalışan sayıları: 4 kalıpçı'));
    });
  });

  group('Ekran', () {
    testWidgets('görüşme ekranı: sorular görünür, sonunda kaydedilir ve özetle kapanır', (tester) async {
      SharedPreferences.setMockInitialValues({'gemini_api_anahtari': 'deneme-anahtari'});
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
        // Görüşme dökümü gönderiliyor mu?
        expect(istek.body, contains('soru-cevap'));
        final s = DateTime.now();
        final gun = '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'kayitlar': [
                            {
                              'projeId': 'g', 'soylenenAd': 'gera', 'tarih': gun, 'kalipci': 4, 'demirci': 5,
                              'kalipciIs': 'döşeme kalıbı', 'demirciIs': 'temel', 'yemekKalipci': 10,
                            },
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
      final ses = _SahteSes(['gerada 4 kalıpçı 5 demirci', 'döşeme kalıbı ve temel', 'yok', 'kalıpçı 10', 'evet', 'yok']);
      final eklenen = <(String, GunlukKayit)>[];
      String? sonuc;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              sonuc = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => SesliGorusmeSayfa(
                    projeler: [_gera, _ka],
                    projeGunlukKayitlari: const {},
                    onKayitEkle: (id, k) => eklenen.add((id, k)),
                    onKayitGuncelle: (a, b, c) {},
                    ses: ses,
                    servis: AiKayitService(istemci: istemci),
                    havaServisi: _HavasizServis(),
                  ),
                ),
              );
            },
            child: const Text('ac'),
          ),
        ),
      ));
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();

      expect(sonuc, '1 yeni kayıt');
      final (id, k) = eklenen.single;
      expect((id, k.kalipci, k.demirci, k.yemekKalipci), ('g', 4, 5, 10));
      expect(k.kalipciYapilanIs, 'döşeme kalıbı');
      expect(find.text('ac'), findsOneWidget); // görüşme ekranı kapandı
    });
  });
}
