import 'dart:convert';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santiyepro/models/gunluk_kayit.dart';
import 'package:santiyepro/models/proje.dart';
import 'package:santiyepro/screens/hakedis_hatirlatma_sayfa.dart';
import 'package:santiyepro/screens/proje_detay_sayfa.dart';
import 'package:santiyepro/services/hava_servisi.dart';

class _Havasiz implements HavaServisi {
  @override
  Future<GunHavasi?> gunHavasi(DateTime gun) async => null;
}

Proje _proje(String id, String ad) =>
    Proje(id: id, ad: ad, aciklama: '', baslangicTarihi: DateTime(2026, 1, 1), toplamGun: 100);

final _gera = _proje('g', 'Gera makina');
final _ka = _proje('k', 'KA Otomotiv');

Map<String, List<GunlukKayit>> _kayitlar() => {
      'g': [
        GunlukKayit(tarih: DateTime(2026, 11, 3), kalipci: 4, hakedisNotu: 'Bodrum perde ek kalıp 12 m²'),
        GunlukKayit(tarih: DateTime(2026, 11, 5), kalipci: 5), // hatırlatma yok
        GunlukKayit(tarih: DateTime(2026, 10, 28), hakedisNotu: 'Ekim: merdiven kalıbı'),
      ],
      'k': [
        GunlukKayit(tarih: DateTime(2026, 11, 3), demirci: 2, hakedisNotu: 'Temel filiz ek demir'),
        GunlukKayit(tarih: DateTime(2026, 11, 7), hakedisNotu: '   '), // boşluk sayılmaz
      ],
    };

void main() {
  group('Kayıt modeli', () {
    test('hakediş hatırlatması saklanır; boşsa dosyaya yazılmaz', () {
      final k = GunlukKayit(tarih: DateTime(2026, 11, 3), hakedisNotu: 'Ek iş');
      final geri = GunlukKayit.fromJson(jsonDecode(jsonEncode(k.toJson())) as Map<String, dynamic>);
      expect(geri.hakedisNotu, 'Ek iş');
      expect(GunlukKayit(tarih: DateTime(2026, 11, 3)).toJson().containsKey('hakedisNotu'), isFalse);
      expect(GunlukKayit.fromJson({'tarih': '2026-11-01T00:00:00.000'}).hakedisNotu, '');
    });
  });

  group('Toplama', () {
    test('tüm şantiyelerden toplanır, yeniden eskiye sıralanır, boş olanlar alınmaz', () {
      final l = HakedisHatirlatmaSayfa.topla([_gera, _ka], _kayitlar());
      expect(l.map((h) => h.metin), ['Bodrum perde ek kalıp 12 m²', 'Temel filiz ek demir', 'Ekim: merdiven kalıbı']);
      // Aynı gün: şantiye adına göre (Gera önce).
      final ayni = HakedisHatirlatmaSayfa.topla([_ka, _gera], {
        'g': [GunlukKayit(tarih: DateTime(2026, 11, 3), hakedisNotu: 'a')],
        'k': [GunlukKayit(tarih: DateTime(2026, 11, 3), hakedisNotu: 'b')],
      });
      expect(ayni.map((h) => h.proje.id), ['g', 'k']);
    });

    test('ay, şantiye ve arama ile süzülür', () {
      expect(HakedisHatirlatmaSayfa.topla([_gera, _ka], _kayitlar(), yil: 2026, ay: 11).length, 2);
      expect(HakedisHatirlatmaSayfa.topla([_gera, _ka], _kayitlar(), yil: 2026, ay: 10).single.metin,
          'Ekim: merdiven kalıbı');
      expect(HakedisHatirlatmaSayfa.topla([_gera, _ka], _kayitlar(), projeId: 'k').single.metin, 'Temel filiz ek demir');
      expect(HakedisHatirlatmaSayfa.topla([_gera, _ka], _kayitlar(), ara: 'KALI').length, 2); // kalıp, kalıbı
      expect(HakedisHatirlatmaSayfa.topla([_gera, _ka], _kayitlar(), ara: 'otomotiv').single.proje.id, 'k');
    });

    test('Excel: başlık ve her gün bir satır, eskiden yeniye', () {
      final bayt = HakedisHatirlatmaSayfa.excelOlustur(HakedisHatirlatmaSayfa.topla([_gera, _ka], _kayitlar()));
      final sayfa = xls.Excel.decodeBytes(bayt!).tables['Hakediş Hatırlatma']!;
      String hucre(int satir, int sutun) => sayfa.rows[satir][sutun]!.value.toString();
      expect(sayfa.maxRows, 4);
      expect([hucre(0, 0), hucre(0, 1), hucre(0, 2)], ['Tarih', 'Şantiye', 'Hakediş hatırlatma']);
      expect([hucre(1, 0), hucre(1, 1), hucre(1, 2)], ['28.10.2026', 'Gera makina', 'Ekim: merdiven kalıbı']);
      expect(hucre(3, 2), 'Temel filiz ek demir');
    });
  });

  group('Ekranlar', () {
    void genis(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('sayfa: hatırlatmalar listelenir; düzenlenince yalnızca not değişir, silinince kaybolur', (tester) async {
      genis(tester);
      final kayitlar = _kayitlar();
      final guncellenen = <(String, int, GunlukKayit)>[];
      await tester.pumpWidget(MaterialApp(
        home: HakedisHatirlatmaSayfa(
          projeler: [_gera, _ka],
          projeGunlukKayitlari: kayitlar,
          onGunlukKayitGuncelle: (id, i, k) {
            guncellenen.add((id, i, k));
            kayitlar[id]![i] = k;
          },
        ),
      ));
      // Tüm aylar.
      await tester.tap(find.byType(DropdownButton<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tüm aylar').last);
      await tester.pumpAndSettle();
      expect(find.text('3 hatırlatma'), findsOneWidget);
      expect(find.text('03.11.2026 · Gera makina'), findsOneWidget);

      await tester.tap(find.text('Bodrum perde ek kalıp 12 m²'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Bodrum perde ek kalıp 14 m²');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      final (id, i, k) = guncellenen.single;
      expect((id, i, k.hakedisNotu, k.kalipci), ('g', 0, 'Bodrum perde ek kalıp 14 m²', 4));
      expect(find.text('Bodrum perde ek kalıp 14 m²'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert).at(1)); // KA Otomotiv, 03.11
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil').last);
      await tester.pumpAndSettle();
      expect(find.text('2 hatırlatma'), findsOneWidget);
      expect(kayitlar['k']![0].hakedisNotu, '');
      expect(kayitlar['k']![0].demirci, 2); // günün diğer bilgisi kaldı
    });

    testWidgets('giriş formuna yazılan hakediş hatırlatması kayda yazılır', (tester) async {
      genis(tester);
      final kaydedilen = <GunlukKayit>[];
      await tester.pumpWidget(MaterialApp(
        home: ProjeDetaySayfa(
          proje: _gera,
          gunlukKayitlar: const [],
          onKayitEkle: kaydedilen.add,
          onKayitGuncelle: (_, k) => kaydedilen.add(k),
          projeGunlukKayitlari: const {},
          ekipler: const [],
          baslangicSekmesi: 1,
          havaServisi: _Havasiz(),
        ),
      ));
      await tester.pumpAndSettle();
      final kutu = find.ancestor(of: find.text('Hakediş hatırlatma'), matching: find.byType(Column)).first;
      await tester.enterText(find.descendant(of: kutu, matching: find.byType(TextField)), 'Kolon filizi ek demir');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(kaydedilen.single.hakedisNotu, 'Kolon filizi ek demir');
    });
  });
}
