import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/gunluk_kayit.dart';
import '../models/proje.dart';
import 'app_log.dart';

/// Günlük şantiye raporunu A4 PDF olarak üretir.
///
/// Fotoğraflar Cloudinary'den küçültülmüş (en fazla 1000 piksel, JPEG)
/// halleriyle indirilir; böylece rapor birkaç MB'ı geçmez, WhatsApp ile
/// gönderilebilir ve ücretsiz kotadan az harcar.
class GunlukRaporPdf {
  static const _aylar = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const _gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

  static const _lacivert = PdfColor.fromInt(0xFF1A237E);
  static const _acikGri = PdfColor.fromInt(0xFFF1F3F8);
  static const _cizgi = PdfColor.fromInt(0xFFD5D9E2);
  static const _ikincil = PdfColor.fromInt(0xFF5F6470);

  /// [kayitlar]: yalnızca o gün kaydı olan şantiyeler (proje, kayıt).
  /// [ilerleme]: fotoğraf indirme ilerlemesi (indirilen, toplam).
  static Future<Uint8List> olustur({
    required DateTime tarih,
    required List<(Proje, GunlukKayit)> kayitlar,
    String? hazirlayan,
    void Function(int indirilen, int toplam)? ilerleme,
  }) async {
    final duz = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final kalin = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    // Fotoğrafları önceden indir (sayfa çizimi eşzamanlı olmalı).
    final toplamFoto = kayitlar.fold<int>(0, (t, e) => t + e.$2.fotografYollari.length);
    int indirilen = 0;
    final fotolar = <GunlukKayit, List<pw.ImageProvider>>{};
    final alinamayan = <GunlukKayit, int>{};
    for (final (_, kayit) in kayitlar) {
      final liste = <pw.ImageProvider>[];
      for (final yol in kayit.fotografYollari) {
        final resim = await _fotografGetir(yol);
        if (resim != null) {
          liste.add(resim);
        } else {
          alinamayan[kayit] = (alinamayan[kayit] ?? 0) + 1;
        }
        indirilen++;
        ilerleme?.call(indirilen, toplamFoto);
      }
      fotolar[kayit] = liste;
    }

    final tarihMetni = '${tarih.day} ${_aylar[tarih.month - 1]} ${tarih.year}, ${_gunler[tarih.weekday - 1]}';
    final belge = pw.Document(
      title: 'Günlük Şantiye Raporu - $tarihMetni',
      author: hazirlayan ?? 'ŞantiyePro',
      creator: 'ŞantiyePro',
    );

    belge.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
          theme: pw.ThemeData.withFont(base: duz, bold: kalin),
        ),
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('ŞantiyePro · Günlük Şantiye Raporu · $tarihMetni',
                  style: const pw.TextStyle(fontSize: 8, color: _ikincil)),
              pw.Text('Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: _ikincil)),
            ],
          ),
        ),
        build: (ctx) => [
          _baslik(tarihMetni, hazirlayan),
          pw.SizedBox(height: 12),
          _gunOzeti(kayitlar),
          pw.SizedBox(height: 16),
          for (final (proje, kayit) in kayitlar)
            ..._santiyeBolumu(proje, kayit, fotolar[kayit] ?? const [], alinamayan[kayit] ?? 0),
        ],
      ),
    );

    return belge.save();
  }

  static Future<pw.ImageProvider?> _fotografGetir(String yol) async {
    try {
      Uint8List? bayt;
      if (yol.startsWith('http://') || yol.startsWith('https://')) {
        var url = yol;
        if (url.contains('res.cloudinary.com') && url.contains('/upload/')) {
          // Raporda yakınlaştırınca bulanmasın diye kutudan büyük alınır.
          url = url.replaceFirst('/upload/', '/upload/w_1500,h_1500,c_limit,q_auto,f_jpg/');
        }
        final yanit = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        if (yanit.statusCode == 200) bayt = yanit.bodyBytes;
      } else {
        final dosya = File(yol);
        final uzanti = yol.toLowerCase();
        // PDF yalnızca JPEG ve PNG'yi gömebilir.
        if (await dosya.exists() &&
            (uzanti.endsWith('.jpg') || uzanti.endsWith('.jpeg') || uzanti.endsWith('.png'))) {
          bayt = await dosya.readAsBytes();
        }
      }
      return bayt == null ? null : pw.MemoryImage(bayt);
    } catch (e) {
      appLog('Rapor fotoğrafı alınamadı: $e');
      return null;
    }
  }

  static pw.Widget _baslik(String tarihMetni, String? hazirlayan) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _lacivert, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('GÜNLÜK ŞANTİYE RAPORU',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _lacivert)),
                pw.SizedBox(height: 3),
                pw.Text(tarihMetni, style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
          if (hazirlayan != null && hazirlayan.trim().isNotEmpty)
            pw.Text('Hazırlayan: ${hazirlayan.trim()}',
                style: const pw.TextStyle(fontSize: 10, color: _ikincil)),
        ],
      ),
    );
  }

  static pw.Widget _gunOzeti(List<(Proje, GunlukKayit)> kayitlar) {
    final k = kayitlar.map((e) => e.$2);
    final kalipci = k.fold<int>(0, (t, x) => t + x.kalipci);
    final demirci = k.fold<int>(0, (t, x) => t + x.demirci);
    final diger = k.fold<int>(0, (t, x) => t + x.diger);
    final vinc = k.fold<double>(0, (t, x) => t + x.vincler.fold<double>(0, (a, v) => a + v.netSaat));
    final yevmiye = k.fold<double>(0, (t, x) => t + x.yevmiyeler.fold<double>(0, (a, y) => a + y.miktar));

    pw.Widget hucre(String deger, String etiket) => pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text(deger, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _lacivert)),
              pw.SizedBox(height: 2),
              pw.Text(etiket, style: const pw.TextStyle(fontSize: 8, color: _ikincil)),
            ],
          ),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: pw.BoxDecoration(color: _acikGri, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(
        children: [
          hucre('${kayitlar.length}', 'şantiye'),
          hucre('$kalipci', 'kalıpçı'),
          hucre('$demirci', 'demirci'),
          if (diger > 0) hucre('$diger', 'diğer'),
          hucre('${kalipci + demirci + diger}', 'toplam işçi'),
          hucre(_sayi(vinc), 'vinç saati'),
          hucre(_sayi(yevmiye), 'yevmiye'),
        ],
      ),
    );
  }

  /// Bir şantiyenin bölümü. Sayfalara bölünebilmesi için tek parça değil,
  /// ayrı ayrı widget'lar olarak döner.
  static List<pw.Widget> _santiyeBolumu(
      Proje proje, GunlukKayit kayit, List<pw.ImageProvider> fotolar, int alinamayan) {
    final satirlar = <List<String>>[];
    final ekip = [
      if (kayit.kalipci > 0) '${kayit.kalipci} kalıpçı',
      if (kayit.demirci > 0) '${kayit.demirci} demirci',
      if (kayit.diger > 0) '${kayit.diger} diğer',
    ];
    if (ekip.isNotEmpty) satirlar.add(['Ekip', ekip.join(', ')]);
    if (kayit.kalipciYapilanIs.trim().isNotEmpty) satirlar.add(['Kalıpçı işi', kayit.kalipciYapilanIs.trim()]);
    if (kayit.demirciYapilanIs.trim().isNotEmpty) satirlar.add(['Demirci işi', kayit.demirciYapilanIs.trim()]);
    if (kayit.beton.trim().isNotEmpty) satirlar.add(['Beton', kayit.beton.trim()]);
    if (kayit.vincler.isNotEmpty) {
      satirlar.add([
        'Vinç',
        kayit.vincler.map((v) {
          final mola = v.mola > 0 ? ', mola ${v.mola} dk' : '';
          final aciklama = v.aciklama.trim().isEmpty ? '' : ' - ${v.aciklama.trim()}';
          return '${v.firmaAdi.isEmpty ? 'Vinç' : v.firmaAdi}: ${v.baslangic} - ${v.bitis}$mola (${_sayi(v.netSaat)} sa)$aciklama';
        }).join('\n'),
      ]);
    }
    if (kayit.yevmiyeler.isNotEmpty) {
      satirlar.add([
        'Yevmiye',
        kayit.yevmiyeler.map((y) {
          final aciklama = y.aciklama.trim().isEmpty ? '' : ' - ${y.aciklama.trim()}';
          return '${y.ekipAdi}: ${_sayi(y.miktar)}$aciklama';
        }).join('\n'),
      ]);
    }
    final yemek = [
      if (kayit.yemekKalipci > 0) 'kalıpçı ${kayit.yemekKalipci}',
      if (kayit.yemekDemirci > 0) 'demirci ${kayit.yemekDemirci}',
      if (kayit.yemekDiger > 0) 'diğer ${kayit.yemekDiger}',
    ];
    if (yemek.isNotEmpty) satirlar.add(['Yemek', yemek.join(', ')]);
    if (kayit.notlar.trim().isNotEmpty) satirlar.add(['Notlar', kayit.notlar.trim()]);

    final baslik = pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: _lacivert,
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(proje.ad,
                style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
          ),
          if (proje.aciklama.trim().isNotEmpty)
            pw.Text(proje.aciklama.trim(), style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
        ],
      ),
    );

    final tablo = satirlar.isEmpty
        ? null
        : pw.Table(
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _cizgi, width: 0.5),
              bottom: pw.BorderSide(color: _cizgi, width: 0.5),
            ),
            columnWidths: const {0: pw.FixedColumnWidth(78), 1: pw.FlexColumnWidth()},
            children: [
              for (final s in satirlar)
                pw.TableRow(
                  verticalAlignment: pw.TableCellVerticalAlignment.top,
                  children: [
                    pw.Container(
                      color: _acikGri,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: pw.Text(s[0], style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: pw.Text(s[1], style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
            ],
          );

    // Fotoğraflar ikişerli satırlar; her satır ayrı widget ki sayfa sonunda
    // bölünebilsin.
    final fotoSatirlari = [
      for (int i = 0; i < fotolar.length; i += 2)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(
            children: [
              pw.Expanded(child: _fotoKutusu(fotolar[i], '${proje.ad} · ${i + 1}/${fotolar.length}')),
              pw.SizedBox(width: 6),
              pw.Expanded(
                  child: i + 1 < fotolar.length
                      ? _fotoKutusu(fotolar[i + 1], '${proje.ad} · ${i + 2}/${fotolar.length}')
                      : pw.SizedBox()),
            ],
          ),
        ),
    ];

    // Başlık, tablo ve ilk fotoğraf satırı aynı sayfada kalsın: başlık sayfa
    // sonunda tek başına, fotoğrafı da sonraki sayfada sahipsiz kalmasın.
    // Metin çok uzunsa birlikte bir sayfaya sığmayabilir; o zaman bölünebilir
    // düzene dönülür (yoksa PDF oluşturma hata verir).
    final metinUzunlugu = satirlar.fold<int>(0, (t, s) => t + s[1].length + 40);
    final birlikteSigar = metinUzunlugu < 1500;

    return [
      if (birlikteSigar)
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              baslik,
              ?tablo,
              if (fotoSatirlari.isNotEmpty) fotoSatirlari.first,
            ],
          ),
        )
      else ...[
        baslik,
        ?tablo,
        if (fotoSatirlari.isNotEmpty) fotoSatirlari.first,
      ],
      ...fotoSatirlari.skip(1),
      if (alinamayan > 0)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text('$alinamayan fotoğraf rapora eklenemedi (indirilemedi ya da bu cihazda yok).',
              style: const pw.TextStyle(fontSize: 8, color: _ikincil)),
        ),
      pw.SizedBox(height: 10),
    ];
  }

  /// Fotoğraf ve sol alt köşesinde sahibini gösteren etiket. Bir şantiyenin
  /// fotoğrafları sonraki sayfaya taşarsa hangi şantiyeye ait olduğu
  /// etiketten anlaşılır.
  static pw.Widget _fotoKutusu(pw.ImageProvider resim, String etiket) {
    return pw.Container(
      height: 180,
      decoration: pw.BoxDecoration(color: _acikGri, border: pw.Border.all(color: _cizgi, width: 0.5)),
      child: pw.Stack(
        children: [
          pw.Positioned.fill(child: pw.Center(child: pw.Image(resim, fit: pw.BoxFit.contain))),
          pw.Positioned(
            left: 0,
            bottom: 0,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              color: const PdfColor(0, 0, 0, 0.6),
              child: pw.Text(etiket, style: const pw.TextStyle(color: PdfColors.white, fontSize: 7)),
            ),
          ),
        ],
      ),
    );
  }

  static String _sayi(double d) =>
      d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
}
