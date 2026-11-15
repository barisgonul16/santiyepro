import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/malzeme.dart';
import '../models/malzeme_hareketi.dart';
import '../models/proje.dart';
import '../services/app_log.dart';
import '../services/claude_gelen_kutusu.dart';
import '../services/storage_service.dart';
import '../theme/theme_colors.dart';

/// Malzemeler: şantiyelere gelen / giden malzemenin defteri.
///
/// - Şantiyeler: seçilen şantiyede şu an ne var (gelen − giden).
/// - Hareketler: tüm gelen, giden ve aktarma kayıtları, süzgeçlerle.
/// - Aletler: demirbaş/alet listesi (Hilti, kırıcı...); şantiyesi değişince
///   hareket olarak da kaydedilir.
class MalzemelerSayfaPage extends StatefulWidget {
  final List<Proje> projeler;
  final List<MalzemeHareketi> hareketler;
  final void Function(List<MalzemeHareketi>) onHareketleriEkle;
  final void Function(MalzemeHareketi) onHareketGuncelle;
  final void Function(String id) onHareketSil;
  /// Şantiye seçicilerdeki "Yeni şantiye ekle" ile eklenen şantiye.
  final void Function(Proje) onProjeEkle;

  final List<Malzeme> malzemeler;
  final Function(Malzeme) onMalzemeEkle;
  final Function(int, Malzeme) onMalzemeGuncelle;
  final Function(int) onMalzemeSil;

  const MalzemelerSayfaPage({
    super.key,
    required this.projeler,
    required this.hareketler,
    required this.onHareketleriEkle,
    required this.onHareketGuncelle,
    required this.onHareketSil,
    required this.onProjeEkle,
    required this.malzemeler,
    required this.onMalzemeEkle,
    required this.onMalzemeGuncelle,
    required this.onMalzemeSil,
  });

  @override
  State<MalzemelerSayfaPage> createState() => _MalzemelerSayfaPageState();
}

const List<String> _birimler = ['adet', 'm²', 'm³', 'm', 'kg', 'ton', 'takım', 'paket', 'top'];

/// Şantiye seçicilerinde "Yeni şantiye ekle" seçeneğinin değeri.
const String _yeniSantiye = '__yeni_santiye__';

DropdownMenuItem<T> _yeniSantiyeOgesi<T>(T deger) => DropdownMenuItem<T>(
      value: deger,
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_circle_outline, size: 20, color: Colors.orange),
        SizedBox(width: 8),
        Flexible(
          child: Text('Yeni şantiye ekle',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
        ),
      ]),
    );

/// Kısa şantiye ekleme penceresi (ad, firma, başlangıç, planlanan gün).
/// Ayrıntılar sonra Projeler sayfasından düzenlenebilir.
Future<Proje?> _yeniSantiyeSor(BuildContext context) async {
  final ad = TextEditingController();
  final firma = TextEditingController();
  final gun = TextEditingController();
  final bugun = DateTime.now();
  DateTime baslangic = DateTime(bugun.year, bugun.month, bugun.day);
  String? hata;
  return showDialog<Proje>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialog) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: Text('Yeni şantiye', style: TextStyle(color: ThemeColors.textPrimary(context))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ad,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Şantiye adı', errorText: hata),
              ),
              TextField(controller: firma, decoration: const InputDecoration(labelText: 'Firma / açıklama (isteğe bağlı)')),
              TextField(
                controller: gun,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Planlanan gün (isteğe bağlı)'),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final secilen = await showDatePicker(
                    context: context,
                    initialDate: baslangic,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (secilen != null) setDialog(() => baslangic = secilen);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Başlangıç',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(_tarihMetni(baslangic)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (ad.text.trim().isEmpty) {
                setDialog(() => hata = 'Şantiye adını yaz');
                return;
              }
              Navigator.pop(
                context,
                Proje(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  ad: ad.text.trim(),
                  aciklama: firma.text.trim(),
                  baslangicTarihi: baslangic,
                  toplamGun: int.tryParse(gun.text.trim()) ?? 0,
                ),
              );
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    ),
  );
}

String _tarihMetni(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';

Color _turRengi(HareketTuru tur) => switch (tur) {
      HareketTuru.geldi => Colors.green.shade600,
      HareketTuru.gitti => Colors.red.shade400,
      HareketTuru.aktarma => Colors.blue.shade400,
    };

IconData _turIkonu(HareketTuru tur) => switch (tur) {
      HareketTuru.geldi => Icons.south_west,
      HareketTuru.gitti => Icons.north_east,
      HareketTuru.aktarma => Icons.swap_horiz,
    };

String _turAdi(HareketTuru tur) => switch (tur) {
      HareketTuru.geldi => 'Geldi',
      HareketTuru.gitti => 'Gitti',
      HareketTuru.aktarma => 'Aktarma',
    };

class _MalzemelerSayfaPageState extends State<MalzemelerSayfaPage> with SingleTickerProviderStateMixin {
  late final TabController _sekme = TabController(length: 3, vsync: this);

  String? _seciliSantiye;
  /// Seçicilerin anahtarı: "Yeni şantiye ekle"den vazgeçilince seçici eski
  /// değerine dönsün diye artırılır.
  int _secimSurumu = 0;

  /// Yeni şantiye ekler, kimliğini döndürür (vazgeçilirse null).
  Future<String?> _santiyeEkle() async {
    final p = await _yeniSantiyeSor(context);
    if (p == null) return null;
    widget.onProjeEkle(p);
    return p.id;
  }

  // Hareketler sekmesi süzgeçleri.
  HareketTuru? _turSuzgeci;
  String? _santiyeSuzgeci;
  String _arama = '';

  // Claude'dan (claude.ai) gelen, onay bekleyen malzeme hareketleri.
  final _gelenKutusu = ClaudeGelenKutusu(klasor: 'malzeme_onerileri');
  Map<String, Map<String, dynamic>> _hamOneriler = const {};
  bool _kutuIsleniyor = false;

  @override
  void initState() {
    super.initState();
    _sekme.addListener(() {
      if (!_sekme.indexIsChanging) setState(() {});
    });
    StorageService.sonEsitleme.addListener(_gelenKutusunuDenetle);
    _gelenKutusunuDenetle();
  }

  @override
  void dispose() {
    StorageService.sonEsitleme.removeListener(_gelenKutusunuDenetle);
    _sekme.dispose();
    super.dispose();
  }

  Map<String, String> get _projeAdlari => {for (final p in widget.projeler) p.id: p.ad};

  String _projeAdi(String id) => _projeAdlari[id] ?? 'Silinmiş şantiye';

  /// Şantiye seçicide görünenler: önce devam edenler, sonra içinde hareket
  /// olan biten şantiyeler.
  List<Proje> get _secilebilirSantiyeler {
    final hareketli = {for (final h in widget.hareketler) ...[h.kaynakProjeId, h.hedefProjeId]};
    return [
      ...widget.projeler.where((p) => p.durum != 'Tamamlandı'),
      ...widget.projeler.where((p) => p.durum == 'Tamamlandı' && hareketli.contains(p.id)),
    ];
  }

  // ------------------------------------------------------------- Claude

  Future<void> _gelenKutusunuDenetle() async {
    if (_kutuIsleniyor) return;
    final ham = await _gelenKutusu.bekleyenler();
    if (!mounted || _kutuIsleniyor) return;
    setState(() => _hamOneriler = ham);
  }

  /// Öneri belgelerini hareketlere çevirir. Kimlikler öneriye bağlıdır; aynı
  /// öneri iki kez kaydedilse bile hareket çiftlenmez.
  (List<MalzemeHareketi>, List<String>, int) _onerileriCoz() {
    final projeIdleri = {for (final p in widget.projeler) p.id};
    final hareketler = <MalzemeHareketi>[];
    final idler = <String>[];
    var atlanan = 0;
    final simdi = DateTime.now();
    _hamOneriler.forEach((oneriId, veri) {
      idler.add(oneriId);
      try {
        final icerik = jsonDecode(veri['json'] as String? ?? '');
        final liste = icerik is Map ? icerik['hareketler'] : null;
        if (liste is! List) {
          atlanan++;
          return;
        }
        for (final (i, h) in liste.indexed) {
          if (h is! Map) {
            atlanan++;
            continue;
          }
          final m = Map<String, dynamic>.from(h);
          final kaynak = (m['kaynakProjeId'] ?? '').toString();
          final hedef = (m['hedefProjeId'] ?? '').toString();
          if ((kaynak.isEmpty && hedef.isEmpty) ||
              (kaynak.isNotEmpty && !projeIdleri.contains(kaynak)) ||
              (hedef.isNotEmpty && !projeIdleri.contains(hedef))) {
            atlanan++;
            continue;
          }
          final tarih = DateTime.tryParse((m['tarih'] ?? '').toString()) ?? simdi;
          final miktar = m['miktar'] is num ? (m['miktar'] as num).toDouble() : double.tryParse('${m['miktar']}') ?? 0;
          final malzeme = (m['malzeme'] ?? '').toString().trim();
          if (malzeme.isEmpty || miktar <= 0) {
            atlanan++;
            continue;
          }
          hareketler.add(MalzemeHareketi(
            id: 'claude_${oneriId}_$i',
            tarih: DateTime(tarih.year, tarih.month, tarih.day),
            malzeme: malzeme,
            miktar: miktar,
            birim: (m['birim'] ?? 'adet').toString().trim().isEmpty ? 'adet' : (m['birim']).toString().trim(),
            kaynakProjeId: kaynak,
            hedefProjeId: hedef,
            disYer: (m['disYer'] ?? '').toString().trim(),
            irsaliyeNo: (m['irsaliyeNo'] ?? '').toString().trim(),
            not: (m['not'] ?? '').toString().trim(),
            kaynak: 'claude',
          ));
        }
      } catch (e) {
        atlanan++;
        appLog('Claude malzeme önerisi okunamadı ($oneriId): $e');
      }
    });
    hareketler.sort((a, b) => a.tarih.compareTo(b.tarih));
    return (hareketler, idler, atlanan);
  }

  Future<void> _claudeOnerileriniAc() async {
    final (hareketler, idler, atlanan) = _onerileriCoz();
    final aciklamalar = [
      for (final v in _hamOneriler.values)
        if ((v['aciklama'] as String? ?? '').trim().isNotEmpty) '"${(v['aciklama'] as String).trim()}"',
    ];
    final secim = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: Text("Claude'dan gelen malzemeler", style: TextStyle(color: ThemeColors.textPrimary(context))),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Claude'a söylediklerinden hazırlandı${aciklamalar.isEmpty ? '' : ': ${aciklamalar.join(', ')}'}. "
                  'Kaydetmezsen eklenmez; kaydettikten sonra her satırı ayrıca düzeltebilirsin.',
                  style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13),
                ),
                if (atlanan > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '$atlanan satır okunamadı (şantiye bulunamadı ya da malzeme/miktar eksik); kaydedilince '
                      "onlar eklenmez. Gerekirse elle gir ya da Claude'a yeniden söyle.",
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 10),
                if (hareketler.isEmpty)
                  Text('Okunabilen hareket yok (şantiye bulunamadı ya da bilgi eksik).',
                      style: TextStyle(color: ThemeColors.textSecondary(context))),
                for (final h in hareketler) _hareketSatiri(h, dokunulabilir: false),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'sil'),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sonra')),
          if (hareketler.isNotEmpty)
            ElevatedButton(onPressed: () => Navigator.pop(context, 'kaydet'), child: const Text('Kaydet')),
        ],
      ),
    );
    if (secim == null || !mounted) return;
    setState(() => _kutuIsleniyor = true);
    try {
      if (secim == 'kaydet') {
        final varOlan = {for (final h in widget.hareketler) h.id};
        final yeni = hareketler.where((h) => !varOlan.contains(h.id)).toList();
        if (yeni.isNotEmpty) widget.onHareketleriEkle(yeni);
        await _gelenKutusu.sil(idler, uygulandi: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${yeni.length} malzeme hareketi kaydedildi'),
          backgroundColor: Colors.green.shade700,
        ));
      } else {
        await _gelenKutusu.sil(idler);
      }
      if (mounted) setState(() => _hamOneriler = const {});
    } finally {
      if (mounted) setState(() => _kutuIsleniyor = false);
    }
    await _gelenKutusunuDenetle();
  }

  Widget _claudeKarti() {
    final (hareketler, _, _) = _onerileriCoz();
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.deepPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Claude'dan ${hareketler.length} malzeme hareketi onay bekliyor",
              style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: _kutuIsleniyor ? null : _claudeOnerileriniAc, child: const Text('Gör')),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- iskelet

  @override
  Widget build(BuildContext context) {
    final aletSekmesi = _sekme.index == 2;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'malzeme_ekle',
        onPressed: aletSekmesi ? () => _aletDuzenle() : () => _hareketFormu(),
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add),
        label: Text(aletSekmesi ? 'Alet' : 'Malzeme girişi'),
      ),
      body: Column(
        children: [
          if (_hamOneriler.isNotEmpty) _claudeKarti(),
          TabBar(
            controller: _sekme,
            labelColor: Colors.orange,
            unselectedLabelColor: ThemeColors.textSecondary(context),
            indicatorColor: Colors.orange,
            tabs: const [
              Tab(text: 'Şantiyeler', icon: Icon(Icons.inventory_2_outlined, size: 20)),
              Tab(text: 'Hareketler', icon: Icon(Icons.sync_alt, size: 20)),
              Tab(text: 'Aletler', icon: Icon(Icons.build_outlined, size: 20)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _sekme,
              children: [_santiyelerSekmesi(), _hareketlerSekmesi(), _aletlerSekmesi()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bosMesaj(String metin) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(metin,
              textAlign: TextAlign.center, style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 15)),
        ),
      );

  Widget _baslik(String metin) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(metin,
            style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13, fontWeight: FontWeight.w600)),
      );

  // ------------------------------------------------------------- Şantiyeler

  Widget _santiyelerSekmesi() {
    final santiyeler = _secilebilirSantiyeler;
    if (santiyeler.isEmpty) return _bosMesaj('Önce Projeler sayfasından bir şantiye ekle.');
    if (_seciliSantiye == null || !santiyeler.any((p) => p.id == _seciliSantiye)) {
      _seciliSantiye = santiyeler.first.id;
    }
    final id = _seciliSantiye!;
    final stok = santiyeStoku(widget.hareketler, id);
    final mevcut = stok.where((s) => s.kalan.abs() > 0.0005).toList();
    final biten = stok.where((s) => s.kalan.abs() <= 0.0005).toList();
    final sonHareketler = widget.hareketler.where((h) => h.ilgili(id)).toList()
      ..sort((a, b) => b.tarih.compareTo(a.tarih));

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('santiye_${id}_$_secimSurumu'),
          initialValue: id,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Şantiye',
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.apartment),
          ),
          items: [
            for (final p in santiyeler)
              DropdownMenuItem(
                value: p.id,
                child: Text(p.durum == 'Tamamlandı' ? '${p.ad} (bitti)' : p.ad, overflow: TextOverflow.ellipsis),
              ),
            _yeniSantiyeOgesi(_yeniSantiye),
          ],
          onChanged: (v) async {
            if (v == _yeniSantiye) {
              final yeni = await _santiyeEkle();
              if (!mounted) return;
              setState(() {
                if (yeni != null) _seciliSantiye = yeni;
                _secimSurumu++;
              });
            } else {
              setState(() => _seciliSantiye = v);
            }
          },
        ),
        _baslik('Şu an şantiyede'),
        if (mevcut.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              sonHareketler.isEmpty
                  ? 'Bu şantiyeye henüz malzeme girilmedi. Aşağıdaki "Malzeme girişi" ile ekle.'
                  : 'Şantiyede kalan malzeme yok.',
              style: TextStyle(color: ThemeColors.textTertiary(context)),
            ),
          ),
        for (final s in mevcut) _stokSatiri(s),
        if (widget.malzemeler.any((a) => a.projeId == id)) ...[
          _baslik('Aletler'),
          for (final a in widget.malzemeler.where((a) => a.projeId == id))
            Card(
              color: ThemeColors.cardBackground(context),
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                onTap: () => _aletGecmisi(a),
                leading: Icon(Icons.build, color: ThemeColors.textTertiary(context)),
                title: Text(a.ad,
                    style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.w600)),
                subtitle: a.durum.isEmpty
                    ? null
                    : Text(a.durum, style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
              ),
            ),
        ],
        if (biten.isNotEmpty) ...[
          _baslik('Tamamı gitmiş'),
          for (final s in biten) _stokSatiri(s, soluk: true),
        ],
        if (sonHareketler.isNotEmpty) ...[
          _baslik('Son hareketler'),
          for (final h in sonHareketler.take(8)) _hareketSatiri(h),
          if (sonHareketler.length > 8)
            TextButton(
              onPressed: () => setState(() {
                _santiyeSuzgeci = id;
                _sekme.animateTo(1);
              }),
              child: Text('Tüm hareketler (${sonHareketler.length})'),
            ),
        ],
      ],
    );
  }

  Widget _stokSatiri(MalzemeStoku s, {bool soluk = false}) {
    final eksi = s.kalan < 0;
    return Card(
      color: ThemeColors.cardBackground(context),
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        onTap: () => _malzemeGecmisi(s.malzeme),
        title: Text(s.malzeme,
            style: TextStyle(
                color: soluk ? ThemeColors.textTertiary(context) : ThemeColors.textPrimary(context),
                fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Gelen ${miktarMetni(s.gelen)} · Giden ${miktarMetni(s.giden)} · Son: ${_tarihMetni(s.sonHareket)}',
          style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12),
        ),
        trailing: Text(
          '${miktarMetni(s.kalan)} ${s.birim}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: eksi ? Colors.red : (soluk ? ThemeColors.textTertiary(context) : Colors.orange.shade700),
          ),
        ),
      ),
    );
  }

  /// Bir malzemenin tüm şantiyelerdeki yolculuğu.
  void _malzemeGecmisi(String malzeme) {
    final anahtar = malzemeAnahtari(malzeme);
    final liste = widget.hareketler.where((h) => malzemeAnahtari(h.malzeme) == anahtar).toList()
      ..sort((a, b) => b.tarih.compareTo(a.tarih));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeColors.cardBackground(context),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, kaydirma) => ListView(
          controller: kaydirma,
          padding: const EdgeInsets.all(14),
          children: [
            Text(malzeme,
                style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Tüm şantiyelerdeki gelişi ve gidişi', style: TextStyle(color: ThemeColors.textSecondary(context))),
            const SizedBox(height: 10),
            for (final h in liste) _hareketSatiri(h),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Hareketler

  Widget _hareketlerSekmesi() {
    final aranan = malzemeAnahtari(_arama);
    final liste = widget.hareketler.where((h) {
      if (_turSuzgeci != null && h.tur != _turSuzgeci) return false;
      if (_santiyeSuzgeci != null && !h.ilgili(_santiyeSuzgeci!)) return false;
      if (aranan.isEmpty) return true;
      final metin = malzemeAnahtari(
          '${h.malzeme} ${h.irsaliyeNo} ${h.disYer} ${h.not} ${_projeAdi(h.kaynakProjeId)} ${_projeAdi(h.hedefProjeId)}');
      return metin.contains(aranan);
    }).toList()
      ..sort((a, b) {
        final t = b.tarih.compareTo(a.tarih);
        return t != 0 ? t : b.id.compareTo(a.id);
      });

    final santiyeVarMi = _santiyeSuzgeci == null || widget.projeler.any((p) => p.id == _santiyeSuzgeci);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: TextField(
            onChanged: (v) => setState(() => _arama = v),
            style: TextStyle(color: ThemeColors.textPrimary(context)),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: 'Ara: pano, irsaliye no, firma…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: DropdownButtonFormField<String?>(
            key: ValueKey('hareket_santiye_${santiyeVarMi ? _santiyeSuzgeci : null}'),
            initialValue: santiyeVarMi ? _santiyeSuzgeci : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Şantiye',
              border: OutlineInputBorder(),
              isDense: true,
              prefixIcon: Icon(Icons.apartment),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Tüm şantiyeler')),
              for (final p in widget.projeler)
                DropdownMenuItem<String?>(
                  value: p.id,
                  child: Text(p.durum == 'Tamamlandı' ? '${p.ad} (bitti)' : p.ad, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _santiyeSuzgeci = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                const ButtonSegment(value: -1, label: Text('Tümü')),
                for (final t in HareketTuru.values)
                  ButtonSegment(
                    value: t.index,
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(_turAdi(t))),
                  ),
              ],
              selected: {_turSuzgeci?.index ?? -1},
              onSelectionChanged: (s) =>
                  setState(() => _turSuzgeci = s.first < 0 ? null : HareketTuru.values[s.first]),
            ),
          ),
        ),
        Expanded(
          child: liste.isEmpty
              ? _bosMesaj(widget.hareketler.isEmpty
                  ? 'Henüz malzeme hareketi yok.\nŞantiyeye malzeme gelince "Malzeme girişi" ile not al.'
                  : 'Bu süzgece uyan hareket yok.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 90),
                  itemCount: liste.length,
                  itemBuilder: (context, i) => _hareketSatiri(liste[i]),
                ),
        ),
      ],
    );
  }

  String _guzergah(MalzemeHareketi h) {
    final dis = h.disYer.isEmpty ? null : h.disYer;
    return switch (h.tur) {
      HareketTuru.geldi => '${dis ?? 'Dışarıdan'} → ${_projeAdi(h.hedefProjeId)}',
      HareketTuru.gitti => '${_projeAdi(h.kaynakProjeId)} → ${dis ?? 'Dışarı'}',
      HareketTuru.aktarma => '${_projeAdi(h.kaynakProjeId)} → ${_projeAdi(h.hedefProjeId)}',
    };
  }

  Widget _hareketSatiri(MalzemeHareketi h, {bool dokunulabilir = true}) {
    final renk = _turRengi(h.tur);
    final alt = [
      '${_turAdi(h.tur)} · ${_tarihMetni(h.tarih)}',
      _guzergah(h),
      if (h.irsaliyeNo.isNotEmpty) 'İrsaliye ${h.irsaliyeNo}',
      if (h.not.isNotEmpty) h.not,
    ];
    return Card(
      color: ThemeColors.cardBackground(context),
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        onTap: dokunulabilir ? () => _hareketFormu(duzenlenen: h) : null,
        onLongPress: dokunulabilir ? () => _hareketiSil(h) : null,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: renk.withValues(alpha: 0.15),
          child: Icon(_turIkonu(h.tur), color: renk, size: 20),
        ),
        title: Text('${miktarMetni(h.miktar)} ${h.birim} ${h.malzeme}',
            style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.w600)),
        subtitle: Text(alt.join('\n'), style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
        isThreeLine: alt.length > 2,
        trailing: h.fotoYolu.isNotEmpty && File(h.fotoYolu).existsSync()
            ? Icon(Icons.photo_camera, size: 18, color: ThemeColors.textTertiary(context))
            : (h.kaynak == 'claude' ? const Icon(Icons.auto_awesome, size: 16, color: Colors.deepPurple) : null),
      ),
    );
  }

  Future<void> _hareketiSil(MalzemeHareketi h) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: Text('Silinsin mi?', style: TextStyle(color: ThemeColors.textPrimary(context))),
        content: Text('${miktarMetni(h.miktar)} ${h.birim} ${h.malzeme} (${_tarihMetni(h.tarih)}) silinecek.',
            style: TextStyle(color: ThemeColors.textSecondary(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (evet == true) widget.onHareketSil(h.id);
  }

  Future<void> _hareketFormu({MalzemeHareketi? duzenlenen}) async {
    final varsayilanSantiye = _sekme.index == 0 ? _seciliSantiye : _santiyeSuzgeci;
    final sonuc = await Navigator.push<List<MalzemeHareketi>>(
      context,
      MaterialPageRoute(
        builder: (context) => _HareketFormu(
          projeler: widget.projeler,
          hareketler: widget.hareketler,
          duzenlenen: duzenlenen,
          varsayilanSantiye: varsayilanSantiye,
          onProjeEkle: widget.onProjeEkle,
        ),
      ),
    );
    if (sonuc == null || sonuc.isEmpty || !mounted) return;
    if (duzenlenen != null) {
      widget.onHareketGuncelle(sonuc.first);
    } else {
      widget.onHareketleriEkle(sonuc);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${sonuc.length} kalem kaydedildi')));
    }
  }

  // ------------------------------------------------------------- Aletler

  /// Aletler sekmesindeki süzgeç: null = tümü, '' = depoda, diğerleri şantiye.
  String? _aletSuzgeci;

  String _aletYeri(Malzeme a) {
    if (a.projeId.isNotEmpty) return _projeAdi(a.projeId);
    return a.konum.isNotEmpty ? a.konum : 'Depoda';
  }

  Widget _aletlerSekmesi() {
    final aktifler = widget.projeler.where((p) => p.durum != 'Tamamlandı').toList();
    final suzgecVar = _aletSuzgeci == null || _aletSuzgeci!.isEmpty || aktifler.any((p) => p.id == _aletSuzgeci);
    final suzgec = suzgecVar ? _aletSuzgeci : null;
    final liste = [
      for (final (i, a) in widget.malzemeler.indexed)
        if (suzgec == null || a.projeId == suzgec) (i, a),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
          child: DropdownButtonFormField<String?>(
            key: ValueKey('alet_suzgec_${suzgec}_$_secimSurumu'),
            initialValue: suzgec,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Şantiye',
              border: OutlineInputBorder(),
              isDense: true,
              prefixIcon: Icon(Icons.apartment),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Tüm aletler')),
              const DropdownMenuItem<String?>(value: '', child: Text('Depoda / şantiyede değil')),
              for (final p in aktifler) DropdownMenuItem<String?>(value: p.id, child: Text(p.ad)),
              _yeniSantiyeOgesi<String?>(_yeniSantiye),
            ],
            onChanged: (v) async {
              if (v == _yeniSantiye) {
                final yeni = await _santiyeEkle();
                if (!mounted) return;
                setState(() {
                  if (yeni != null) _aletSuzgeci = yeni;
                  _secimSurumu++;
                });
              } else {
                setState(() => _aletSuzgeci = v);
              }
            },
          ),
        ),
        Expanded(
          child: liste.isEmpty
              ? _bosMesaj(widget.malzemeler.isEmpty
                  ? 'Alet ve demirbaşlar (Hilti, kırıcı, vinç kancası…) için.\nHenüz alet eklenmedi.'
                  : 'Burada alet yok.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 90),
                  itemCount: liste.length,
                  itemBuilder: (context, sira) {
                    final (index, alet) = liste[sira];
                    Color durumRengi = Colors.green;
                    if (alet.durum.toLowerCase().contains('tamir')) durumRengi = Colors.red;
                    if (alet.durum.toLowerCase().contains('depo')) durumRengi = Colors.blue;
                    return Card(
                      color: ThemeColors.cardBackground(context),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () => _aletGecmisi(alet),
                        leading: alet.fotoYolu.isNotEmpty && File(alet.fotoYolu).existsSync()
                            ? SizedBox(
                                width: 56, height: 56, child: Image.file(File(alet.fotoYolu), fit: BoxFit.cover))
                            : Container(
                                width: 56,
                                height: 56,
                                color: ThemeColors.border(context),
                                child: Icon(Icons.build, color: ThemeColors.textTertiary(context)),
                              ),
                        title: Text(alet.ad,
                            style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.location_on, size: 14, color: ThemeColors.textTertiary(context)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(_aletYeri(alet),
                                    style: TextStyle(color: ThemeColors.textSecondary(context))),
                              ),
                            ]),
                            if (alet.durum.isNotEmpty) Text(alet.durum, style: TextStyle(color: durumRengi)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => _aletDuzenle(malzeme: alet, index: index),
                        ),
                        onLongPress: () async {
                          final evet = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: ThemeColors.cardBackground(context),
                              title: Text('Sil', style: TextStyle(color: ThemeColors.textPrimary(context))),
                              content: Text(
                                  '${alet.ad} silinsin mi? Geçmiş gidiş gelişleri Hareketler sekmesinde kalır.',
                                  style: TextStyle(color: ThemeColors.textSecondary(context))),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Sil'),
                                ),
                              ],
                            ),
                          );
                          if (evet == true) widget.onMalzemeSil(index);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Aletin hangi şantiyede ne zaman bulunduğu.
  void _aletGecmisi(Malzeme alet) {
    final liste = widget.hareketler.where((h) => h.aletId == alet.id).toList()
      ..sort((a, b) => b.tarih.compareTo(a.tarih));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeColors.cardBackground(context),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, kaydirma) => ListView(
          controller: kaydirma,
          padding: const EdgeInsets.all(14),
          children: [
            Text(alet.ad,
                style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Şu an: ${_aletYeri(alet)}', style: TextStyle(color: ThemeColors.textSecondary(context))),
            const SizedBox(height: 10),
            if (liste.isEmpty)
              Text('Henüz şantiye değişikliği yok. Düzenle ile şantiyesini seçince burada görünür.',
                  style: TextStyle(color: ThemeColors.textTertiary(context))),
            for (final h in liste) _hareketSatiri(h),
          ],
        ),
      ),
    );
  }

  /// Aletin şantiyesi değişince hareket kaydı: depodan şantiyeye "geldi",
  /// şantiyeden şantiyeye "aktarma", şantiyeden depoya "gitti".
  MalzemeHareketi? _aletHareketi(Malzeme alet, String eskiProje, DateTime tarih) {
    if (eskiProje == alet.projeId) return null;
    return MalzemeHareketi(
      id: '${DateTime.now().microsecondsSinceEpoch}_alet',
      tarih: tarih,
      malzeme: alet.ad,
      miktar: 1,
      birim: 'adet',
      kaynakProjeId: eskiProje,
      hedefProjeId: alet.projeId,
      disYer: eskiProje.isEmpty || alet.projeId.isEmpty ? 'Depo' : '',
      aletId: alet.id,
    );
  }

  Future<void> _aletDuzenle({Malzeme? malzeme, int? index}) async {
    String? fotoYolu = malzeme?.fotoYolu;
    final ad = TextEditingController(text: malzeme?.ad ?? '');
    final durum = TextEditingController(text: malzeme?.durum ?? '');
    final eskiProje = malzeme?.projeId ?? '';
    // Yeni alet, süzgeçte seçili şantiyeyle başlar.
    String projeId = malzeme == null ? (_aletSuzgeci ?? '') : eskiProje;
    final bugun = DateTime.now();
    DateTime tarih = DateTime(bugun.year, bugun.month, bugun.day);
    List<Proje> secenekler() =>
        widget.projeler.where((p) => p.durum != 'Tamamlandı' || p.id == eskiProje).toList();
    if (!secenekler().any((p) => p.id == projeId)) projeId = '';
    var seciciSurumu = 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          backgroundColor: ThemeColors.cardBackground(context),
          title: Text(malzeme == null ? 'Yeni alet' : 'Aleti düzenle',
              style: TextStyle(color: ThemeColors.textPrimary(context))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FotoKutusu(yol: fotoYolu, onSecildi: (y) => setDialog(() => fotoYolu = y)),
                TextField(controller: ad, decoration: const InputDecoration(labelText: 'Alet adı (ör. Hilti)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('alet_santiye_${projeId}_$seciciSurumu'),
                  initialValue: projeId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Hangi şantiyede', border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Depoda / şantiyede değil')),
                    for (final p in secenekler()) DropdownMenuItem(value: p.id, child: Text(p.ad)),
                    _yeniSantiyeOgesi(_yeniSantiye),
                  ],
                  onChanged: (v) async {
                    if (v == _yeniSantiye) {
                      final yeni = await _santiyeEkle();
                      setDialog(() {
                        if (yeni != null) projeId = yeni;
                        seciciSurumu++;
                      });
                    } else {
                      setDialog(() => projeId = v ?? '');
                    }
                  },
                ),
                if (projeId != eskiProje) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final secilen = await showDatePicker(
                        context: context,
                        initialDate: tarih,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (secilen != null) setDialog(() => tarih = secilen);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Ne zaman götürüldü',
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(_tarihMetni(tarih)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Bu değişiklik Hareketler sekmesine kaydedilir.',
                      style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12)),
                ],
                TextField(
                    controller: durum, decoration: const InputDecoration(labelText: 'Durum (ör. Çalışıyor, Tamirde)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                if (ad.text.trim().isEmpty) return;
                final yeni = Malzeme(
                  id: malzeme?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  ad: ad.text.trim(),
                  // Eski serbest yazı konum, şantiye seçilince gereksiz kalır.
                  konum: projeId.isEmpty ? (malzeme?.konum ?? '') : '',
                  durum: durum.text.trim(),
                  fotoYolu: fotoYolu ?? '',
                  projeId: projeId,
                );
                if (malzeme == null) {
                  widget.onMalzemeEkle(yeni);
                } else {
                  widget.onMalzemeGuncelle(index!, yeni);
                }
                final hareket = _aletHareketi(yeni, eskiProje, tarih);
                if (hareket != null) widget.onHareketleriEkle([hareket]);
                Navigator.pop(context);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- fotoğraf

/// Fotoğraf seçer ve uygulamanın kendi klasörüne kopyalar (geçici klasördeki
/// dosya zamanla silinebiliyor). Fotoğraf yalnızca bu cihazda kalır.
Future<String?> _fotografSec(BuildContext context) async {
  final secici = ImagePicker();
  ImageSource? kaynak = ImageSource.gallery;
  if (!Platform.isWindows) {
    kaynak = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Kamera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galeri'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
  }
  if (kaynak == null) return null;
  final secilen = await secici.pickImage(source: kaynak, imageQuality: 80, maxWidth: 1800);
  if (secilen == null) return null;
  try {
    final klasor = Directory('${(await getApplicationDocumentsDirectory()).path}/malzeme_fotolari');
    if (!await klasor.exists()) await klasor.create(recursive: true);
    final uzanti = secilen.path.contains('.') ? secilen.path.substring(secilen.path.lastIndexOf('.')) : '.jpg';
    final hedef = '${klasor.path}/${DateTime.now().millisecondsSinceEpoch}$uzanti';
    await File(secilen.path).copy(hedef);
    return hedef;
  } catch (e) {
    appLog('Malzeme fotoğrafı kopyalanamadı: $e');
    return secilen.path;
  }
}

class _FotoKutusu extends StatelessWidget {
  final String? yol;
  final void Function(String?) onSecildi;
  const _FotoKutusu({required this.yol, required this.onSecildi});

  @override
  Widget build(BuildContext context) {
    final var_ = yol != null && yol!.isNotEmpty && File(yol!).existsSync();
    return GestureDetector(
      onTap: () async {
        final y = await _fotografSec(context);
        if (y != null) onSecildi(y);
      },
      child: Container(
        height: 110,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: ThemeColors.border(context), borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: var_
            ? Stack(fit: StackFit.expand, children: [
                Image.file(File(yol!), fit: BoxFit.cover),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onSecildi(''),
                  ),
                ),
              ])
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, color: ThemeColors.textTertiary(context), size: 28),
                  Text('Fotoğraf (isteğe bağlı, yalnız bu cihazda kalır)',
                      style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12)),
                ],
              ),
      ),
    );
  }
}

// ----------------------------------------------------------------- giriş formu

class _Kalem {
  final TextEditingController malzeme;
  final TextEditingController miktar;
  String birim;
  _Kalem({String malzeme = '', String miktar = '', this.birim = 'adet'})
      : malzeme = TextEditingController(text: malzeme),
        miktar = TextEditingController(text: miktar);
}

/// Hızlı giriş: aynı gün, aynı şantiye ve aynı irsaliyeyle gelen birden çok
/// kalem tek seferde girilir. Düzenlemede tek kalem gösterilir.
class _HareketFormu extends StatefulWidget {
  final List<Proje> projeler;
  final List<MalzemeHareketi> hareketler;
  final MalzemeHareketi? duzenlenen;
  final String? varsayilanSantiye;
  final void Function(Proje) onProjeEkle;

  const _HareketFormu({
    required this.projeler,
    required this.hareketler,
    this.duzenlenen,
    this.varsayilanSantiye,
    required this.onProjeEkle,
  });

  @override
  State<_HareketFormu> createState() => _HareketFormuState();
}

class _HareketFormuState extends State<_HareketFormu> {
  late HareketTuru _tur;
  String? _santiye; // geldi: nereye; gitti/aktarma: nereden
  String? _hedef; // yalnızca aktarma
  late DateTime _tarih;
  final _disYer = TextEditingController();
  final _irsaliye = TextEditingController();
  final _not = TextEditingController();
  String? _foto;
  final List<_Kalem> _kalemler = [];
  String? _hata;
  /// Bu formda "Yeni şantiye ekle" ile eklenenler (liste dışarıda da
  /// güncellenir; burada hemen görünsün diye ayrıca tutulur).
  final List<Proje> _eklenenler = [];
  int _seciciSurumu = 0;

  @override
  void initState() {
    super.initState();
    final d = widget.duzenlenen;
    final aktifler = _projeler;
    if (d != null) {
      _tur = d.tur;
      _santiye = d.tur == HareketTuru.geldi ? d.hedefProjeId : d.kaynakProjeId;
      _hedef = d.tur == HareketTuru.aktarma ? d.hedefProjeId : null;
      _tarih = d.tarih;
      _disYer.text = d.disYer;
      _irsaliye.text = d.irsaliyeNo;
      _not.text = d.not;
      _foto = d.fotoYolu;
      _kalemler.add(_Kalem(malzeme: d.malzeme, miktar: miktarMetni(d.miktar), birim: d.birim));
    } else {
      _tur = HareketTuru.geldi;
      _santiye = aktifler.any((p) => p.id == widget.varsayilanSantiye)
          ? widget.varsayilanSantiye
          : (aktifler.isEmpty ? null : aktifler.first.id);
      final bugun = DateTime.now();
      _tarih = DateTime(bugun.year, bugun.month, bugun.day);
      _kalemler.add(_Kalem());
    }
  }

  /// Seçilebilir şantiyeler: devam edenler + düzenlenen kaydın şantiyeleri.
  List<Proje> get _projeler {
    final d = widget.duzenlenen;
    return [
      ...widget.projeler.where((p) => p.durum != 'Tamamlandı' || (d != null && d.ilgili(p.id))),
      ..._eklenenler.where((e) => !widget.projeler.any((p) => p.id == e.id)),
    ];
  }

  /// Daha önce girilmiş malzeme adları (öneri için), en sık kullanılan önce.
  List<String> get _bilinenMalzemeler {
    final sayac = <String, (String, int)>{};
    for (final h in widget.hareketler) {
      final a = malzemeAnahtari(h.malzeme);
      sayac[a] = (sayac[a]?.$1 ?? h.malzeme.trim(), (sayac[a]?.$2 ?? 0) + 1);
    }
    final liste = sayac.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final x in liste) x.$1];
  }

  String _sonBirim(String malzeme) {
    final a = malzemeAnahtari(malzeme);
    for (final h in widget.hareketler.reversed) {
      if (malzemeAnahtari(h.malzeme) == a) return h.birim;
    }
    return '';
  }

  void _kaydet() {
    setState(() => _hata = null);
    if (_santiye == null) return setState(() => _hata = 'Şantiye seç');
    if (_tur == HareketTuru.aktarma) {
      if (_hedef == null) return setState(() => _hata = 'Nereye gittiğini seç');
      if (_hedef == _santiye) return setState(() => _hata = 'Nereden ve nereye aynı şantiye olamaz');
    }
    final dolu = _kalemler.where((k) => k.malzeme.text.trim().isNotEmpty || k.miktar.text.trim().isNotEmpty).toList();
    if (dolu.isEmpty) return setState(() => _hata = 'En az bir malzeme yaz');
    final sonuc = <MalzemeHareketi>[];
    final kok = DateTime.now().microsecondsSinceEpoch;
    for (final (i, k) in dolu.indexed) {
      final ad = k.malzeme.text.trim();
      final miktar = double.tryParse(k.miktar.text.trim().replaceAll(',', '.'));
      if (ad.isEmpty) return setState(() => _hata = '${i + 1}. satırda malzeme adı yok');
      if (miktar == null || miktar <= 0) return setState(() => _hata = '${i + 1}. satırda miktar geçersiz ($ad)');
      final d = widget.duzenlenen;
      sonuc.add(MalzemeHareketi(
        id: d?.id ?? '${kok}_$i',
        tarih: _tarih,
        malzeme: ad,
        miktar: miktar,
        birim: k.birim,
        kaynakProjeId: _tur == HareketTuru.geldi ? '' : _santiye!,
        hedefProjeId: switch (_tur) {
          HareketTuru.geldi => _santiye!,
          HareketTuru.gitti => '',
          HareketTuru.aktarma => _hedef!,
        },
        disYer: _tur == HareketTuru.aktarma ? '' : _disYer.text.trim(),
        irsaliyeNo: _irsaliye.text.trim(),
        not: _not.text.trim(),
        fotoYolu: _foto ?? '',
        kaynak: d?.kaynak ?? 'uygulama',
      ));
    }
    Navigator.pop(context, sonuc);
  }

  Widget _santiyeSecici(String etiket, String? deger, void Function(String?) degisti) {
    final projeler = _projeler;
    return DropdownButtonFormField<String>(
      key: ValueKey('${etiket}_${deger}_$_seciciSurumu'),
      initialValue: projeler.any((p) => p.id == deger) ? deger : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: etiket, border: const OutlineInputBorder(), isDense: true),
      items: [
        for (final p in projeler) DropdownMenuItem(value: p.id, child: Text(p.ad)),
        _yeniSantiyeOgesi(_yeniSantiye),
      ],
      onChanged: (v) async {
        if (v != _yeniSantiye) return degisti(v);
        final yeni = await _yeniSantiyeSor(context);
        if (!mounted) return;
        if (yeni != null) {
          widget.onProjeEkle(yeni);
          _eklenenler.add(yeni);
          degisti(yeni.id);
        }
        setState(() => _seciciSurumu++);
      },
    );
  }

  /// Gitti / aktarmada: şantiyede kayıtlı olandan fazlası mı gidiyor? Engel
  /// değil (eski malzeme girilmemiş olabilir), yalnızca uyarı.
  String? _kalanUyarisi(_Kalem k) {
    if (_tur == HareketTuru.geldi || _santiye == null) return null;
    final ad = k.malzeme.text.trim();
    final miktar = double.tryParse(k.miktar.text.trim().replaceAll(',', '.'));
    if (ad.isEmpty || miktar == null) return null;
    final digerleri = widget.hareketler.where((h) => h.id != widget.duzenlenen?.id);
    final stok = santiyeStoku(digerleri, _santiye!).where((s) =>
        malzemeAnahtari(s.malzeme) == malzemeAnahtari(ad) && malzemeAnahtari(s.birim) == malzemeAnahtari(k.birim));
    final kalan = stok.isEmpty ? 0.0 : stok.first.kalan;
    if (miktar <= kalan + 0.0005) return null;
    return 'Kayıtlara göre şantiyede ${miktarMetni(kalan)} ${k.birim} var';
  }

  @override
  Widget build(BuildContext context) {
    final duzenleme = widget.duzenlenen != null;
    final bilinen = _bilinenMalzemeler;
    return Scaffold(
      appBar: AppBar(
        title: Text(duzenleme ? 'Hareketi düzenle' : 'Malzeme girişi'),
        actions: [TextButton(onPressed: _kaydet, child: const Text('Kaydet'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        children: [
          SegmentedButton<HareketTuru>(
            segments: const [
              ButtonSegment(value: HareketTuru.geldi, label: Text('Geldi'), icon: Icon(Icons.south_west)),
              ButtonSegment(value: HareketTuru.gitti, label: Text('Gitti'), icon: Icon(Icons.north_east)),
              ButtonSegment(value: HareketTuru.aktarma, label: Text('Aktarma'), icon: Icon(Icons.swap_horiz)),
            ],
            selected: {_tur},
            onSelectionChanged: (s) => setState(() => _tur = s.first),
          ),
          const SizedBox(height: 6),
          Text(
            switch (_tur) {
              HareketTuru.geldi => 'Şantiyeye dışarıdan (tedarikçi, kiralama, depo) malzeme geldi.',
              HareketTuru.gitti => 'Şantiyeden malzeme gitti (iade, depo, başka firma).',
              HareketTuru.aktarma => 'Bir şantiyeden diğerine taşındı.',
            },
            style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12),
          ),
          const SizedBox(height: 14),
          _santiyeSecici(
            _tur == HareketTuru.geldi ? 'Hangi şantiyeye geldi' : 'Hangi şantiyeden',
            _santiye,
            (v) => setState(() => _santiye = v),
          ),
          const SizedBox(height: 10),
          if (_tur == HareketTuru.aktarma)
            _santiyeSecici('Hangi şantiyeye', _hedef, (v) => setState(() => _hedef = v))
          else
            TextField(
              controller: _disYer,
              decoration: InputDecoration(
                labelText: _tur == HareketTuru.geldi ? 'Kimden geldi (firma, depo)' : 'Nereye gitti (firma, depo)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final secilen = await showDatePicker(
                context: context,
                initialDate: _tarih,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (secilen != null) setState(() => _tarih = secilen);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'Tarih', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today)),
              child: Text(_tarihMetni(_tarih)),
            ),
          ),
          const SizedBox(height: 16),
          Text(duzenleme ? 'Malzeme' : 'Malzemeler',
              style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final (i, k) in _kalemler.indexed) ...[
            Row(
              key: ObjectKey(k),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: k.malzeme.text),
                    optionsBuilder: (v) {
                      final a = malzemeAnahtari(v.text);
                      if (a.isEmpty) return bilinen.take(8);
                      return bilinen.where((m) => malzemeAnahtari(m).contains(a)).take(8);
                    },
                    onSelected: (m) => setState(() {
                      k.malzeme.text = m;
                      final b = _sonBirim(m);
                      if (_birimler.contains(b)) k.birim = b;
                    }),
                    fieldViewBuilder: (context, ctrl, odak, gonder) {
                      return TextField(
                        controller: ctrl,
                        focusNode: odak,
                        onChanged: (v) => setState(() => k.malzeme.text = v),
                        decoration: InputDecoration(
                          labelText: 'Malzeme',
                          hintText: 'Trio pano 270×90',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          helperText: _kalanUyarisi(k),
                          helperMaxLines: 2,
                          helperStyle: TextStyle(color: Colors.orange.shade800),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: k.miktar,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Miktar', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _birimler.contains(k.birim) ? k.birim : 'adet',
                  items: [for (final b in _birimler) DropdownMenuItem(value: b, child: Text(b))],
                  onChanged: (v) => setState(() => k.birim = v ?? 'adet'),
                ),
                if (_kalemler.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => setState(() => _kalemler.removeAt(i)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (!duzenleme)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _kalemler.add(_Kalem())),
                icon: const Icon(Icons.add),
                label: const Text('Başka malzeme (aynı irsaliye)'),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _irsaliye,
            decoration: const InputDecoration(labelText: 'İrsaliye no', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _not,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Not (plaka, kim teslim aldı…)', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          _FotoKutusu(yol: _foto, onSecildi: (y) => setState(() => _foto = y)),
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_hata!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _kaydet,
            icon: const Icon(Icons.check),
            label: const Text('Kaydet'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46)),
          ),
        ],
      ),
    );
  }
}
