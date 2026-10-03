import 'package:flutter/material.dart';
import '../theme/theme_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';

class AyarlarSayfaPage extends StatefulWidget {
  final AppSettings currentSettings;
  final Function(AppSettings) onSettingsChanged;

  const AyarlarSayfaPage({
    super.key,
    required this.currentSettings,
    required this.onSettingsChanged,
  });

  @override
  State<AyarlarSayfaPage> createState() => _AyarlarSayfaPageState();
}

class _AyarlarSayfaPageState extends State<AyarlarSayfaPage> {
  late AppSettings _settings;
  final _settingsService = SettingsService();

  // Tüm mevcut sayfalar
  final List<Map<String, dynamic>> _availablePages = [
    {'index': 0, 'title': 'Ana Sayfa', 'icon': Icons.home, 'color': Colors.cyan},
    {'index': 1, 'title': 'Projeler', 'icon': Icons.folder, 'color': Colors.blue},
    {'index': 2, 'title': 'Yevmiyeler', 'icon': Icons.payments, 'color': Colors.purple},
    {'index': 3, 'title': 'Görevler', 'icon': Icons.check_circle, 'color': Colors.purple},
    {'index': 4, 'title': 'Notlar', 'icon': Icons.note, 'color': Colors.orange},
    {'index': 5, 'title': 'Pratik Bilgiler', 'icon': Icons.lightbulb, 'color': Colors.green},
    {'index': 6, 'title': 'Takvim', 'icon': Icons.calendar_today, 'color': Colors.cyan},
    {'index': 7, 'title': 'Faturalar', 'icon': Icons.attach_money, 'color': Colors.amber},
    {'index': 8, 'title': 'Yemek', 'icon': Icons.restaurant, 'color': Colors.orangeAccent},
    {'index': 9, 'title': 'Malzemeler', 'icon': Icons.build, 'color': Colors.brown},
    {'index': 10, 'title': 'Eskizler', 'icon': Icons.brush, 'color': Colors.pink},
    {'index': 11, 'title': 'Pomodoro', 'icon': Icons.timer, 'color': Colors.red},
    {'index': 12, 'title': 'Haritalar', 'icon': Icons.map, 'color': Colors.teal},
    {'index': 13, 'title': 'Günlük Rapor', 'icon': Icons.description, 'color': Colors.indigo},
  ];

  @override
  void initState() {
    super.initState();
    _settings = widget.currentSettings;
  }

  final _storageService = StorageService();
  bool _yedeklemeCalisiyor = false;

  void _bilgiGoster(String mesaj, Color renk) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: renk,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Tüm verileri tek bir JSON dosyası olarak kullanıcının seçtiği klasöre yazar.
  Future<void> _yedekAl() async {
    final klasor = await FilePicker.platform.getDirectoryPath();
    if (klasor == null) return;

    setState(() => _yedeklemeCalisiyor = true);
    try {
      final yol = await _storageService.exportBackup(klasor);
      final dosyaAdi = yol.split(RegExp(r'[\\/]')).last;
      _bilgiGoster('Yedek oluşturuldu: $dosyaAdi', Colors.green);
    } catch (e) {
      _bilgiGoster('Yedek alınamadı: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _yedeklemeCalisiyor = false);
    }
  }

  /// Yedek dosyasından geri yükler. Mevcut veri üzerine yazılacağı için önce onay alınır.
  Future<void> _yedektenGeriYukle() async {
    final secim = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final yol = secim?.files.single.path;
    if (yol == null) return;

    if (!mounted) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yedekten Geri Yükle'),
        content: const Text(
          'Bu işlem cihazdaki mevcut verilerin üzerine yazar ve yedekteki '
          'veriyi buluta gönderir.\n\nMevcut verilerinizin bir kopyası '
          'otomatik olarak saklanır, ancak yine de devam etmeden önce yeni '
          'bir yedek almanız önerilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Geri Yükle'),
          ),
        ],
      ),
    );

    if (onay != true) return;

    setState(() => _yedeklemeCalisiyor = true);
    try {
      final sayi = await _storageService.importBackup(yol);
      _bilgiGoster(
        '$sayi veri grubu geri yüklendi. Değişikliklerin görünmesi için '
        'uygulamayı yeniden başlatın.',
        Colors.green,
      );
    } catch (e) {
      _bilgiGoster('Geri yükleme başarısız: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _yedeklemeCalisiyor = false);
    }
  }

  Future<void> _saveSettings() async {
    await _settingsService.saveSettings(_settings);
    widget.onSettingsChanged(_settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ayarlar kaydedildi'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _selectBottomNavPage(int slotIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('${slotIndex + 1}. kısayol için sayfa seçin', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availablePages.length,
            itemBuilder: (context, index) {
              final page = _availablePages[index];
              final isSelected = _settings.bottomNavIndexes.contains(page['index']);
              
              return ListTile(
                leading: Icon(page['icon'] as IconData, color: page['color'] as Color),
                title: Text(page['title'] as String, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() {
                    List<int> newIndexes = List.from(_settings.bottomNavIndexes);
                    newIndexes[slotIndex] = page['index'] as int;
                    _settings = _settings.copyWith(bottomNavIndexes: newIndexes);
                  });
                  Navigator.pop(context);
                  _saveSettings();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }

  void _sehirSecDialog(BuildContext context) {
    final controller = TextEditingController(text: _settings.sehir);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Şehir Seçin', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            hintText: 'Şehir adı girin (Örn: Bursa)',
            hintStyle: TextStyle(color: ThemeColors.textTertiary(context)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: ThemeColors.textTertiary(context)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _settings = _settings.copyWith(sehir: controller.text.trim());
                });
                _saveSettings();
              }
              Navigator.pop(context);
            },
            child: const Text('Kaydet', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Başlık
          Text(
            'Ayarlar',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 30),

          // Tema Ayarları
          _buildSectionTitle('Görünüm'),
          Card(
            child: SwitchListTile(
              title: Text('Koyu Tema', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              subtitle: Text(
                _settings.isDarkMode ? 'Aktif' : 'Kapalı',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
              value: _settings.isDarkMode,
              activeColor: Colors.blue,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(isDarkMode: value);
                });
                _saveSettings();
              },
              secondary: Icon(
                _settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: _settings.isDarkMode ? Colors.blue : Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Hava Durumu Ayarları
          _buildSectionTitle('Hava Durumu Bildirimi'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.wb_sunny_outlined, color: Colors.amber),
              title: Text('Şehir', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              subtitle: Text(
                _settings.sehir.isEmpty ? 'Seçilmedi (Varsayılan: Bursa)' : _settings.sehir,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
              trailing: const Icon(Icons.edit, color: Colors.blue),
              onTap: () => _sehirSecDialog(context),
            ),
          ),
          const SizedBox(height: 30),

          // Alt Navigasyon Ayarları
          _buildSectionTitle('Alt Navigasyon Kısayolları'),
          const SizedBox(height: 10),
          Text(
            '${AppSettings.kisayolSayisi} kısayol seçebilirsiniz',
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14),
          ),
          const SizedBox(height: 15),

          // Kısayol yerleri
          ...List.generate(AppSettings.kisayolSayisi, (slotIndex) {
            final pageIndex = _settings.bottomNavIndexes[slotIndex];
            final page = _availablePages.firstWhere((p) => p['index'] == pageIndex);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (page['color'] as Color).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(page['icon'] as IconData, color: page['color'] as Color),
                ),
                title: Text('${slotIndex + 1}. kısayol', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12)),
                subtitle: Text(page['title'] as String, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.edit, color: Colors.blue),
                onTap: () => _selectBottomNavPage(slotIndex),
              ),
            );
          }),

          const SizedBox(height: 30),

          // Yedekleme
          _buildSectionTitle('Veri Yedekleme'),
          const SizedBox(height: 10),
          Text(
            'Tüm projeler, günlük kayıtlar, faturalar ve notlar tek bir dosyaya '
            'yazılır. Dosyayı bilgisayarınızda veya bulut sürücünüzde saklayın.',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),
          Card(
            child: ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.green),
              title: Text(
                'Yedek Al',
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              subtitle: Text(
                'Verileri bir klasöre kaydet',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
              trailing: _yedeklemeCalisiyor
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _yedeklemeCalisiyor ? null : _yedekAl,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore_page, color: Colors.orange),
              title: Text(
                'Yedekten Geri Yükle',
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              subtitle: Text(
                'Mevcut verilerin üzerine yazar',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _yedeklemeCalisiyor ? null : _yedektenGeriYukle,
            ),
          ),

          const SizedBox(height: 30),

          // Varsayılana Dön
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _settings = AppSettings(); // Varsayılan ayarlar
              });
              _saveSettings();
            },
            icon: const Icon(Icons.restore),
            label: const Text('Varsayılan Ayarlara Dön'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Versiyon Bilgisi ve Manuel Güncelleme Kontrolü
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final versionText = snapshot.hasData
                  ? "Sürüm: v${snapshot.data!.version}+${snapshot.data!.buildNumber}"
                  : "";
              return Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      UpdateService().checkForUpdates(context, showSnackBarIfUpdated: true);
                    },
                    icon: const Icon(Icons.system_update, color: Colors.blue),
                    label: const Text('Güncellemeleri Kontrol Et'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (versionText.isNotEmpty)
                    Text(
                      versionText,
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
    );
  }
}
