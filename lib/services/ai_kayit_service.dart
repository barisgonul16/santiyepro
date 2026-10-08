import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gunluk_kayit.dart';
import '../models/proje.dart';
import 'app_log.dart';

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
      vincler.isEmpty &&
      yevmiyeler.isEmpty;

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
      yemekKalipci: temel.yemekKalipci,
      yemekDemirci: temel.yemekDemirci,
      yemekDiger: temel.yemekDiger,
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

  /// Önce bunlar denenir; hiçbiri yoksa hesabın model listesinden "flash"
  /// içeren ilk uygun model seçilir. Model adları zamanla değiştiği için sabit
  /// tek bir ada güvenilmez.
  static const List<String> _tercihler = ['gemini-flash-latest', 'gemini-flash-lite-latest'];

  static Future<String> anahtar() async =>
      (await SharedPreferences.getInstance()).getString(_anahtarAyari)?.trim() ?? '';

  static Future<void> anahtarKaydet(String deger) async {
    final prefs = await SharedPreferences.getInstance();
    final temiz = deger.trim();
    if (temiz.isEmpty) {
      await prefs.remove(_anahtarAyari);
    } else {
      await prefs.setString(_anahtarAyari, temiz);
    }
    // Anahtar değişince model yeniden seçilsin.
    await prefs.remove(_modelAyari);
  }

  final http.Client _istemci;
  AiKayitService({http.Client? istemci}) : _istemci = istemci ?? http.Client();

  Map<String, String> _basliklar(String anahtar) => {
        'Content-Type': 'application/json',
        'x-goog-api-key': anahtar,
      };

  AiKayitHatasi _hata(http.Response yanit) {
    String ayrinti = '';
    try {
      ayrinti = (jsonDecode(utf8.decode(yanit.bodyBytes))['error']['message'] ?? '').toString();
    } catch (_) {}
    appLog('Gemini hatası ${yanit.statusCode}: $ayrinti');
    switch (yanit.statusCode) {
      case 400:
      case 401:
      case 403:
        return const AiKayitHatasi('Yapay zekâ anahtarı kabul edilmedi. Ayarlar\'dan anahtarı kontrol et.');
      case 429:
        return const AiKayitHatasi('Ücretsiz kullanım sınırına ulaşıldı. Biraz sonra yeniden dene.');
      default:
        return AiKayitHatasi('Yapay zekâ yanıt vermedi (kod ${yanit.statusCode}). Biraz sonra yeniden dene.');
    }
  }

  /// Bu anahtarla kullanılabilen, metin üreten bir "flash" modeli bulur.
  Future<String> _modelSec(String anahtar) async {
    final prefs = await SharedPreferences.getInstance();
    final kayitli = prefs.getString(_modelAyari);
    if (kayitli != null && kayitli.isNotEmpty) return kayitli;

    final yanit = await _istemci
        .get(Uri.parse('$_taban/models?pageSize=200'), headers: _basliklar(anahtar))
        .timeout(const Duration(seconds: 20));
    if (yanit.statusCode != 200) throw _hata(yanit);
    final modeller = ((jsonDecode(utf8.decode(yanit.bodyBytes))['models'] ?? []) as List)
        .where((m) => ((m['supportedGenerationMethods'] ?? []) as List).contains('generateContent'))
        .map((m) => (m['name'] as String).replaceFirst('models/', ''))
        .toList();

    String? secilen;
    for (final t in _tercihler) {
      if (modeller.contains(t)) {
        secilen = t;
        break;
      }
    }
    // Ses, görsel ve canlı modeller metin işi için uygun değil.
    const istenmeyen = ['image', 'tts', 'live', 'audio', 'embedding', 'vision', 'thinking'];
    secilen ??= modeller.cast<String?>().firstWhere(
          (m) => m!.contains('flash') && !istenmeyen.any(m.contains),
          orElse: () => null,
        );
    if (secilen == null) {
      throw const AiKayitHatasi('Bu anahtarla kullanılabilecek uygun bir yapay zekâ modeli bulunamadı.');
    }
    await prefs.setString(_modelAyari, secilen);
    return secilen;
  }

  /// Anahtarın çalıştığını dener; çalışıyorsa seçilen modelin adını döndürür.
  Future<String> anahtariDene() async {
    final a = await anahtar();
    if (a.isEmpty) throw const AiKayitHatasi('Önce anahtarı gir.');
    (await SharedPreferences.getInstance()).remove(_modelAyari);
    return _modelSec(a);
  }

  static String _gun(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// Yapay zekâya verilen yönerge. Yalnızca söylenen metin, bugünün tarihi ve
  /// şantiye adları gönderilir.
  static String yonerge(String metin, List<Proje> projeler, DateTime bugun) {
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

Kurallar:
- Her şantiye ve gün için ayrı bir kayıt üret. Tarih söylenmediyse bugünü kullan; "dün", "evvelsi gün", "pazartesi" gibi ifadeleri bugüne göre tarihe çevir (gelecek tarih üretme).
- Söylenen şantiye adını listedeki en yakın şantiyeyle eşleştir ve "projeId" alanına o şantiyenin id değerini yaz. Emin değilsen "projeId" boş kalsın. "soylenenAd" alanına şantiyenin konuşmada geçen adını yaz.
- Söylenmeyen hiçbir sayıyı ya da işi uydurma. Belirtilmeyen sayı 0, belirtilmeyen metin boş olsun.
- "kalipci", "demirci", "diger": o gün çalışan kişi sayıları (tam sayı). Düz işçi, amele, usta dışı çalışanlar "diger".
- "kalipciIs": kalıpçıların yaptığı iş; "demirciIs": demircilerin yaptığı iş. Kısa ve söylendiği gibi yaz, konuşma dilindeki dolgu sözlerini at.
- "beton": dökülen beton (yeri ve varsa miktarı, ör. "bodrum perde betonu 40 m³").
- "vincler": vinç çalıştıysa her biri için firma, başlangıç ve bitiş saati ("HH:MM", 24 saat), mola (dakika) ve açıklama. Saat söylenmediyse boş bırak.
- "yevmiyeler": yevmiyeli iş varsa ekip adı, miktar (yevmiye sayısı, yarım gün 0.5) ve açıklama.
- "notlar": yukarıdakilere girmeyen önemli bilgiler (malzeme, gecikme, hava, ziyaret).
- "anlasilmayan": hiçbir kayda yerleştiremediğin kısım varsa kısaca yaz, yoksa boş bırak.

Yalnızca şu biçimde JSON döndür:
{"kayitlar":[{"projeId":"","soylenenAd":"","tarih":"YYYY-MM-DD","kalipci":0,"demirci":0,"diger":0,"kalipciIs":"","demirciIs":"","beton":"","notlar":"","vincler":[{"firma":"","baslangic":"","bitis":"","mola":0,"aciklama":""}],"yevmiyeler":[{"ekip":"","miktar":0,"aciklama":""}]}],"anlasilmayan":""}

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
  Future<(List<SesliKayitTaslagi>, String)> cozumle(String metin, List<Proje> projeler, DateTime bugun) async {
    final a = await anahtar();
    if (a.isEmpty) {
      throw const AiKayitHatasi('Yapay zekâ anahtarı girilmemiş. Ayarlar > Sesle kayıt bölümünden ekle.');
    }
    final http.Response yanit;
    try {
      final model = await _modelSec(a);
      yanit = await _istemci
          .post(
            Uri.parse('$_taban/models/$model:generateContent'),
            headers: _basliklar(a),
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': yonerge(metin, projeler, bugun)}
                  ]
                }
              ],
              'generationConfig': {'temperature': 0, 'responseMimeType': 'application/json'},
            }),
          )
          .timeout(const Duration(seconds: 45));
    } on AiKayitHatasi {
      rethrow;
    } catch (e) {
      appLog('Gemini isteği başarısız: $e');
      throw const AiKayitHatasi('Yapay zekâya ulaşılamadı. İnternet bağlantını kontrol et.');
    }
    if (yanit.statusCode == 404) {
      // Seçili model kaldırılmış olabilir; bir sonraki denemede yeniden seçilir.
      (await SharedPreferences.getInstance()).remove(_modelAyari);
    }
    if (yanit.statusCode != 200) throw _hata(yanit);

    final String cevap;
    try {
      final govde = jsonDecode(utf8.decode(yanit.bodyBytes));
      cevap = ((govde['candidates'] as List).first['content']['parts'] as List)
          .map((p) => p['text'] ?? '')
          .join();
    } catch (_) {
      throw const AiKayitHatasi('Yapay zekâ boş yanıt verdi. Yeniden dene.');
    }
    return taslaklariCoz(cevap, projeler, bugun);
  }
}
