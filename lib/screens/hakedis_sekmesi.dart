import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/hakedis.dart';
import '../models/proje.dart';
import '../services/app_log.dart';
import '../services/storage_service.dart';
import '../theme/theme_colors.dart';

/// Bir hakediş dönemindeki günlük kayıtların toplamı.
class HakedisDonemOzeti {
  final int kayitGunu;
  final int kalipci;
  final int demirci;
  final int diger;
  final double vincSaat;
  final int vincGun;
  final double yevmiye;

  const HakedisDonemOzeti({
    required this.kayitGunu,
    required this.kalipci,
    required this.demirci,
    required this.diger,
    required this.vincSaat,
    required this.vincGun,
    required this.yevmiye,
  });

  int get toplamAdamGun => kalipci + demirci + diger;
}

final _tarihBicimi = DateFormat('dd.MM.yyyy');
final _sayiBicimi = NumberFormat('#,##0.##', 'tr_TR');

String _sayi(double d) => _sayiBicimi.format(d);

/// Verim gibi hesaplanan değerler için: en çok bir ondalık.
String _yuvarlak(double d) => NumberFormat('#,##0.#', 'tr_TR').format(d);

/// Proje sayfasının "Hakediş" sekmesi: dönem dönem yapılan işin metrajı ve
/// o dönemde çalışan adam-gün.
class HakedisSekmesi extends StatefulWidget {
  final Proje proje;
  /// Uygulamada kayıtlı ekip adları (yevmiye girişindekiyle aynı liste).
  final List<String> ekipler;
  final HakedisDonemOzeti Function(DateTime baslangic, DateTime bitis) donemOzeti;

  const HakedisSekmesi({
    super.key,
    required this.proje,
    required this.ekipler,
    required this.donemOzeti,
  });

  @override
  State<HakedisSekmesi> createState() => _HakedisSekmesiState();
}

class _HakedisSekmesiState extends State<HakedisSekmesi> with AutomaticKeepAliveClientMixin {
  final _depo = StorageService();
  List<Hakedis> _hakedisler = [];
  bool _yukleniyor = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final tumu = await _depo.loadHakedisler();
    if (!mounted) return;
    setState(() {
      _hakedisler = tumu.where((h) => h.projeId == widget.proje.id).toList()
        ..sort((a, b) => b.baslangic.compareTo(a.baslangic));
      _yukleniyor = false;
    });
  }

  /// Diğer projelerin hakedişlerini ezmemek için liste diskten yeniden okunur.
  Future<void> _degistir(void Function(List<Hakedis> tumu) islem) async {
    try {
      final tumu = await _depo.loadHakedisler();
      islem(tumu);
      await _depo.saveHakedisler(tumu);
    } catch (e) {
      appLog('Hakediş kaydedilemedi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hakediş kaydedilemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
    await _yukle();
  }

  Future<void> _formuAc([Hakedis? mevcut]) async {
    // Yeni hakediş, bir öncekinin bittiği günün ertesinden başlar.
    final onceki = _hakedisler.isEmpty
        ? null
        : _hakedisler.reduce((a, b) => a.bitis.isAfter(b.bitis) ? a : b);
    final sonuc = await showDialog<Hakedis>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _HakedisFormu(
        projeId: widget.proje.id,
        mevcut: mevcut,
        onceki: mevcut == null ? onceki : null,
        ekipler: widget.ekipler,
        donemOzeti: widget.donemOzeti,
      ),
    );
    if (sonuc == null) return;
    await _degistir((tumu) {
      final sira = tumu.indexWhere((h) => h.id == sonuc.id);
      if (sira >= 0) {
        tumu[sira] = sonuc;
      } else {
        tumu.add(sonuc);
      }
    });
  }

  Future<void> _sil(Hakedis h, int no) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: Text('Hakediş $no silinsin mi?', style: TextStyle(color: ThemeColors.textPrimary(context))),
        content: Text(
          '${_tarihBicimi.format(h.baslangic)} – ${_tarihBicimi.format(h.bitis)} dönemine ait metraj silinir. '
          'Günlük kayıtlar etkilenmez.',
          style: TextStyle(color: ThemeColors.textSecondary(context)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (onay != true) return;
    await _degistir((tumu) => tumu.removeWhere((x) => x.id == h.id));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_yukleniyor) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _formuAc(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Yeni hakediş'),
          ),
        ),
        const SizedBox(height: 10),
        if (_hakedisler.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Text(
              'Henüz hakediş yok.\n\nDönemi ve yapılan işin metrajını gir; o dönemde kaç adam-gün '
              'çalışıldığı günlük kayıtlardan kendiliğinden hesaplanır.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ThemeColors.textTertiary(context), height: 1.4),
            ),
          ),
        // En yeni üstte; numara en eskiden başlar.
        for (int i = 0; i < _hakedisler.length; i++)
          _buildKart(_hakedisler[i], _hakedisler.length - i),
      ],
    );
  }

  Widget _buildKart(Hakedis h, int no) {
    final ozet = widget.donemOzeti(h.baslangic, h.bitis);
    final donemGunu = DateTime(h.bitis.year, h.bitis.month, h.bitis.day)
            .difference(DateTime(h.baslangic.year, h.baslangic.month, h.baslangic.day))
            .inDays +
        1;
    final girilen = h.kalemler.where((k) => k.miktar > 0).toList();
    final paraVar = girilen.any((k) => k.birimFiyat > 0);
    final ikincil = TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12);
    final soluk = TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12);
    final metin = TextStyle(color: ThemeColors.textPrimary(context), fontSize: 14);

    Widget hucre(String s, TextStyle stil, {bool saga = true}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(s, style: stil, textAlign: saga ? TextAlign.right : TextAlign.left),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 12),
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Hakediş $no',
                  style: TextStyle(
                      color: ThemeColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${_tarihBicimi.format(h.baslangic)} – ${_tarihBicimi.format(h.bitis)}', style: ikincil),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: ThemeColors.icon(context)),
                onSelected: (secim) => secim == 'duzenle' ? _formuAc(h) : _sil(h, no),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
                  PopupMenuItem(value: 'sil', child: Text('Sil')),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kayıt girilen gün: ${ozet.kayitGunu} / $donemGunu',
                    style: ozet.kayitGunu == 0
                        ? soluk.copyWith(color: ThemeColors.uyari(context))
                        : soluk),
                const SizedBox(height: 8),
                if (girilen.isEmpty)
                  Text('Metraj girilmedi.', style: soluk)
                else
                  Table(
                    columnWidths: paraVar
                        ? const {
                            0: FlexColumnWidth(2.2),
                            1: FlexColumnWidth(3),
                            2: FlexColumnWidth(2.4),
                            3: FlexColumnWidth(3.2),
                          }
                        : const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1)},
                    children: [
                      TableRow(children: [
                        hucre('İş', soluk, saga: false),
                        hucre('Metraj', soluk),
                        if (paraVar) hucre('Fiyat', soluk),
                        if (paraVar) hucre('Tutar', soluk),
                      ]),
                      for (final k in girilen)
                        TableRow(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(k.ad, style: metin),
                                if (k.ekip.isNotEmpty) Text(k.ekip, style: soluk.copyWith(fontSize: 11)),
                              ],
                            ),
                          ),
                          hucre('${_sayi(k.miktar)} ${k.birim}', metin.copyWith(fontWeight: FontWeight.w600)),
                          if (paraVar) hucre(k.birimFiyat > 0 ? _sayi(k.birimFiyat) : '-', metin),
                          if (paraVar) hucre(k.birimFiyat > 0 ? _sayi(k.tutar) : '-', metin),
                        ]),
                    ],
                  ),
                if (paraVar) ...[
                  Divider(height: 12, color: ThemeColors.divider(context)),
                  Row(
                    children: [
                      Expanded(child: Text('Toplam', style: metin.copyWith(fontWeight: FontWeight.bold))),
                      Text('${_sayi(h.toplamTutar)} TL', style: metin.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _adamKutusu('Kalıpçı', ozet.kalipci),
                    const SizedBox(width: 8),
                    _adamKutusu('Demirci', ozet.demirci),
                    const SizedBox(width: 8),
                    _adamKutusu('Diğer', ozet.diger),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    'Toplam ${ozet.toplamAdamGun} adam-gün',
                    if (ozet.vincSaat > 0) 'vinç ${_sayi(ozet.vincSaat)} saat (${ozet.vincGun} gün)',
                    if (ozet.yevmiye > 0) 'yevmiye ${_sayi(ozet.yevmiye)}',
                  ].join(' · '),
                  style: ikincil,
                ),
                for (final v in _verimSatirlari(h, ozet))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(v.$1, style: ikincil)),
                        Text(v.$2, style: metin.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                if (h.not.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(h.not.trim(), style: ikincil.copyWith(fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kalıp metrajı kalıpçı adam-gününe, demir metrajı demirci adam-gününe
  /// bölünür. Diğer kalemler için verim hesaplanmaz.
  List<(String, String)> _verimSatirlari(Hakedis h, HakedisDonemOzeti ozet) {
    double toplam(String ad) =>
        h.kalemler.where((k) => k.ad == ad).fold(0.0, (t, k) => t + k.miktar);
    String birim(String ad) => h.kalemler.firstWhere((k) => k.ad == ad).birim;

    final satirlar = <(String, String)>[];
    final kalip = toplam('Kalıp');
    if (kalip > 0 && ozet.kalipci > 0) {
      satirlar.add(('Kalıp verimi', '${_yuvarlak(kalip / ozet.kalipci)} ${birim('Kalıp')} / adam-gün'));
    }
    final demir = toplam('Demir');
    if (demir > 0 && ozet.demirci > 0) {
      final tonMu = birim('Demir') == 'ton';
      final deger = (tonMu ? demir * 1000 : demir) / ozet.demirci;
      satirlar.add(('Demir verimi', '${_yuvarlak(deger)} ${tonMu ? 'kg' : birim('Demir')} / adam-gün'));
    }
    return satirlar;
  }

  Widget _adamKutusu(String baslik, int sayi) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ThemeColors.background(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslik, style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
            Text('$sayi',
                style: TextStyle(
                    color: ThemeColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// Formdaki tek satırın düzenlenebilir hâli.
class _Satir {
  /// Hazır gelen kalem (Kalıp, Demir, Beton, İskele): adı, birimi ve ekibi
  /// sabittir, silinemez.
  final bool sabit;
  final TextEditingController ad;
  final TextEditingController miktar;
  final TextEditingController fiyat;
  String birim;
  String ekip;

  _Satir({
    required this.sabit,
    required String ad,
    required this.birim,
    required this.ekip,
    double miktar = 0,
    double fiyat = 0,
  })  : ad = TextEditingController(text: ad),
        miktar = TextEditingController(text: _HakedisFormuState._yaz(miktar)),
        fiyat = TextEditingController(text: _HakedisFormuState._yaz(fiyat));

  void dispose() {
    ad.dispose();
    miktar.dispose();
    fiyat.dispose();
  }
}

class _HakedisFormu extends StatefulWidget {
  final String projeId;
  final Hakedis? mevcut;
  /// Yeni hakedişte tarih, satırlar ve birim fiyatların alınacağı önceki hakediş.
  final Hakedis? onceki;
  final List<String> ekipler;
  final HakedisDonemOzeti Function(DateTime, DateTime) donemOzeti;

  const _HakedisFormu({
    required this.projeId,
    required this.mevcut,
    required this.onceki,
    required this.ekipler,
    required this.donemOzeti,
  });

  @override
  State<_HakedisFormu> createState() => _HakedisFormuState();
}

class _HakedisFormuState extends State<_HakedisFormu> {
  late DateTime _baslangic;
  late DateTime _bitis;
  final List<_Satir> _satirlar = [];
  late final TextEditingController _not;

  @override
  void initState() {
    super.initState();
    final mevcut = widget.mevcut;
    final onceki = widget.onceki;
    if (mevcut != null) {
      _baslangic = mevcut.baslangic;
      _bitis = mevcut.bitis;
    } else {
      final bugun = DateTime.now();
      _baslangic = onceki != null
          ? DateTime(onceki.bitis.year, onceki.bitis.month, onceki.bitis.day + 1)
          : DateTime(bugun.year, bugun.month, 1);
      // Dönemin sonu: başlangıç ayının son günü.
      _bitis = DateTime(_baslangic.year, _baslangic.month + 1, 0);
    }

    // Düzenlemede kayıtlı satırlar; yeni hakedişte öncekinin satırları
    // (ekip ve birim fiyatıyla, metrajı boş) hazır gelir.
    final kaynak = mevcut?.kalemler ?? onceki?.kalemler ?? const <HakedisKalemi>[];
    final kullanilan = <HakedisKalemi>{};
    for (final v in Hakedis.varsayilanKalemler) {
      HakedisKalemi? eslesen;
      for (final k in kaynak) {
        if (k.ad == v.ad && !kullanilan.contains(k)) {
          eslesen = k;
          break;
        }
      }
      if (eslesen != null) kullanilan.add(eslesen);
      _satirlar.add(_Satir(
        sabit: true,
        ad: v.ad,
        birim: v.birim,
        ekip: v.ekip,
        miktar: mevcut != null ? (eslesen?.miktar ?? 0) : 0,
        fiyat: eslesen?.birimFiyat ?? 0,
      ));
    }
    for (final k in kaynak) {
      if (kullanilan.contains(k)) continue;
      _satirlar.add(_Satir(
        sabit: false,
        ad: k.ad,
        birim: k.birim,
        ekip: k.ekip,
        miktar: mevcut != null ? k.miktar : 0,
        fiyat: k.birimFiyat,
      ));
    }
    _not = TextEditingController(text: mevcut?.not ?? '');
  }

  @override
  void dispose() {
    for (final s in _satirlar) {
      s.dispose();
    }
    _not.dispose();
    super.dispose();
  }

  /// Kutuya yazılacak hâli: sıfır boş, ondalık virgülle, binlik ayraç yok.
  static String _yaz(double d) {
    if (d == 0) return '';
    final s = d == d.roundToDouble() ? d.toInt().toString() : d.toString();
    return s.replaceAll('.', ',');
  }

  /// "1850", "42,5", "1.850" ve "1.850,5" yazımlarını okur. Yalnızca nokta
  /// içeren ve üçerli gruplanmış sayı (1.850) binlik ayraçlı sayılır.
  static double _oku(String s) {
    var t = s.trim();
    if (t.contains(',')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^[0-9]{1,3}([.][0-9]{3})+$').hasMatch(t)) {
      t = t.replaceAll('.', '');
    }
    return double.tryParse(t) ?? 0;
  }

  Future<void> _tarihSec(bool baslangicMi) async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: baslangicMi ? _baslangic : _bitis,
      firstDate: DateTime(2015),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
    );
    if (secilen == null) return;
    setState(() {
      if (baslangicMi) {
        _baslangic = secilen;
        if (_bitis.isBefore(_baslangic)) _bitis = _baslangic;
      } else {
        _bitis = secilen;
        if (_bitis.isBefore(_baslangic)) _baslangic = _bitis;
      }
    });
  }

  void _satirEkle({String ad = '', String birim = 'm²', String ekip = ''}) {
    setState(() => _satirlar.add(_Satir(sabit: false, ad: ad, birim: birim, ekip: ekip)));
  }

  void _kaydet() {
    Navigator.pop(
      context,
      Hakedis(
        id: widget.mevcut?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        projeId: widget.projeId,
        baslangic: _baslangic,
        bitis: _bitis,
        kalemler: [
          for (final s in _satirlar)
            // Elle eklenen satır, adı ve metrajı girilmediyse kaydedilmez.
            if (s.sabit || (s.ad.text.trim().isNotEmpty && _oku(s.miktar.text) > 0))
              HakedisKalemi(
                ad: s.ad.text.trim(),
                birim: s.birim,
                miktar: _oku(s.miktar.text),
                birimFiyat: _oku(s.fiyat.text),
                ekip: s.ekip,
              ),
        ],
        not: _not.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ozet = widget.donemOzeti(_baslangic, _bitis);
    final soluk = TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12);
    final metin = TextStyle(color: ThemeColors.textPrimary(context), fontSize: 14);
    final sayiGirisi = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    final ekipSecenekleri = <String>[
      ...Hakedis.ekipTurleri,
      for (final e in widget.ekipler)
        if (e.trim().isNotEmpty && !Hakedis.ekipTurleri.contains(e)) e,
    ];

    InputDecoration kutu(String ipucu, {String? etiket}) => InputDecoration(
          isDense: true,
          hintText: ipucu,
          hintStyle: soluk,
          labelText: etiket,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        );

    Widget tarihKutusu(String baslik, DateTime tarih, bool baslangicMi) => Expanded(
          child: InkWell(
            onTap: () => _tarihSec(baslangicMi),
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: kutu('', etiket: baslik),
              child: Text(_tarihBicimi.format(tarih), style: metin),
            ),
          ),
        );

    Widget acilir(String etiket, String deger, List<String> secenekler, ValueChanged<String> degisti,
        {String bos = ''}) {
      final liste = [if (bos.isNotEmpty) '', ...secenekler, if (deger.isNotEmpty && !secenekler.contains(deger)) deger];
      return InputDecorator(
        decoration: kutu('', etiket: etiket).copyWith(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: liste.contains(deger) ? deger : liste.first,
            isExpanded: true,
            isDense: true,
            style: Theme.of(context).textTheme.bodyMedium?.merge(metin) ?? metin,
            dropdownColor: ThemeColors.cardBackground(context),
            items: [
              for (final s in liste)
                DropdownMenuItem(
                  value: s,
                  child: Text(s.isEmpty ? bos : s, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => degisti(v ?? '')),
          ),
        ),
      );
    }

    Widget satir(_Satir s) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: ThemeColors.background(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: s.sabit
                        ? Text(s.ad.text, style: metin.copyWith(fontWeight: FontWeight.bold))
                        : TextField(controller: s.ad, style: metin, decoration: kutu('İş adı')),
                  ),
                  const SizedBox(width: 8),
                  if (s.sabit)
                    Text(s.ekip, style: soluk)
                  else
                    Expanded(
                      flex: 6,
                      child: acilir('Ekip', s.ekip, ekipSecenekleri, (v) => s.ekip = v, bos: 'Seçilmedi'),
                    ),
                  if (!s.sabit)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Satırı kaldır',
                      icon: Icon(Icons.close, size: 18, color: ThemeColors.icon(context)),
                      onPressed: () => setState(() {
                        _satirlar.remove(s);
                        s.dispose();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: s.miktar,
                      style: metin,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: sayiGirisi,
                      decoration: kutu('', etiket: s.sabit ? 'Metraj (${s.birim})' : 'Metraj'),
                    ),
                  ),
                  if (!s.sabit) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: acilir('Birim', s.birim, Hakedis.birimler, (v) => s.birim = v),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: s.fiyat,
                      style: metin,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: sayiGirisi,
                      decoration: kutu('', etiket: 'Fiyat (TL)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

    return AlertDialog(
      backgroundColor: ThemeColors.cardBackground(context),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      title: Text(widget.mevcut == null ? 'Yeni hakediş' : 'Hakedişi düzenle',
          style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 18)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Row(
                children: [
                  tarihKutusu('Başlangıç', _baslangic, true),
                  const SizedBox(width: 8),
                  tarihKutusu('Bitiş', _bitis, false),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Bu dönemde ${ozet.kayitGunu} gün kayıt, ${ozet.toplamAdamGun} adam-gün '
                '(kalıpçı ${ozet.kalipci}, demirci ${ozet.demirci}, diğer ${ozet.diger})',
                style: soluk,
              ),
              const SizedBox(height: 12),
              for (final s in _satirlar) satir(s),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _satirEkle(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Satır ekle'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _satirEkle(ad: 'Yevmiye', birim: 'yevmiye'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Yevmiye ekle'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _not,
                style: metin,
                maxLines: 2,
                minLines: 1,
                decoration: kutu('Not (isteğe bağlı)'),
              ),
              const SizedBox(height: 6),
              Text('Küsurat için virgül kullan (42,5). Fiyat isteğe bağlı; girmezsen yalnızca metraj görünür.',
                  style: soluk),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: _kaydet, child: const Text('Kaydet')),
      ],
    );
  }
}
