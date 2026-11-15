import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class ClaudeGelenKutusu {
  /// Kaydedilmiş ama buluttan silinememiş (ör. internet yokken) önerilerin
  /// kimlikleri. Silme başarılı olana kadar yeniden gösterilmezler; aynı
  /// öneri iki kez kaydedilip vinç/yevmiye satırları çiftlenmesin diye.
  static const String _uygulananlarAyari = 'claude_uygulanan_oneriler';

  CollectionReference<Map<String, dynamic>>? _koleksiyon() {
    if (StorageService.bulutKapali) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('data')
        .doc('claude_gelen')
        .collection('oneriler');
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
        olusturma: zaman is Timestamp ? zaman.toDate() : null,
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
    final koleksiyon = _koleksiyon();
    if (koleksiyon == null) return const {};
    try {
      final sonuc = await koleksiyon.get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 10));
      final uygulanan = await _uygulananlar();
      final ham = <String, Map<String, dynamic>>{
        for (final belge in sonuc.docs)
          if (!uygulanan.contains(belge.id)) belge.id: belge.data(),
      };
      // Önceden kaydedilip silinemeyenler bu kez silinmeyi dener.
      final kalan = uygulanan.intersection({for (final b in sonuc.docs) b.id});
      if (kalan.isNotEmpty) unawaited(sil(kalan));
      if (kalan.length != uygulanan.length) await _uygulananlariYaz(kalan);
      return ham;
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
    final koleksiyon = _koleksiyon();
    if (koleksiyon == null) return;
    final silinen = <String>{};
    Future<void> birini(String id) async {
      try {
        await koleksiyon.doc(id).delete().timeout(const Duration(seconds: 10));
        silinen.add(id);
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
