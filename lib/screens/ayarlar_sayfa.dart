import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

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
    {'index': 2, 'title': 'Görevler', 'icon': Icons.check_circle, 'color': Colors.purple},
    {'index': 3, 'title': 'Notlar', 'icon': Icons.note, 'color': Colors.orange},
    {'index': 4, 'title': 'Pratik Bilgiler', 'icon': Icons.lightbulb, 'color': Colors.green},
    {'index': 5, 'title': 'Takvim', 'icon': Icons.calendar_today, 'color': Colors.cyan},
    {'index': 6, 'title': 'Faturalar', 'icon': Icons.attach_money, 'color': Colors.amber},
    {'index': 7, 'title': 'Malzemeler', 'icon': Icons.build, 'color': Colors.brown},
    {'index': 8, 'title': 'Eskizler', 'icon': Icons.brush, 'color': Colors.pink},
    {'index': 9, 'title': 'Pomodoro', 'icon': Icons.timer, 'color': Colors.red},
    {'index': 10, 'title': 'Haritalar', 'icon': Icons.map, 'color': Colors.teal},
  ];

  @override
  void initState() {
    super.initState();
    _settings = widget.currentSettings;
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
        title: Text('Slot ${slotIndex + 1} için Sayfa Seçin', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color)),
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

          // Alt Navigasyon Ayarları
          _buildSectionTitle('Alt Navigasyon Kısayolları'),
          const SizedBox(height: 10),
          Text(
            '3 kısayol seçebilirsiniz',
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14),
          ),
          const SizedBox(height: 15),

          // 3 Slot
          ...List.generate(3, (slotIndex) {
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
                title: Text('Slot ${slotIndex + 1}', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12)),
                subtitle: Text(page['title'] as String, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.edit, color: Colors.blue),
                onTap: () => _selectBottomNavPage(slotIndex),
              ),
            );
          }),

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
          
          // Versiyon Bilgisi
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Center(
                  child: Text(
                    "Sürüm: v${snapshot.data!.version}+${snapshot.data!.buildNumber}",
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
                  ),
                );
              }
              return const SizedBox();
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
