import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart'; // Just in case, though not used directly in MainScreen but Haritalar uses it
import 'models/hatirlatici.dart';
import 'models/proje.dart';
import 'models/gorev.dart';
import 'models/gunluk_kayit.dart';
import 'models/not.dart';
import 'models/fatura.dart';
import 'models/harcama.dart';
import 'models/malzeme.dart';
import 'models/pratik_bilgi.dart';
import 'screens/ana_sayfa.dart';
import 'screens/projeler_sayfa.dart';
import 'screens/gorevler_sayfa.dart';
import 'screens/notlar_sayfa.dart';
import 'screens/pratik_bilgiler_sayfa.dart';
import 'screens/takvim_sayfa.dart';
import 'screens/eskizler_sayfa.dart';
import 'screens/pomodoro_sayfa.dart';
import 'screens/haritalar_sayfa.dart';
import 'services/calendar_service.dart';


import 'screens/finans_sayfa.dart';

import 'screens/malzemeler_sayfa.dart';
import 'screens/login_sayfa.dart';
import 'widgets/custom_bottom_nav_bar.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'screens/profil_sayfa.dart';
import 'screens/splash_screen.dart';
import 'screens/ayarlar_sayfa.dart';
import 'models/app_settings.dart';
import 'services/settings_service.dart';
import 'services/update_service.dart'; // import eklendi
import 'theme/app_theme.dart';
import 'theme/theme_colors.dart';

import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  try {
    print("LOG: Starting Firebase initialization...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("LOG: Firebase initialization finished");
    
    // Windows'ta pluginlerin oturması için küçük bir bekleme ekliyoruz
    if (Platform.isWindows) {
      print("LOG: Windows detected, waiting 2 seconds for native plugins...");
      await Future.delayed(const Duration(seconds: 2));
    }
  } catch (e) {
    print("LOG: Firebase init error: $e");
  }
  
  try {
    await NotificationService().init();
    await NotificationService().requestPermissions();
  } catch (e) {
    debugPrint("Notification init error: $e");
  }
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();

  // Root state'e erişim için static metod
  static MyAppState of(BuildContext context) {
    return context.findAncestorStateOfType<MyAppState>()!;
  }
}

class MyAppState extends State<MyApp> {
  AppSettings _settings = AppSettings();
  final _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.loadSettings();
    setState(() {
      _settings = settings;
    });
  }

  void updateSettings(AppSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proje Takip',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthWrapper(),
    );
  }
}

// Animasyonlu Yükleniyor Ekranı
class _AnimatedLoadingScreen extends StatefulWidget {
  const _AnimatedLoadingScreen();

  @override
  State<_AnimatedLoadingScreen> createState() => _AnimatedLoadingScreenState();
}

class _AnimatedLoadingScreenState extends State<_AnimatedLoadingScreen> {
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _animateDots();
  }

  void _animateDots() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 6; // 0-5 arası, 5 noktaya kadar
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * (_dotCount + 1);
    
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A4D33), Color(0xFF0D2B1D)],
        ),
      ),
      child: Center(
        child: Text(
          'Yükleniyor$dots',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _splashAnimationComplete = false;
  bool _isDataReady = false;
  bool _startedLoading = false;

  void _onSplashComplete() {
    setState(() {
      _splashAnimationComplete = true;
    });
  }

  Future<void> _preloadData() async {
    if (_startedLoading) return;
    print("LOG: _preloadData started");
    _startedLoading = true;
    
    try {
      print("LOG: Syncing with cloud...");
      await StorageService().syncEverythingWithCloud();
      print("LOG: Sync complete");
    } catch (e) {
      print("LOG: Preload data error: $e");
    }
    
    if (mounted) {
      print("LOG: Setting _isDataReady to true");
      setState(() {
        _isDataReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Stream<User?>? authStream;
    try {
      if (Firebase.apps.isNotEmpty) {
        authStream = FirebaseAuth.instance.authStateChanges();
      }
    } catch (_) {}

    return StreamBuilder<User?>(
      stream: authStream,
      builder: (context, snapshot) {
        // Firebase başlatılamadıysa direkt ana ekrana git (Çevrimdışı Mod / Windows)
        try {
          // Firebase instance kontrolü (try-catch bloğu main'de hatayı yuttuğu için burada instance erişimi deneyelim)
          if (FirebaseAuth.instance.app.name == '[DEFAULT]') {
             // Erişim başarılı, devam et
          }
        } catch (e) {
          // Firebase yok, çevrimdışı mod
          debugPrint("Offline mode: Firebase not initialized.");
          if (_splashAnimationComplete) {
            return const MainScreen();
          }
          return SplashScreen(onComplete: _onSplashComplete);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen(onComplete: _onSplashComplete);
        }

        final User? user = snapshot.data;

        // Kullanıcı çıkış yaptıysa yükleme durumlarını sıfırla
        if (user == null && _isDataReady) {
          _isDataReady = false;
          _startedLoading = false;
        }

        // Giriş yapılmışsa veri yüklemeyi başlat
        if (user != null && !_isDataReady) {
          print("LOG: User logged in, but data not ready. Starting preload.");
          _preloadData();
        }

        // Durum Kontrolü ve Yönlendirme
        if (_splashAnimationComplete) {
          if (user == null) {
            return const LoginSayfa();
          } else if (_isDataReady) {
            return const MainScreen();
          } else {
            // Splash zaten bir kez oynatıldı, şimdi sadece verilerin senkronize olmasını bekliyoruz
            return Container(
              color: const Color(0xFF1A4D33), // Splash ile aynı yeşil
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white24,
                  strokeWidth: 2,
                ),
              ),
            );
          }
        }

        // Uygulama ilk açıldığında gösterilen ana animasyonlu splash
        return SplashScreen(onComplete: _onSplashComplete);
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final StorageService _storageService = StorageService();
  final SettingsService _settingsService = SettingsService();
  int _selectedIndex = 0;
  List<Hatirlatici> hatirlaticilar = [];
  List<Proje> projeler = [];
  List<Gorev> gorevler = [];
  List<Not> notlar = [];
  Map<String, List<GunlukKayit>> projeGunlukKayitlari = {};
  List<LocationItem> savedLocations = [];
  
  // Yeni Özellikler
  List<Fatura> faturalar = [];
  List<Harcama> harcamalar = [];
  List<Malzeme> malzemeler = [];
  List<PratikBilgi> customPratikBilgiler = [];

  // Ayarlar
  AppSettings _appSettings = AppSettings();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.loadSettings();
    setState(() {
      _appSettings = settings;
    });
  }

  void _onSettingsChanged(AppSettings newSettings) {
    setState(() {
      _appSettings = newSettings;
    });
    // Global temayı güncellemek için MyApp state'ini de güncelle
    if (mounted) {
      MyApp.of(context).updateSettings(newSettings);
    }
  }

  Future<void> _initializeApp() async {
    // Bildirim servisleri zaten main() içinde başlatılıyor ve izinler isteniyor.
    // Windows'ta çökme riskini azaltmak için burada tekrar çağırmıyoruz.
    await _loadSettings();
    await _loadAllData();
    
    // Uygulama tamamen açıldıktan 2 saniye sonra güncelleme kontrolü yap
    if (mounted) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) UpdateService().checkForUpdates(context);
      });
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    // Sync already handled in AuthWrapper for authenticated users
    
    final projects = await _storageService.loadProjects();
    final tasks = await _storageService.loadTasks();
    final notes = await _storageService.loadNotes();
    final reminders = await _storageService.loadReminders();
    
    // Takvimden hatırlatıcıları çek ve birleştir
    List<Hatirlatici> mergedReminders = List.from(reminders);
    try {
      final calendarService = CalendarService();
      final calReminders = await calendarService.fetchCalendarReminders();
      
      // Sadece listede olmayanları ekle (ID bazlı kontrol)
      for (var calRem in calReminders) {
        if (!mergedReminders.any((r) => r.id == calRem.id)) {
          mergedReminders.add(calRem);
        }
      }
    } catch (e) {
      debugPrint("Calendar sync error: $e");
    }



    final logs = await _storageService.loadProjectLogs();

    final locations = await _storageService.loadLocations();
    
    final loadedFaturalar = await _storageService.loadFaturalar();
    final loadedHarcamalar = await _storageService.loadHarcamalar();
    final loadedMalzemeler = await _storageService.loadMalzemeler();
    final loadedPratikBilgiler = await _storageService.loadPratikBilgiler();

    setState(() {
      projeler = projects;
      gorevler = tasks;
      notlar = notes;
      hatirlaticilar = mergedReminders;
      projeGunlukKayitlari = logs;

      savedLocations = locations;
      
      faturalar = loadedFaturalar;
      harcamalar = loadedHarcamalar;
      malzemeler = loadedMalzemeler;
      customPratikBilgiler = loadedPratikBilgiler;
      
      // Varsayılan konumlar yoksa ekle (ilk açılış)
      if (savedLocations.isEmpty) {
         savedLocations = [
           LocationItem(name: 'Evim (Timsah Arena)', latitude: 40.2208, longitude: 28.9839, type: 'Ev'),
           LocationItem(name: 'Barakfakih Şantiye', latitude: 40.2155, longitude: 29.2140, type: 'Şantiye'),
         ];
         _storageService.saveLocations(savedLocations);
      }
      
      _isLoading = false;
    });

    // Reschedule all future pending reminders to ensure they are active in the system
    for (var item in reminders) {
      if (!item.tamamlandi) {
        DateTime scheduledTime = DateTime(
          item.tarih.year,
          item.tarih.month,
          item.tarih.day,
          item.saat.hour,
          item.saat.minute,
        );
        
        if (scheduledTime.isAfter(DateTime.now())) {
          NotificationService().scheduleNotification(
            item.id.hashCode,
            item.baslik,
            item.aciklama,
            scheduledTime,
          );
        }
      }
    }
  }

  // Hatırlatıcı fonksiyonları
  Future<void> _hatirlaticiEkle(Hatirlatici yeniHatirlatici) async {
    // Hatırlatıcı eklendiği an izinleri kontrol et/iste
    await NotificationService().requestPermissions();
    
    setState(() {
      hatirlaticilar.add(yeniHatirlatici);
      _storageService.saveReminders(hatirlaticilar);
      
      // Schedule Notification
      DateTime scheduledTime = DateTime(
        yeniHatirlatici.tarih.year,
        yeniHatirlatici.tarih.month,
        yeniHatirlatici.tarih.day,
        yeniHatirlatici.saat.hour,
        yeniHatirlatici.saat.minute,
      );
      
      if (scheduledTime.isAfter(DateTime.now())) {
        NotificationService().scheduleNotification(
          yeniHatirlatici.id.hashCode,
          yeniHatirlatici.baslik,
          yeniHatirlatici.aciklama,
          scheduledTime,
        );
      }
    });
  }

  void _hatirlaticiSil(int index) {
    final hatirlatici = hatirlaticilar[index];
    setState(() {
      NotificationService().cancelNotification(hatirlatici.id.hashCode);
      hatirlaticilar.removeAt(index);
      _storageService.saveReminders(hatirlaticilar);
    });
  }

  void _hatirlaticiTamamla(int index) {
    setState(() {
      hatirlaticilar[index].tamamlandi = !hatirlaticilar[index].tamamlandi;
      _storageService.saveReminders(hatirlaticilar);
      
      if (hatirlaticilar[index].tamamlandi) {
         NotificationService().cancelNotification(hatirlaticilar[index].id.hashCode);
      } else {
         // Reschedule if uncompleted? Assuming rescheduling for original time if in future
         final item = hatirlaticilar[index];
         DateTime scheduledTime = DateTime(
            item.tarih.year,
            item.tarih.month,
            item.tarih.day,
            item.saat.hour,
            item.saat.minute,
         );
         if (scheduledTime.isAfter(DateTime.now())) {
            NotificationService().scheduleNotification(
              item.id.hashCode,
              item.baslik,
              item.aciklama,
              scheduledTime,
            );
         }
      }
    });
  }

  Future<void> _hatirlaticiDuzenle(int index, Hatirlatici yeniHatirlatici) async {
    await NotificationService().requestPermissions();
    setState(() {
      // Cancel old
      NotificationService().cancelNotification(hatirlaticilar[index].id.hashCode);
      
      hatirlaticilar[index] = yeniHatirlatici;
      _storageService.saveReminders(hatirlaticilar);
      
      // Schedule new
       DateTime scheduledTime = DateTime(
        yeniHatirlatici.tarih.year,
        yeniHatirlatici.tarih.month,
        yeniHatirlatici.tarih.day,
        yeniHatirlatici.saat.hour,
        yeniHatirlatici.saat.minute,
      );
      
      if (scheduledTime.isAfter(DateTime.now())) {
        NotificationService().scheduleNotification(
          yeniHatirlatici.id.hashCode,
          yeniHatirlatici.baslik,
          yeniHatirlatici.aciklama,
          scheduledTime,
        );
      }
    });
  }

  Future<void> _hatirlaticiErtele(int index, int gunSayisi) async {
    await NotificationService().requestPermissions();
    setState(() {
       // Cancel old
      NotificationService().cancelNotification(hatirlaticilar[index].id.hashCode);

      hatirlaticilar[index].tarih = hatirlaticilar[index].tarih.add(
        Duration(days: gunSayisi),
      );
      _storageService.saveReminders(hatirlaticilar);
      
       // Schedule new
       final item = hatirlaticilar[index];
       DateTime scheduledTime = DateTime(
        item.tarih.year,
        item.tarih.month,
        item.tarih.day,
        item.saat.hour,
        item.saat.minute,
      );
      
      if (scheduledTime.isAfter(DateTime.now())) {
        NotificationService().scheduleNotification(
          item.id.hashCode,
          item.baslik,
          item.aciklama,
          scheduledTime,
        );
      }
    });
  }

  Future<void> _hatirlaticiErteleOzel(int index, DateTime yeniTarih, TimeOfDay yeniSaat) async {
    await NotificationService().requestPermissions();
    setState(() {
       // Cancel old
      NotificationService().cancelNotification(hatirlaticilar[index].id.hashCode);

      hatirlaticilar[index].tarih = yeniTarih;
      hatirlaticilar[index].saat = yeniSaat;
      _storageService.saveReminders(hatirlaticilar);

      // Schedule new
      DateTime scheduledTime = DateTime(
        yeniTarih.year,
        yeniTarih.month,
        yeniTarih.day,
        yeniSaat.hour,
        yeniSaat.minute,
      );

      if (scheduledTime.isAfter(DateTime.now())) {
        NotificationService().scheduleNotification(
          hatirlaticilar[index].id.hashCode,
          hatirlaticilar[index].baslik,
          hatirlaticilar[index].aciklama,
          scheduledTime,
        );
      }
    });
  }

  Future<void> _hatirlaticiErteleDakika(int index, int dakika) async {
    await NotificationService().requestPermissions();
    setState(() {
       // Cancel old
      NotificationService().cancelNotification(hatirlaticilar[index].id.hashCode);

      final anlik = DateTime.now();
      final yeniZaman = anlik.add(Duration(minutes: dakika));

      hatirlaticilar[index].tarih = DateTime(yeniZaman.year, yeniZaman.month, yeniZaman.day);
      hatirlaticilar[index].saat = TimeOfDay(hour: yeniZaman.hour, minute: yeniZaman.minute);
      _storageService.saveReminders(hatirlaticilar);

      // Schedule new
      if (yeniZaman.isAfter(DateTime.now())) {
        NotificationService().scheduleNotification(
          hatirlaticilar[index].id.hashCode,
          hatirlaticilar[index].baslik,
          hatirlaticilar[index].aciklama,
          yeniZaman,
        );
      }
    });
  }

  // Proje fonksiyonları
  void _projeEkle(Proje yeniProje) {
    setState(() {
      projeler.add(yeniProje);
      _storageService.saveProjects(projeler);
    });
  }

  void _projeSil(int index) {
    setState(() {
      projeler.removeAt(index);
      _storageService.saveProjects(projeler);
    });
  }

  void _projeDuzenle(int index, Proje yeniProje) {
    setState(() {
      projeler[index] = yeniProje;
      _storageService.saveProjects(projeler);
    });
  }

  void _gunlukKayitEkle(String projeId, GunlukKayit kayit) {
    setState(() {
      if (!projeGunlukKayitlari.containsKey(projeId)) {
        projeGunlukKayitlari[projeId] = [];
      }
      
      // Güvenlik: Aynı gün için zaten kayıt var mı kontrol et
      final existingIndex = projeGunlukKayitlari[projeId]!.indexWhere(
        (k) => k.tarih.year == kayit.tarih.year && 
               k.tarih.month == kayit.tarih.month && 
               k.tarih.day == kayit.tarih.day
      );

      if (existingIndex != -1) {
        // Zaten varsa güncelle (Emanetçi çözüm)
        projeGunlukKayitlari[projeId]![existingIndex] = kayit;
      } else {
        projeGunlukKayitlari[projeId]!.add(kayit);
      }
      
      _storageService.saveProjectLogs(projeGunlukKayitlari);
      
      // Proje son güncelleme zamanını güncelle
      final index = projeler.indexWhere((p) => p.id == projeId);
      if (index != -1) {
        projeler[index].sonGuncelleme = DateTime.now();
        _storageService.saveProjects(projeler);
      }
    });
  }

  void _gunlukKayitGuncelle(String projeId, int index, GunlukKayit kayit) {
    setState(() {
      if (projeGunlukKayitlari.containsKey(projeId)) {
        projeGunlukKayitlari[projeId]![index] = kayit;
        _storageService.saveProjectLogs(projeGunlukKayitlari);

        // Proje son güncelleme zamanını güncelle
        final pIndex = projeler.indexWhere((p) => p.id == projeId);
        if (pIndex != -1) {
          projeler[pIndex].sonGuncelleme = DateTime.now();
          _storageService.saveProjects(projeler);
        }
      }
    });
  }

  // Görev fonksiyonları
  void _gorevEkle(Gorev yeniGorev) {
    setState(() {
      gorevler.add(yeniGorev);
      _storageService.saveTasks(gorevler);
    });
  }

  void _gorevSil(int index) {
    setState(() {
      gorevler.removeAt(index);
      _storageService.saveTasks(gorevler);
    });
  }

  void _gorevTamamla(int index) {
    setState(() {
      gorevler[index].tamamlandi = !gorevler[index].tamamlandi;
      _storageService.saveTasks(gorevler);
    });
  }

  void _gorevDuzenle(int index, Gorev yeniGorev) {
    setState(() {
      gorevler[index] = yeniGorev;
      _storageService.saveTasks(gorevler);
    });
  }

  // Not fonksiyonları
  void _notEkle(Not yeniNot) {
    setState(() {
      notlar.add(yeniNot);
      _storageService.saveNotes(notlar);
    });
  }

  void _notSil(int index) {
    setState(() {
      notlar.removeAt(index);
      _storageService.saveNotes(notlar);
    });
  }

  void _notDuzenle(int index, Not yeniNot) {
    setState(() {
      notlar[index] = yeniNot;
      _storageService.saveNotes(notlar);
    });
  }
  
  // Konum Fonksiyonları
  void _konumEkle(LocationItem item) {
    setState(() {
      savedLocations.add(item);
      _storageService.saveLocations(savedLocations);
    });
  }
  
  void _konumSil(int index) {
     setState(() {
       savedLocations.removeAt(index);
       _storageService.saveLocations(savedLocations);
     });
  }

  void _pratikBilgiEkle(PratikBilgi yeniBilgi) {
    setState(() {
      customPratikBilgiler.add(yeniBilgi);
      _storageService.savePratikBilgiler(customPratikBilgiler);
    });
  }

  void _pratikBilgiGuncelle(int index, PratikBilgi yeniBilgi) {
    setState(() {
      customPratikBilgiler[index] = yeniBilgi;
      _storageService.savePratikBilgiler(customPratikBilgiler);
    });
  }

  void _pratikBilgiSil(int index) {
    setState(() {
      customPratikBilgiler.removeAt(index);
      _storageService.savePratikBilgiler(customPratikBilgiler);
    });
  }

  // Finans
  void _faturaEkle(Fatura f) {
    setState(() {
      faturalar.add(f);
      _storageService.saveFaturalar(faturalar);
    });
  }

  void _faturaSil(int index) {
    setState(() {
      faturalar.removeAt(index);
      _storageService.saveFaturalar(faturalar);
    });
  }

  void _faturaGuncelle(int index, Fatura f) {
    setState(() {
      faturalar[index] = f;
      _storageService.saveFaturalar(faturalar);
    });
  }

  void _harcamaEkle(Harcama h) {
    setState(() {
      harcamalar.add(h);
      _storageService.saveHarcamalar(harcamalar);
    });
  }

  void _harcamaSil(int index) {
    setState(() {
      harcamalar.removeAt(index);
      _storageService.saveHarcamalar(harcamalar);
    });
  }

  void _harcamaGuncelle(int index, Harcama h) {
    setState(() {
      harcamalar[index] = h;
      _storageService.saveHarcamalar(harcamalar);
    });
  }

  Future<void> _hesapSifirla({required bool isArchive, bool? isFatura}) async {
    if (faturalar.isEmpty && harcamalar.isEmpty) return;

    if (isArchive) {
      // Arşivle
      if (isFatura == null || isFatura == true) {
        await _storageService.archiveFaturalar();
        setState(() {
          faturalar.clear();
          _storageService.saveFaturalar(faturalar);
        });
      }
      if (isFatura == null || isFatura == false) {
        await _storageService.archiveHarcamalar();
        setState(() {
          harcamalar.clear();
          _storageService.saveHarcamalar(harcamalar);
        });
      }
      
      if (mounted) {
        String msg = isFatura == null ? "Tüm finans verileri" : (isFatura ? "Faturalar" : "Harcamalar");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yeni hesap dönemi başlatıldı. $msg arşivlendi.'), backgroundColor: Colors.green),
        );
      }
    } else {
      // Komple Sil (Geri Alma şansı ver)
      final backupFaturalar = List<Fatura>.from(faturalar);
      final backupHarcamalar = List<Harcama>.from(harcamalar);

      setState(() {
        if (isFatura == null || isFatura == true) {
          faturalar.clear();
          _storageService.saveFaturalar(faturalar);
        }
        if (isFatura == null || isFatura == false) {
          harcamalar.clear();
          _storageService.saveHarcamalar(harcamalar);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Veriler silindi! (Geri almak için 10 saniyeniz var)', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'GERİ AL',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  if (isFatura == null || isFatura == true) {
                    faturalar = backupFaturalar;
                    _storageService.saveFaturalar(faturalar);
                  }
                  if (isFatura == null || isFatura == false) {
                    harcamalar = backupHarcamalar;
                    _storageService.saveHarcamalar(harcamalar);
                  }
                });
              },
            ),
          ),
        );
      }
    }
  }

  // Malzeme
  void _malzemeEkle(Malzeme yeniMalzeme) {
    setState(() {
      malzemeler.add(yeniMalzeme);
      _storageService.saveMalzemeler(malzemeler);
    });
  }
  
  void _malzemeGuncelle(int index, Malzeme yeniMalzeme) {
    setState(() {
      malzemeler[index] = yeniMalzeme;
      _storageService.saveMalzemeler(malzemeler);
    });
  }

  void _malzemeSil(int index) {
    setState(() {
      malzemeler.removeAt(index);
      _storageService.saveMalzemeler(malzemeler);
    });
  }

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.home, 'title': 'Ana Sayfa', 'color': Colors.cyan},
    {'icon': Icons.folder, 'title': 'Projeler', 'color': Colors.blue},
    {'icon': Icons.check_circle, 'title': 'Görevler', 'color': Colors.purple},
    {'icon': Icons.note, 'title': 'Notlar', 'color': Colors.orange},
    {'icon': Icons.lightbulb, 'title': 'Pratik Bilgiler', 'color': Colors.green},
    {'icon': Icons.calendar_today, 'title': 'Takvim', 'color': Colors.cyan},
    {'icon': Icons.attach_money, 'title': 'Faturalar', 'color': Colors.amber},
    {'icon': Icons.build, 'title': 'Malzemeler', 'color': Colors.brown},
    {'icon': Icons.brush, 'title': 'Eskizler', 'color': Colors.pink},
    {'icon': Icons.timer, 'title': 'Pomodoro', 'color': Colors.red},
    {'icon': Icons.map, 'title': 'Haritalar', 'color': Colors.teal},
    {'icon': Icons.settings, 'title': 'Ayarlar', 'color': Colors.grey},
  ];

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return AnaSayfaPage(
          hatirlaticilar: hatirlaticilar,
          projeler: projeler,
          gorevler: gorevler,
          notlar: notlar,
          onHatirlaticiEkle: _hatirlaticiEkle,
          onHatirlaticiSil: _hatirlaticiSil,
          onHatirlaticiTamamla: _hatirlaticiTamamla,
          onHatirlaticiDuzenle: _hatirlaticiDuzenle,
          onPageChange: (index) => setState(() => _selectedIndex = index),
          onRefresh: _loadAllData,
        );
      case 1:
        return ProjelerSayfaPage(
          projeler: projeler,
          onProjeEkle: _projeEkle,
          onProjeSil: _projeSil,
          onProjeDuzenle: _projeDuzenle,
          projeGunlukKayitlari: projeGunlukKayitlari,
          onGunlukKayitEkle: _gunlukKayitEkle,
          onGunlukKayitGuncelle: _gunlukKayitGuncelle,
        );
      case 2:
        return GorevlerSayfaPage(
          gorevler: gorevler,
          hatirlaticilar: hatirlaticilar,
          onGorevEkle: _gorevEkle,
          onGorevSil: _gorevSil,
          onGorevTamamla: _gorevTamamla,
          onGorevDuzenle: _gorevDuzenle,
        );
      case 3:
        return NotlarSayfaPage(
          notlar: notlar,
          onNotEkle: _notEkle,
          onNotSil: _notSil,
          onNotDuzenle: _notDuzenle,
        );
      case 4:
        return PratikBilgilerSayfaPage(
          customPratikBilgiler: customPratikBilgiler,
          onEkle: _pratikBilgiEkle,
          onGuncelle: _pratikBilgiGuncelle,
          onSil: _pratikBilgiSil,
        );
      case 5:
        return TakvimSayfaPage(
          projeler: projeler,
          projeGunlukKayitlari: projeGunlukKayitlari,
        );
      case 6: // Faturalar (Finans)
        return FinansSayfaPage(
          faturalar: faturalar,
          harcamalar: harcamalar,
          projeler: projeler,
          onFaturaEkle: _faturaEkle,
          onFaturaSil: _faturaSil,
          onFaturaGuncelle: _faturaGuncelle,
          onHarcamaEkle: _harcamaEkle,
          onHarcamaSil: _harcamaSil,
          onHarcamaGuncelle: _harcamaGuncelle,
          onHesapSifirla: (archive, {isFatura}) => _hesapSifirla(isArchive: archive, isFatura: isFatura),
        );
      case 7: // Malzemeler
        return MalzemelerSayfaPage(
          malzemeler: malzemeler,
          onMalzemeEkle: _malzemeEkle,
          onMalzemeGuncelle: _malzemeGuncelle,
          onMalzemeSil: _malzemeSil,
        );
      case 8:
        return const EskizlerSayfaPage();
      case 9:
        return const PomodoroSayfaPage();
      case 10:
        return HaritalarSayfaPage(
          savedLocations: savedLocations,
          onAddLocation: _konumEkle,
          onDeleteLocation: _konumSil,
        );
      case 11: // Ayarlar
        return AyarlarSayfaPage(
          currentSettings: _appSettings,
          onSettingsChanged: _onSettingsChanged,
        );
      default:
        return Center(
          child: Text(
            '${_menuItems[index]['title']} sayfası hazırlanıyor...',
            style: const TextStyle(fontSize: 18, color: Colors.white54),
          ),
        );
    }
  }

  List<BottomNavItem> _getBottomNavItems() {
    return _appSettings.bottomNavIndexes.map((index) {
      if (index >= 0 && index < _menuItems.length) {
        final page = _menuItems[index];
        return BottomNavItem(
          icon: page['icon'] as IconData,
          label: page['title'] as String,
          color: page['color'] as Color,
        );
      }
      // Fallback
      return const BottomNavItem(
        icon: Icons.home,
        label: 'Ana Sayfa',
        color: Colors.cyan,
      );
    }).toList();
  }

  Widget _buildSideMenu({required bool isDrawer}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: isDrawer ? 304 : 250, // Standard drawer width or fixed sidebar width
      color: ThemeColors.headerBackground(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDrawer) // App bar handles title on mobile
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'Proje Takip',
                style: TextStyle(
                  color: Colors.cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else 
            const SizedBox(height: 50), // Spacing for drawer

          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final isSelected = _selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                        if (isDrawer) {
                          Navigator.pop(context); // Close drawer
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? item['color'].withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border(
                            left: BorderSide(
                              color: isSelected ? item['color'] : Colors.transparent,
                              width: 4,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: item['color'],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                item['icon'],
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                item['title'],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : ThemeColors.textSecondary(context),
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          // Desktop Layout
          return Scaffold(
            body: Row(
              children: [
                _buildSideMenu(isDrawer: false),
                Expanded(child: _getPage(_selectedIndex)),
              ],
            ),
          );
        } else {
          // Mobile Layout
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            appBar: AppBar(
              backgroundColor: isDark ? const Color(0xFF0d0d0d) : Colors.white,
              title: Text(
                _menuItems[_selectedIndex]['title'],
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.account_circle, color: Colors.blueAccent),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilSayfa()));
                  },
                ),
              ],
            ),
            drawer: Drawer(
              backgroundColor: ThemeColors.headerBackground(context),
              child: _buildSideMenu(isDrawer: true),
            ),
            body: _getPage(_selectedIndex),
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: _appSettings.bottomNavIndexes.indexOf(_selectedIndex),
              onTap: (index) {
                setState(() => _selectedIndex = _appSettings.bottomNavIndexes[index]);
              },
              items: _getBottomNavItems(),
            ),
          );
        }
      },
    );
  }
}
