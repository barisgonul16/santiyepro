import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gunluk_kayit.dart';
import '../models/hakedis.dart';
import '../models/proje.dart';
import '../services/storage_service.dart';
import '../theme/theme_colors.dart';
import 'ekip_cubugu.dart';

/// Ana sayfadaki "Aylık özet": tüm şantiyelerin ay ay adam-günü ve o ay
/// biten hakedişlerin metrajı / tutarı.
class AylikOzetKarti extends StatefulWidget {
  final List<Proje> projeler;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;

  const AylikOzetKarti({super.key, required this.projeler, required this.projeGunlukKayitlari});

  @override
  State<AylikOzetKarti> createState() => _AylikOzetKartiState();
}

class _AyToplami {
  int kayitGunu = 0;
  int kalipci = 0;
  int demirci = 0;
  int diger = 0;
  /// Hakediş kalemi adı -> (miktar, birim). Aynı adlı kalemler toplanır.
  final Map<String, (double, String)> metraj = {};
  double tutar = 0;

  int get adamGun => kalipci + demirci + diger;
  bool get bos => kayitGunu == 0 && metraj.isEmpty && tutar == 0;
}

class _AylikOzetKartiState extends State<AylikOzetKarti> {
  static const _aylarKisa = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  /// Kapalıyken gösterilen ay sayısı; "Daha fazla" ile [_cokAy] aya çıkar.
  static const int _azAy = 3;
  static const int _cokAy = 12;

  static final _sayiBicimi = NumberFormat('#,##0.##', 'tr_TR');

  List<Hakedis> _hakedisler = [];
  bool _tumunuGoster = false;

  @override
  void initState() {
    super.initState();
    _hakedisleriYukle();
  }

  Future<void> _hakedisleriYukle() async {
    final tumu = await StorageService().loadHakedisler();
    if (!mounted) return;
    setState(() => _hakedisler = tumu);
  }

  /// Ayın anahtarı: yıl * 12 + (ay - 1). Sıralamak ve geriye saymak kolay olur.
  static int _ayNo(DateTime t) => t.year * 12 + t.month - 1;

  Map<int, _AyToplami> _topla() {
    final projeIdleri = {for (final p in widget.projeler) p.id};
    final aylar = <int, _AyToplami>{};
    for (final id in projeIdleri) {
      for (final k in widget.projeGunlukKayitlari[id] ?? const <GunlukKayit>[]) {
        final t = aylar.putIfAbsent(_ayNo(k.tarih), _AyToplami.new);
        t.kayitGunu++;
        t.kalipci += k.kalipci;
        t.demirci += k.demirci;
        t.diger += k.diger;
      }
    }
    // Hakediş, döneminin bittiği aya yazılır.
    for (final h in _hakedisler) {
      if (!projeIdleri.contains(h.projeId)) continue;
      final t = aylar.putIfAbsent(_ayNo(h.bitis), _AyToplami.new);
      t.tutar += h.toplamTutar;
      for (final k in h.kalemler) {
        if (k.miktar <= 0) continue;
        final onceki = t.metraj[k.ad];
        // Aynı adlı kalem farklı birimle girildiyse toplanamaz; ilk birim korunur.
        if (onceki == null) {
          t.metraj[k.ad] = (k.miktar, k.birim);
        } else if (onceki.$2 == k.birim) {
          t.metraj[k.ad] = (onceki.$1 + k.miktar, k.birim);
        }
      }
    }
    return aylar;
  }

  @override
  Widget build(BuildContext context) {
    final aylar = _topla();
    final buAy = _ayNo(DateTime.now());
    final ilkVeriAyi = aylar.keys.isEmpty ? buAy : aylar.keys.reduce((a, b) => a < b ? a : b);
    // Bu aydan geriye doğru; ilk kaydın olduğu aydan öncesi gösterilmez.
    final gosterilecek = [
      for (int ay = buAy; ay > buAy - (_tumunuGoster ? _cokAy : _azAy) && ay >= ilkVeriAyi; ay--) ay,
    ];
    final dahaFazlaVar = ilkVeriAyi <= buAy - _azAy;

    // Çubukların ölçeği: gösterilen aylardaki en kalabalık ekip.
    int enCok = 1;
    for (final ay in gosterilecek) {
      final t = aylar[ay];
      if (t == null) continue;
      for (final v in [t.kalipci, t.demirci, t.diger]) {
        if (v > enCok) enCok = v;
      }
    }

    final baslik = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ThemeColors.textPrimary(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Aylık özet', style: baslik)),
            if (dahaFazlaVar)
              TextButton(
                onPressed: () => setState(() => _tumunuGoster = !_tumunuGoster),
                child: Text(_tumunuGoster ? 'Daha az' : 'Daha fazla'),
              ),
          ],
        ),
        Text('Tüm şantiyelerin toplamı (adam-gün)',
            style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          decoration: BoxDecoration(
            color: ThemeColors.cardBackground(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < gosterilecek.length; i++) ...[
                if (i > 0) Divider(height: 1, color: ThemeColors.divider(context)),
                _buildAySatiri(gosterilecek[i], aylar[gosterilecek[i]] ?? _AyToplami(), enCok),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAySatiri(int ayNo, _AyToplami t, int enCok) {
    final ikincil = TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12);
    final ekip = [
      if (t.kalipci > 0) (t.kalipci, 'kalıpçı', ThemeColors.kalipci),
      if (t.demirci > 0) (t.demirci, 'demirci', ThemeColors.demirci),
      if (t.diger > 0) (t.diger, 'diğer', ThemeColors.digerEkip),
    ];
    final hakedis = [
      for (final e in t.metraj.entries) '${e.key.toLowerCase()} ${_sayiBicimi.format(e.value.$1)} ${e.value.$2}',
      if (t.tutar > 0) '${_sayiBicimi.format(t.tutar)} TL',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_aylarKisa[ayNo % 12],
                    style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${ayNo ~/ 12}', style: ikincil),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.bos)
                  Text('Kayıt yok', style: ikincil)
                else ...[
                  for (final (sayi, ad, renk) in ekip)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: EkipCubugu(sayi: sayi, enCok: enCok, renk: renk, ad: ad),
                    ),
                  if (t.kayitGunu > 0)
                    Text('Toplam ${_sayiBicimi.format(t.adamGun)} adam-gün · ${t.kayitGunu} kayıt', style: ikincil),
                  if (hakedis.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Hakediş: ${hakedis.join(' · ')}',
                          style: TextStyle(
                              color: ThemeColors.textPrimary(context), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
