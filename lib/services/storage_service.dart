import 'dart:convert';
import 'dart:io';
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
import '../models/harcama.dart';
import '../models/malzeme.dart';
import '../models/pratik_bilgi.dart';

class StorageService {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _getFile(String filename) async {
    final path = await _localPath;
    return File('$path/$filename');
  }

  Future<void> saveProjects(List<Proje> projects) async {
    final file = await _getFile('projects.json');
    final String jsonString = jsonEncode(projects.map((p) => p.toJson()).toList());
    await file.writeAsString(jsonString);
    await _syncToFirestore('projects', jsonString);
  }

  Future<void> _syncToFirestore(String collection, String data) async {
    if (Firebase.apps.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('data').doc(collection);
      await docRef.set({'json': data, 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  Future<List<Proje>> loadProjects() async {
    try {
      final file = await _getFile('projects.json');
      if (!await file.exists()) return [];
      final String contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((j) => Proje.fromJson(j)).toList();
    } catch (e) {
      print('Proje yükleme hatası: $e');
      return [];
    }
  }

  Future<void> saveTasks(List<Gorev> tasks) async {
    final file = await _getFile('tasks.json');
    final String jsonString = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await file.writeAsString(jsonString);
    await _syncToFirestore('tasks', jsonString);
  }

  Future<List<Gorev>> loadTasks() async {
    try {
      final file = await _getFile('tasks.json');
      if (!await file.exists()) return [];
      final String contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((j) => Gorev.fromJson(j)).toList();
    } catch (e) {
      print('Görev yükleme hatası: $e');
      return [];
    }
  }

  Future<void> saveNotes(List<Not> notes) async {
    final file = await _getFile('notes.json');
    final String jsonString = jsonEncode(notes.map((n) => n.toJson()).toList());
    await file.writeAsString(jsonString);
    await _syncToFirestore('notes', jsonString);
  }

  Future<List<Not>> loadNotes() async {
    try {
      final file = await _getFile('notes.json');
      if (!await file.exists()) return [];
      final String contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((j) => Not.fromJson(j)).toList();
    } catch (e) {
      print('Not yükleme hatası: $e');
      return [];
    }
  }

  Future<void> saveReminders(List<Hatirlatici> reminders) async {
    final file = await _getFile('reminders.json');
    final String jsonString = jsonEncode(reminders.map((r) => r.toJson()).toList());
    await file.writeAsString(jsonString);
    await _syncToFirestore('reminders', jsonString);
  }

  Future<List<Hatirlatici>> loadReminders() async {
    try {
      final file = await _getFile('reminders.json');
      if (!await file.exists()) return [];
      final String contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((j) => Hatirlatici.fromJson(j)).toList();
    } catch (e) {
      print('Hatırlatıcı yükleme hatası: $e');
      return [];
    }
  }

  Future<void> saveLocations(List<LocationItem> locations) async {
    final file = await _getFile('locations.json');
    final String jsonString = jsonEncode(locations.map((l) => l.toJson()).toList());
    await file.writeAsString(jsonString);
    await _syncToFirestore('locations', jsonString);
  }

  Future<List<LocationItem>> loadLocations() async {
    try {
      final file = await _getFile('locations.json');
      if (!await file.exists()) return [];
      final String contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((j) => LocationItem.fromJson(j)).toList();
    } catch (e) {
      print('Konum yükleme hatası: $e');
      return [];
    }
  }

  Future<void> saveProjectLogs(Map<String, List<GunlukKayit>> logs) async {
    final file = await _getFile('project_logs.json');
    final Map<String, dynamic> jsonMap = {};
    logs.forEach((key, value) {
      jsonMap[key] = value.map((v) => v.toJson()).toList();
    });
    final String jsonString = jsonEncode(jsonMap);
    await file.writeAsString(jsonString);
    await _syncToFirestore('project_logs', jsonString);
  }

  Future<Map<String, List<GunlukKayit>>> loadProjectLogs() async {
    try {
      final file = await _getFile('project_logs.json');
      if (!await file.exists()) return {};
      final String contents = await file.readAsString();
      final Map<String, dynamic> jsonMap = jsonDecode(contents);
      
      final Map<String, List<GunlukKayit>> result = {};
      jsonMap.forEach((key, value) {
        if (value is List) {
          result[key] = value.map((v) => GunlukKayit.fromJson(v)).toList();
        }
      });
      return result;
    } catch (e) {
      print('Günlük kayıt yükleme hatası: $e');
      return {};
    }
  }

  Future<void> saveSketches(Map<String, List<dynamic>> sketches) async {
    final file = await _getFile('sketches.json');
    final String jsonString = jsonEncode(sketches);
    await file.writeAsString(jsonString);
    await _syncToFirestore('sketches', jsonString);
  }

  Future<Map<String, List<dynamic>>> loadSketches() async {
    try {
      final file = await _getFile('sketches.json');
      if (!await file.exists()) return {};
      final String contents = await file.readAsString();
      final Map<String, dynamic> jsonMap = jsonDecode(contents);
      
      final Map<String, List<dynamic>> result = {};
      jsonMap.forEach((key, value) {
        if (value is List) {
          result[key] = value;
        }
      });
      return result;
    } catch (e) {
      print('Eskiz yükleme hatası: $e');
      return {};
    }
  }

  // --- FATURA ---
  Future<void> saveFaturalar(List<Fatura> items) async {
    final file = await _getFile('faturalar.json');
    final String jsonString = jsonEncode(items.map((i) => i.toJson()).toList());
    await file.writeAsString(jsonString);
    await _syncToFirestore('faturalar', jsonString);
  }

  Future<List<Fatura>> loadFaturalar() async {
    try {
      final file = await _getFile('faturalar.json');
      if (!await file.exists()) return [];
      final String contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((j) => Fatura.fromJson(j)).toList();
    } catch (e) {
      print('Fatura yükleme hatası: $e');
      return [];
    }
  }

  // --- HARCAMA ---
  Future<void> saveHarcamalar(List<Harcama> items) async {
    final file = await _getFile('harcamalar.json');
    final String jsonString = jsonEncode(items.map((i) => i.toJson()).toList());
    await file.writeAsString(jsonString);
    await _syncToFirestore('harcamalar', jsonString);
  }

  Future<List<Harcama>> loadHarcamalar() async {
    try {
      final file = await _getFile('harcamalar.json');
      if (!await file.exists()) return [];
      final String contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((j) => Harcama.fromJson(j)).toList();
    } catch (e) {
      print('Harcama yükleme hatası: $e');
      return [];
    }
  }

  // --- MALZEME ---
  Future<void> saveMalzemeler(List<Malzeme> items) async {
    final file = await _getFile('malzemeler.json');
    final String jsonString = jsonEncode(items.map((i) => i.toJson()).toList());
    await file.writeAsString(jsonString);
    await _syncToFirestore('malzemeler', jsonString);
  }

  Future<List<Malzeme>> loadMalzemeler() async {
    try {
      final file = await _getFile('malzemeler.json');
      if (!await file.exists()) return [];
      final String contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((j) => Malzeme.fromJson(j)).toList();
    } catch (e) {
      print('Malzeme yükleme hatası: $e');
      return [];
    }
  }

  // --- PRATİK BİLGİ ---
  Future<void> savePratikBilgiler(List<PratikBilgi> items) async {
    final file = await _getFile('pratik_bilgiler.json');
    final String jsonString = jsonEncode(items.map((i) => i.toJson()).toList());
    await file.writeAsString(jsonString);
    await _syncToFirestore('pratik_bilgiler', jsonString);
  }

  Future<List<PratikBilgi>> loadPratikBilgiler() async {
    try {
      final file = await _getFile('pratik_bilgiler.json');
      if (!await file.exists()) return [];
      final String contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((j) => PratikBilgi.fromJson(j)).toList();
    } catch (e) {
      print('Pratik Bilgi yükleme hatası: $e');
      return [];
    }
  }

  // --- FULL CLOUD SYNC ---
  Future<void> syncEverythingWithCloud() async {
    // Firebase başlatılmadıysa senkronizasyon yapma (Windows/Offline)
    if (Firebase.apps.isEmpty) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final collections = [
      'projects', 'tasks', 'notes', 'reminders', 'locations', 
      'project_logs', 'sketches', 'faturalar', 'harcamalar', 
      'malzemeler', 'pratik_bilgiler'
    ];

    try {
      print("LOG: Starting parallel sync for ${collections.length} collections");
      // Tüm fetch işlemlerini paralel başlatıyoruz
      final syncTasks = collections.map((col) async {
        try {
          print("LOG: Syncing collection: $col");
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('data')
              .doc(col)
              .get()
              .timeout(const Duration(seconds: 4)); // Her biri için ayrı timeout

          if (doc.exists) {
            final String cloudJson = doc.data()?['json'] ?? '';
            if (cloudJson.isNotEmpty) {
              final file = await _getFile('$col.json');
              await file.writeAsString(cloudJson);
              print("LOG: Collection $col sync successful");
            } else {
              print("LOG: Collection $col is empty in cloud");
            }
          } else {
            print("LOG: Collection $col does not exist in cloud");
          }
        } catch (e) {
          print("LOG: Sync error for $col: $e");
        }
      });

      // Toplamda en fazla 5 saniye bekle, sonra devam et
      await Future.wait(syncTasks).timeout(const Duration(seconds: 5));
    } catch (e) {
      print("Global sync timeout or error: $e");
    }
  }

  // --- CLOUD SYNC ---
  // ... (previous methods)

  // --- ARCHIVE DATA ---
  Future<void> archiveFaturalar() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      final file = await _getFile('faturalar.json');
      if (await file.exists()) {
        final path = await _localPath;
        await file.rename('$path/faturalar_archive_$timestamp.json');
      }
    } catch (e) {
      print("Fatura arşivleme hatası: $e");
    }
  }

  Future<void> archiveHarcamalar() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      final file = await _getFile('harcamalar.json');
      if (await file.exists()) {
        final path = await _localPath;
        await file.rename('$path/harcamalar_archive_$timestamp.json');
      }
    } catch (e) {
      print("Harcama arşivleme hatası: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getArchives() async {
    final path = await _localPath;
    final dir = Directory(path);
    final List<Map<String, dynamic>> archives = [];
    
    try {
      final files = dir.listSync();
      for (var file in files) {
        if (file is File) {
          final filename = file.path.split(Platform.pathSeparator).last;
          if (filename.contains('_archive_')) {
            final parts = filename.split('_');
            final type = parts[0]; // faturalar or harcamalar
            final timestampStr = parts.last.split('.').first;
            final timestamp = int.tryParse(timestampStr) ?? 0;
            
            archives.add({
              'filename': filename,
              'type': type == 'faturalar' ? 'Faturalar' : 'Harcamalar',
              'date': DateTime.fromMillisecondsSinceEpoch(timestamp),
              'path': file.path,
            });
          }
        }
      }
      archives.sort((a, b) => (b['date'] as DateTime).compareTo(a['date']));
    } catch (e) {
      print("Arşiv listeleme hatası: $e");
    }
    return archives;
  }

  Future<List<dynamic>> loadArchiveData(String filename) async {
    try {
      final path = await _localPath;
      final file = File('$path/$filename');
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      return jsonDecode(contents);
    } catch (e) {
      print("Arşiv yükleme hatası: $e");
      return [];
    }
  }

  @Deprecated("Use archiveFaturalar or archiveHarcamalar instead")
  Future<void> archiveFinansData() async {
    await archiveFaturalar();
    await archiveHarcamalar();
  }

  // --- CLEAR LOCAL DATA ---
  Future<void> clearLocalData() async {
    final collections = [
      'projects', 'tasks', 'notes', 'reminders', 'locations', 
      'project_logs', 'sketches', 'faturalar', 'harcamalar', 
      'malzemeler', 'pratik_bilgiler'
    ];

    for (var col in collections) {
      try {
        final file = await _getFile('$col.json');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print("Error clearing $col: $e");
      }
    }
  }
}
