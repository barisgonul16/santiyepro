import 'package:flutter/foundation.dart';

import '../models/gunluk_kayit.dart';
import '../models/proje.dart';
import 'ai_kayit_service.dart';

/// Konuşma ve dinleme. Gerçek cihazda telefonun sesi ve ses tanıması,
/// testlerde sahte bir uygulama kullanılır.
abstract class SesArayuzu {
  /// [metin]'i sesli okur; okuma bitince (ya da [durdur] çağrılınca) tamamlanır.
  Future<void> konus(String metin);

  /// Bir cevap dinler. Hiçbir şey duyulmazsa null döner.
  Future<String?> dinle();

  /// Konuşmayı ve dinlemeyi hemen keser; bekleyen [konus]/[dinle] biter.
  Future<void> durdur();

  /// Ekrandan yazılan cevap: süren dinlemeyi bu metinle bitirir.
  void yaziylaCevapla(String metin) {}
}

/// Görüşmede söylenen kısa cevapların anlamı. Sadeleştirilmiş (küçük harf,
/// Türkçe harfler ASCII'ye çevrilmiş) metin üzerinde çalışır; böylece "Hayır",
/// "hayir", "HAYIR." aynı sayılır.
class GorusmeDili {
  static const Map<String, String> _harf = {
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', 'â': 'a', 'î': 'i', 'û': 'u',
  };

  static String sade(String metin) {
    final kucuk = metin.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
    final b = StringBuffer();
    for (final r in kucuk.runes) {
      final h = String.fromCharCode(r);
      b.write(_harf[h] ?? h);
    }
    return b.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> kelimeler(String metin) => sade(metin).split(' ').where((k) => k.isNotEmpty).toList();

  static bool _rakamVar(String metin) => RegExp(r'\d').hasMatch(metin);

  static const _olumsuzlar = {'yok', 'yoktu', 'hayir', 'hic', 'hicbiri', 'hicbir', 'olmadi', 'degil', 'yook'};
  static const _olumlular = {'var', 'vardi', 'evet', 'oldu', 'tabi', 'tabii', 'he', 'hee', 'olur', 'aynen'};
  static const _dolgu = {
    'abi', 'ya', 'yani', 'bir', 'sey', 'su', 'an', 'simdilik', 'bugun', 'baska', 'tamam', 'kimse', 'calisan',
    'diger', 'beton', 'vinc', 'yevmiye', 'not', 'de', 'da', 'o', 'bu', 'ne', 'yemek', 'onlar', 'onda', 'pek',
    'gerek', 'yokki', 'efendim', 'hocam', 'usta',
  };

  /// "yok", "hayır, başka kimse yoktu" gibi yalnızca olumsuz cevap mı?
  static bool olumsuz(String metin) {
    if (_rakamVar(metin)) return false;
    final k = kelimeler(metin);
    if (k.isEmpty || k.length > 6) return false;
    return k.any(_olumsuzlar.contains) && k.every((w) => _olumsuzlar.contains(w) || _dolgu.contains(w));
  }

  /// "var", "evet var" gibi ayrıntısız olumlu cevap mı?
  static bool sadeceOlumlu(String metin) {
    if (_rakamVar(metin)) return false;
    final k = kelimeler(metin);
    if (k.isEmpty || k.length > 4) return false;
    return k.any(_olumlular.contains) && k.every((w) => _olumlular.contains(w) || _dolgu.contains(w));
  }

  static const _onaylar = {
    'evet', 'tamam', 'kaydet', 'kaydedebilirsin', 'kaydedin', 'olur', 'onayla', 'onayliyorum', 'dogru', 'aynen',
    'he', 'hee', 'tabi', 'tabii', 'ok', 'okey', 'peki',
  };
  static const _retler = {'hayir', 'yanlis', 'duzelt', 'degistir', 'olmaz', 'yok', 'bekle', 'dur', 'degil'};

  /// "Kaydedeyim mi?" sorusunun cevabı: true evet, false hayır, null anlaşılmadı.
  static bool? onay(String metin) {
    final k = kelimeler(metin);
    if (k.isEmpty) return null;
    if (k.any(_retler.contains)) return false;
    if (k.length <= 4 && k.any(_onaylar.contains)) return true;
    return null;
  }

  /// Kısa komutlar. Uzun cümlelerde (içerik) komut aranmaz.
  static GorusmeKomutu? komut(String metin) {
    final k = kelimeler(metin);
    if (k.isEmpty || k.length > 3) return null;
    final s = k.join(' ');
    if (s.startsWith('tekrar') || s == 'bir daha' || s == 'anlamadim' || s == 'ne dedin') return GorusmeKomutu.tekrarla;
    if (s == 'geri' || s.startsWith('geri ') || s == 'onceki' || s == 'onceki soru') return GorusmeKomutu.geri;
    if (s.startsWith('iptal') || s.startsWith('vazgec') || s == 'kapat' || s == 'gorusmeyi bitir') {
      return GorusmeKomutu.iptal;
    }
    return null;
  }

  /// "Yemek 20 kişi; hangi ekip?" sorusunun cevabı.
  static YemekSecimi? yemekSecimi(String metin) {
    final s = sade(metin);
    final secenekler = <YemekSecimi>{
      if (s.contains('kalip')) YemekSecimi.kalipci,
      if (s.contains('demir')) YemekSecimi.demirci,
      if (s.contains('diger') || s.contains('isci') || s.contains('amele')) YemekSecimi.diger,
      if (s.contains('dagit') || s.contains('paylas') || s.contains('bol')) YemekSecimi.dagit,
    };
    return secenekler.length == 1 ? secenekler.first : null;
  }

  /// Söylenen addan şantiyeyi bulur ("gerada" → "Gera makina"). Birden çok
  /// şantiye eşit derecede uyuyorsa ya da hiçbiri uymuyorsa null döner.
  static Proje? santiyeBul(String metin, List<Proje> projeler) {
    final soylenen = kelimeler(metin).where((k) => k.length >= 3).toList();
    Proje? enIyi;
    var enIyiPuan = 0;
    var esit = false;
    for (final p in projeler) {
      final adlar = kelimeler(p.ad).where((k) => k.length >= 3).toList();
      final puan = adlar.where((a) => soylenen.any((s) => s.startsWith(a) || (s.length >= 4 && a.startsWith(s)))).length;
      if (puan > enIyiPuan) {
        enIyi = p;
        enIyiPuan = puan;
        esit = false;
      } else if (puan == enIyiPuan && puan > 0) {
        esit = true;
      }
    }
    return enIyiPuan > 0 && !esit ? enIyi : null;
  }
}

enum GorusmeKomutu { tekrarla, geri, iptal }

enum YemekSecimi { kalipci, demirci, diger, dagit }

enum GorusmeAsamasi { hazir, konusuyor, dinliyor, isleniyor, bitti }

/// Ekranda gösterilenler: o anki aşama, son soru ve son duyulan cevap.
@immutable
class GorusmeDurumu {
  final GorusmeAsamasi asama;
  final String soru;
  final String cevap;
  const GorusmeDurumu({this.asama = GorusmeAsamasi.hazir, this.soru = '', this.cevap = ''});
}

enum GorusmeSonucu {
  /// Kayıtlar kaydedildi, görüşme bitti.
  tamamlandi,

  /// Kullanıcı "hayır/düzelt" dedi: [GorusmeMotoru.tabloTaslaklari] tabloda düzeltilecek.
  tabloyaGecildi,
  iptal,

  /// Cevap duyulamadı ya da yapay zekâya ulaşılamadı; [GorusmeMotoru.calistir]
  /// yeniden çağrılırsa kalınan sorudan devam edilir.
  durduruldu,
}

sealed class _Cevap {
  const _Cevap();
}

class _Metin extends _Cevap {
  final String metin;
  const _Metin(this.metin);
}

class _Komut extends _Cevap {
  final GorusmeKomutu komut;
  const _Komut(this.komut);
}

class _Sessiz extends _Cevap {
  const _Sessiz();
}

class _Adim {
  final String id;

  /// Yapay zekâya giden dökümde satırın başlığı.
  final String konu;

  /// "yok" denebilen, "var" denirse ayrıntısı sorulan soru.
  final bool varYok;
  final String Function(Map<String, String> cevaplar) soru;
  const _Adim(this.id, this.konu, this.soru, {this.varYok = false});
}

/// Eller serbest kayıt görüşmesi: sorular sabit sırayla sorulur (her cevapta
/// beklemek yok), cevaplar en sonda tek seferde yapay zekâyla kayıtlara
/// çevrilir, özet okunur ve "evet" denince kaydedilir.
class GorusmeMotoru {
  final SesArayuzu ses;

  /// Devam eden şantiyeler.
  final List<Proje> projeler;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;
  final Future<(List<SesliKayitTaslagi>, String)> Function(String dokum) cozumle;

  /// Onaylanan taslakları kaydeder; "1 yeni kayıt" gibi bir özet döner.
  final Future<String> Function(List<SesliKayitTaslagi> taslaklar) kaydet;
  final DateTime Function() simdi;

  GorusmeMotoru({
    required this.ses,
    required this.projeler,
    required this.projeGunlukKayitlari,
    required this.cozumle,
    required this.kaydet,
    DateTime Function()? simdi,
  }) : simdi = simdi ?? DateTime.now;

  final ValueNotifier<GorusmeDurumu> durum = ValueNotifier(const GorusmeDurumu());

  /// "Hayır/düzelt" denince tabloda düzeltilmek üzere bırakılan taslaklar.
  List<SesliKayitTaslagi> tabloTaslaklari = [];
  String anlasilmayan = '';

  /// Kaydedilen her turun özeti ("1 yeni kayıt").
  final List<String> kaydedilenler = [];

  /// Görüşmeyi durduran hata (yapay zekâya ulaşılamadı gibi); ekranda gösterilir.
  String? hata;

  bool _iptal = false;

  // Yarıda kalan turun durumu (durdurulunca kalınan yerden devam etmek için).
  Map<String, String> _cevaplar = {};
  int _adim = 0;

  static const String _notAldim = 'Tamam. ';

  void iptalEt() {
    _iptal = true;
    ses.durdur();
  }

  void _yaz(GorusmeAsamasi asama, {String? soru, String? cevap}) {
    durum.value = GorusmeDurumu(
      asama: asama,
      soru: soru ?? durum.value.soru,
      cevap: cevap ?? (soru != null ? '' : durum.value.cevap),
    );
  }

  Future<void> _soyle(String metin) async {
    if (_iptal) return;
    _yaz(GorusmeAsamasi.konusuyor, soru: metin);
    await ses.konus(metin);
  }

  Proje? get _tekProje => projeler.length == 1 ? projeler.first : null;

  Proje? _proje(String id) {
    for (final p in projeler) {
      if (p.id == id) return p;
    }
    return null;
  }

  late final List<_Adim> _adimlar = [
    _Adim(
      'sayilar',
      _tekProje == null ? 'Şantiye ve çalışan sayıları' : 'Şantiye (${_tekProje!.ad}) ve çalışan sayıları',
      (_) => _tekProje == null ? 'Hangi şantiye? Kaç kalıpçı, kaç demirci?' : '${_tekProje!.ad}: kaç kalıpçı, kaç demirci?',
    ),
    _Adim('isler', 'Yapılan işler', (_) => 'Ne iş yaptılar?'),
    _Adim('ek', 'Diğer çalışanlar, beton, vinç, yevmiye ve notlar',
        (_) => 'Başka çalışan, beton, vinç, yevmiye ya da not var mı?',
        varYok: true),
    _Adim('yemek', 'Yemek sayıları', _yemekSorusu, varYok: true),
  ];

  String _yemekSorusu(Map<String, String> cevaplar) {
    final p = _tekProje ?? GorusmeDili.santiyeBul(cevaplar['sayilar'] ?? '', projeler);
    final kahvalti = p?.kahvaltiVar ?? false;
    final aksam = p?.aksamVar ?? false;
    if (!kahvalti && !aksam) return 'Yemek kaç kişi, ekip ekip?';
    final ogunler = [if (kahvalti) 'Kahvaltı', 'öğle', if (aksam) 'akşam'];
    final liste = ogunler.length == 2 ? '${ogunler[0]} ve ${ogunler[1]}' : '${ogunler[0]}, ${ogunler[1]} ve ${ogunler[2]}';
    return '$liste yemeği kaç kişi, ekip ekip?';
  }

  /// Soruyu okur ve cevabı dinler. "Tekrarla" denince soruyu yeniden okur;
  /// üç kez üst üste bir şey duyulmazsa [_Sessiz] döner.
  Future<_Cevap> _sor(String soru, {String onSoz = ''}) async {
    var soylenecek = '$onSoz$soru';
    var bos = 0;
    while (bos < 3) {
      if (_iptal) return const _Komut(GorusmeKomutu.iptal);
      _yaz(GorusmeAsamasi.konusuyor, soru: soru);
      await ses.konus(soylenecek);
      if (_iptal) return const _Komut(GorusmeKomutu.iptal);
      _yaz(GorusmeAsamasi.dinliyor);
      final duyulan = (await ses.dinle())?.trim() ?? '';
      if (_iptal) return const _Komut(GorusmeKomutu.iptal);
      if (duyulan.isEmpty) {
        bos++;
        soylenecek = 'Duyamadım. $soru';
        continue;
      }
      _yaz(GorusmeAsamasi.dinliyor, cevap: duyulan);
      final komut = GorusmeDili.komut(duyulan);
      if (komut == GorusmeKomutu.tekrarla) {
        soylenecek = soru;
        continue;
      }
      if (komut != null) return _Komut(komut);
      return _Metin(duyulan);
    }
    return const _Sessiz();
  }

  Future<GorusmeSonucu> _durdur() async {
    await _soyle('Seni duyamıyorum, görüşmeyi durduruyorum. Devam etmek için ekrandaki düğmeye bas.');
    _yaz(GorusmeAsamasi.bitti);
    return GorusmeSonucu.durduruldu;
  }

  Future<GorusmeSonucu> _iptalSonucu() async {
    if (!_iptal) await ses.konus('İptal ettim.');
    _yaz(GorusmeAsamasi.bitti);
    return GorusmeSonucu.iptal;
  }

  /// Görüşmeyi yürütür. Durdurulmuş bir görüşmede yeniden çağrılırsa kalınan
  /// sorudan devam eder.
  Future<GorusmeSonucu> calistir() async {
    _iptal = false;
    hata = null;
    // Açılışta konuşma yok, doğrudan ilk soru (komutlar ekranda yazılı).
    String? ilkCevap;
    while (true) {
      final sonuc = await _tur(ilkCevap: ilkCevap);
      if (sonuc != null) return sonuc;

      // Tur kaydedildi.
      final c = await _sor('Başka şantiye var mı?', onSoz: 'Kaydettim. ');
      switch (c) {
        case _Sessiz():
        case _Komut():
          await _soyle('Tamam, iyi çalışmalar.');
          _yaz(GorusmeAsamasi.bitti);
          return GorusmeSonucu.tamamlandi;
        case _Metin(:final metin):
          if (GorusmeDili.olumsuz(metin) || GorusmeDili.onay(metin) == false) {
            await _soyle('Tamam, iyi çalışmalar.');
            _yaz(GorusmeAsamasi.bitti);
            return GorusmeSonucu.tamamlandi;
          }
          // "Evet" ise baştan; "KA Otomotivde 3 kalıpçı vardı" gibi bir cevapsa
          // o, yeni turun ilk cevabıdır.
          ilkCevap = GorusmeDili.sadeceOlumlu(metin) || GorusmeDili.onay(metin) == true ? null : metin;
      }
    }
  }

  /// Bir şantiye için soruları sorar, kayıtları hazırlar ve onaylatır.
  /// Kaydedildiyse null, görüşme bittiyse sonucu döner.
  Future<GorusmeSonucu?> _tur({String? ilkCevap}) async {
    var onSoz = '';
    if (ilkCevap != null) {
      _cevaplar = {'sayilar': ilkCevap};
      _adim = 1;
      onSoz = _notAldim;
    }
    while (_adim < _adimlar.length) {
      final adim = _adimlar[_adim];
      var c = await _sor(adim.soru(_cevaplar), onSoz: onSoz);
      onSoz = '';
      // "Var" dendiyse ayrıntısı sorulur.
      if (c is _Metin && adim.varYok && GorusmeDili.sadeceOlumlu(c.metin)) {
        c = await _sor('Anlat.');
      }
      switch (c) {
        case _Sessiz():
          return _durdur();
        case _Komut(komut: GorusmeKomutu.iptal):
          return _iptalSonucu();
        case _Komut(komut: GorusmeKomutu.geri):
          if (_adim > 0) _adim--;
        case _Komut():
          break;
        case _Metin(:final metin):
          _cevaplar[adim.id] = adim.varYok && GorusmeDili.olumsuz(metin) ? 'yok' : metin;
          _adim++;
          onSoz = _notAldim;
      }
    }

    // Yapay zekâ cevapları sütunlara dağıtır.
    // Yapay zekâ ~1 sn sürüyor; beklerken konuşmaya gerek yok.
    if (_iptal) return _iptalSonucu();
    _yaz(GorusmeAsamasi.isleniyor, soru: 'Kayıtlar hazırlanıyor…');
    final dokum = [
      for (final a in _adimlar)
        if (_cevaplar[a.id] != null) '${a.konu}: ${_cevaplar[a.id]}',
    ].join('\n');
    List<SesliKayitTaslagi> taslaklar;
    try {
      final (t, a) = await cozumle(dokum);
      taslaklar = t;
      anlasilmayan = a;
    } on AiKayitHatasi catch (e) {
      hata = e.mesaj;
      await _soyle('${e.mesaj} Görüşmeyi durduruyorum.');
      _yaz(GorusmeAsamasi.bitti);
      return GorusmeSonucu.durduruldu;
    } catch (e) {
      hata = 'Beklenmeyen hata: $e';
      await _soyle('Bir hata oldu, görüşmeyi durduruyorum.');
      _yaz(GorusmeAsamasi.bitti);
      return GorusmeSonucu.durduruldu;
    }
    if (_iptal) return _iptalSonucu();
    _cevaplar = {};
    _adim = 0;

    if (taslaklar.isEmpty) {
      final c = await _sor('Söylediklerinden kayıt çıkaramadım. Baştan alalım mı?');
      if (c is _Metin && (GorusmeDili.onay(c.metin) == true || GorusmeDili.sadeceOlumlu(c.metin))) {
        return _tur();
      }
      return c is _Sessiz ? _durdur() : _iptalSonucu();
    }

    // Eksikler sesle tamamlanır: şantiye ve ekibi söylenmeyen yemek.
    for (final t in taslaklar) {
      if (t.projeId.isEmpty) {
        final sonuc = await _santiyeSor(t, taslaklar);
        if (sonuc != null) return sonuc;
      }
      for (final o in t.ekipBekleyenOgunler) {
        final sonuc = await _yemekEkibiSor(t, o, taslaklar);
        if (sonuc != null) return sonuc;
      }
    }

    // Özet ve onay.
    final ozet = taslaklar.map(_ozet).join(' ');
    var soru = '$ozet Kaydedeyim mi?';
    for (var deneme = 0; deneme < 2; deneme++) {
      final c = await _sor(soru);
      switch (c) {
        case _Sessiz():
          tabloTaslaklari = taslaklar;
          return _durdur();
        case _Komut(komut: GorusmeKomutu.iptal):
          return _iptalSonucu();
        case _Komut():
          break;
        case _Metin(:final metin):
          final onay = GorusmeDili.onay(metin);
          if (onay == true) {
            _yaz(GorusmeAsamasi.isleniyor, soru: 'Kaydediliyor…');
            kaydedilenler.add(await kaydet(taslaklar));
            return null;
          }
          if (onay == false) return _tabloyaGec(taslaklar);
      }
      soru = 'Kaydedeyim mi? Evet ya da hayır de.';
    }
    return _tabloyaGec(taslaklar);
  }

  Future<GorusmeSonucu> _tabloyaGec(List<SesliKayitTaslagi> taslaklar) async {
    tabloTaslaklari = taslaklar;
    await _soyle('Tamam, tabloyu açıyorum. Oradan düzeltip kaydedebilirsin.');
    _yaz(GorusmeAsamasi.bitti);
    return GorusmeSonucu.tabloyaGecildi;
  }

  Future<GorusmeSonucu?> _santiyeSor(SesliKayitTaslagi t, List<SesliKayitTaslagi> taslaklar) async {
    final adlar = projeler.length <= 4 ? ' ${projeler.map((p) => p.ad).join(', ')}.' : '';
    var soru = t.soylenenAd.isEmpty
        ? 'Hangi şantiye?$adlar'
        : '"${t.soylenenAd}" şantiyesini bulamadım. Hangi şantiye?$adlar';
    for (var deneme = 0; deneme < 2; deneme++) {
      final c = await _sor(soru);
      if (c is _Sessiz) {
        tabloTaslaklari = taslaklar;
        return _durdur();
      }
      if (c is _Komut && c.komut == GorusmeKomutu.iptal) return _iptalSonucu();
      if (c is _Metin) {
        final p = GorusmeDili.santiyeBul(c.metin, projeler);
        if (p != null) {
          t.projeId = p.id;
          return null;
        }
      }
      soru = 'Anlayamadım. Hangi şantiye?$adlar';
    }
    return _tabloyaGec(taslaklar);
  }

  /// Yemeği ekip ayırmadan söylendiyse hangi ekibe ait olduğunu sorar.
  Future<GorusmeSonucu?> _yemekEkibiSor(
      SesliKayitTaslagi t, YemekOgunu o, List<SesliKayitTaslagi> taslaklar) async {
    final ad = switch (o) {
      YemekOgunu.kahvalti => 'Kahvaltı',
      YemekOgunu.ogle => 'Öğle yemeği',
      YemekOgunu.aksam => 'Akşam yemeği',
    };
    var soru = '$ad ${t.ogunToplami(o)} kişi dedin. Kalıpçı mı, demirci mi, diğer mi? Ya da dağıt de.';
    for (var deneme = 0; deneme < 2; deneme++) {
      final c = await _sor(soru);
      if (c is _Sessiz) {
        tabloTaslaklari = taslaklar;
        return _durdur();
      }
      if (c is _Komut && c.komut == GorusmeKomutu.iptal) return _iptalSonucu();
      final secim = c is _Metin ? GorusmeDili.yemekSecimi(c.metin) : null;
      switch (secim) {
        case YemekSecimi.kalipci:
          t.ogunuEkibeYaz(o, YemekEkibi.kalipci);
          return null;
        case YemekSecimi.demirci:
          t.ogunuEkibeYaz(o, YemekEkibi.demirci);
          return null;
        case YemekSecimi.diger:
          t.ogunuEkibeYaz(o, YemekEkibi.diger);
          return null;
        case YemekSecimi.dagit:
          final c = _calisanlar(t);
          t.ogunuDagit(o, kalipci: c.$1, demirci: c.$2, diger: c.$3);
          return null;
        case null:
          soru = 'Anlayamadım. Kalıpçı mı, demirci mi, diğer mi?';
      }
    }
    return _tabloyaGec(taslaklar);
  }

  /// Taslaktaki, yoksa o günün kayıtlı çalışan sayıları.
  (int, int, int) _calisanlar(SesliKayitTaslagi t) {
    GunlukKayit? mevcut;
    for (final k in projeGunlukKayitlari[t.projeId] ?? const <GunlukKayit>[]) {
      if (k.tarih.year == t.tarih.year && k.tarih.month == t.tarih.month && k.tarih.day == t.tarih.day) mevcut = k;
    }
    return (
      t.kalipci > 0 ? t.kalipci : (mevcut?.kalipci ?? 0),
      t.demirci > 0 ? t.demirci : (mevcut?.demirci ?? 0),
      t.diger > 0 ? t.diger : (mevcut?.diger ?? 0),
    );
  }

  static String _kisalt(String s, [int sinir = 70]) {
    final t = s.trim();
    return t.length <= sinir ? t : '${t.substring(0, sinir)}…';
  }

  /// Sesli okunacak kısa özet.
  String _ozet(SesliKayitTaslagi t) {
    const aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    final s = simdi();
    final bugun = DateTime(s.year, s.month, s.day);
    final gun = DateTime(t.tarih.year, t.tarih.month, t.tarih.day);
    final fark = bugun.difference(gun).inDays;
    final tarih = fark == 0 ? '' : (fark == 1 ? ', dün' : ', ${gun.day} ${aylar[gun.month - 1]}');
    final sayilar = [
      if (t.kalipci > 0) '${t.kalipci} kalıpçı',
      if (t.demirci > 0) '${t.demirci} demirci',
      if (t.diger > 0) '${t.diger} diğer',
    ];
    String ogun(String ad, int k, int d, int g) {
      final toplam = k + d + g;
      if (toplam == 0) return '';
      final ekipler = [if (k > 0) 'kalıpçı $k', if (d > 0) 'demirci $d', if (g > 0) 'diğer $g'];
      return '$ad $toplam kişi${ekipler.length > 1 ? ' (${ekipler.join(', ')})' : ''}.';
    }

    final ekstraOgun = t.kahvaltiKalipci + t.kahvaltiDemirci + t.kahvaltiDiger + t.aksamKalipci + t.aksamDemirci + t.aksamDiger > 0;
    return [
      '${_proje(t.projeId)?.ad ?? t.soylenenAd}$tarih:',
      sayilar.isEmpty ? 'çalışan sayısı yok.' : '${sayilar.join(', ')}.',
      if (t.kalipciIs.trim().isNotEmpty) 'Kalıpçı işi: ${_kisalt(t.kalipciIs)}.',
      if (t.demirciIs.trim().isNotEmpty) 'Demirci işi: ${_kisalt(t.demirciIs)}.',
      if (t.beton.trim().isNotEmpty) 'Beton: ${_kisalt(t.beton)}.',
      if (t.vincler.isNotEmpty) 'Vinç: ${t.vincler.map((v) => v.firmaAdi.isEmpty ? 'var' : v.firmaAdi).join(', ')}.',
      if (t.yevmiyeler.isNotEmpty) 'Yevmiye: ${t.yevmiyeler.length} satır.',
      ogun('Kahvaltı', t.kahvaltiKalipci, t.kahvaltiDemirci, t.kahvaltiDiger),
      ogun(ekstraOgun ? 'Öğle yemeği' : 'Yemek', t.yemekKalipci, t.yemekDemirci, t.yemekDiger),
      ogun('Akşam yemeği', t.aksamKalipci, t.aksamDemirci, t.aksamDiger),
      if (t.notlar.trim().isNotEmpty) 'Not: ${_kisalt(t.notlar)}.',
    ].where((p) => p.isNotEmpty).join(' ');
  }
}
