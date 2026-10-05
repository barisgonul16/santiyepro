import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gunluk_kayit.dart';
import '../models/proje.dart';
import '../theme/theme_colors.dart';

/// Tüm şantiyelerin günlük kayıtlarında (yapılan iş, beton, notlar, vinç ve
/// yevmiye açıklamaları) kelime arar. Sonuca dokununca [onSec] çağrılır.
class KayitAramaSayfa extends StatefulWidget {
  final List<Proje> projeler;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;
  final void Function(Proje proje, DateTime tarih) onSec;

  const KayitAramaSayfa({
    super.key,
    required this.projeler,
    required this.projeGunlukKayitlari,
    required this.onSec,
  });

  /// Büyük/küçük harf ve Türkçe harf farkını yok sayar: "DÖŞEME", "doseme"
  /// ve "döşeme" aynı sayılır.
  static String sade(String s) {
    const cift = {
      'İ': 'i', 'I': 'i', 'ı': 'i', 'Ş': 's', 'ş': 's', 'Ğ': 'g', 'ğ': 'g',
      'Ü': 'u', 'ü': 'u', 'Ö': 'o', 'ö': 'o', 'Ç': 'c', 'ç': 'c',
    };
    final b = StringBuffer();
    for (final r in s.runes) {
      final h = String.fromCharCode(r);
      b.write(cift[h] ?? h.toLowerCase());
    }
    return b.toString();
  }

  @override
  State<KayitAramaSayfa> createState() => _KayitAramaSayfaState();
}

class _Sonuc {
  final Proje proje;
  final GunlukKayit kayit;
  /// Aranan kelimenin geçtiği alanlar: (başlık, metin).
  final List<(String, String)> alanlar;
  const _Sonuc(this.proje, this.kayit, this.alanlar);
}

class _KayitAramaSayfaState extends State<KayitAramaSayfa> {
  static const int _enCokSonuc = 100;
  final _kutu = TextEditingController();
  String _aranan = '';

  @override
  void dispose() {
    _kutu.dispose();
    super.dispose();
  }

  List<(String, String)> _alanlar(GunlukKayit k) => [
        ('Kalıpçı işi', k.kalipciYapilanIs),
        ('Demirci işi', k.demirciYapilanIs),
        ('Beton', k.beton),
        ('Not', k.notlar),
        for (final v in k.vincler) ('Vinç', '${v.firmaAdi} ${v.aciklama}'.trim()),
        for (final y in k.yevmiyeler) ('Yevmiye', '${y.ekipAdi} ${y.aciklama}'.trim()),
      ];

  List<_Sonuc> _ara() {
    // Her kelime kaydın herhangi bir alanında geçmeli.
    final kelimeler = KayitAramaSayfa.sade(_aranan).split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
    if (kelimeler.isEmpty || kelimeler.every((k) => k.length < 2)) return [];

    final sonuclar = <_Sonuc>[];
    for (final p in widget.projeler) {
      for (final k in widget.projeGunlukKayitlari[p.id] ?? const <GunlukKayit>[]) {
        final alanlar = _alanlar(k).where((a) => a.$2.trim().isNotEmpty).toList();
        final hepsi = KayitAramaSayfa.sade(alanlar.map((a) => a.$2).join('\n'));
        if (!kelimeler.every(hepsi.contains)) continue;
        final gecenler =
            alanlar.where((a) => kelimeler.any(KayitAramaSayfa.sade(a.$2).contains)).toList();
        sonuclar.add(_Sonuc(p, k, gecenler));
      }
    }
    sonuclar.sort((a, b) => b.kayit.tarih.compareTo(a.kayit.tarih));
    return sonuclar;
  }

  @override
  Widget build(BuildContext context) {
    final sonuclar = _ara();
    final gosterilen = sonuclar.take(_enCokSonuc).toList();
    final ikincil = TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13);
    final tarihBicimi = DateFormat('dd.MM.yyyy');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: ThemeColors.headerBackground(context),
        iconTheme: IconThemeData(color: ThemeColors.icon(context)),
        title: TextField(
          controller: _kutu,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 17),
          decoration: InputDecoration(
            hintText: 'Kayıtlarda ara (ör. döşeme betonu)',
            hintStyle: TextStyle(color: ThemeColors.textTertiary(context)),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _aranan = v),
        ),
        actions: [
          if (_aranan.isNotEmpty)
            IconButton(
              tooltip: 'Temizle',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _kutu.clear();
                _aranan = '';
              }),
            ),
        ],
      ),
      body: _aranan.trim().length < 2
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text(
                  'Yapılan iş, beton, not, vinç ve yevmiye açıklamalarında arar.\nEn az 2 harf yaz.',
                  textAlign: TextAlign.center,
                  style: ikincil.copyWith(height: 1.4),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: gosterilen.length + 1,
              separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : Divider(height: 1, color: ThemeColors.divider(context)),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      sonuclar.isEmpty
                          ? 'Sonuç bulunamadı.'
                          : sonuclar.length > _enCokSonuc
                              ? '${sonuclar.length} kayıt bulundu; en yeni $_enCokSonuc tanesi gösteriliyor.'
                              : '${sonuclar.length} kayıt bulundu.',
                      style: ikincil,
                    ),
                  );
                }
                final s = gosterilen[i - 1];
                return InkWell(
                  onTap: () => widget.onSec(s.proje, s.kayit.tarih),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(tarihBicimi.format(s.kayit.tarih),
                                style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(s.proje.ad,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: ThemeColors.textPrimary(context), fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        for (final (baslik, metin) in s.alanlar)
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '$baslik: ', style: TextStyle(color: ThemeColors.textTertiary(context))),
                              TextSpan(text: metin.trim()),
                            ]),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: ikincil,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
