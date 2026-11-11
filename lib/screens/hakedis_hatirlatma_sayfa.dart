import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/gunluk_kayit.dart';
import '../models/proje.dart';
import '../theme/theme_colors.dart';

/// Günlük kayıtlara yazılmış bir hakediş hatırlatması.
class HakedisHatirlatmasi {
  final Proje proje;

  /// Kaydın, projenin günlük kayıt listesindeki sırası (düzenlemek için).
  final int kayitIndex;
  final GunlukKayit kayit;
  const HakedisHatirlatmasi(this.proje, this.kayitIndex, this.kayit);

  DateTime get tarih => kayit.tarih;
  String get metin => kayit.hakedisNotu.trim();
}

/// Günlük kayıtlardaki "Hakediş hatırlatma" notlarını tüm şantiyelerden toplar;
/// ay ve şantiyeye göre süzülür, düzenlenir ve Excel'e aktarılır.
class HakedisHatirlatmaSayfa extends StatefulWidget {
  final List<Proje> projeler;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;
  final void Function(String projeId, int index, GunlukKayit kayit) onGunlukKayitGuncelle;

  const HakedisHatirlatmaSayfa({
    super.key,
    required this.projeler,
    required this.projeGunlukKayitlari,
    required this.onGunlukKayitGuncelle,
  });

  /// Hatırlatmalar, yeniden eskiye. [ay] null ise tüm aylar, [projeId] boşsa
  /// tüm şantiyeler; [ara] metinde ya da şantiye adında aranır.
  static List<HakedisHatirlatmasi> topla(
    List<Proje> projeler,
    Map<String, List<GunlukKayit>> kayitlar, {
    int? yil,
    int? ay,
    String projeId = '',
    String ara = '',
  }) {
    final aranan = _sade(ara.trim());
    final liste = <HakedisHatirlatmasi>[
      for (final p in projeler)
        if (projeId.isEmpty || p.id == projeId)
          for (final (i, k) in (kayitlar[p.id] ?? const <GunlukKayit>[]).indexed)
            if (k.hakedisNotu.trim().isNotEmpty &&
                (ay == null || (k.tarih.year == yil && k.tarih.month == ay)) &&
                (aranan.isEmpty ||
                    _sade(k.hakedisNotu).contains(aranan) ||
                    _sade(p.ad).contains(aranan)))
              HakedisHatirlatmasi(p, i, k),
    ];
    liste.sort((a, b) {
      final t = b.tarih.compareTo(a.tarih);
      return t != 0 ? t : a.proje.ad.toLowerCase().compareTo(b.proje.ad.toLowerCase());
    });
    return liste;
  }

  /// Büyük/küçük harf ve Türkçe harf farkı gözetmeden aramak için ("KALIP" ≈ "kalıp").
  static String _sade(String s) {
    const harf = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u'};
    final kucuk = s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
    return kucuk.split('').map((h) => harf[h] ?? h).join();
  }

  /// Excel dosyası: her satır bir günün hatırlatması (eskiden yeniye).
  static List<int>? excelOlustur(List<HakedisHatirlatmasi> liste) {
    final sirali = [...liste]
      ..sort((a, b) {
        final t = a.tarih.compareTo(b.tarih);
        return t != 0 ? t : a.proje.ad.toLowerCase().compareTo(b.proje.ad.toLowerCase());
      });
    final excel = xls.Excel.createExcel();
    final sayfa = excel['Hakediş Hatırlatma'];
    excel.delete('Sheet1');
    sayfa.appendRow([
      xls.TextCellValue('Tarih'),
      xls.TextCellValue('Şantiye'),
      xls.TextCellValue('Hakediş hatırlatma'),
    ]);
    for (final h in sirali) {
      sayfa.appendRow([
        xls.TextCellValue(DateFormat('dd.MM.yyyy').format(h.tarih)),
        xls.TextCellValue(h.proje.ad),
        xls.TextCellValue(h.metin),
      ]);
    }
    sayfa.setColumnWidth(0, 12);
    sayfa.setColumnWidth(1, 24);
    sayfa.setColumnWidth(2, 70);
    return excel.save();
  }

  @override
  State<HakedisHatirlatmaSayfa> createState() => _HakedisHatirlatmaSayfaState();
}

class _HakedisHatirlatmaSayfaState extends State<HakedisHatirlatmaSayfa> {
  static const _aylar = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  int _yil = DateTime.now().year;

  /// null: tüm aylar.
  int? _ay = DateTime.now().month;
  String _projeId = '';
  String _ara = '';

  List<HakedisHatirlatmasi> get _liste => HakedisHatirlatmaSayfa.topla(
        widget.projeler,
        widget.projeGunlukKayitlari,
        yil: _yil,
        ay: _ay,
        projeId: _projeId,
        ara: _ara,
      );

  Future<void> _excelAktar() async {
    final liste = _liste;
    if (liste.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktarılacak hatırlatma yok.')),
      );
      return;
    }
    final klasor = await FilePicker.platform.getDirectoryPath();
    if (klasor == null || !mounted) return;
    try {
      final bayt = HakedisHatirlatmaSayfa.excelOlustur(liste);
      if (bayt == null) throw const FormatException('Excel oluşturulamadı');
      final donem = _ay == null ? 'Tum' : '${_yil}_${_ay.toString().padLeft(2, '0')}';
      final ad = 'Hakedis_Hatirlatma_${donem}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      File('$klasor/$ad')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bayt);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel kaydedildi: $ad'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel kaydedilemedi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Notu değiştirir; boş bırakılırsa hatırlatma silinir. Kaydın diğer
  /// bilgilerine dokunulmaz.
  void _notuYaz(HakedisHatirlatmasi h, String metin) {
    final yeni = GunlukKayit.fromJson(h.kayit.toJson())..hakedisNotu = metin.trim();
    widget.onGunlukKayitGuncelle(h.proje.id, h.kayitIndex, yeni);
    setState(() {});
  }

  Future<void> _duzenle(HakedisHatirlatmasi h) async {
    final kutu = TextEditingController(text: h.metin);
    final sonuc = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${h.proje.ad} · ${DateFormat('dd.MM.yyyy').format(h.tarih)}'),
        content: TextField(
          controller: kutu,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Hakediş hatırlatma', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, kutu.text), child: const Text('Kaydet')),
        ],
      ),
    );
    // Kutu, pencere kapanma animasyonu bitene kadar kullanılıyor; elle kapatılmaz.
    if (sonuc != null && mounted) _notuYaz(h, sonuc);
  }

  Future<void> _sil(HakedisHatirlatmasi h) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hatırlatma silinsin mi?'),
        content: Text('${h.proje.ad}, ${DateFormat('dd.MM.yyyy').format(h.tarih)} günündeki hakediş hatırlatması silinir. '
            'Günün diğer bilgileri kalır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (onay == true && mounted) _notuYaz(h, '');
  }

  @override
  Widget build(BuildContext context) {
    final liste = _liste;
    final metin = TextStyle(color: ThemeColors.textPrimary(context), fontSize: 14);
    final ikincil = TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12);
    final simdi = DateTime.now().year;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
            color: Colors.deepOrange.withValues(alpha: 0.08),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
              spacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<int?>(
                  value: _ay,
                  underline: const SizedBox(),
                  dropdownColor: ThemeColors.cardBackground(context),
                  style: metin,
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Tüm aylar')),
                    for (var i = 1; i <= 12; i++) DropdownMenuItem<int?>(value: i, child: Text(_aylar[i - 1])),
                  ],
                  onChanged: (v) => setState(() => _ay = v),
                ),
                if (_ay != null)
                  DropdownButton<int>(
                    value: _yil,
                    underline: const SizedBox(),
                    dropdownColor: ThemeColors.cardBackground(context),
                    style: metin,
                    items: [
                      for (var y = simdi - 3; y <= simdi + 1; y++) DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (v) => setState(() => _yil = v ?? _yil),
                  ),
                DropdownButton<String>(
                  value: _projeId,
                  underline: const SizedBox(),
                  dropdownColor: ThemeColors.cardBackground(context),
                  style: metin,
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Tüm şantiyeler')),
                    for (final p in widget.projeler)
                      DropdownMenuItem(value: p.id, child: Text(p.ad, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _projeId = v ?? ''),
                ),
              ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Excel\'e aktar',
                  onPressed: _excelAktar,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: TextField(
              style: metin,
              onChanged: (v) => setState(() => _ara = v),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Hatırlatmalarda ara',
                hintStyle: ikincil,
                border: InputBorder.none,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${liste.length} hatırlatma', style: ikincil),
            ),
          ),
          Expanded(
            child: liste.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Hatırlatma yok.\nGünlük kayıtta "Hakediş hatırlatma" kutusuna yazılanlar burada toplanır.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ThemeColors.textSecondary(context)),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: liste.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: ThemeColors.border(context)),
                    itemBuilder: (context, i) {
                      final h = liste[i];
                      return ListTile(
                        onTap: () => _duzenle(h),
                        title: Text(h.metin, style: metin),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('${DateFormat('dd.MM.yyyy').format(h.tarih)} · ${h.proje.ad}', style: ikincil),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: ThemeColors.textTertiary(context)),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
                            PopupMenuItem(value: 'sil', child: Text('Sil', style: TextStyle(color: Colors.redAccent))),
                          ],
                          onSelected: (v) => v == 'sil' ? _sil(h) : _duzenle(h),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
