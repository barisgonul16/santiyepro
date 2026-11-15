import 'package:flutter_test/flutter_test.dart';
import 'package:santiyepro/models/malzeme_hareketi.dart';

MalzemeHareketi h(String id, String malzeme, double miktar,
        {String kaynak = '', String hedef = '', String birim = 'adet', int gun = 1}) =>
    MalzemeHareketi(
      id: id,
      tarih: DateTime(2026, 11, gun),
      malzeme: malzeme,
      miktar: miktar,
      birim: birim,
      kaynakProjeId: kaynak,
      hedefProjeId: hedef,
    );

void main() {
  test('tür nereden/nereye alanlarından çıkar', () {
    expect(h('1', 'x', 1, hedef: 'p1').tur, HareketTuru.geldi);
    expect(h('2', 'x', 1, kaynak: 'p1').tur, HareketTuru.gitti);
    expect(h('3', 'x', 1, kaynak: 'p1', hedef: 'p2').tur, HareketTuru.aktarma);
  });

  test('stok: gelen − giden, Türkçe harf ve boşluk farkı aynı malzeme', () {
    final liste = [
      h('1', 'Trio Pano', 100, hedef: 'p1', gun: 1),
      h('2', 'trıo  pano', 30, kaynak: 'p1', hedef: 'p2', gun: 5),
      h('3', 'Ø12 demir', 6.5, hedef: 'p1', birim: 'ton', gun: 6),
      h('4', 'Ø12 demir', 2, kaynak: 'p1', birim: 'ton', gun: 7),
    ];
    final p1 = santiyeStoku(liste, 'p1');
    expect(p1.map((s) => [s.malzeme, s.kalan]).toList(), [
      ['Trio Pano', 70.0],
      ['Ø12 demir', 4.5],
    ]);
    expect(p1.first.sonHareket, DateTime(2026, 11, 5));
    final p2 = santiyeStoku(liste, 'p2');
    expect(p2.single.kalan, 30);
    expect(p2.single.giden, 0);
  });

  test('JSON gidiş-dönüş ve eksik alanlar', () {
    final a = MalzemeHareketi(
      id: 'a',
      tarih: DateTime(2026, 11, 14),
      malzeme: 'Kontrplak 18 mm',
      miktar: 40,
      birim: 'adet',
      hedefProjeId: 'p1',
      disYer: 'Yapı donanım',
      irsaliyeNo: '004512',
      kaynak: 'claude',
    );
    final b = MalzemeHareketi.fromJson(a.toJson());
    expect(b.toJson(), a.toJson());
    final eksik = MalzemeHareketi.fromJson({'id': 'z', 'tarih': '2026-11-01', 'hedefProjeId': 'p1', 'miktar': '3'});
    expect([eksik.malzeme, eksik.birim, eksik.miktar, eksik.kaynak], ['İsimsiz malzeme', 'adet', 3.0, 'uygulama']);
  });

  test('miktar metni', () {
    expect(miktarMetni(6.5), '6,5');
    expect(miktarMetni(40), '40');
    expect(miktarMetni(0.1 + 0.2), '0,3');
  });
}
