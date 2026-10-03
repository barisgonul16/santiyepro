import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profil_sayfa.dart';
import '../models/hatirlatici.dart';
import '../models/proje.dart';
import '../models/gorev.dart';
import '../models/not.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../models/gunluk_kayit.dart';
import 'proje_detay_sayfa.dart';
import 'package:intl/intl.dart';
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
  /// Buluttan eşitleyip verileri yeniden yükler.
  final Future<void> Function()? onRefresh;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;
  final List<String> ekipler;
  final Function(String, GunlukKayit) onGunlukKayitEkle;
  final Function(String, int, GunlukKayit) onGunlukKayitGuncelle;

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
    required this.projeGunlukKayitlari,
    required this.ekipler,
    required this.onGunlukKayitEkle,
    required this.onGunlukKayitGuncelle,
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

    final aktifProjeler = widget.projeler.where((p) => p.durum != 'Tamamlandı').toList();
    // 3-30 gündür kaydı olmayan devam eden şantiyeler. Daha uzun süredir
    // kayıt girilmeyen (fiilen durmuş) şantiyeler uyarıyı kalabalıklaştırmasın.
    final kayitsizlar = aktifProjeler.where((p) {
      final fark = _gunFarki(_sonKayit(p)?.tarih);
      return p.kayitHatirlatma && fark != null && fark >= _uyariGunSiniri && fark <= 30;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return RefreshIndicator(
          onRefresh: _yenile,
          color: Colors.orange,
          backgroundColor: ThemeColors.cardBackground(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isMobile ? 14 : 30),
          child: Center(
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık: tarih ve bulut durumu
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatTarih(DateTime.now()),
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                  ),
                  _buildBulutGostergesi(),
                ],
              ),
              const SizedBox(height: 14),

              // Bugünün kaydı
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: aktifProjeler.isEmpty ? null : () => _bugununKaydiSec(aktifProjeler),
                  icon: const Icon(Icons.add_circle_outline, size: 24),
                  label: const Text('Bugünün kaydını gir', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Kayıt girilmeyen şantiyeler uyarısı
              if (kayitsizlar.isNotEmpty) ...[
                _buildKayitUyarisi(kayitsizlar, aktifProjeler),
                const SizedBox(height: 12),
              ],

              // Devam eden şantiyeler
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Devam eden şantiyeler',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ThemeColors.textPrimary(context)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onPageChange(1),
                    child: Text('Tümü (${widget.projeler.length})'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (aktifProjeler.isEmpty)
                _bosKutu('Devam eden şantiye yok')
              else
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: ThemeColors.cardBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < aktifProjeler.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: ThemeColors.divider(context)),
                        _buildSantiyeSatiri(aktifProjeler[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 20),

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

              // Hatırlatıcılar Başlığı ve Ekle Butonu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hatırlatıcılar',
                    style: TextStyle(
                      fontSize: 18,
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
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ThemeColors.cardBackground(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ThemeColors.border(context)),
                  ),
                    child: Text(
                      'Yaklaşan hatırlatıcı yok',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 16),
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
                    style: TextStyle(color: ThemeColors.textSecondary(context), fontWeight: FontWeight.bold),
                  ),
                  leading: Icon(Icons.check_circle_outline, color: ThemeColors.textTertiary(context)),
                  collapsedIconColor: ThemeColors.textTertiary(context),
                  iconColor: Colors.orange,
                  initiallyExpanded: _showCompleted,
                  onExpansionChanged: (val) => setState(() => _showCompleted = val),
                  children: tamamlananHatirlaticilar.map((hatirlatici) {
                     final realIndex = widget.hatirlaticilar.indexOf(hatirlatici);
                     return ListTile(
                       title: Text(
                         hatirlatici.baslik,
                         style: TextStyle(
                           color: ThemeColors.textTertiary(context),
                           decoration: TextDecoration.lineThrough,
                         ),
                       ),
                       subtitle: Text(
                         "${_formatTarih(hatirlatici.tarih)}, ${_formatSaat(hatirlatici.saat)}",
                         style: TextStyle(color: ThemeColors.textTertiary(context).withOpacity(0.7)),
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
          ),
          ),
        );
      },
    );
  }

  // --- Şantiyeler, bugünün kaydı ve bulut göstergesi ---

  static const _aylarKisa = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  /// Bu kadar gün kayıt girilmeyen şantiye için ana sayfada uyarı çıkar.
  static const int _uyariGunSiniri = 3;

  bool _yenileniyor = false;

  /// Buluttan eşitleyip ekranı yeniler (bulut düğmesi ve aşağı çekme).
  Future<void> _yenile() async {
    if (_yenileniyor) return;
    setState(() => _yenileniyor = true);
    try {
      await widget.onRefresh?.call();
    } finally {
      if (mounted) setState(() => _yenileniyor = false);
    }
  }

  GunlukKayit? _sonKayit(Proje p) {
    GunlukKayit? son;
    for (final k in widget.projeGunlukKayitlari[p.id] ?? const <GunlukKayit>[]) {
      if (son == null || k.tarih.isAfter(son.tarih)) son = k;
    }
    return son;
  }

  /// Bugünden kaç gün önce (0 = bugün). Kayıt yoksa null.
  int? _gunFarki(DateTime? t) {
    if (t == null) return null;
    final b = DateTime.now();
    return DateTime(b.year, b.month, b.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  }

  Widget _buildBulutGostergesi() {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: StorageService.sonEsitleme,
      builder: (context, son, _) {
        IconData ikon;
        Color renk;
        String metin;
        if (StorageService.bulutKapali) {
          ikon = Icons.cloud_off;
          renk = ThemeColors.textTertiary(context);
          metin = 'Bulut kapalı';
        } else if (son == null) {
          ikon = Icons.cloud_off;
          renk = Colors.orangeAccent;
          metin = 'Eşitlenmedi';
        } else if (StorageService.sonEsitlemeEksik || StorageService.degradedCollections.isNotEmpty) {
          ikon = Icons.cloud_sync;
          renk = Colors.orangeAccent;
          metin = 'Eksik ${DateFormat('HH:mm').format(son)}';
        } else {
          ikon = Icons.cloud_done;
          renk = Colors.greenAccent;
          metin = DateFormat('HH:mm').format(son);
        }
        return Tooltip(
          message: 'Bulutla son eşitleme. Dokunarak yenile.',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _yenileniyor ? null : _yenile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: renk.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_yenileniyor)
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: renk))
                  else
                    Icon(ikon, size: 18, color: renk),
                  const SizedBox(width: 6),
                  Text(_yenileniyor ? 'Eşitleniyor' : metin, style: TextStyle(color: renk, fontSize: 13)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _projeyiAc(Proje proje, {int sekme = 0}) {
    final kayitlar = widget.projeGunlukKayitlari[proje.id] ?? <GunlukKayit>[];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjeDetaySayfa(
          proje: proje,
          gunlukKayitlar: kayitlar,
          onKayitEkle: (kayit) => widget.onGunlukKayitEkle(proje.id, kayit),
          onKayitGuncelle: (i, kayit) => widget.onGunlukKayitGuncelle(proje.id, i, kayit),
          projeGunlukKayitlari: widget.projeGunlukKayitlari,
          ekipler: widget.ekipler,
          baslangicSekmesi: sekme,
        ),
      ),
    );
  }

  /// Tek şantiye varsa doğrudan, yoksa seçtirerek bugünün formunu açar.
  void _bugununKaydiSec(List<Proje> aktifProjeler) {
    if (aktifProjeler.length == 1) {
      _projeyiAc(aktifProjeler.first, sekme: 1);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.cardBackground(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Hangi şantiye?',
                    style: TextStyle(color: ThemeColors.textPrimary(ctx), fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              for (final p in aktifProjeler)
                ListTile(
                  leading: Icon(
                    _gunFarki(_sonKayit(p)?.tarih) == 0 ? Icons.check_circle : Icons.construction,
                    color: _gunFarki(_sonKayit(p)?.tarih) == 0 ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  title: Text(p.ad, style: TextStyle(color: ThemeColors.textPrimary(ctx), fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _gunFarki(_sonKayit(p)?.tarih) == 0 ? 'Bugünün kaydı girilmiş' : _sonKayitMetni(p),
                    style: TextStyle(color: ThemeColors.textSecondary(ctx)),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _projeyiAc(p, sekme: 1);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _sonKayitMetni(Proje p) {
    final son = _sonKayit(p);
    if (son == null) return 'Henüz kayıt yok';
    final fark = _gunFarki(son.tarih)!;
    if (fark == 0) return 'Son kayıt bugün';
    if (fark == 1) return 'Son kayıt dün';
    return 'Son kayıt ${son.tarih.day} ${_aylarKisa[son.tarih.month - 1]} ($fark gün önce)';
  }

  Widget _buildKayitUyarisi(List<Proje> kayitsizlar, List<Proje> aktifProjeler) {
    final enAz = kayitsizlar.map((p) => _gunFarki(_sonKayit(p)?.tarih)!).reduce((a, b) => a < b ? a : b);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _bugununKaydiSec(aktifProjeler),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${kayitsizlar.length} şantiyede $enAz gündür kayıt girilmedi',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kayitsizlar.map((p) => p.ad).join(', '),
                    style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSantiyeSatiri(Proje p) {
    final son = _sonKayit(p);
    final fark = _gunFarki(son?.tarih);
    // Yeşil: bugün/dün, turuncu: birkaç gündür yok, gri: bir aydan uzun
    // süredir yok ya da hiç yok.
    final renk = fark == null || fark > 30 || (!p.kayitHatirlatma && fark > 1)
        ? ThemeColors.textTertiary(context)
        : (fark <= 1 ? Colors.greenAccent : Colors.amber);
    final ekip = son == null
        ? ''
        : [
            if (son.kalipci > 0) '${son.kalipci} kalıpçı',
            if (son.demirci > 0) '${son.demirci} demirci',
            if (son.diger > 0) '${son.diger} diğer',
          ].join(', ');
    final altSatir = [
      if (p.aciklama.trim().isNotEmpty) p.aciklama.trim(),
      if (ekip.isNotEmpty) ekip,
    ].join(' · ');
    final tarihMetni = son == null
        ? 'kayıt yok'
        : (fark == 0 ? 'bugün' : (fark == 1 ? 'dün' : '${son.tarih.day} ${_aylarKisa[son.tarih.month - 1]}'));

    return InkWell(
      onTap: () => _projeyiAc(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.w600)),
                  if (altSatir.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(altSatir,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(tarihMetni, style: TextStyle(color: renk, fontSize: 13, fontWeight: FontWeight.w600)),
            Icon(Icons.chevron_right, color: ThemeColors.textTertiary(context)),
          ],
        ),
      ),
    );
  }

  Widget _bosKutu(String metin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Text(metin, textAlign: TextAlign.center, style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 15)),
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
                icon: Icon(Icons.more_vert, color: ThemeColors.textTertiary(context)),
                color: ThemeColors.cardBackground(context),
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
