import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gunluk_kayit.dart';
import '../models/proje.dart';
import 'app_log.dart';

/// Yemek öğünleri. Öğle yemeği, eski kayıtlardaki "yemek" alanlarıdır.
enum YemekOgunu { kahvalti, ogle, aksam }

/// Yemeğin ait olduğu ekip.
enum YemekEkibi { kalipci, demirci, diger }

/// Yapay zekânın bir şantiye için konuşmadan çıkardığı taslak. Kullanıcı
/// onaylamadan hiçbir şey kaydedilmez.
class SesliKayitTaslagi {
  /// Eşleşen projenin kimliği; eşleşmediyse boş.
  String projeId;
  /// Konuşmada geçen şantiye adı (eşleşmediğinde kullanıcıya gösterilir).
  final String soylenenAd;
  DateTime tarih;
  int kalipci;
  int demirci;
  int diger;
  String kalipciIs;
  String demirciIs;
  String beton;
  String notlar;
  /// Yemek yiyen kişi sayısı, ekip ekip.
  int yemekKalipci;
  int yemekDemirci;
  int yemekDiger;
  /// Yemek ekip ayrımı yapılmadan tek sayı olarak söylendiyse o sayı.
  final int yemekToplam;
  /// Kahvaltı ve akşam yemeği için aynıları (yemek* alanları öğle yemeğidir).
  int kahvaltiKalipci;
  int kahvaltiDemirci;
  int kahvaltiDiger;
  final int kahvaltiToplam;
  int aksamKalipci;
  int aksamDemirci;
  int aksamDiger;
  final int aksamToplam;
  /// Çalışan sayısına göre ekiplere paylaştırılan öğünler (kullanıcı düzeltene
  /// kadar onay ekranında uyarı gösterilir).
  final Set<YemekOgunu> _dagitilan = {};
  /// Kullanıcının "yok say" dediği, ekibi seçilmemiş tek sayılar.
  final Set<YemekOgunu> _yoksayilan = {};
  /// Yemek sayıları koddan değişince artar; onay ekranındaki kutuları tazelemek için.
  int yemekSurumu = 0;
  final List<VincBilgisi> vincler;
  final List<YevmiyeBilgisi> yevmiyeler;

  SesliKayitTaslagi({
    required this.projeId,
    required this.soylenenAd,
    required this.tarih,
    this.kalipci = 0,
    this.demirci = 0,
    this.diger = 0,
    this.kalipciIs = '',
    this.demirciIs = '',
    this.beton = '',
    this.notlar = '',
    this.yemekKalipci = 0,
    this.yemekDemirci = 0,
    this.yemekDiger = 0,
    this.yemekToplam = 0,
    this.kahvaltiKalipci = 0,
    this.kahvaltiDemirci = 0,
    this.kahvaltiDiger = 0,
    this.kahvaltiToplam = 0,
    this.aksamKalipci = 0,
    this.aksamDemirci = 0,
    this.aksamDiger = 0,
    this.aksamToplam = 0,
    List<VincBilgisi>? vincler,
    List<YevmiyeBilgisi>? yevmiyeler,
  })  : vincler = vincler ?? [],
        yevmiyeler = yevmiyeler ?? [];

  bool get bos =>
      kalipci == 0 &&
      demirci == 0 &&
      diger == 0 &&
      kalipciIs.trim().isEmpty &&
      demirciIs.trim().isEmpty &&
      beton.trim().isEmpty &&
      notlar.trim().isEmpty &&
      yemekKalipci == 0 &&
      yemekDemirci == 0 &&
      yemekDiger == 0 &&
      yemekToplam == 0 &&
      kahvaltiKalipci == 0 &&
      kahvaltiDemirci == 0 &&
      kahvaltiDiger == 0 &&
      kahvaltiToplam == 0 &&
      aksamKalipci == 0 &&
      aksamDemirci == 0 &&
      aksamDiger == 0 &&
      aksamToplam == 0 &&
      vincler.isEmpty &&
      yevmiyeler.isEmpty;

  /// En büyük kalan yöntemiyle [toplam]'ı [sayilar] oranında paylaştırır; toplam
  /// her zaman korunur. Sayılar sıfırsa tamamı ilk ekibe (kalıpçı) yazılır.
  static List<int> _pay(int toplam, List<int> sayilar) {
    final t = sayilar.fold<int>(0, (a, b) => a + b);
    if (t <= 0) return [toplam, 0, 0];
    final ham = [for (final s in sayilar) toplam * s / t];
    final pay = [for (final h in ham) h.floor()];
    var kalan = toplam - pay.fold<int>(0, (a, b) => a + b);
    final sira = [0, 1, 2]..sort((a, b) => (ham[b] - pay[b]).compareTo(ham[a] - pay[a]));
    for (final i in sira) {
      if (kalan <= 0) break;
      pay[i]++;
      kalan--;
    }
    return pay;
  }

  /// [o] öğünü için ekip ekip yazılmış sayılar: kalıpçı, demirci, diğer.
  List<int> _ekipler(YemekOgunu o) => switch (o) {
        YemekOgunu.kahvalti => [kahvaltiKalipci, kahvaltiDemirci, kahvaltiDiger],
        YemekOgunu.ogle => [yemekKalipci, yemekDemirci, yemekDiger],
        YemekOgunu.aksam => [aksamKalipci, aksamDemirci, aksamDiger],
      };

  void _ekipleriYaz(YemekOgunu o, List<int> p) {
    switch (o) {
      case YemekOgunu.kahvalti:
        kahvaltiKalipci = p[0];
        kahvaltiDemirci = p[1];
        kahvaltiDiger = p[2];
      case YemekOgunu.ogle:
        yemekKalipci = p[0];
        yemekDemirci = p[1];
        yemekDiger = p[2];
      case YemekOgunu.aksam:
        aksamKalipci = p[0];
        aksamDemirci = p[1];
        aksamDiger = p[2];
    }
    yemekSurumu++;
  }

  /// [o] öğünü için ekip söylenmeden tek sayı olarak söylenen değer (yoksa 0).
  int ogunToplami(YemekOgunu o) => switch (o) {
        YemekOgunu.kahvalti => kahvaltiToplam,
        YemekOgunu.ogle => yemekToplam,
        YemekOgunu.aksam => aksamToplam,
      };

  /// Tek sayı olarak söylenmiş ama hangi ekibe ait olduğu henüz seçilmemiş
  /// öğünler. Ekip kendiliğinden tahmin edilmez: onay ekranında kullanıcıya
  /// sorulur ve seçilmeden kayıt yapılmaz.
  List<YemekOgunu> get ekipBekleyenOgunler => [
        for (final o in YemekOgunu.values)
          if (ogunToplami(o) > 0 && _ekipler(o).every((s) => s == 0) && !_yoksayilan.contains(o)) o,
      ];

  /// Tek sayı olarak söylenen öğünün tamamını [ekip]'e yazar.
  void ogunuEkibeYaz(YemekOgunu o, YemekEkibi ekip) {
    final p = [0, 0, 0];
    p[ekip.index] = ogunToplami(o);
    _dagitilan.remove(o);
    _ekipleriYaz(o, p);
  }

  /// Tek sayı olarak söylenen öğünü çalışan sayılarına göre ekiplere
  /// paylaştırır; toplam korunur. Çalışan sayısı yoksa tamamı kalıpçıya yazılır.
  void ogunuDagit(YemekOgunu o, {required int kalipci, required int demirci, required int diger}) {
    _dagitilan.add(o);
    _ekipleriYaz(o, _pay(ogunToplami(o), [kalipci, demirci, diger]));
  }

  /// Ekibi seçilmemiş sayıyı kaydetmekten vazgeçer.
  void ogunuYoksay(YemekOgunu o) {
    _yoksayilan.add(o);
    yemekSurumu++;
  }

  /// Çalışan sayısına göre paylaştırılmış öğünler.
  List<YemekOgunu> get dagitilanOgunler => [
        for (final o in YemekOgunu.values)
          if (_dagitilan.contains(o)) o,
      ];

  /// Kullanıcı bir öğünün sayılarını elle değiştirdi: o öğün için "dağıtıldı"
  /// uyarısı kalkar.
  void ogunuElleDegistirdi(YemekOgunu o) => _dagitilan.remove(o);

  /// Şantiye ya da gün değişince çalışan sayıları da değişir; paylaştırılmış
  /// öğünler yeni sayılara göre yeniden paylaştırılır.
  void dagitilanlariYenile({required int kalipci, required int demirci, required int diger}) {
    for (final o in dagitilanOgunler) {
      ogunuDagit(o, kalipci: kalipci, demirci: demirci, diger: diger);
    }
  }

  /// Taslağı o günün kaydına işler. [mevcut] varsa üzerine eklenir: verilen
  /// sayılar eskisinin yerine geçer, metinler sona eklenir, vinç ve yevmiye
  /// satırları listeye katılır. Fotoğraflar ve yemek sayıları korunur.
  GunlukKayit kayda(GunlukKayit? mevcut) {
    String ekle(String eski, String yeni) {
      final e = eski.trim(), y = yeni.trim();
      if (y.isEmpty) return e;
      if (e.isEmpty || e.toLowerCase().contains(y.toLowerCase())) return e.isEmpty ? y : e;
      return '$e, $y';
    }

    final temel = mevcut ?? GunlukKayit(tarih: DateTime(tarih.year, tarih.month, tarih.day));
    return GunlukKayit(
      tarih: temel.tarih,
      kalipci: kalipci > 0 ? kalipci : temel.kalipci,
      demirci: demirci > 0 ? demirci : temel.demirci,
      diger: diger > 0 ? diger : temel.diger,
      yemekKalipci: yemekKalipci > 0 ? yemekKalipci : temel.yemekKalipci,
      yemekDemirci: yemekDemirci > 0 ? yemekDemirci : temel.yemekDemirci,
      yemekDiger: yemekDiger > 0 ? yemekDiger : temel.yemekDiger,
      kahvaltiKalipci: kahvaltiKalipci > 0 ? kahvaltiKalipci : temel.kahvaltiKalipci,
      kahvaltiDemirci: kahvaltiDemirci > 0 ? kahvaltiDemirci : temel.kahvaltiDemirci,
      kahvaltiDiger: kahvaltiDiger > 0 ? kahvaltiDiger : temel.kahvaltiDiger,
      aksamKalipci: aksamKalipci > 0 ? aksamKalipci : temel.aksamKalipci,
      aksamDemirci: aksamDemirci > 0 ? aksamDemirci : temel.aksamDemirci,
      aksamDiger: aksamDiger > 0 ? aksamDiger : temel.aksamDiger,
      hava: temel.hava,
      havaMin: temel.havaMin,
      havaMax: temel.havaMax,
      havaDurdu: temel.havaDurdu,
      kalipciYapilanIs: ekle(temel.kalipciYapilanIs, kalipciIs),
      demirciYapilanIs: ekle(temel.demirciYapilanIs, demirciIs),
      beton: ekle(temel.beton, beton),
      notlar: ekle(temel.notlar, notlar),
      fotografYollari: List<String>.from(temel.fotografYollari),
      vincler: [...temel.vincler, ...vincler],
      yevmiyeler: [...temel.yevmiyeler, ...yevmiyeler],
    );
  }
}

/// Kullanıcıya gösterilecek, anlaşılır hata.
class AiKayitHatasi implements Exception {
  final String mesaj;
  const AiKayitHatasi(this.mesaj);
  @override
  String toString() => mesaj;
}

/// Konuşma metnini Google Gemini ile şantiye kayıtlarına ayırır.
///
/// Anahtar uygulamaya gömülmez: kullanıcı kendi ücretsiz anahtarını Ayarlar'a
/// girer ve anahtar yalnızca o cihazda saklanır (buluta eşitlenmez).
class AiKayitService {
  static const String _anahtarAyari = 'gemini_api_anahtari';
  static const String _modelAyari = 'gemini_model';
  static const String _taban = 'https://generativelanguage.googleapis.com/v1beta';

  /// Hesabın model listesi alınamazsa denenecek modeller.
  static const List<String> _yedekModeller = [
    'gemini-flash-lite-latest',
    'gemini-3.5-flash-lite',
    'gemini-flash-latest',
  ];

  /// Metin ayıklama için uygun olmayan model türleri.
  static const List<String> _istenmeyen = [
    'image', 'tts', 'live', 'audio', 'embedding', 'vision', 'robotics', 'computer', 'omni', 'preview', 'thinking',
  ];

  /// Anahtardaki boşluk, satır sonu, görünmez ve Türkçe karakterleri ayıklar.
  /// Telefondan yapıştırılan anahtarlarda bunlar bulunabiliyor; başlığa
  /// yazılamadıkları için istek hiç gitmeden "ulaşılamadı" hatası çıkıyordu.
  static String anahtariTemizle(String ham) {
    final kodlar = ham.runes.where((r) => r >= 0x21 && r <= 0x7E).toList();
    var s = String.fromCharCodes(kodlar);
    // Yanlışlıkla kopyalanan tırnaklar.
    s = s.replaceAll('"', '').replaceAll("'", '').replaceAll('`', '');
    return s;
  }

  static Future<String> anahtar() async =>
      anahtariTemizle((await SharedPreferences.getInstance()).getString(_anahtarAyari) ?? '');

  static Future<void> anahtarKaydet(String deger) async {
    final prefs = await SharedPreferences.getInstance();
    final temiz = anahtariTemizle(deger);
    if (temiz.isEmpty) {
      await prefs.remove(_anahtarAyari);
    } else {
      await prefs.setString(_anahtarAyari, temiz);
    }
    // Anahtar değişince model yeniden seçilsin.
    await prefs.remove(_modelAyari);
  }

  final http.Client _istemci;
  final Duration _istekZamanAsimi;
  final Duration _listeZamanAsimi;

  AiKayitService({
    http.Client? istemci,
    Duration istekZamanAsimi = const Duration(seconds: 25),
    Duration listeZamanAsimi = const Duration(seconds: 15),
  })  : _istemci = istemci ?? http.Client(),
        _istekZamanAsimi = istekZamanAsimi,
        _listeZamanAsimi = listeZamanAsimi;

  Map<String, String> _basliklar(String anahtar) => {
        'Content-Type': 'application/json',
        'x-goog-api-key': anahtar,
      };

  /// Hata gövdesinden (varsa) hatanın durumu ve iletisi.
  static (String durum, String ileti, String neden) _hataAyrintisi(http.Response yanit) {
    try {
      final e = jsonDecode(utf8.decode(yanit.bodyBytes))['error'];
      String neden = '';
      for (final d in (e['details'] ?? const []) as List) {
        if (d is Map && d['reason'] != null) neden = '${d['reason']}';
      }
      return ('${e['status'] ?? ''}', '${e['message'] ?? ''}', neden);
    } catch (_) {
      return ('', '', '');
    }
  }

  /// Anahtarın kendisiyle ilgili bir hata mı? (Bu durumda başka model denenmez.)
  static bool _anahtarHatasi(http.Response yanit) {
    if (yanit.statusCode == 401 || yanit.statusCode == 403) return true;
    if (yanit.statusCode == 400) {
      final (_, ileti, neden) = _hataAyrintisi(yanit);
      return neden == 'API_KEY_INVALID' || ileti.toLowerCase().contains('api key');
    }
    return false;
  }

  AiKayitHatasi _hata(http.Response yanit) {
    final (durum, ileti, _) = _hataAyrintisi(yanit);
    appLog('Gemini hatası ${yanit.statusCode} $durum: $ileti');
    if (_anahtarHatasi(yanit)) {
      return const AiKayitHatasi('Yapay zekâ anahtarı kabul edilmedi. Ayarlar\'dan anahtarı silip yeniden yapıştır.');
    }
    switch (yanit.statusCode) {
      case 429:
        return const AiKayitHatasi('Ücretsiz kullanım sınırına ulaşıldı. Biraz sonra yeniden dene.');
      case 500:
      case 502:
      case 503:
      case 504:
        return const AiKayitHatasi('Yapay zekâ şu an çok yoğun. Birkaç dakika sonra yeniden dene.');
      default:
        return AiKayitHatasi('Yapay zekâ yanıt vermedi (kod ${yanit.statusCode}). Biraz sonra yeniden dene.');
    }
  }

  /// Bağlantı ve biçim hatalarını anlaşılır iletiye çevirir.
  static AiKayitHatasi _istisna(Object e) {
    if (e is AiKayitHatasi) return e;
    if (e is TimeoutException) {
      return const AiKayitHatasi('Yapay zekâ zamanında yanıt vermedi. Biraz sonra yeniden dene.');
    }
    if (e is FormatException) {
      return const AiKayitHatasi('Anahtarda geçersiz karakter var. Ayarlar\'dan anahtarı silip yeniden yapıştır.');
    }
    if (e is SocketException || e is http.ClientException) {
      return const AiKayitHatasi('Google\'a bağlanılamadı. İnternet bağlantını kontrol et.');
    }
    appLog('Gemini isteği başarısız: $e');
    return AiKayitHatasi('Beklenmeyen hata (${e.runtimeType}). Yeniden dene.');
  }

  /// Denenecek modeller, sırayla. Hızlı "lite" modeller önde: büyük modeller
  /// ücretsiz katmanda sık sık yoğun (503) ya da çok yavaş oluyor.
  Future<List<String>> _adaylar(String anahtar) async {
    final prefs = await SharedPreferences.getInstance();
    final onceki = prefs.getString(_modelAyari) ?? '';

    var bulunan = <String>[];
    try {
      final yanit = await _istemci
          .get(Uri.parse('$_taban/models?pageSize=200'), headers: _basliklar(anahtar))
          .timeout(_listeZamanAsimi);
      if (yanit.statusCode == 200) {
        bulunan = ((jsonDecode(utf8.decode(yanit.bodyBytes))['models'] ?? []) as List)
            .where((m) => ((m['supportedGenerationMethods'] ?? []) as List).contains('generateContent'))
            .map((m) => (m['name'] as String).replaceFirst('models/', ''))
            .toList();
      } else if (_anahtarHatasi(yanit)) {
        throw _hata(yanit);
      }
    } on AiKayitHatasi {
      rethrow;
    } on TimeoutException {
      // Liste alınamadı; yedek adlarla devam edilir.
    } on FormatException {
      rethrow;
    } catch (e) {
      if (e is SocketException || e is http.ClientException) rethrow;
      appLog('Model listesi okunamadı: $e');
    }

    final uygun = bulunan.where((m) => m.contains('flash') && !_istenmeyen.any(m.contains)).toList();
    int sirala(String a, String b) {
      final la = a.contains('latest') ? 0 : 1, lb = b.contains('latest') ? 0 : 1;
      if (la != lb) return la - lb;
      return b.compareTo(a); // yeni sürüm önce
    }

    final lite = uygun.where((m) => m.contains('lite')).toList()..sort(sirala);
    final buyuk = uygun.where((m) => !m.contains('lite')).toList()..sort(sirala);

    // Yalnızca hızlı (lite) model hatırlanır: büyük model ücretsiz katmanda aynı
    // işi 1 sn yerine 25-45 sn'de yapıyor. Eskiden yedek olarak bir kez çalışan
    // büyük model hatırlanıp her istekte ilk deneniyordu.
    final adaylar = <String>[
      if (onceki.contains('lite') && (bulunan.isEmpty || bulunan.contains(onceki))) onceki,
      ...(lite.isEmpty && buyuk.isEmpty ? _yedekModeller : [...lite.take(3), ...buyuk.take(1)]),
    ];
    return adaylar.toSet().toList();
  }

  /// Aday modelleri sırayla dener; ilk başarılı yanıtın metnini ve modelini
  /// döndürür. Anahtar hatasında ya da bağlantı yokken başka model denenmez.
  Future<(String, String)> _uret(String anahtar, String istem) async {
    final prefs = await SharedPreferences.getInstance();
    final adaylar = await _adaylar(anahtar);
    AiKayitHatasi? sonHata;

    for (final model in adaylar) {
      try {
        final yanit = await _istemci
            .post(
              Uri.parse('$_taban/models/$model:generateContent'),
              headers: _basliklar(anahtar),
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': istem}
                    ]
                  }
                ],
                'generationConfig': {'temperature': 0, 'responseMimeType': 'application/json'},
              }),
            )
            .timeout(_istekZamanAsimi);

        if (yanit.statusCode == 200) {
          final String metin;
          try {
            final govde = jsonDecode(utf8.decode(yanit.bodyBytes));
            metin = ((govde['candidates'] as List).first['content']['parts'] as List)
                .map((p) => p['text'] ?? '')
                .join();
          } catch (_) {
            sonHata = const AiKayitHatasi('Yapay zekâ boş yanıt verdi. Yeniden dene.');
            continue;
          }
          if (model.contains('lite')) {
            await prefs.setString(_modelAyari, model);
          } else {
            await prefs.remove(_modelAyari);
          }
          return (model, metin);
        }

        final hata = _hata(yanit);
        if (_anahtarHatasi(yanit)) throw hata;
        sonHata = hata; // yoğunluk, kota ya da modele özgü hata: sıradaki model
      } on AiKayitHatasi {
        rethrow;
      } on TimeoutException catch (e) {
        sonHata = _istisna(e);
      } catch (e) {
        if (e is SocketException || e is http.ClientException || e is FormatException) throw _istisna(e);
        sonHata = _istisna(e);
      }
    }
    // Hiçbiri çalışmadıysa bir sonraki denemede yeniden seçilsin.
    await prefs.remove(_modelAyari);
    throw sonHata ?? const AiKayitHatasi('Yapay zekâya ulaşılamadı. Biraz sonra yeniden dene.');
  }

  /// Anahtarın çalıştığını dener; çalışıyorsa cevap veren modelin adını döndürür.
  Future<String> anahtariDene() async {
    final a = await anahtar();
    if (a.isEmpty) throw const AiKayitHatasi('Önce anahtarı gir.');
    (await SharedPreferences.getInstance()).remove(_modelAyari);
    try {
      final (model, _) = await _uret(a, 'Yalnızca {"tamam":true} JSON nesnesini döndür.');
      return model;
    } catch (e) {
      throw _istisna(e);
    }
  }

  static String _gun(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// Yapay zekâya verilen yönerge. Yalnızca söylenen metin, bugünün tarihi ve
  /// şantiye adları gönderilir.
  static String yonerge(String metin, List<Proje> projeler, DateTime bugun, {bool gorusme = false}) {
    const gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final liste = [
      for (final p in projeler)
        '- id: "${p.id}" | ad: "${p.ad}"${p.aciklama.trim().isEmpty ? '' : ' | açıklama: "${p.aciklama.trim()}"'}',
    ].join('\n');
    return '''
Bir inşaat taşeronunun (kalıp ve demir işleri) sesle söylediği günlük şantiye notunu yapılandırılmış kayıtlara çevir.

Bugün: ${_gun(bugun)} (${gunler[bugun.weekday - 1]})

Şantiyeler:
$liste
${gorusme ? '''
Not, soru-cevap biçiminde bir görüşmenin dökümüdür: her satır "konu: cevap" biçimindedir. "yok" cevabı o konuda bir şey olmadığı anlamına gelir. Aksi söylenmedikçe hepsi aynı şantiye ve aynı gün içindir.
''' : ''}
Kurallar:
- Her şantiye ve gün için ayrı bir kayıt üret. Tarih söylenmediyse bugünü kullan; "dün", "evvelsi gün", "pazartesi" gibi ifadeleri bugüne göre tarihe çevir (gelecek tarih üretme).
- Söylenen şantiye adını listedeki en yakın şantiyeyle eşleştir ve "projeId" alanına o şantiyenin id değerini yaz. Emin değilsen "projeId" boş kalsın. "soylenenAd" alanına şantiyenin konuşmada geçen adını yaz.
- Söylenmeyen hiçbir sayıyı ya da işi uydurma. Belirtilmeyen sayı 0, belirtilmeyen metin boş olsun.
- "kalipci", "demirci", "diger": o gün çalışan kişi sayıları (tam sayı). Düz işçi, amele, usta dışı çalışanlar "diger".
- "kalipciIs": kalıpçıların yaptığı iş; "demirciIs": demircilerin yaptığı iş. Kısa ve söylendiği gibi yaz, konuşma dilindeki dolgu sözlerini at.
- "beton": dökülen beton (yeri ve varsa miktarı, ör. "bodrum perde betonu 40 m³").
- "vincler": vinç çalıştıysa her biri için firma, başlangıç ve bitiş saati ("HH:MM", 24 saat), mola (dakika) ve açıklama. Saat söylenmediyse boş bırak.
- "yevmiyeler": yevmiyeli iş varsa ekip adı, miktar (yevmiye sayısı, yarım gün 0.5) ve açıklama.
- Yemek: öğünlere göre ayır. "yemek" ve "öğle yemeği" öğle yemeğidir; "kahvaltı" kahvaltıdır; "akşam yemeği" ya da "akşam" akşam yemeğidir. Her öğün için yemek yiyen / yemek verilen kişi sayısını yaz. Yemek bilgisini ASLA "notlar" alanına yazma. Ekip ayrı ayrı söylendiyse (kalıpçı, demirci, diğer) öğle için "yemekKalipci", "yemekDemirci", "yemekDiger"; kahvaltı için "kahvaltiKalipci", "kahvaltiDemirci", "kahvaltiDiger"; akşam için "aksamKalipci", "aksamDemirci", "aksamDiger" alanlarına yaz. Ekip ayrımı yapmadan tek sayı söylendiyse ("yemek 12", "kahvaltı 8", "akşam yemeği 10", "12 kişilik yemek") yalnızca "yemek", "kahvalti" ya da "aksam" alanına yaz. Söylenmeyen her şey 0.
- "notlar": yukarıdakilere girmeyen önemli bilgiler (malzeme, gecikme, hava, ziyaret). Yemek sayısı notlara yazılmaz.
- "anlasilmayan": hiçbir kayda yerleştiremediğin kısım varsa kısaca yaz, yoksa boş bırak.

Yalnızca şu biçimde JSON döndür:
{"kayitlar":[{"projeId":"","soylenenAd":"","tarih":"YYYY-MM-DD","kalipci":0,"demirci":0,"diger":0,"kalipciIs":"","demirciIs":"","beton":"","notlar":"","yemek":0,"yemekKalipci":0,"yemekDemirci":0,"yemekDiger":0,"kahvalti":0,"kahvaltiKalipci":0,"kahvaltiDemirci":0,"kahvaltiDiger":0,"aksam":0,"aksamKalipci":0,"aksamDemirci":0,"aksamDiger":0,"vincler":[{"firma":"","baslangic":"","bitis":"","mola":0,"aciklama":""}],"yevmiyeler":[{"ekip":"","miktar":0,"aciklama":""}]}],"anlasilmayan":""}

Söylenen not:
"""
$metin
"""''';
  }

  /// Model yanıtındaki JSON'u taslaklara çevirir. Bilinmeyen proje kimliği
  /// boşaltılır, gelecekteki tarih bugüne çekilir; boş taslaklar atılır.
  static (List<SesliKayitTaslagi>, String) taslaklariCoz(String jsonMetni, List<Proje> projeler, DateTime bugun) {
    var temiz = jsonMetni.trim();
    // Model bazen JSON'u ``` içine alır.
    final blok = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(temiz);
    if (blok != null) temiz = blok.group(1)!.trim();
    final dynamic kok;
    try {
      kok = jsonDecode(temiz);
    } catch (_) {
      throw const AiKayitHatasi('Yapay zekânın yanıtı anlaşılamadı. Yeniden dene.');
    }
    if (kok is! Map) throw const AiKayitHatasi('Yapay zekânın yanıtı anlaşılamadı. Yeniden dene.');

    int tam(dynamic v) => v is num ? v.round().clamp(0, 9999) : (int.tryParse('$v') ?? 0).clamp(0, 9999);
    double ondalik(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v'.replaceAll(',', '.')) ?? 0);
    String yazi(dynamic v) => v == null ? '' : '$v'.trim();
    String saat(dynamic v) {
      final m = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(yazi(v));
      if (m == null) return '';
      final s = int.parse(m.group(1)!), d = int.parse(m.group(2)!);
      if (s > 23 || d > 59) return '';
      return '${s.toString().padLeft(2, '0')}:${d.toString().padLeft(2, '0')}';
    }

    final idler = {for (final p in projeler) p.id};
    final bugunGun = DateTime(bugun.year, bugun.month, bugun.day);
    final taslaklar = <SesliKayitTaslagi>[];
    for (final k in (kok['kayitlar'] is List ? kok['kayitlar'] as List : const [])) {
      if (k is! Map) continue;
      var tarih = DateTime.tryParse(yazi(k['tarih'])) ?? bugunGun;
      tarih = DateTime(tarih.year, tarih.month, tarih.day);
      if (tarih.isAfter(bugunGun)) tarih = bugunGun;
      final id = yazi(k['projeId']);
      final t = SesliKayitTaslagi(
        projeId: idler.contains(id) ? id : '',
        soylenenAd: yazi(k['soylenenAd']),
        tarih: tarih,
        kalipci: tam(k['kalipci']),
        demirci: tam(k['demirci']),
        diger: tam(k['diger']),
        kalipciIs: yazi(k['kalipciIs']),
        demirciIs: yazi(k['demirciIs']),
        beton: yazi(k['beton']),
        notlar: yazi(k['notlar']),
        yemekKalipci: tam(k['yemekKalipci']),
        yemekDemirci: tam(k['yemekDemirci']),
        yemekDiger: tam(k['yemekDiger']),
        yemekToplam: tam(k['yemek']),
        kahvaltiKalipci: tam(k['kahvaltiKalipci']),
        kahvaltiDemirci: tam(k['kahvaltiDemirci']),
        kahvaltiDiger: tam(k['kahvaltiDiger']),
        kahvaltiToplam: tam(k['kahvalti']),
        aksamKalipci: tam(k['aksamKalipci']),
        aksamDemirci: tam(k['aksamDemirci']),
        aksamDiger: tam(k['aksamDiger']),
        aksamToplam: tam(k['aksam']),
        vincler: [
          for (final v in (k['vincler'] is List ? k['vincler'] as List : const []))
            if (v is Map && (yazi(v['firma']).isNotEmpty || saat(v['baslangic']).isNotEmpty || yazi(v['aciklama']).isNotEmpty))
              VincBilgisi(
                firmaAdi: yazi(v['firma']),
                baslangic: saat(v['baslangic']),
                bitis: saat(v['bitis']),
                mola: tam(v['mola']),
                aciklama: yazi(v['aciklama']),
              ),
        ],
        yevmiyeler: [
          for (final y in (k['yevmiyeler'] is List ? k['yevmiyeler'] as List : const []))
            if (y is Map && ondalik(y['miktar']) > 0)
              YevmiyeBilgisi(ekipAdi: yazi(y['ekip']), miktar: ondalik(y['miktar']), aciklama: yazi(y['aciklama'])),
        ],
      );
      if (!t.bos) taslaklar.add(t);
    }
    return (taslaklar, yazi(kok['anlasilmayan']));
  }

  /// Konuşma metnini taslak kayıtlara çevirir. İkinci değer, yapay zekânın
  /// hiçbir kayda yerleştiremediği kısımdır (yoksa boş).
  Future<(List<SesliKayitTaslagi>, String)> cozumle(String metin, List<Proje> projeler, DateTime bugun,
      {bool gorusme = false}) async {
    final a = await anahtar();
    if (a.isEmpty) {
      throw const AiKayitHatasi('Yapay zekâ anahtarı girilmemiş. Ayarlar > Sesle kayıt bölümünden ekle.');
    }
    try {
      final (_, cevap) = await _uret(a, yonerge(metin, projeler, bugun, gorusme: gorusme));
      return taslaklariCoz(cevap, projeler, bugun);
    } catch (e) {
      throw _istisna(e);
    }
  }
}
