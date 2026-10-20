import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/gunluk_kayit.dart';
import '../models/proje.dart';
import '../services/ai_kayit_service.dart';
import '../services/app_log.dart';
import '../services/cihaz_sesi.dart';
import '../services/gorusme_motoru.dart';
import '../services/hava_servisi.dart';
import '../services/taslak_kaydi.dart';
import '../theme/theme_colors.dart';
import 'sesli_kayit_sayfa.dart';

/// Eller serbest kayıt: uygulama soruları sesli sorar, kullanıcı sesle
/// cevaplar; sonunda özet okunur ve "evet" denince kaydedilir. Ekran
/// görüşme boyunca açık kalır. Sonuç olarak kayıt özetini döndürür.
class SesliGorusmeSayfa extends StatefulWidget {
  /// Devam eden şantiyeler.
  final List<Proje> projeler;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;
  final void Function(String projeId, GunlukKayit kayit) onKayitEkle;
  final void Function(String projeId, int index, GunlukKayit kayit) onKayitGuncelle;

  /// Testlerde sahte ses/servis vermek için.
  final SesArayuzu? ses;
  final AiKayitService? servis;
  final HavaServisi? havaServisi;

  const SesliGorusmeSayfa({
    super.key,
    required this.projeler,
    required this.projeGunlukKayitlari,
    required this.onKayitEkle,
    required this.onKayitGuncelle,
    this.ses,
    this.servis,
    this.havaServisi,
  });

  static const String _acilisAyari = 'gorusme_acilista';

  /// "Uygulama açılınca sesli görüşmeyi başlat" ayarı (yalnızca bu cihazda).
  static Future<bool> acilistaBaslasinMi() async =>
      (await SharedPreferences.getInstance()).getBool(_acilisAyari) ?? false;

  static Future<void> acilistaBaslat(bool deger) async =>
      (await SharedPreferences.getInstance()).setBool(_acilisAyari, deger);

  @override
  State<SesliGorusmeSayfa> createState() => _SesliGorusmeSayfaState();
}

class _SesliGorusmeSayfaState extends State<SesliGorusmeSayfa> {
  late final SesArayuzu _ses = widget.ses ?? CihazSesi();
  late final AiKayitService _servis = widget.servis ?? AiKayitService();
  late final GorusmeMotoru _motor = GorusmeMotoru(
    ses: _ses,
    projeler: widget.projeler,
    projeGunlukKayitlari: widget.projeGunlukKayitlari,
    cozumle: (dokum) => _servis.cozumle(dokum, widget.projeler, DateTime.now(), gorusme: true),
    kaydet: (taslaklar) => taslaklariKaydet(
      taslaklar: taslaklar,
      projeGunlukKayitlari: widget.projeGunlukKayitlari,
      onKayitEkle: widget.onKayitEkle,
      onKayitGuncelle: widget.onKayitGuncelle,
      havaServisi: widget.havaServisi,
    ),
  );

  final _yazi = TextEditingController();
  bool _calisiyor = false;
  bool _tabloyaGidiliyor = false;
  GorusmeSonucu? _sonuc;

  @override
  void initState() {
    super.initState();
    _ekraniAcikTut(true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _baslat());
  }

  @override
  void dispose() {
    _motor.iptalEt();
    _ekraniAcikTut(false);
    _yazi.dispose();
    super.dispose();
  }

  Future<void> _ekraniAcikTut(bool acik) async {
    try {
      await WakelockPlus.toggle(enable: acik);
    } catch (e) {
      appLog('Ekran açık tutulamadı: $e');
    }
  }

  String? get _uyari {
    final ses = _ses;
    if (_motor.hata != null) return _motor.hata;
    if (ses is CihazSesi) {
      if (ses.sesTanimaHatasi != null) return '${ses.sesTanimaHatasi} Cevapları aşağıya yazabilirsin.';
      if (!ses.turkceSesVar) {
        return Platform.isAndroid
            ? 'Telefonda Türkçe okuma sesi yok; sorular yalnızca ekranda görünür. '
                'Ayarlar > Sistem > Diller > Metin okuma bölümünden Google Türkçe sesini indirebilirsin.'
            : 'Bu cihazda sesli okuma yok; sorular ekranda görünür. Cevapları söyleyebilir ya da yazabilirsin.';
      }
    }
    return null;
  }

  Future<void> _baslat() async {
    if (_calisiyor || !mounted) return;
    setState(() {
      _calisiyor = true;
      _sonuc = null;
    });
    final ses = _ses;
    if (ses is CihazSesi) {
      await ses.hazirla();
      if (mounted) setState(() {});
    }
    GorusmeSonucu sonuc;
    try {
      sonuc = await _motor.calistir();
    } catch (e) {
      _motor.hata = 'Beklenmeyen hata: $e';
      sonuc = GorusmeSonucu.durduruldu;
    }
    if (!mounted || _tabloyaGidiliyor) return;
    setState(() {
      _calisiyor = false;
      _sonuc = sonuc;
    });
    switch (sonuc) {
      case GorusmeSonucu.tamamlandi:
      case GorusmeSonucu.iptal:
        Navigator.pop(context, _ozet());
      case GorusmeSonucu.tabloyaGecildi:
        await _tabloyaGec();
      case GorusmeSonucu.durduruldu:
        break; // ekranda "Devam et" düğmesi
    }
  }

  String? _ozet([String? ek]) {
    final parcalar = [..._motor.kaydedilenler, if (ek != null && ek.isNotEmpty) ek];
    return parcalar.isEmpty ? null : parcalar.join(', ');
  }

  /// Tabloyu (sesle kayıt onay ekranı) açar; görüşme biter.
  Future<void> _tabloyaGec() async {
    if (_tabloyaGidiliyor) return;
    _tabloyaGidiliyor = true;
    _motor.iptalEt();
    final ozet = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SesliKayitSayfa(
          projeler: widget.projeler,
          projeGunlukKayitlari: widget.projeGunlukKayitlari,
          onKayitEkle: widget.onKayitEkle,
          onKayitGuncelle: widget.onKayitGuncelle,
          servis: widget.servis,
          havaServisi: widget.havaServisi,
          baslangicTaslaklari: _motor.tabloTaslaklari,
          baslangicAnlasilmayan: _motor.anlasilmayan,
        ),
      ),
    );
    if (mounted) Navigator.pop(context, _ozet(ozet));
  }

  void _yaziyiGonder() {
    final metin = _yazi.text.trim();
    if (metin.isEmpty) return;
    _ses.yaziylaCevapla(metin);
    _yazi.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: ThemeColors.headerBackground(context),
        iconTheme: IconThemeData(color: ThemeColors.icon(context)),
        title: Text('Sesli görüşme', style: TextStyle(color: ThemeColors.textPrimary(context))),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<GorusmeDurumu>(
          valueListenable: _motor.durum,
          builder: (context, d, _) {
            final uyari = _uyari;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (uyari != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ThemeColors.uyari(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(uyari, style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 13)),
                    ),
                  // Klavye açılınca orta kısım küçülür ve kayar; alt kısım taşmaz.
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: _durumSimgesi(d.asama)),
                            const SizedBox(height: 10),
                            Text(_asamaYazisi(d.asama),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13)),
                            const SizedBox(height: 18),
                            Text(
                              d.soru,
                              key: const Key('gorusme_soru'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: ThemeColors.textPrimary(context), fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 14),
                            if (d.cevap.isNotEmpty)
                              Text('“${d.cevap}”',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: ThemeColors.textSecondary(context),
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text('İstediğin an: "tekrarla", "geri", "iptal"',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12)),
                  const SizedBox(height: 8),
                  if (_sonuc == GorusmeSonucu.durduruldu) ...[
                    FilledButton.icon(
                      onPressed: _baslat,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Devam et'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _yazi,
                          textInputAction: TextInputAction.send,
                          // Gönderince klavye kapanmasın; sıradaki cevap da yazılabilsin.
                          onEditingComplete: _yaziyiGonder,
                          style: TextStyle(color: ThemeColors.textPrimary(context)),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Yazarak cevapla',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Gönder',
                        onPressed: _yaziyiGonder,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _tabloyaGec,
                    icon: const Icon(Icons.table_rows_outlined),
                    label: const Text('Tabloya geç'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _asamaYazisi(GorusmeAsamasi a) => switch (a) {
        GorusmeAsamasi.konusuyor => 'Soruyor…',
        GorusmeAsamasi.dinliyor => 'Dinliyorum, konuşabilirsin',
        GorusmeAsamasi.isleniyor => 'Hazırlanıyor…',
        GorusmeAsamasi.bitti => _sonuc == GorusmeSonucu.durduruldu ? 'Durduruldu' : '',
        GorusmeAsamasi.hazir => 'Başlıyor…',
      };

  Widget _durumSimgesi(GorusmeAsamasi a) {
    if (a == GorusmeAsamasi.isleniyor) {
      return const SizedBox(width: 96, height: 96, child: CircularProgressIndicator(strokeWidth: 5));
    }
    final (simge, renk) = switch (a) {
      GorusmeAsamasi.dinliyor => (Icons.mic, Colors.redAccent),
      GorusmeAsamasi.konusuyor => (Icons.volume_up, Colors.orange),
      _ => (Icons.pause, Colors.grey),
    };
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(shape: BoxShape.circle, color: renk.withValues(alpha: 0.15)),
      child: Icon(simge, size: 52, color: renk),
    );
  }
}
