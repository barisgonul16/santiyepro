import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:santiyepro/models/gunluk_kayit.dart';
import 'package:santiyepro/models/proje.dart';
import 'package:santiyepro/services/claude_gelen_kutusu.dart';

Proje _p(String id, String ad) =>
    Proje(id: id, ad: ad, aciklama: '', baslangicTarihi: DateTime(2026, 1, 1), toplamGun: 100);

void main() {
  final projeler = [_p('p1', 'Gera makina'), _p('p2', 'KA Otomotiv')];
  final bugun = DateTime(2026, 11, 15, 10);

  // Sunucunun (araclar/santiyepro_worker/src/yazma.js) yazdığı biçim.
  Map<String, dynamic> belge(Map<String, dynamic> kayit, {String aciklama = ''}) => {
        'json': jsonEncode({
          'kayitlar': [kayit],
          'anlasilmayan': '',
        }),
        'aciklama': aciklama,
        'olusturma': DateTime(2026, 11, 15, 9),
        'kaynak': 'claude',
      };

  final tamKayit = {
    'projeId': 'p1', 'soylenenAd': 'Gera makina', 'tarih': '2026-11-14',
    'kalipci': 5, 'demirci': 0, 'diger': 1,
    'kalipciIs': 'kolon kalıbı', 'demirciIs': '', 'beton': '', 'notlar': 'santral beton vermedi', 'hakedis': 'bekleme 2 saat',
    'yemek': 7, 'yemekKalipci': 0, 'yemekDemirci': 0, 'yemekDiger': 0,
    'kahvalti': 0, 'kahvaltiKalipci': 0, 'kahvaltiDemirci': 0, 'kahvaltiDiger': 0,
    'aksam': 0, 'aksamKalipci': 0, 'aksamDemirci': 0, 'aksamDiger': 0,
    'vincler': [{'firma': 'teknik vinç', 'baslangic': '08:30', 'bitis': '15:00', 'mola': 60, 'aciklama': 'kolon atıldı'}],
    'yevmiyeler': [{'ekip': 'Kalıpçı Muhammet', 'miktar': 0.5, 'aciklama': ''}],
  };

  test('sunucunun önerisi taslağa çevrilir', () {
    final o = ClaudeGelenKutusu.cozumle('abc', belge(tamKayit, aciklama: 'gera dün'), projeler, bugun)!;
    expect(o.id, 'abc');
    expect(o.aciklama, 'gera dün');
    expect(o.olusturma, DateTime(2026, 11, 15, 9));
    final t = o.taslaklar.single;
    expect(t.projeId, 'p1');
    expect(t.tarih, DateTime(2026, 11, 14));
    expect([t.kalipci, t.diger, t.yemekToplam], [5, 1, 7]);
    expect(t.hakedisNotu, 'bekleme 2 saat');
    expect(t.vincler.single.netSaat, 5.5);
    expect(t.yevmiyeler.single.miktar, 0.5);
    // Ekibi söylenmemiş yemek sayısı onay ekranında sorulur.
    expect(t.ekipBekleyenOgunler, isNotEmpty);
  });

  test('mevcut kayda işlenir: sayılar değişir, yazılar eklenir', () {
    final t = ClaudeGelenKutusu.cozumle('abc', belge(tamKayit), projeler, bugun)!.taslaklar.single;
    final mevcut = GunlukKayit(tarih: DateTime(2026, 11, 14), kalipci: 3, demirci: 2, notlar: 'yağmur', fotografYollari: ['a.jpg']);
    final k = t.kayda(mevcut);
    expect([k.kalipci, k.demirci, k.diger], [5, 2, 1]);
    expect(k.notlar, 'yağmur, santral beton vermedi');
    expect(k.fotografYollari, ['a.jpg']);
    expect(k.vincler.length, 1);
  });

  test('bozuk ya da boş öneri okunmaz', () {
    expect(ClaudeGelenKutusu.cozumle('x', {'json': '{bozuk'}, projeler, bugun), isNull);
    expect(ClaudeGelenKutusu.cozumle('x', {'json': jsonEncode({'kayitlar': []})}, projeler, bugun), isNull);
    expect(ClaudeGelenKutusu.cozumle('x', {}, projeler, bugun), isNull);
    expect(ClaudeGelenKutusu.cozumle('x', belge({'projeId': 'p1', 'tarih': '2026-11-14'}), projeler, bugun), isNull);
  });

  test('bilinmeyen şantiye boş kalır, gelecek tarih bugüne çekilir', () {
    final t = ClaudeGelenKutusu.cozumle(
            'x', belge({'projeId': 'silinmis', 'soylenenAd': 'Eski', 'tarih': '2026-12-01', 'kalipci': 2}), projeler, bugun)!
        .taslaklar
        .single;
    expect(t.projeId, '');
    expect(t.soylenenAd, 'Eski');
    expect(t.tarih, DateTime(2026, 11, 15));
  });

  test('şantiye listesi sonradan yüklenince eşleşir; okunamayan ayrılır', () {
    final ham = {'a': belge(tamKayit), 'b': <String, dynamic>{'json': '{bozuk'}};
    final (bos, okunamayan) = ClaudeGelenKutusu.ayir(ham, const [], bugun);
    expect(bos.single.taslaklar.single.projeId, '');
    expect(okunamayan, ['b']);
    final (dolu, _) = ClaudeGelenKutusu.ayir(ham, projeler, bugun);
    expect(dolu.single.taslaklar.single.projeId, 'p1');
  });

  test('Firestore REST liste yanıtı ham veriye çevrilir', () {
    final yanit = {
      'documents': [
        {
          'name': 'projects/p/databases/(default)/documents/users/u/data/claude_gelen/oneriler/abc123',
          'fields': {
            'json': {'stringValue': jsonEncode({'kayitlar': [tamKayit]})},
            'aciklama': {'stringValue': 'gera dün'},
            'olusturma': {'timestampValue': '2026-11-15T06:00:00.123Z'},
            'kaynak': {'stringValue': 'claude'},
          },
          'createTime': '2026-11-15T06:00:01Z',
        },
        {'name': '.../oneriler/bos', 'fields': {}, 'createTime': '2026-11-15T07:00:00Z'},
        {'bozuk': true},
      ],
    };
    final ham = ClaudeGelenKutusu.listeyiCoz(yanit);
    expect(ham.keys, ['abc123', 'bos']);
    expect(ham['abc123']!['aciklama'], 'gera dün');
    expect((ham['abc123']!['olusturma'] as DateTime).toUtc(), DateTime.utc(2026, 11, 15, 6, 0, 0, 123));
    expect((ham['bos']!['olusturma'] as DateTime).toUtc(), DateTime.utc(2026, 11, 15, 7));
    final (oneriler, okunamayan) = ClaudeGelenKutusu.ayir(ham, projeler, bugun);
    expect(oneriler.single.taslaklar.single.projeId, 'p1');
    expect(oneriler.single.aciklama, 'gera dün');
    expect(okunamayan, ['bos']);
    expect(ClaudeGelenKutusu.listeyiCoz({}), isEmpty);
  });
}
