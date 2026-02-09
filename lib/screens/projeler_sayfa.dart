import 'package:flutter/material.dart';
import '../models/proje.dart';
import '../models/gunluk_kayit.dart';
import 'proje_detay_sayfa.dart';
import '../theme/theme_colors.dart';

class ProjelerSayfaPage extends StatelessWidget {
  final List<Proje> projeler;
  final Function(Proje) onProjeEkle;
  final Function(int) onProjeSil;
  final Function(int, Proje) onProjeDuzenle;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;
  final Function(String, GunlukKayit) onGunlukKayitEkle;
  final Function(String, int, GunlukKayit) onGunlukKayitGuncelle;

  const ProjelerSayfaPage({
    super.key,
    required this.projeler,
    required this.onProjeEkle,
    required this.onProjeSil,
    required this.onProjeDuzenle,
    required this.projeGunlukKayitlari,
    required this.onGunlukKayitEkle,
    required this.onGunlukKayitGuncelle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800; // Increased breakpoint for grid

        return Container(
          padding: EdgeInsets.all(isMobile ? 15 : 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Projeler',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () => _projeEkleDialog(context),
                      icon: Icon(Icons.add),
                      label: const Text('Yeni Proje'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Projeler',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _projeEkleDialog(context),
                      icon: Icon(Icons.add),
                      label: const Text('Yeni Proje'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 30),
              
              // Grid
              Expanded(
                child: projeler.isEmpty
                    ? Center(
                        child: Text(
                          'Henüz proje eklenmemiş',
                          style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 16),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 1 : 3,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: isMobile ? 1.8 : 1.5,
                        ),
                        itemCount: projeler.length,
                        itemBuilder: (context, index) {
                          return _buildProjeKart(context, index, projeler[index]);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjeKart(BuildContext context, int index, Proje proje) {
    final ilerleme = _ilerlemeHesapla(proje);
    final kayitlar = projeGunlukKayitlari[proje.id] ?? [];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjeDetaySayfa(
              proje: proje,
              gunlukKayitlar: kayitlar,
              onKayitEkle: (kayit) => onGunlukKayitEkle(proje.id, kayit),
              onKayitGuncelle: (i, kayit) =>
                  onGunlukKayitGuncelle(proje.id, i, kayit),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: proje.durum == "Tamamlandı" 
              ? Colors.green.withOpacity(0.2) 
              : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: proje.durum == "Tamamlandı" 
                ? Colors.green.withOpacity(0.5) 
                : Colors.grey.withOpacity(0.5), 
            width: 2
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    proje.ad,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: proje.durum == "Tamamlandı" ? Colors.white : ThemeColors.textPrimary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton(
                  color: ThemeColors.cardBackground(context),
                  icon: Icon(Icons.more_vert, color: proje.durum == "Tamamlandı" ? Colors.white70 : ThemeColors.textSecondary(context)),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Text(
                        'Düzenle',
                        style: TextStyle(color: ThemeColors.textPrimary(context)),
                      ),
                      onTap: () => Future.delayed(
                        Duration.zero,
                        () => _projeDuzenleDialog(context, index, proje),
                      ),
                    ),
                    PopupMenuItem(
                      child: const Text(
                        'Sil',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () => Future.delayed(
                        Duration.zero,
                        () => _projeSilDialog(context, index, proje.ad),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              proje.aciklama,
              style: TextStyle(
                color: proje.durum == "Tamamlandı" ? Colors.white70 : ThemeColors.textSecondary(context),
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: proje.durum == "Tamamlandı" ? Colors.white60 : ThemeColors.textTertiary(context),
                ),
                const SizedBox(width: 5),
                Text(
                  '${proje.baslangicTarihi.day}/${proje.baslangicTarihi.month}/${proje.baslangicTarihi.year}',
                  style: TextStyle(
                    color: proje.durum == "Tamamlandı" ? Colors.white60 : ThemeColors.textTertiary(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 15),
                Icon(
                  Icons.access_time, 
                  size: 14, 
                  color: proje.durum == "Tamamlandı" ? Colors.white60 : ThemeColors.textTertiary(context)
                ),
                const SizedBox(width: 5),
                Text(
                  '${proje.toplamGun} gün',
                  style: TextStyle(
                    color: proje.durum == "Tamamlandı" ? Colors.white60 : ThemeColors.textTertiary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: ilerleme / 100,
                    backgroundColor: proje.durum == "Tamamlandı" ? Colors.white24 : ThemeColors.border(context),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${ilerleme.toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _ilerlemeHesapla(Proje proje) {
    final toplamGun = proje.toplamGun;
    final gecenGun = DateTime.now().difference(proje.baslangicTarihi).inDays;
    if (toplamGun == 0) return 0;
    return (gecenGun / toplamGun * 100).clamp(0, 100);
  }

  void _projeEkleDialog(BuildContext context) {
    final adController = TextEditingController();
    final aciklamaController = TextEditingController();
    final toplamGunController = TextEditingController();
    DateTime? baslangicTarihi;
    String secilenDurum = "Devam Ediyor";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: ThemeColors.cardBackground(context),
          title: const Text(
            'Yeni Proje',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: adController,
                  style: TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Proje Adı',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: aciklamaController,
                  style: TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: toplamGunController,
                  style: TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Toplam Gün',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: secilenDurum,
                  dropdownColor: const Color(0xFF3d3d3d),
                  style: TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Durum',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "Devam Ediyor",
                      child: Text("Devam Ediyor"),
                    ),
                    DropdownMenuItem(
                      value: "Tamamlandı",
                      child: Text("Tamamlandı"),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => secilenDurum = val);
                  },
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) =>
                          Theme(data: ThemeData.dark(), child: child!),
                    );
                    if (picked != null)
                      setState(() => baslangicTarihi = picked);
                  },
                  icon: Icon(Icons.calendar_today),
                  label: Text(
                    baslangicTarihi == null
                        ? 'Başlangıç Tarihi Seç'
                        : '${baslangicTarihi!.day}/${baslangicTarihi!.month}/${baslangicTarihi!.year}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                  ),
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
                if (adController.text.isNotEmpty &&
                    toplamGunController.text.isNotEmpty &&
                    baslangicTarihi != null) {
                  onProjeEkle(
                    Proje(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      ad: adController.text,
                      aciklama: aciklamaController.text,
                      baslangicTarihi: baslangicTarihi!,
                      toplamGun: int.parse(toplamGunController.text),
                      durum: secilenDurum,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _projeDuzenleDialog(BuildContext context, int index, Proje proje) {
    final adController = TextEditingController(text: proje.ad);
    final aciklamaController = TextEditingController(text: proje.aciklama);
    final toplamGunController = TextEditingController(
      text: proje.toplamGun.toString(),
    );
    DateTime? baslangicTarihi = proje.baslangicTarihi;
    String secilenDurum = proje.durum;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: ThemeColors.cardBackground(context),
          title: const Text(
            'Projeyi Düzenle',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: adController,
                  style: TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Proje Adı',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: aciklamaController,
                  style: TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: toplamGunController,
                  style: TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Toplam Gün',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: secilenDurum,
                  dropdownColor: const Color(0xFF3d3d3d),
                  style: TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Durum',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "Devam Ediyor",
                      child: Text("Devam Ediyor"),
                    ),
                    DropdownMenuItem(
                      value: "Tamamlandı",
                      child: Text("Tamamlandı"),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => secilenDurum = val);
                  },
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: baslangicTarihi,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) =>
                          Theme(data: ThemeData.dark(), child: child!),
                    );
                    if (picked != null)
                      setState(() => baslangicTarihi = picked);
                  },
                  icon: Icon(Icons.calendar_today),
                  label: Text(
                    '${baslangicTarihi!.day}/${baslangicTarihi!.month}/${baslangicTarihi!.year}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                  ),
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
                if (adController.text.isNotEmpty &&
                    toplamGunController.text.isNotEmpty) {
                  onProjeDuzenle(
                    index,
                    Proje(
                      id: proje.id,
                      ad: adController.text,
                      aciklama: aciklamaController.text,
                      baslangicTarihi: baslangicTarihi!,
                      toplamGun: int.parse(toplamGunController.text),
                      durum: secilenDurum,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  void _projeSilDialog(BuildContext context, int index, String ad) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: const Text('Projeyi Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '"$ad" projesini silmek istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              onProjeSil(index);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
