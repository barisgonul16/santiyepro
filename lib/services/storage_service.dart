import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/proje.dart';
import '../models/gorev.dart';
import '../models/not.dart';
import '../models/hatirlatici.dart';
import '../models/gunluk_kayit.dart';
import '../screens/haritalar_sayfa.dart';
import '../models/fatura.dart';
import '../models/hakedis.dart';
import '../models/harcama.dart';
import '../models/malzeme.dart';
import '../models/pratik_bilgi.dart';
import '../main.dart' show firestoreDisabled;
import 'app_log.dart';

/// Veri yüklenirken oluşan ve kullanıcıya bildirilmesi gereken durum.
class StorageWarning {
  final String koleksiyon;
  final String mesaj;

  const StorageWarning(this.koleksiyon, this.mesaj);
}

class StorageService {
  /// Yerel dosya + bulut senkronizasyonuna dahil olan tüm koleksiyonlar.
  static const List<String> collections = [
    'projects', 'tasks', 'notes', 'reminders', 'locations',
    'project_logs', 'sketches', 'faturalar', 'harcamalar',
    'malzemeler', 'pratik_bilgiler', 'ekipler', 'hakedisler',
  ];

  /// Koleksiyon adlarının kullanıcıya gösterilecek karşılıkları.
  static const Map<String, String> collectionNames = {
    'projects': 'Projeler',
    'tasks': 'Görevler',
    'notes': 'Notlar',
    'reminders': 'Hatırlatıcılar',
    'locations': 'Konumlar',
    'project_logs': 'Günlük kayıtlar',
    'sketches': 'Eskizler',
    'faturalar': 'Faturalar',
    'harcamalar': 'Harcamalar',
    'malzemeler': 'Malzemeler',
    'pratik_bilgiler': 'Pratik bilgiler',
    'ekipler': 'Ekipler',
    'hakedisler': 'Hakedişler',
  };

  /// Yüklenirken sorun çıkan koleksiyonlar.
  ///
  /// Bu koleksiyonlar buluta GÖNDERİLMEZ. Aksi halde eksik okunmuş bir liste
  /// buluttaki sağlam veriyi kalıcı olarak silerdi.
  static final Set<String> degradedCollections = <String>{};

  /// Kullanıcıya gösterilmek üzere biriken uyarılar.
  static final List<StorageWarning> warnings = <StorageWarning>[];

  /// Bulutla en son başarılı alışveriş zamanı (indirme ya da gönderme).
  /// Ana sayfadaki bulut göstergesi bunu dinler.
  static final ValueNotifier<DateTime?> sonEsitleme = ValueNotifier<DateTime?>(null);

  /// Son eşitlemede bazı bölümler buluttan alınamadıysa true.
  static bool sonEsitlemeEksik = false;

  /// Bulut bu oturumda kullanılamıyor (Firebase yok ya da Windows'ta kapalı).
  static bool get bulutKapali => Firebase.apps.isEmpty || firestoreDisabled;

  /// Aynı anda iki eşitleme çalışmasın (defter paylaşılıyor).
  static Future<void>? _suranEsitleme;

  /// Bulut sorgusu başına zaman aşımı. Koleksiyonlar paralel çekildiği için
  /// toplam senkronizasyon süresi de yaklaşık bu kadardır.
  static const Duration _sorguZamanAsimi = Duration(seconds: 6);

  /// Dosya zaman damgası karşılaştırmalarında kabul edilen saat sapması.
  static const int _zamanToleransiMs = 2000;

  /// Firestore'un tek doküman sınırı 1 MiB. Alan adları ve kodlama payı için
  /// biraz altında kalınır.
  static const int _firestoreBelgeSiniri = 900 * 1024;

  /// Kullanıcıyı bilgilendirir ama koleksiyonu bloke etmez.
  static void _bilgilendir(String koleksiyon, String mesaj) {
    final zatenVar = warnings.any(
      (w) => w.koleksiyon == koleksiyon && w.mesaj == mesaj,
    );
    if (!zatenVar) {
      warnings.add(StorageWarning(koleksiyon, mesaj));
    }
    appLog('DEPOLAMA BİLGİSİ [$koleksiyon]: $mesaj');
  }

  /// Koleksiyonu "sorunlu" işaretler (buluta gönderim durur) ve kullanıcıyı uyarır.
  static void _uyar(String koleksiyon, String mesaj) {
    degradedCollections.add(koleksiyon);
    _bilgilendir(koleksiyon, mesaj);
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _getFile(String filename) async {
    final path = await _localPath;
    return File('$path/$filename');
  }

  // ---------------------------------------------------------------------------
  // ATOMİK YAZMA
  // ---------------------------------------------------------------------------

  /// JSON'u önce geçici dosyaya yazar, mevcut dosyanın yedeğini alır ve ancak
  /// ondan sonra hedefin üzerine taşır.
  ///
  /// Yazma yarıda kesilirse (çökme, pil bitmesi) hedef dosya bozulmaz; en kötü
  /// ihtimalle bir önceki sürüm `.bak` dosyasından geri gelir.
  Future<void> _writeFileAtomic(String koleksiyon, String jsonString) async {
    final path = await _localPath;
    final hedef = File('$path/$koleksiyon.json');
    final gecici = File('$path/$koleksiyon.json.tmp');
    final yedek = File('$path/$koleksiyon.json.bak');

    try {
      await gecici.writeAsString(jsonString, flush: true);

      if (await hedef.exists()) {
        try {
          await hedef.copy(yedek.path);
        } catch (e) {
          appLog('Yedek alınamadı ($koleksiyon): $e');
        }
      }

      try {
        await gecici.rename(hedef.path);
      } on FileSystemException {
        // Bazı platformlarda var olan dosyanın üzerine rename başarısız olur.
        if (await hedef.exists()) await hedef.delete();
        await gecici.rename(hedef.path);
      }
    } catch (e) {
      _uyar(koleksiyon, 'Veri diske yazılamadı: $e');
      rethrow;
    }
  }

  /// Diske yazar ve ardından buluta gönderir.
  Future<void> _writeJson(String koleksiyon, String jsonString) async {
    try {
      await _writeFileAtomic(koleksiyon, jsonString);
    } catch (_) {
      // Disk yazımı başarısızsa buluta göndermek daha da tehlikelidir.
      return;
    }
    await _syncToFirestore(koleksiyon, jsonString);
  }

  // ---------------------------------------------------------------------------
  // OKUMA
  // ---------------------------------------------------------------------------

  /// Bozuk dosyanın kopyasını `<koleksiyon>.bozuk-<zaman>.json` olarak saklar.
  Future<void> _karantinayaAl(String koleksiyon, File dosya) async {
    try {
      final path = await _localPath;
      final zaman = DateTime.now().millisecondsSinceEpoch;
      await dosya.copy('$path/$koleksiyon.bozuk-$zaman.json');
    } catch (e) {
      appLog('Bozuk dosya karantinaya alınamadı ($koleksiyon): $e');
    }
  }

  /// Koleksiyonun ham JSON içeriğini döndürür.
  ///
  /// Ana dosya bozuksa otomatik olarak `.bak` yedeğine düşer. Hiçbiri
  /// okunamazsa `null` döner ve koleksiyon "sorunlu" olarak işaretlenir.
  Future<String?> _readRaw(String koleksiyon) async {
    final path = await _localPath;
    final hedef = File('$path/$koleksiyon.json');
    final yedek = File('$path/$koleksiyon.json.bak');

    if (!await hedef.exists()) {
      // Dosya hiç yok: ilk açılış. Bu bir hata değil.
      return null;
    }

    try {
      final icerik = await hedef.readAsString();
      if (icerik.trim().isNotEmpty) {
        jsonDecode(icerik); // yalnızca geçerlilik kontrolü
        return icerik;
      }
      _uyar(koleksiyon, 'Veri dosyası boş bulundu, yedek deneniyor.');
    } catch (e) {
      _uyar(koleksiyon, 'Veri dosyası okunamadı, yedek deneniyor: $e');
      await _karantinayaAl(koleksiyon, hedef);
    }

    if (await yedek.exists()) {
      try {
        final icerik = await yedek.readAsString();
        jsonDecode(icerik);
        await yedek.copy(hedef.path);
        _uyar(koleksiyon,
            'Ana dosya kullanılamadı, otomatik yedekten geri yüklendi.');
        return icerik;
      } catch (e) {
        _uyar(koleksiyon, 'Yedek dosya da okunamadı: $e');
      }
    }

    return null;
  }

  /// JSON listesini kayıt bazında çözer.
  ///
  /// Tek bir bozuk kayıt tüm listeyi düşürmez; yalnızca o kayıt atlanır ve
  /// durum uyarı olarak kaydedilir.
  Future<List<T>> _readList<T>(
    String koleksiyon,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final ham = await _readRaw(koleksiyon);
    if (ham == null) return <T>[];

    final dynamic cozulmus;
    try {
      cozulmus = jsonDecode(ham);
    } catch (e) {
      _uyar(koleksiyon, 'Veri çözümlenemedi: $e');
      return <T>[];
    }

    if (cozulmus is! List) {
      _uyar(koleksiyon, 'Veri beklenen liste biçiminde değil.');
      return <T>[];
    }

    final sonuc = <T>[];
    int atlanan = 0;
    for (final kayit in cozulmus) {
      try {
        sonuc.add(fromJson(Map<String, dynamic>.from(kayit as Map)));
      } catch (e) {
        atlanan++;
        appLog('Kayıt atlandı ($koleksiyon): $e');
      }
    }

    if (atlanan > 0) {
      _uyar(koleksiyon, '$atlanan kayıt okunamadı ve atlandı.');
    }
    return sonuc;
  }

  // ---------------------------------------------------------------------------
  // BULUTA GÖNDERME
  // ---------------------------------------------------------------------------

  Future<void> _syncToFirestore(String koleksiyon, String data) async {
    if (Firebase.apps.isEmpty) return;

    // Windows'ta buluttan indirme kapalı. İndirme yapılmıyorsa yükleme de
    // yapılmamalıdır: boş/eski yerel veri buluttaki veriyi silerdi.
    if (firestoreDisabled) {
      appLog('Bulut kapalı — $koleksiyon gönderilmedi.');
      return;
    }

    // Yüklenirken sorun çıkan koleksiyon buluta gönderilmez.
    if (degradedCollections.contains(koleksiyon)) {
      appLog('$koleksiyon sorunlu olarak işaretli — buluta gönderilmedi.');
      return;
    }

    // Firestore'da tek doküman en fazla 1 MiB olabilir. Bir koleksiyonun
    // tamamı tek alanda tutulduğu için bu sınır aşıldığında yazma sessizce
    // başarısız olur ve kullanıcı senkronun durduğunu fark etmez.
    final int boyut = utf8.encode(data).length;
    if (boyut > _firestoreBelgeSiniri) {
      _uyar(
        koleksiyon,
        'Veri boyutu bulut sınırını aştı (${(boyut / 1024 / 1024).toStringAsFixed(2)} MB / 1 MB). '
        'Bu veri artık buluta yedeklenmiyor; cihazda güvende. '
        'Ayarlar > Veri Yedekleme ile dosya yedeği alın.',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('data')
        .doc(koleksiyon);

    // Bu koleksiyon için henüz bir senkronizasyon temeli yoksa, buluttaki
    // veriyi hiç görmemişiz demektir. Bu durumda körlemesine yazmak, açılışta
    // senkronizasyon başarısız olduysa (yeni cihaz + internet yok) buluttaki
    // veriyi silerdi. Önce buluta bakılır.
    final defter = await _defteriYukle();
    if (defter[koleksiyon] == null) {
      try {
        final mevcut = await docRef.get().timeout(_sorguZamanAsimi);
        final String bulutJson = mevcut.data()?['json'] ?? '';
        if (mevcut.exists && bulutJson.trim().isNotEmpty) {
          _uyar(
            koleksiyon,
            'Bulutta bu cihaza henüz indirilmemiş veri var. Cihazdaki '
            'değişiklikler buluta gönderilmedi. İnternet bağlantısıyla '
            'uygulamayı yeniden başlatın.',
          );
          return;
        }
      } catch (e) {
        _uyar(
          koleksiyon,
          'Buluttaki veri doğrulanamadı, üzerine yazılmadı: $e',
        );
        return;
      }
    }

    try {
      await docRef
          .set({'json': data, 'updatedAt': FieldValue.serverTimestamp()});
      await _gonderimiKaydet(koleksiyon);
      sonEsitleme.value = DateTime.now();
    } catch (e) {
      appLog('Buluta gönderme hatası ($koleksiyon): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // SENKRONİZASYON DEFTERİ
  // ---------------------------------------------------------------------------
  //
  // Her koleksiyon için en son uygulanan bulut zamanı ve o andaki yerel dosya
  // zamanı saklanır. Böylece "bulut mu yeni, cihaz mı yeni" sorusu
  // cevaplanabilir ve koşulsuz üzerine yazma önlenir.

  Future<Map<String, dynamic>> _defteriYukle() async {
    try {
      final file = await _getFile('sync_meta.json');
      if (!await file.exists()) return <String, dynamic>{};
      final icerik = await file.readAsString();
      final cozulmus = jsonDecode(icerik);
      if (cozulmus is Map) return Map<String, dynamic>.from(cozulmus);
    } catch (e) {
      appLog('Senkronizasyon defteri okunamadı: $e');
    }
    return <String, dynamic>{};
  }

  Future<void> _defteriKaydet(Map<String, dynamic> defter) async {
    try {
      final file = await _getFile('sync_meta.json');
      await file.writeAsString(jsonEncode(defter), flush: true);
    } catch (e) {
      appLog('Senkronizasyon defteri yazılamadı: $e');
    }
  }

  Future<int> _yerelZaman(String koleksiyon) async {
    try {
      final path = await _localPath;
      final file = File('$path/$koleksiyon.json');
      if (!await file.exists()) return 0;
      return (await file.lastModified()).millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  /// Cihazda olup buluta henüz gönderilmemiş değişikliği olan koleksiyonların
  /// görünen adlarını döndürür. Çıkış yapmadan önce kullanılır: çıkış yerel
  /// veriyi sildiği için bu değişiklikler kaybolur.
  ///
  /// Emin olunamayan durumlar (defter kaydı yok, bulut kapalı, koleksiyon
  /// sorunlu) da gönderilmemiş sayılır; yanlışlıkla "güvenli" demektense
  /// fazladan uyarmak tercih edilir.
  Future<List<String>> gonderilmemisKoleksiyonlar() async {
    final defter = await _defteriYukle();
    final List<String> sonuc = [];
    for (final koleksiyon in collections) {
      final int yerel = await _yerelZaman(koleksiyon);
      if (yerel == 0) continue; // Cihazda bu veri hiç yok.

      final kayit = defter[koleksiyon];
      final bool gonderilmemis = firestoreDisabled ||
          degradedCollections.contains(koleksiyon) ||
          kayit is! Map ||
          yerel > ((kayit['localMtime'] as int?) ?? 0) + _zamanToleransiMs;
      if (gonderilmemis) {
        sonuc.add(collectionNames[koleksiyon] ?? koleksiyon);
      }
    }
    return sonuc;
  }

  /// Buluta başarılı gönderim sonrası defteri günceller.
  Future<void> _gonderimiKaydet(String koleksiyon) async {
    final defter = await _defteriYukle();
    defter[koleksiyon] = {
      'cloudAppliedAt': DateTime.now().millisecondsSinceEpoch,
      'localMtime': await _yerelZaman(koleksiyon),
    };
    await _defteriKaydet(defter);
  }

  // ---------------------------------------------------------------------------
  // BULUTTAN İNDİRME
  // ---------------------------------------------------------------------------

  /// Buluttan eşitler. Zaten bir eşitleme sürüyorsa onun bitmesini bekler.
  Future<void> syncEverythingWithCloud() {
    return _suranEsitleme ??=
        _esitle().whenComplete(() => _suranEsitleme = null);
  }

  Future<void> _esitle() async {
    if (Firebase.apps.isEmpty || firestoreDisabled) {
      appLog('Bulut senkronizasyonu atlandı — yerel veri kullanılıyor.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final defter = await _defteriYukle();

    // Bu sürüme geçiş anı. Bundan ÖNCE var olan yerel dosyalar için eski
    // davranış (bulut kazanır) korunur; SONRA oluşmuş ama hiç senkronize
    // olmamış dosyalar ise çevrimdışı yapılmış iş kabul edilip korunur.
    defter['_migratedAt'] ??= DateTime.now().millisecondsSinceEpoch;

    // Koleksiyonlar paralel çekilir: toplam süre 12 x tek sorgu değil,
    // yaklaşık tek sorgu süresi kadardır.
    final sonuclar = await Future.wait(
      collections.map((col) => _koleksiyonuSenkronize(user.uid, col, defter)),
    );

    await _defteriKaydet(defter);
    sonEsitlemeEksik = sonuclar.contains(false);
    sonEsitleme.value = DateTime.now();
    appLog('Bulut senkronizasyonu tamamlandı.');
  }

  /// Koleksiyonu eşitler. Bulut sorgusu başarısız olduysa false döner.
  Future<bool> _koleksiyonuSenkronize(
    String uid,
    String koleksiyon,
    Map<String, dynamic> defter,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('data')
          .doc(koleksiyon)
          .get()
          .timeout(_sorguZamanAsimi);

      if (!doc.exists) return true;

      final String bulutJson = doc.data()?['json'] ?? '';
      if (bulutJson.trim().isEmpty) return true;

      final Timestamp? bulutTs = doc.data()?['updatedAt'] as Timestamp?;
      final int bulutZamani = bulutTs?.millisecondsSinceEpoch ?? 0;

      final kayit = defter[koleksiyon];
      final Map<String, dynamic> defterKaydi =
          kayit is Map ? Map<String, dynamic>.from(kayit) : <String, dynamic>{};

      final int yerelZaman = await _yerelZaman(koleksiyon);

      // Yerel dosya hiç yoksa buluttan almak her zaman doğrudur.
      if (yerelZaman == 0) {
        await _buluttanUygula(koleksiyon, bulutJson, bulutZamani, defter);
        return true;
      }

      if (defterKaydi.isEmpty) {
        // Karşılaştırma temeli yok. Dosya bu sürüme geçişten önce varsa eski
        // davranış uygulanır; sonra oluştuysa çevrimdışı yapılmış iştir.
        final int gecisZamani = defter['_migratedAt'] as int? ?? 0;
        if (yerelZaman <= gecisZamani) {
          await _buluttanUygula(koleksiyon, bulutJson, bulutZamani, defter);
        } else {
          await _cakismayiKaydet(koleksiyon, bulutJson, bulutZamani, yerelZaman, defter);
        }
        return true;
      }

      final int uygulananBulutZamani =
          defterKaydi['cloudAppliedAt'] as int? ?? 0;
      final int bilinenYerelZaman = defterKaydi['localMtime'] as int? ?? 0;

      final bool bulutDahaYeni =
          bulutZamani > uygulananBulutZamani + _zamanToleransiMs;
      final bool yerelDegismis =
          yerelZaman > bilinenYerelZaman + _zamanToleransiMs;

      // Bulutta bizim göndermediğimiz bir değişiklik yok.
      if (!bulutDahaYeni) return true;

      if (yerelDegismis) {
        await _cakismayiKaydet(
            koleksiyon, bulutJson, bulutZamani, yerelZaman, defter);
        return true;
      }

      await _buluttanUygula(koleksiyon, bulutJson, bulutZamani, defter);
      return true;
    } catch (e) {
      appLog('Senkronizasyon hatası ($koleksiyon): $e');
      return false;
    }
  }

  /// Her iki taraf da değişmişse çağrılır.
  ///
  /// Cihazdaki veri korunur (kullanıcının en son gördüğü veri odur), bulut
  /// kopyası ayrı bir dosyaya yazılır ve kullanıcı uyarılır. Böylece hiçbir
  /// taraf kaybolmaz. Temel güncellendiği için sonraki kayıtta cihazdaki veri
  /// buluta gönderilebilir.
  Future<void> _cakismayiKaydet(
    String koleksiyon,
    String bulutJson,
    int bulutZamani,
    int yerelZaman,
    Map<String, dynamic> defter,
  ) async {
    final path = await _localPath;
    final zaman = DateTime.now().millisecondsSinceEpoch;
    final kopya = File('$path/$koleksiyon.buluttan-$zaman.json');
    try {
      await kopya.writeAsString(bulutJson, flush: true);
    } catch (e) {
      appLog('Bulut kopyası yazılamadı ($koleksiyon): $e');
    }

    defter[koleksiyon] = {
      'cloudAppliedAt':
          bulutZamani > 0 ? bulutZamani : DateTime.now().millisecondsSinceEpoch,
      'localMtime': yerelZaman,
    };

    // Bilerek "sorunlu" işaretlenmez: veri sağlamdır, yalnızca iki kopya
    // ayrışmıştır. Aksi halde bu cihaz buluta bir daha hiç yazamazdı.
    final kopyaAdi = kopya.path.split(Platform.pathSeparator).last;
    _bilgilendir(
      koleksiyon,
      'Bu cihazdaki ve buluttaki veriler farklı. Cihazdaki veri korundu, '
      'bulut kopyası $kopyaAdi dosyasına kaydedildi.',
    );
  }

  Future<void> _buluttanUygula(
    String koleksiyon,
    String bulutJson,
    int bulutZamani,
    Map<String, dynamic> defter,
  ) async {
    try {
      await _writeFileAtomic(koleksiyon, bulutJson);
      defter[koleksiyon] = {
        'cloudAppliedAt': bulutZamani > 0
            ? bulutZamani
            : DateTime.now().millisecondsSinceEpoch,
        'localMtime': await _yerelZaman(koleksiyon),
      };
      appLog('$koleksiyon buluttan güncellendi.');
    } catch (e) {
      appLog('Bulut verisi uygulanamadı ($koleksiyon): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // KAYDETME / YÜKLEME
  // ---------------------------------------------------------------------------

  Future<void> saveEkipler(List<String> ekipler) =>
      _writeJson('ekipler', jsonEncode(ekipler));

  Future<List<String>> loadEkipler() async {
    final ham = await _readRaw('ekipler');
    if (ham == null) return [];
    try {
      final cozulmus = jsonDecode(ham);
      if (cozulmus is! List) return [];
      return cozulmus.map((e) => e.toString()).toList();
    } catch (e) {
      _uyar('ekipler', 'Veri çözümlenemedi: $e');
      return [];
    }
  }

  Future<void> saveProjects(List<Proje> projects) => _writeJson(
      'projects', jsonEncode(projects.map((p) => p.toJson()).toList()));

  Future<List<Proje>> loadProjects() => _readList('projects', Proje.fromJson);

  Future<void> saveTasks(List<Gorev> tasks) =>
      _writeJson('tasks', jsonEncode(tasks.map((t) => t.toJson()).toList()));

  Future<List<Gorev>> loadTasks() => _readList('tasks', Gorev.fromJson);

  Future<void> saveNotes(List<Not> notes) =>
      _writeJson('notes', jsonEncode(notes.map((n) => n.toJson()).toList()));

  Future<List<Not>> loadNotes() => _readList('notes', Not.fromJson);

  Future<void> saveReminders(List<Hatirlatici> reminders) => _writeJson(
      'reminders', jsonEncode(reminders.map((r) => r.toJson()).toList()));

  Future<List<Hatirlatici>> loadReminders() =>
      _readList('reminders', Hatirlatici.fromJson);

  Future<void> saveLocations(List<LocationItem> locations) => _writeJson(
      'locations', jsonEncode(locations.map((l) => l.toJson()).toList()));

  Future<List<LocationItem>> loadLocations() =>
      _readList('locations', LocationItem.fromJson);

  Future<void> saveFaturalar(List<Fatura> items) =>
      _writeJson('faturalar', jsonEncode(items.map((i) => i.toJson()).toList()));

  Future<List<Fatura>> loadFaturalar() =>
      _readList('faturalar', Fatura.fromJson);

  Future<void> saveHakedisler(List<Hakedis> items) => _writeJson(
      'hakedisler', jsonEncode(items.map((i) => i.toJson()).toList()));

  Future<List<Hakedis>> loadHakedisler() =>
      _readList('hakedisler', Hakedis.fromJson);

  Future<void> saveHarcamalar(List<Harcama> items) => _writeJson(
      'harcamalar', jsonEncode(items.map((i) => i.toJson()).toList()));

  Future<List<Harcama>> loadHarcamalar() =>
      _readList('harcamalar', Harcama.fromJson);

  Future<void> saveMalzemeler(List<Malzeme> items) => _writeJson(
      'malzemeler', jsonEncode(items.map((i) => i.toJson()).toList()));

  Future<List<Malzeme>> loadMalzemeler() =>
      _readList('malzemeler', Malzeme.fromJson);

  Future<void> savePratikBilgiler(List<PratikBilgi> items) => _writeJson(
      'pratik_bilgiler', jsonEncode(items.map((i) => i.toJson()).toList()));

  Future<List<PratikBilgi>> loadPratikBilgiler() =>
      _readList('pratik_bilgiler', PratikBilgi.fromJson);

  Future<void> saveProjectLogs(Map<String, List<GunlukKayit>> logs) {
    final Map<String, dynamic> jsonMap = {};
    logs.forEach((key, value) {
      jsonMap[key] = value.map((v) => v.toJson()).toList();
    });
    return _writeJson('project_logs', jsonEncode(jsonMap));
  }

  Future<Map<String, List<GunlukKayit>>> loadProjectLogs() async {
    final ham = await _readRaw('project_logs');
    if (ham == null) return {};

    final dynamic cozulmus;
    try {
      cozulmus = jsonDecode(ham);
    } catch (e) {
      _uyar('project_logs', 'Veri çözümlenemedi: $e');
      return {};
    }

    if (cozulmus is! Map) {
      _uyar('project_logs', 'Veri beklenen biçimde değil.');
      return {};
    }

    final Map<String, List<GunlukKayit>> sonuc = {};
    int atlanan = 0;
    cozulmus.forEach((key, value) {
      if (value is! List) return;
      final kayitlar = <GunlukKayit>[];
      for (final kayit in value) {
        try {
          kayitlar.add(
              GunlukKayit.fromJson(Map<String, dynamic>.from(kayit as Map)));
        } catch (e) {
          atlanan++;
          appLog('Günlük kayıt atlandı: $e');
        }
      }
      sonuc[key.toString()] = kayitlar;
    });

    if (atlanan > 0) {
      _uyar('project_logs', '$atlanan kayıt okunamadı ve atlandı.');
    }
    return sonuc;
  }

  Future<void> saveSketches(Map<String, List<dynamic>> sketches) =>
      _writeJson('sketches', jsonEncode(sketches));

  Future<Map<String, List<dynamic>>> loadSketches() async {
    final ham = await _readRaw('sketches');
    if (ham == null) return {};

    final dynamic cozulmus;
    try {
      cozulmus = jsonDecode(ham);
    } catch (e) {
      _uyar('sketches', 'Veri çözümlenemedi: $e');
      return {};
    }

    if (cozulmus is! Map) {
      _uyar('sketches', 'Veri beklenen biçimde değil.');
      return {};
    }

    final Map<String, List<dynamic>> sonuc = {};
    cozulmus.forEach((key, value) {
      if (value is List) sonuc[key.toString()] = value;
    });
    return sonuc;
  }

  // ---------------------------------------------------------------------------
  // YEDEKLEME / GERİ YÜKLEME
  // ---------------------------------------------------------------------------

  static String _dosyaZamanEki() {
    final n = DateTime.now();
    String iki(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${iki(n.month)}${iki(n.day)}_${iki(n.hour)}${iki(n.minute)}';
  }

  /// Tüm koleksiyonları tek bir JSON dosyasına yazar ve dosya yolunu döndürür.
  Future<String> exportBackup(String hedefKlasor) async {
    final Map<String, String> veri = {};
    for (final col in collections) {
      final ham = await _readRaw(col);
      if (ham != null) veri[col] = ham;
    }

    final paket = {
      'app': 'SantiyePro',
      'formatVersion': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'data': veri,
    };

    final dosya = File('$hedefKlasor/santiyepro_yedek_${_dosyaZamanEki()}.json');
    await dosya.writeAsString(jsonEncode(paket), flush: true);
    return dosya.path;
  }

  /// Yedek dosyasından geri yükler ve geri yüklenen koleksiyon sayısını döndürür.
  ///
  /// Geri yükleme öncesi mevcut veri atomik yazma sayesinde `.bak` olarak
  /// saklanır; yanlış dosya seçilse bile eski veri kaybolmaz.
  Future<int> importBackup(String dosyaYolu) async {
    final dosya = File(dosyaYolu);
    final icerik = await dosya.readAsString();
    final cozulmus = jsonDecode(icerik);

    if (cozulmus is! Map || cozulmus['data'] is! Map) {
      throw const FormatException(
          'Bu dosya geçerli bir ŞantiyePro yedeği değil.');
    }

    final veri = Map<String, dynamic>.from(cozulmus['data'] as Map);
    int geriYuklenen = 0;

    for (final girdi in veri.entries) {
      if (!collections.contains(girdi.key)) continue;
      final deger = girdi.value;
      if (deger is! String || deger.trim().isEmpty) continue;

      try {
        jsonDecode(deger); // geçerlilik kontrolü
      } catch (e) {
        appLog('Yedekteki ${girdi.key} bozuk, atlandı: $e');
        continue;
      }

      await _writeFileAtomic(girdi.key, deger);
      // Geri yüklenen koleksiyon artık sağlam kabul edilir.
      degradedCollections.remove(girdi.key);
      warnings.removeWhere((w) => w.koleksiyon == girdi.key);
      await _syncToFirestore(girdi.key, deger);
      geriYuklenen++;
    }

    return geriYuklenen;
  }

  // ---------------------------------------------------------------------------
  // ARŞİV
  // ---------------------------------------------------------------------------

  Future<void> _arsivle(String koleksiyon) async {
    final zaman = DateTime.now().millisecondsSinceEpoch;
    try {
      final file = await _getFile('$koleksiyon.json');
      if (await file.exists()) {
        final path = await _localPath;
        await file.rename('$path/${koleksiyon}_archive_$zaman.json');
      }
    } catch (e) {
      appLog('Arşivleme hatası ($koleksiyon): $e');
    }
  }

  Future<void> archiveFaturalar() => _arsivle('faturalar');

  Future<void> archiveHarcamalar() => _arsivle('harcamalar');

  Future<List<Map<String, dynamic>>> getArchives() async {
    final path = await _localPath;
    final dir = Directory(path);
    final List<Map<String, dynamic>> archives = [];

    try {
      final files = dir.listSync();
      for (var file in files) {
        if (file is! File) continue;
        final filename = file.path.split(Platform.pathSeparator).last;
        if (!filename.contains('_archive_')) continue;

        final parts = filename.split('_');
        final type = parts[0]; // faturalar veya harcamalar
        final timestampStr = parts.last.split('.').first;
        final timestamp = int.tryParse(timestampStr) ?? 0;

        archives.add({
          'filename': filename,
          'type': type == 'faturalar' ? 'Faturalar' : 'Harcamalar',
          'date': DateTime.fromMillisecondsSinceEpoch(timestamp),
          'path': file.path,
        });
      }
      archives.sort((a, b) => (b['date'] as DateTime).compareTo(a['date']));
    } catch (e) {
      appLog('Arşiv listeleme hatası: $e');
    }
    return archives;
  }

  Future<List<dynamic>> loadArchiveData(String filename) async {
    try {
      final path = await _localPath;
      final file = File('$path/$filename');
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      final cozulmus = jsonDecode(contents);
      return cozulmus is List ? cozulmus : [];
    } catch (e) {
      appLog('Arşiv yükleme hatası: $e');
      return [];
    }
  }

  @Deprecated("Use archiveFaturalar or archiveHarcamalar instead")
  Future<void> archiveFinansData() async {
    await archiveFaturalar();
    await archiveHarcamalar();
  }

  // ---------------------------------------------------------------------------
  // TEMİZLEME
  // ---------------------------------------------------------------------------

  Future<void> clearLocalData() async {
    for (final col in collections) {
      for (final ek in const ['.json', '.json.bak', '.json.tmp']) {
        try {
          final file = await _getFile('$col$ek');
          if (await file.exists()) await file.delete();
        } catch (e) {
          appLog('Silme hatası ($col$ek): $e');
        }
      }
    }
    try {
      final defter = await _getFile('sync_meta.json');
      if (await defter.exists()) await defter.delete();
    } catch (e) {
      appLog('Defter silme hatası: $e');
    }
    degradedCollections.clear();
    warnings.clear();
  }
}
