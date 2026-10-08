import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/gunluk_kayit.dart';
import '../models/proje.dart';
import '../services/ai_kayit_service.dart';
import '../theme/theme_colors.dart';

/// Sesle kayıt: kullanıcı günün işlerini anlatır, yapay zekâ şantiye şantiye
/// taslak çıkarır, kullanıcı düzeltip onaylar. Onaysız hiçbir şey kaydedilmez.
class SesliKayitSayfa extends StatefulWidget {
  /// Devam eden şantiyeler.
  final List<Proje> projeler;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;
  final void Function(String projeId, GunlukKayit kayit) onKayitEkle;
  final void Function(String projeId, int index, GunlukKayit kayit) onKayitGuncelle;
  /// Testlerde sahte servis vermek için.
  final AiKayitService? servis;

  const SesliKayitSayfa({
    super.key,
    required this.projeler,
    required this.projeGunlukKayitlari,
    required this.onKayitEkle,
    required this.onKayitGuncelle,
    this.servis,
  });

  @override
  State<SesliKayitSayfa> createState() => _SesliKayitSayfaState();
}

class _SesliKayitSayfaState extends State<SesliKayitSayfa> {
  final _metin = TextEditingController();
  final SpeechToText _ses = SpeechToText();
  late final AiKayitService _servis = widget.servis ?? AiKayitService();

  bool _sesHazir = false;
  bool _dinliyor = false;
  String _dinlemeOncesi = '';
  bool _cozuluyor = false;
  String? _hata;

  /// null: henüz çözümlenmedi (konuşma adımı). Dolu: onay adımı.
  List<SesliKayitTaslagi>? _taslaklar;
  String _anlasilmayan = '';

  final _tarihBicimi = DateFormat('dd.MM.yyyy');

  @override
  void dispose() {
    if (_sesHazir) _ses.cancel();
    _metin.dispose();
    super.dispose();
  }

  Future<void> _dinle() async {
    if (_dinliyor) {
      await _ses.stop();
      if (mounted) setState(() => _dinliyor = false);
      return;
    }
    try {
      _sesHazir = _sesHazir ||
          await _ses.initialize(
            onStatus: (durum) {
              if (mounted && (durum == 'done' || durum == 'notListening')) setState(() => _dinliyor = false);
            },
            onError: (_) {
              if (mounted) setState(() => _dinliyor = false);
            },
          );
    } catch (_) {
      _sesHazir = false;
    }
    if (!mounted) return;
    if (!_sesHazir) {
      setState(() => _hata = 'Bu cihazda sesle yazma kullanılamıyor. Metni elle yazabilirsin.');
      return;
    }
    final diller = await _ses.locales();
    final turkce = diller.where((d) => d.localeId.toLowerCase().startsWith('tr')).toList();
    _dinlemeOncesi = _metin.text.trim();
    setState(() {
      _dinliyor = true;
      _hata = null;
    });
    await _ses.listen(
      listenOptions: SpeechListenOptions(
        localeId: turkce.isEmpty ? null : turkce.first.localeId,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 6),
      ),
      onResult: (sonuc) {
        final soylenen = sonuc.recognizedWords.trim();
        _metin.text = [_dinlemeOncesi, soylenen].where((x) => x.isNotEmpty).join(' ');
      },
    );
  }

  Future<void> _cozumle() async {
    final metin = _metin.text.trim();
    if (metin.isEmpty) return;
    if (_dinliyor) await _ses.stop();
    setState(() {
      _dinliyor = false;
      _cozuluyor = true;
      _hata = null;
    });
    try {
      final (taslaklar, anlasilmayan) = await _servis.cozumle(metin, widget.projeler, DateTime.now());
      if (!mounted) return;
      setState(() {
        _taslaklar = taslaklar;
        _anlasilmayan = anlasilmayan;
        if (taslaklar.isEmpty) {
          _taslaklar = null;
          _hata = 'Söylediklerinden kayıt çıkarılamadı. Şantiye adını ve yapılan işi söyleyerek yeniden dene.';
        }
      });
    } on AiKayitHatasi catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } catch (e) {
      if (mounted) setState(() => _hata = 'Beklenmeyen hata: $e');
    } finally {
      if (mounted) setState(() => _cozuluyor = false);
    }
  }

  /// O şantiyede o güne ait kaydın sırası; yoksa -1.
  int _mevcutSira(SesliKayitTaslagi t) {
    final liste = widget.projeGunlukKayitlari[t.projeId] ?? const <GunlukKayit>[];
    return liste.indexWhere((k) => DateUtils.isSameDay(k.tarih, t.tarih));
  }

  void _kaydet() {
    final taslaklar = _taslaklar!;
    if (taslaklar.any((t) => t.projeId.isEmpty)) {
      setState(() => _hata = 'Şantiyesi seçilmemiş kayıt var. Şantiyeyi seç ya da o kaydı kaldır.');
      return;
    }
    int yeni = 0, guncel = 0;
    for (final t in taslaklar) {
      final sira = _mevcutSira(t);
      if (sira >= 0) {
        final mevcut = widget.projeGunlukKayitlari[t.projeId]![sira];
        widget.onKayitGuncelle(t.projeId, sira, t.kayda(mevcut));
        guncel++;
      } else {
        widget.onKayitEkle(t.projeId, t.kayda(null));
        yeni++;
      }
    }
    final ozet = [if (yeni > 0) '$yeni yeni kayıt', if (guncel > 0) '$guncel kayıt güncellendi'].join(', ');
    Navigator.pop(context, ozet);
  }

  @override
  Widget build(BuildContext context) {
    final onayAdimi = _taslaklar != null;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: ThemeColors.headerBackground(context),
        iconTheme: IconThemeData(color: ThemeColors.icon(context)),
        title: Text(onayAdimi ? 'Kayıtları onayla' : 'Sesle kayıt',
            style: TextStyle(color: ThemeColors.textPrimary(context))),
      ),
      body: SafeArea(child: onayAdimi ? _buildOnay() : _buildKonusma()),
    );
  }

  Widget _buildHata() => _hata == null
      ? const SizedBox.shrink()
      : Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
          ),
          child: Text(_hata!, style: TextStyle(color: ThemeColors.textPrimary(context))),
        );

  Widget _buildKonusma() {
    final ikincil = TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13, height: 1.4);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Bugün hangi şantiyede ne olduğunu anlat. Örnek:\n'
          '"Gera makinada 5 kalıpçı 2 demirci vardı, bodrum perde kalıbı yapıldı, 40 küp beton döküldü. '
          'KA Otomotivde 3 kalıpçı döşeme söküyor."',
          style: ikincil,
        ),
        const SizedBox(height: 14),
        Center(
          child: SizedBox(
            width: 96,
            height: 96,
            child: FilledButton(
              onPressed: _cozuluyor ? null : _dinle,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                backgroundColor: _dinliyor ? Colors.red : Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Icon(_dinliyor ? Icons.stop : Icons.mic, size: 44),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text(_dinliyor ? 'Dinliyorum… bitince durdur' : 'Konuşmak için dokun', style: ikincil)),
        const SizedBox(height: 14),
        TextField(
          controller: _metin,
          minLines: 5,
          maxLines: 12,
          style: TextStyle(color: ThemeColors.textPrimary(context)),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Söylediklerin burada görünür; elle de yazabilir ya da düzeltebilirsin.',
            hintStyle: TextStyle(color: ThemeColors.textTertiary(context)),
            filled: true,
            fillColor: ThemeColors.cardBackground(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        _buildHata(),
        FilledButton.icon(
          onPressed: _cozuluyor || _metin.text.trim().isEmpty ? null : _cozumle,
          icon: _cozuluyor
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_cozuluyor ? 'Çözümleniyor…' : 'Kayıtlara çevir'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        const SizedBox(height: 10),
        Text('Yalnızca bu metin ve şantiye adların yapay zekâya gönderilir. Kaydetmeden önce onay ekranı gelir.',
            style: ikincil.copyWith(fontSize: 12)),
      ],
    );
  }

  Widget _buildOnay() {
    final taslaklar = _taslaklar!;
    final ikincil = TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('Yapay zekâ yanlış anlamış olabilir. Kontrol et, gerekirse düzelt.', style: ikincil),
              const SizedBox(height: 10),
              for (final t in taslaklar) _buildTaslak(t),
              if (_anlasilmayan.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text('Yerleştirilemeyen kısım: $_anlasilmayan',
                      style: ikincil.copyWith(color: ThemeColors.uyari(context))),
                ),
              _buildHata(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _taslaklar = null;
                    _hata = null;
                  }),
                  child: const Text('Geri dön'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: taslaklar.isEmpty ? null : _kaydet,
                  icon: const Icon(Icons.check),
                  label: Text('${taslaklar.length} kaydı kaydet'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaslak(SesliKayitTaslagi t) {
    final metin = TextStyle(color: ThemeColors.textPrimary(context), fontSize: 14);
    final ikincil = TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12);
    final mevcutVar = t.projeId.isNotEmpty && _mevcutSira(t) >= 0;

    InputDecoration kutu(String etiket) => InputDecoration(
          isDense: true,
          labelText: etiket,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        );

    Widget sayi(String etiket, int deger, ValueChanged<int> degisti) => Expanded(
          child: TextFormField(
            key: ValueKey('${identityHashCode(t)}-$etiket'),
            initialValue: deger == 0 ? '' : '$deger',
            style: metin,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: kutu(etiket).copyWith(hintText: '0'),
            onChanged: (v) => degisti(int.tryParse(v) ?? 0),
          ),
        );

    Widget yazi(String etiket, String deger, ValueChanged<String> degisti) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextFormField(
            key: ValueKey('${identityHashCode(t)}-$etiket'),
            initialValue: deger,
            style: metin,
            minLines: 1,
            maxLines: 4,
            decoration: kutu(etiket),
            onChanged: degisti,
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 12),
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(10),
        border: t.projeId.isEmpty ? Border.all(color: Colors.red.withValues(alpha: 0.6)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: t.projeId.isEmpty ? null : t.projeId,
                    isExpanded: true,
                    hint: Text(
                      t.soylenenAd.isEmpty ? 'Şantiye seç' : 'Şantiye seç ("${t.soylenenAd}" bulunamadı)',
                      style: const TextStyle(color: Colors.redAccent),
                      overflow: TextOverflow.ellipsis,
                    ),
                    dropdownColor: ThemeColors.cardBackground(context),
                    style: Theme.of(context).textTheme.bodyMedium?.merge(metin.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                    items: [
                      for (final p in widget.projeler)
                        DropdownMenuItem(value: p.id, child: Text(p.ad, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() {
                      t.projeId = v ?? '';
                      _hata = null;
                    }),
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final secilen = await showDatePicker(
                    context: context,
                    initialDate: t.tarih,
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now(),
                  );
                  if (secilen != null && mounted) setState(() => t.tarih = secilen);
                },
                child: Text(_tarihBicimi.format(t.tarih)),
              ),
              IconButton(
                tooltip: 'Bu kaydı kaldır',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 20, color: ThemeColors.icon(context)),
                onPressed: () => setState(() => _taslaklar!.remove(t)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mevcutVar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Bu güne kayıt var: sayılar güncellenir, yazılar mevcut kaydın sonuna eklenir.',
                        style: ikincil.copyWith(color: ThemeColors.uyari(context))),
                  ),
                Row(
                  children: [
                    sayi('Kalıpçı', t.kalipci, (v) => t.kalipci = v),
                    const SizedBox(width: 8),
                    sayi('Demirci', t.demirci, (v) => t.demirci = v),
                    const SizedBox(width: 8),
                    sayi('Diğer', t.diger, (v) => t.diger = v),
                  ],
                ),
                yazi('Kalıpçı işi', t.kalipciIs, (v) => t.kalipciIs = v),
                yazi('Demirci işi', t.demirciIs, (v) => t.demirciIs = v),
                yazi('Beton', t.beton, (v) => t.beton = v),
                yazi('Not', t.notlar, (v) => t.notlar = v),
                for (final v in List<VincBilgisi>.from(t.vincler))
                  _buildEkSatir(
                    'Vinç: ${[
                      if (v.firmaAdi.isNotEmpty) v.firmaAdi,
                      if (v.baslangic.isNotEmpty || v.bitis.isNotEmpty) '${v.baslangic}–${v.bitis}',
                      if (v.mola > 0) 'mola ${v.mola} dk',
                      if (v.aciklama.isNotEmpty) v.aciklama,
                    ].join(' · ')}',
                    () => setState(() => t.vincler.remove(v)),
                  ),
                for (final y in List<YevmiyeBilgisi>.from(t.yevmiyeler))
                  _buildEkSatir(
                    'Yevmiye: ${[
                      if (y.ekipAdi.isNotEmpty) y.ekipAdi,
                      NumberFormat('0.##', 'tr_TR').format(y.miktar),
                      if (y.aciklama.isNotEmpty) y.aciklama,
                    ].join(' · ')}',
                    () => setState(() => t.yevmiyeler.remove(y)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEkSatir(String yazi, VoidCallback kaldir) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Expanded(child: Text(yazi, style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 13))),
            InkWell(
              onTap: kaldir,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: ThemeColors.icon(context)),
              ),
            ),
          ],
        ),
      );
}
