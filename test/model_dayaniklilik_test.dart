import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:santiyepro/models/fatura.dart';
import 'package:santiyepro/models/gorev.dart';
import 'package:santiyepro/models/gunluk_kayit.dart';
import 'package:santiyepro/models/harcama.dart';
import 'package:santiyepro/models/hatirlatici.dart';
import 'package:santiyepro/models/proje.dart';

/// Bu testler, tek bir bozuk kaydın tüm koleksiyonu düşürmesini önleyen
/// davranışı doğrular. Eskiden `json['tamamlandi']` gibi korumasız alanlar
/// istisna fırlatıyor, StorageService bunu yakalayıp boş liste dönüyordu;
/// kullanıcı bir kayıt eklediğinde de o boş liste diske ve buluta yazılıyordu.
void main() {
  group('Eksik alanlar kaydı düşürmez', () {
    test('Hatirlatici: tamamlandi alanı yoksa varsayılana düşer', () {
      final h = Hatirlatici.fromJson({
        'id': 'a1',
        'baslik': 'Beton dökümü',
        'tarih': '2026-03-01T00:00:00.000',
        'saat': '9:30',
        // 'aciklama' ve 'tamamlandi' bilerek yok
      });

      expect(h.tamamlandi, isFalse);
      expect(h.aciklama, '');
      expect(h.saat.hour, 9);
      expect(h.saat.minute, 30);
    });

    test('Gorev: bozuk saat biçimi istisna fırlatmaz', () {
      final g = Gorev.fromJson({
        'ad': 'Demir kontrolü',
        'tarih': '2026-03-01T00:00:00.000',
        'saat': 'bozuk',
      });

      expect(g.saat.hour, 0);
      expect(g.saat.minute, 0);
      expect(g.ad, 'Demir kontrolü');
    });

    test('Proje: id ve ad eksikse kayıt yine de okunur', () {
      final p = Proje.fromJson({
        'baslangicTarihi': '2026-01-15T00:00:00.000',
        'toplamGun': '120', // sayı yerine metin
      });

      expect(p.id, isNotEmpty);
      expect(p.ad, 'İsimsiz Proje');
      expect(p.toplamGun, 120);
      expect(p.durum, 'Devam Ediyor');
    });

    test('Fatura ve Harcama: tutarlar metin olarak gelse de okunur', () {
      final f = Fatura.fromJson({
        'id': 'f1',
        'tutar': '1500.50',
        'tarih': '2026-02-10T00:00:00.000',
      });
      final h = Harcama.fromJson({
        'id': 'h1',
        'miktar': 250, // eski alan adı
        'tarih': '2026-02-10T00:00:00.000',
      });

      expect(f.tutar, 1500.50);
      expect(f.kdv, 0);
      expect(h.tutar, 250);
      expect(h.kategori, 'Genel');
    });
  });

  group('Zorunlu tarih okunamazsa kayıt atlanır', () {
    test('Tarihi olmayan proje istisna fırlatır', () {
      expect(() => Proje.fromJson({'id': 'p1', 'ad': 'Test'}),
          throwsA(isA<FormatException>()));
    });

    test('Tarihi bozuk günlük kayıt istisna fırlatır', () {
      expect(() => GunlukKayit.fromJson({'tarih': 'dün'}),
          throwsA(isA<FormatException>()));
    });
  });

  group('Liste ayrıştırma: bozuk kayıt diğerlerini düşürmez', () {
    // StorageService._readList ile aynı mantık; oradaki kod path_provider
    // gerektirdiği için davranış burada birebir yeniden kuruluyor.
    List<T> kayitlariCoz<T>(
      String ham,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final cozulmus = jsonDecode(ham) as List;
      final sonuc = <T>[];
      for (final kayit in cozulmus) {
        try {
          sonuc.add(fromJson(Map<String, dynamic>.from(kayit as Map)));
        } catch (_) {
          // bozuk kayıt atlanır
        }
      }
      return sonuc;
    }

    test('3 projeden biri bozuksa diğer 2 proje korunur', () {
      final ham = jsonEncode([
        {
          'id': 'p1',
          'ad': 'Barakfakih',
          'aciklama': '',
          'baslangicTarihi': '2026-01-01T00:00:00.000',
          'toplamGun': 100,
        },
        {
          'id': 'p2',
          'ad': 'Bozuk Kayıt',
          'baslangicTarihi': null, // tarih yok -> atlanmalı
          'toplamGun': 50,
        },
        {
          'id': 'p3',
          'ad': 'Timsah Arena',
          'aciklama': '',
          'baslangicTarihi': '2026-02-01T00:00:00.000',
          'toplamGun': 200,
        },
      ]);

      final projeler = kayitlariCoz(ham, Proje.fromJson);

      expect(projeler.length, 2);
      expect(projeler.map((p) => p.id), ['p1', 'p3']);
    });
  });

  group('Günlük kayıt alt listeleri', () {
    test('Bozuk vinç satırı günün tamamını düşürmez', () {
      final k = GunlukKayit.fromJson({
        'tarih': '2026-03-05T00:00:00.000',
        'kalipci': 8,
        'notlar': 'Beton döküldü',
        'vincler': [
          {'firmaAdi': 'Acar Vinç', 'baslangic': '08:00', 'bitis': '17:00'},
          'bu bir nesne değil', // bozuk satır
        ],
        'fotografYollari': ['https://ornek/1.jpg', null],
      });

      expect(k.kalipci, 8);
      expect(k.notlar, 'Beton döküldü');
      expect(k.vincler.length, 1);
      expect(k.vincler.first.firmaAdi, 'Acar Vinç');
      expect(k.fotografYollari.length, 1);
    });
  });

  group('Gidiş-dönüş bütünlüğü', () {
    test('toJson -> fromJson kaydı bozmaz', () {
      final orijinal = GunlukKayit(
        tarih: DateTime(2026, 3, 5),
        kalipci: 12,
        demirci: 7,
        notlar: 'Şantiye notu: kalıp söküldü',
        beton: 'C30/37',
        fotografYollari: ['https://ornek/foto.jpg'],
        vincler: [VincBilgisi(firmaAdi: 'Acar', baslangic: '08:00', bitis: '17:00', mola: 60)],
        yevmiyeler: [YevmiyeBilgisi(ekipAdi: 'Kalıp Ekibi', miktar: 4.5, aciklama: 'Tam gün')],
      );

      final geri = GunlukKayit.fromJson(jsonDecode(jsonEncode(orijinal.toJson())));

      expect(geri.tarih, orijinal.tarih);
      expect(geri.kalipci, 12);
      expect(geri.demirci, 7);
      expect(geri.notlar, 'Şantiye notu: kalıp söküldü');
      expect(geri.beton, 'C30/37');
      expect(geri.vincler.first.mola, 60);
      expect(geri.yevmiyeler.first.miktar, 4.5);
      expect(geri.fotografYollari, ['https://ornek/foto.jpg']);
    });
  });
}
