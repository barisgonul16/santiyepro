import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/proje.dart';
import 'ai_kayit_service.dart';
import 'app_log.dart';
import 'storage_service.dart';

/// Claude'un (claude.ai'deki ŞantiyePro bağlayıcısı) önerdiği günlük kayıtlar.
///
/// Claude kayıtları doğrudan yazmaz: users/{uid}/data/claude_gelen/oneriler
/// altına öneri bırakır. Uygulama burada onları okur, kullanıcı sesle kayıttaki
/// onay ekranında görüp kaydeder; kayıtları uygulama ekler ve öneriyi siler.
/// Öneri içeriği sesle kayıttaki yapay zekâ yanıtıyla aynı JSON'dur
/// ([AiKayitService.taslaklariCoz]).
class ClaudeOnerisi {
  final String id;
  /// Kullanıcının Claude'a söylediğinin kısa hali (boş olabilir).
  final String aciklama;
  final DateTime? olusturma;
  final List<SesliKayitTaslagi> taslaklar;

  const ClaudeOnerisi({required this.id, required this.aciklama, required this.olusturma, required this.taslaklar});
}

/// Gelen kutusu Firestore'un REST adresinden okunur ve silinir (kullanıcının
/// kimlik jetonuyla, aynı güvenlik kurallarıyla). Firestore eklentisi
/// kullanılmaz: Windows eklentisi bu alt koleksiyon sorgusunu yapamıyor
/// (yayın derlemesinde boş dönüyor, debug derlemesinde uygulamayı
/// çökertiyordu). REST her platformda aynı çalışır; sunucu da aynı adresleri
/// kullanır (araclar/santiyepro_worker/src/firestore.js).
class ClaudeGelenKutusu {
  ClaudeGelenKutusu({http.Client? istemci}) : _istemci = istemci ?? http.Client();

  final http.Client _istemci;
  static const Duration _zamanAsimi = Duration(seconds: 15);

  /// Kaydedilmiş ama buluttan silinememiş (ör. internet yokken) önerilerin
  /// kimlikleri. Silme başarılı olana kadar yeniden gösterilmezler; aynı
  /// öneri iki kez kaydedilip vinç/yevmiye satırları çiftlenmesin diye.
  static const String _uygulananlarAyari = 'claude_uygulanan_oneriler';

  /// Gelen kutusu adresi ve yetki başlığı; bulut kapalıysa ya da giriş
  /// yapılmamışsa null.
  Future<(Uri, Map<String, String>)?> _adres([String? id]) async {
    if (StorageService.bulutKapali) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final jeton = await user.getIdToken();
    if (jeton == null || jeton.isEmpty) return null;
    final proje = Firebase.app().options.projectId;
    final yol = 'https://firestore.googleapis.com/v1/projects/$proje/databases/(default)/documents'
        '/users/${Uri.encodeComponent(user.uid)}/data/claude_gelen/oneriler${id == null ? '' : '/${Uri.encodeComponent(id)}'}';
    return (Uri.parse(yol), {'Authorization': 'Bearer $jeton'});
  }

  /// Firestore REST liste yanıtındaki belgeleri ham veriye çevirir
  /// (kimlik → {json, aciklama, olusturma}).
  static Map<String, Map<String, dynamic>> listeyiCoz(Map<String, dynamic> yanit) {
    final sonuc = <String, Map<String, dynamic>>{};
    final belgeler = yanit['documents'];
    if (belgeler is! List) return sonuc;
    for (final b in belgeler) {
      if (b is! Map || b['name'] is! String) continue;
      final id = (b['name'] as String).split('/').last;
      final alanlar = b['fields'] is Map ? b['fields'] as Map : const {};
      String metin(String ad) {
        final a = alanlar[ad];
        return a is Map && a['stringValue'] is String ? a['stringValue'] as String : '';
      }

      final zamanAlani = alanlar['olusturma'];
      final zamanMetni = zamanAlani is Map && zamanAlani['timestampValue'] is String
          ? zamanAlani['timestampValue'] as String
          : (b['createTime'] is String ? b['createTime'] as String : '');
      sonuc[id] = {
        'json': metin('json'),
        'aciklama': metin('aciklama'),
        'olusturma': DateTime.tryParse(zamanMetni)?.toLocal(),
      };
    }
    return sonuc;
  }

  /// Belge verisini öneriye çevirir; okunamıyorsa ya da kayıt çıkmıyorsa null.
  static ClaudeOnerisi? cozumle(String id, Map<String, dynamic> veri, List<Proje> projeler, DateTime bugun) {
    final json = veri['json'];
    if (json is! String || json.trim().isEmpty) return null;
    try {
      final (taslaklar, _) = AiKayitService.taslaklariCoz(json, projeler, bugun);
      if (taslaklar.isEmpty) return null;
      final zaman = veri['olusturma'];
      return ClaudeOnerisi(
        id: id,
        aciklama: veri['aciklama'] is String ? (veri['aciklama'] as String).trim() : '',
        olusturma: zaman is DateTime ? zaman : null,
        taslaklar: taslaklar,
      );
    } on AiKayitHatasi {
      return null;
    }
  }

  Future<Set<String>> _uygulananlar() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_uygulananlarAyari) ?? const <String>[]).toSet();
  }

  Future<void> _uygulananlariYaz(Set<String> idler) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_uygulananlarAyari, idler.toList());
  }

  /// Bekleyen önerilerin ham belgeleri (kimlik → veri). Şantiye eşleştirmesi
  /// burada yapılmaz: şantiye listesi o anda henüz yüklenmemiş olabilir;
  /// [ayir] her kullanımda güncel listeyle çağrılır. Bulut yoksa ya da sorgu
  /// başarısızsa boş döner.
  Future<Map<String, Map<String, dynamic>>> bekleyenler() async {
    try {
      final adres = await _adres();
      if (adres == null) return const {};
      final (url, basliklar) = adres;
      final hepsi = <String, Map<String, dynamic>>{};
      var sayfa = '';
      do {
        final istek = url.replace(queryParameters: {'pageSize': '100', if (sayfa.isNotEmpty) 'pageToken': sayfa});
        final y = await _istemci.get(istek, headers: basliklar).timeout(_zamanAsimi);
        if (y.statusCode == 404) break;
        if (y.statusCode != 200) throw 'HTTP ${y.statusCode} ${y.body}';
        final govde = jsonDecode(utf8.decode(y.bodyBytes));
        if (govde is! Map<String, dynamic>) break;
        hepsi.addAll(listeyiCoz(govde));
        sayfa = govde['nextPageToken'] is String ? govde['nextPageToken'] as String : '';
      } while (sayfa.isNotEmpty);

      final uygulanan = await _uygulananlar();
      // Önceden kaydedilip silinemeyenler bu kez silinmeyi dener.
      final kalan = uygulanan.intersection(hepsi.keys.toSet());
      if (kalan.isNotEmpty) unawaited(sil(kalan));
      if (kalan.length != uygulanan.length) await _uygulananlariYaz(kalan);
      return {
        for (final e in hepsi.entries)
          if (!uygulanan.contains(e.key)) e.key: e.value,
      };
    } catch (e) {
      appLog('Claude önerileri okunamadı: $e');
      return const {};
    }
  }

  /// Ham belgeleri önerilere çevirir (eskiden yeniye). İkinci liste okunamayan
  /// belgelerin kimlikleri: kullanıcı kaydettiğinde ya da sildiğinde onlar da
  /// temizlenir.
  static (List<ClaudeOnerisi>, List<String>) ayir(
      Map<String, Map<String, dynamic>> ham, List<Proje> projeler, DateTime bugun) {
    final oneriler = <ClaudeOnerisi>[];
    final okunamayan = <String>[];
    ham.forEach((id, veri) {
      final o = cozumle(id, veri, projeler, bugun);
      if (o == null) {
        okunamayan.add(id);
      } else {
        oneriler.add(o);
      }
    });
    oneriler.sort((a, b) => (a.olusturma ?? DateTime(0)).compareTo(b.olusturma ?? DateTime(0)));
    return (oneriler, okunamayan);
  }

  /// Önerileri siler. Kaydedilen öneriler önce "uygulandı" diye işaretlenir:
  /// silme başarısız olsa da bir daha gösterilmezler.
  Future<void> sil(Iterable<String> idler, {bool uygulandi = false}) async {
    final liste = idler.toSet();
    if (liste.isEmpty) return;
    if (uygulandi) await _uygulananlariYaz({...await _uygulananlar(), ...liste});
    final silinen = <String>{};
    Future<void> birini(String id) async {
      try {
        final adres = await _adres(id);
        if (adres == null) return;
        final (url, basliklar) = adres;
        final y = await _istemci.delete(url, headers: basliklar).timeout(_zamanAsimi);
        // 404: zaten silinmiş.
        if (y.statusCode == 200 || y.statusCode == 404) {
          silinen.add(id);
        } else {
          appLog('Claude önerisi silinemedi ($id): HTTP ${y.statusCode}');
        }
      } catch (e) {
        appLog('Claude önerisi silinemedi ($id): $e');
      }
    }

    await Future.wait([for (final id in liste) birini(id)]);
    if (silinen.isNotEmpty) {
      final uygulanan = await _uygulananlar();
      if (uygulanan.intersection(silinen).isNotEmpty) await _uygulananlariYaz(uygulanan.difference(silinen));
    }
  }
}
