import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profil_sayfa.dart';
import '../models/hatirlatici.dart';
import '../models/proje.dart';
import '../models/gorev.dart';
import '../models/not.dart';
import '../services/notification_service.dart';
import '../theme/theme_colors.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Bu değerler parent widget (main.dart) tarafından yönetildiği için
  // burada sadece dummy veya storage'dan okunan verileri göstereceğiz.
  // Ancak mimari gereği main.dart sayfaları yönettiği için,
  // AnaSayfaPage aslında parametre almalıydı.
  // Mevcut yapıda main.dart içindeki _getPage fonksiyonu parametre almıyor gibi görünüyor,
  // fakat main.dart'ı incelediğimizde parametre almadığını gördük (veya ben kaçırdım).
  // EĞER main.dart parametre geçmiyorsa bu sayfada veriler sıfırdan yüklenmeli veya
  // state management kullanılmalı.
  // Ancak best practice olarak main.dart güncellenmeli ve buraya veriler parametre olarak gelmeli.
  // Şimdilik storage servisi burada tekrar çağırmak yerine,
  // main.dart'taki yapıyı bozmadan stateless/stateful widget yapısına uyumlu
  // parametre alan bir AnaSayfaPage tanımlayalım ve main.dart'ı ona göre güncelleyelim.
  
  // Fakat önce dosya yapısını koruyalım. main.dart'ta AnaSayfaPage parametre alıyordu?
  // Kontrol ettiğimde main.dart'ta:
  // case 0: return AnaSayfaPage(...) şeklinde bir kullanım YOKTU,
  // sadece 'Ana Sayfa' title'ı ve içeriği vardı.
  // main.dart'ı tekrar kontrol etmemek için güvenli yol:
  // AnaSayfaPage'i parametre alacak şekilde tasarlayalım.
  
  @override
  Widget build(BuildContext context) {
      return const Center(child: Text("Hata: AnaSayfaPage doğrudan kullanılmamalı, parametreler gerekli."));
  }
}

// Doğru sınıf ismi ve parametreler
class AnaSayfaPage extends StatefulWidget {
  final List<Hatirlatici> hatirlaticilar;
  final List<Proje> projeler;
  final List<Gorev> gorevler;
  final List<Not> notlar;
  final Function(Hatirlatici) onHatirlaticiEkle;
  final Function(int) onHatirlaticiSil;
  final Function(int) onHatirlaticiTamamla;
  final Function(int, Hatirlatici) onHatirlaticiDuzenle;
  final Function(int) onPageChange;
  final Future<void> Function()? onRefresh;

  const AnaSayfaPage({
    super.key,
    required this.hatirlaticilar,
    required this.projeler,
    required this.gorevler,
    required this.notlar,
    required this.onHatirlaticiEkle,
    required this.onHatirlaticiSil,
    required this.onHatirlaticiTamamla,
    required this.onHatirlaticiDuzenle,
    required this.onPageChange,
    this.onRefresh,
  });

  @override
  State<AnaSayfaPage> createState() => _AnaSayfaPageState();
}

class _AnaSayfaPageState extends State<AnaSayfaPage> {
  bool _showCompleted = false;

  String _formatTarih(DateTime tarih) {
    final aylar = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    return '${tarih.day} ${aylar[tarih.month - 1]} ${tarih.year} ${gunler[tarih.weekday - 1]}';
  }

  String _formatSaat(TimeOfDay saat) {
    return '${saat.hour.toString().padLeft(2, '0')}:${saat.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final aktifHatirlaticilar = widget.hatirlaticilar
        .where((h) => !h.tamamlandi)
        .toList()
      ..sort((a, b) {
        int cmp = a.tarih.compareTo(b.tarih);
        if (cmp != 0) return cmp;
        return (a.saat.hour * 60 + a.saat.minute).compareTo(b.saat.hour * 60 + b.saat.minute);
      });

    final tamamlananHatirlaticilar = widget.hatirlaticilar
        .where((h) => h.tamamlandi)
        .toList()
      ..sort((a, b) {
        int cmp = b.tarih.compareTo(a.tarih);
        if (cmp != 0) return cmp;
        return (b.saat.hour * 60 + b.saat.minute).compareTo(a.saat.hour * 60 + a.saat.minute);
      });

    // Sıradaki hatırlatıcı (Gelecekteki en yakın)
    final simdi = DateTime.now();
    Hatirlatici? sonrakiHatirlatici;
    if (aktifHatirlaticilar.isNotEmpty) {
      try {
        sonrakiHatirlatici = aktifHatirlaticilar.firstWhere(
          (h) => h.tarih.isAfter(simdi.subtract(const Duration(minutes: 1))),
          orElse: () => aktifHatirlaticilar.first, 
        );
      } catch (_) {}
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return RefreshIndicator(
          onRefresh: widget.onRefresh ?? () async {},
          color: Colors.orange,
          backgroundColor: ThemeColors.cardBackground(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isMobile ? 15 : 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve Tarih
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTarih(DateTime.now()),
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.textPrimary(context),
                    ),
                  ),
                  // Profil butonu MainScreen AppBar'a taşındı.
                ],
              ),
              const SizedBox(height: 10),

              // Sıradaki Hatırlatıcı Kartı (Varsa)
              if (sonrakiHatirlatici != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade900, Colors.orange.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sıradaki Hatırlatıcı',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              sonrakiHatirlatici.baslik,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "${_formatTarih(sonrakiHatirlatici.tarih)}, ${_formatSaat(sonrakiHatirlatici.saat)}",
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
              ],

              // İstatistik Kartları (Her zaman yatay Row)
              Row(
                children: [
                  Expanded(
                    child: _buildCompactStatCard(
                      widget.projeler.where((p) => p.durum == 'Devam Ediyor').length.toString(),
                      'Projeler',
                      Icons.business,
                      Colors.blue,
                      () => widget.onPageChange(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildCompactStatCard(
                      widget.gorevler.where((g) => !g.tamamlandi).length.toString(),
                      'Görevler',
                      Icons.check_circle_outline,
                      Colors.purple,
                      () => widget.onPageChange(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildCompactStatCard(
                      widget.notlar.length.toString(),
                      'Notlar',
                      Icons.note_alt_outlined,
                      Colors.orange,
                      () => widget.onPageChange(3),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Hatırlatıcılar Başlığı ve Ekle Butonu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hatırlatıcılar',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.textPrimary(context),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _hatirlaticiEkleDialog,
                    icon: Icon(Icons.add, size: 18),
                    label: const Text('Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Aktif Hatırlatıcılar Listesi
              if (aktifHatirlaticilar.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Center(
                    child: Text(
                      'Aktif hatırlatıcı yok',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: aktifHatirlaticilar.length,
                  itemBuilder: (context, index) {
                    final hatirlatici = aktifHatirlaticilar[index];
                    // Gerçek listedeki indexi bul
                    final realIndex = widget.hatirlaticilar.indexOf(hatirlatici);
                    
                    return Dismissible(
                      key: Key(hatirlatici.id),
                      background: Container(

                        padding: const EdgeInsets.only(left: 20),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.centerLeft,
                        child: const Row(
                          children: [
                            Icon(Icons.check, color: Colors.white),
                            SizedBox(width: 10),
                            Text("Tamamla", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
              secondaryBackground: Container(
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.centerRight,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text("Sil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            SizedBox(width: 10),
                            Icon(Icons.delete, color: Colors.white),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          // Tamamla
                          widget.onHatirlaticiTamamla(realIndex);
                          return false; // Listeden oto silinmemesi için (state update ile yenilenecek)
                        } else {
                          // Sil
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: ThemeColors.cardBackground(context),
                              title: const Text('Silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('Sil'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      onDismissed: (direction) {
                        if (direction == DismissDirection.endToStart) {
                           widget.onHatirlaticiSil(realIndex);
                        }
                      },
                      child: _buildHatirlaticiKart(hatirlatici, realIndex),
                    );
                  },
                ),

              const SizedBox(height: 10),

              // Tamamlananlar Bölümü (Accordion / ExpansionTile)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(
                    "Tamamlanan Hatırlatıcılar (${tamamlananHatirlaticilar.length})",
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                  leading: const Icon(Icons.check_circle_outline, color: Colors.white54),
                  collapsedIconColor: Colors.white54,
                  iconColor: Colors.orange,
                  initiallyExpanded: _showCompleted,
                  onExpansionChanged: (val) => setState(() => _showCompleted = val),
                  children: tamamlananHatirlaticilar.map((hatirlatici) {
                     final realIndex = widget.hatirlaticilar.indexOf(hatirlatici);
                     return ListTile(
                       title: Text(
                         hatirlatici.baslik,
                         style: TextStyle(
                           color: Colors.white54,
                           decoration: TextDecoration.lineThrough,
                         ),
                       ),
                       subtitle: Text(
                         "${_formatTarih(hatirlatici.tarih)}, ${_formatSaat(hatirlatici.saat)}",
                         style: TextStyle(color: Colors.white30),
                       ),
                       trailing: IconButton(
                         icon: Icon(Icons.refresh, color: Colors.green),
                         onPressed: () => widget.onHatirlaticiTamamla(realIndex), // Geri al
                       ),
                     );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCompactStatCard(String value, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: ThemeColors.cardBackground(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHatirlaticiKart(Hatirlatici hatirlatici, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_outlined, color: Colors.orange),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hatirlatici.baslik,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ThemeColors.textPrimary(context),
                            ),
                          ),
                        ),
                        if (hatirlatici.id.startsWith('cal_'))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.withOpacity(0.5)),
                            ),
                            child: const Text(
                              'Takvim',
                              style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 5),
                    Text(
                      _formatTarih(hatirlatici.tarih),
                      style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatSaat(hatirlatici.saat),
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white54),
                color: const Color(0xFF3d3d3d),
                onSelected: (value) {
                  if (value == 'duzenle') {
                    _hatirlaticiDuzenleDialog(index, hatirlatici);
                  } else if (value == 'sil') {
                    widget.onHatirlaticiSil(index);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'duzenle',
                    child: Row(children: [Icon(Icons.edit, color: Colors.orange, size: 18), SizedBox(width: 10), Text('Düzenle', style: TextStyle(color: Colors.white))]),
                  ),
                  const PopupMenuItem(
                    value: 'sil',
                    child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 10), Text('Sil', style: TextStyle(color: Colors.white))]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(color: Colors.white10),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => widget.onHatirlaticiTamamla(index),
                icon: Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Tamamla'),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _hatirlaticiEkleDialog() {
    final mesajController = TextEditingController();
    DateTime? secilenTarih;
    TimeOfDay? secilenSaat;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: ThemeColors.cardBackground(context),
          title: const Text('Yeni Hatırlatıcı', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: mesajController,
                  style: TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Hatırlatıcı Mesajı',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  ),
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
                    );
                    if (picked != null) setState(() => secilenTarih = picked);
                  },
                  icon: Icon(Icons.calendar_today),
                  label: Text(
                    secilenTarih == null
                        ? 'Tarih Seç'
                        : '${secilenTarih!.day}/${secilenTarih!.month}/${secilenTarih!.year}',
                  ),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
                    );
                    if (picked != null) setState(() => secilenSaat = picked);
                  },
                  icon: Icon(Icons.access_time),
                  label: Text(
                    secilenSaat == null
                        ? 'Saat Seç'
                        : '${secilenSaat!.hour.toString().padLeft(2, '0')}:${secilenSaat!.minute.toString().padLeft(2, '0')}',
                  ),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (mesajController.text.isNotEmpty && secilenTarih != null && secilenSaat != null) {
                  final hatirlatici = Hatirlatici(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      baslik: mesajController.text,
                      aciklama: '',
                      tarih: secilenTarih!,
                      saat: secilenSaat!,
                    );
                  
                  widget.onHatirlaticiEkle(hatirlatici);
                  
                  // Bildirimi Zamanla
                  await NotificationService().scheduleNotification(
                    int.parse(hatirlatici.id) % 2147483647, // ID'yi int'e çevir
                    'Hatırlatıcı: ${hatirlatici.baslik}',
                    'Zamanı geldi!',
                    DateTime(
                      secilenTarih!.year,
                      secilenTarih!.month,
                      secilenTarih!.day,
                      secilenSaat!.hour,
                      secilenSaat!.minute,
                    ),
                  );

                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _hatirlaticiDuzenleDialog(int index, Hatirlatici hatirlatici) {
    final mesajController = TextEditingController(text: hatirlatici.baslik);
    DateTime? secilenTarih = hatirlatici.tarih;
    TimeOfDay? secilenSaat = hatirlatici.saat;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: ThemeColors.cardBackground(context),
          title: const Text('Hatırlatıcıyı Düzenle', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: mesajController,
                  style: TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Hatırlatıcı Mesajı',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: secilenTarih,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
                    );
                    if (picked != null) setState(() => secilenTarih = picked);
                  },
                  icon: Icon(Icons.calendar_today),
                  label: Text('${secilenTarih!.day}/${secilenTarih!.month}/${secilenTarih!.year}'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: secilenSaat!,
                      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
                    );
                    if (picked != null) setState(() => secilenSaat = picked);
                  },
                  icon: Icon(Icons.access_time),
                  label: Text('${secilenSaat!.hour.toString().padLeft(2, '0')}:${secilenSaat!.minute.toString().padLeft(2, '0')}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (mesajController.text.isNotEmpty) {
                  widget.onHatirlaticiDuzenle(
                    index,
                    Hatirlatici(
                      id: hatirlatici.id,
                      baslik: mesajController.text,
                      aciklama: hatirlatici.aciklama,
                      tarih: secilenTarih!,
                      saat: secilenSaat!,
                      tamamlandi: hatirlatici.tamamlandi,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }
}
