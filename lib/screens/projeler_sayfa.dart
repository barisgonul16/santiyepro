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
  final List<String> ekipler;
  final Function(int, int) onReorder;

  const ProjelerSayfaPage({
    super.key,
    required this.projeler,
    required this.onProjeEkle,
    required this.onProjeSil,
    required this.onProjeDuzenle,
    required this.projeGunlukKayitlari,
    required this.onGunlukKayitEkle,
    required this.onGunlukKayitGuncelle,
    required this.ekipler,
    required this.onReorder,
  });

  static const _aylarKisa = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  @override
  Widget build(BuildContext context) {
    final devamEdenler = projeler.where((p) => p.durum != 'Tamamlandı').toList();
    final tamamlananlar = projeler.where((p) => p.durum == 'Tamamlandı').toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        final sutun = isMobile ? 1 : (constraints.maxWidth < 1300 ? 2 : 3);

        return ListView(
          padding: EdgeInsets.all(isMobile ? 12 : 30),
          children: [
            // Başlık
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Projeler',
                    style: TextStyle(
                      fontSize: isMobile ? 26 : 32,
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.textPrimary(context),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _projeEkleDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni Proje'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (projeler.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Text(
                    'Henüz proje eklenmemiş',
                    style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 16),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  'Devam eden · ${devamEdenler.length}',
                  style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13),
                ),
              ),
              _buildProjeIzgarasi(context, devamEdenler, sutun),
              if (tamamlananlar.isNotEmpty) ...[
                const SizedBox(height: 6),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    childrenPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_circle_outline, color: ThemeColors.textTertiary(context)),
                    title: Text(
                      'Tamamlananlar (${tamamlananlar.length})',
                      style: TextStyle(color: ThemeColors.textSecondary(context), fontWeight: FontWeight.bold),
                    ),
                    children: [_buildProjeIzgarasi(context, tamamlananlar, sutun)],
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  /// Satır kartlarından oluşan ızgara. Uzun basıp sürükleyerek sıralama
  /// korunur; sıralama her zaman tüm listedeki konumlarla yapılır.
  Widget _buildProjeIzgarasi(BuildContext context, List<Proje> liste, int sutun) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: sutun,
        crossAxisSpacing: 14,
        mainAxisSpacing: 12,
        mainAxisExtent: 142,
      ),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final proje = liste[i];
        final index = projeler.indexOf(proje);
        return DragTarget<Proje>(
          onWillAcceptWithDetails: (d) => d.data.id != proje.id,
          onAcceptWithDetails: (d) {
            final eskiIndex = projeler.indexWhere((p) => p.id == d.data.id);
            if (eskiIndex != -1) onReorder(eskiIndex, index);
          },
          builder: (context, adaylar, _) {
            final kart = _buildProjeKart(context, index, proje);
            return LongPressDraggable<Proje>(
              data: proje,
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(
                  opacity: 0.85,
                  child: SizedBox(width: 340, height: 142, child: kart),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: kart),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  border: adaylar.isNotEmpty ? Border.all(color: Colors.blue, width: 2) : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: kart,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProjeKart(BuildContext context, int index, Proje proje) {
    final kayitlar = projeGunlukKayitlari[proje.id] ?? [];
    final tamamlandi = proje.durum == 'Tamamlandı';
    final oran = _ilerlemeHesapla(proje);

    DateTime? sonKayit;
    for (final k in kayitlar) {
      if (sonKayit == null || k.tarih.isAfter(sonKayit)) sonKayit = k.tarih;
    }
    final bugun = DateTime.now();
    final gunFarki = sonKayit == null
        ? null
        : DateTime(bugun.year, bugun.month, bugun.day)
            .difference(DateTime(sonKayit.year, sonKayit.month, sonKayit.day))
            .inDays;
    // Yeşil: dün/bugün, turuncu: birkaç gündür yok, gri: uzun süredir yok.
    final sonKayitRengi = tamamlandi || gunFarki == null || gunFarki > 30
        ? ThemeColors.textTertiary(context)
        : (gunFarki <= 1 ? Colors.greenAccent : Colors.amber);
    final b = proje.baslangicTarihi;
    final ikincil = TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13);

    return Material(
      color: ThemeColors.cardBackground(context),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
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
                projeGunlukKayitlari: projeGunlukKayitlari,
                ekipler: ekipler,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      proje.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: tamamlandi ? ThemeColors.textSecondary(context) : ThemeColors.textPrimary(context),
                      ),
                    ),
                  ),
                  Text(
                    sonKayit == null
                        ? 'kayıt yok'
                        : 'son kayıt ${sonKayit.day} ${_aylarKisa[sonKayit.month - 1]}',
                    style: TextStyle(color: sonKayitRengi, fontSize: 13),
                  ),
                  SizedBox(
                    width: 36,
                    height: 32,
                    child: PopupMenuButton(
                      padding: EdgeInsets.zero,
                      color: ThemeColors.cardBackground(context),
                      icon: Icon(Icons.more_vert, size: 20, color: ThemeColors.textSecondary(context)),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Text('Düzenle', style: TextStyle(color: ThemeColors.textPrimary(context))),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _projeDuzenleDialog(context, index, proje),
                          ),
                        ),
                        PopupMenuItem(
                          child: const Text('Sil', style: TextStyle(color: Colors.red)),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _projeSilDialog(context, index, proje.ad),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  [
                    if (proje.aciklama.trim().isNotEmpty) proje.aciklama.trim(),
                    '${kayitlar.length} kayıt',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ikincil,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.event, size: 14, color: ThemeColors.textTertiary(context)),
                  const SizedBox(width: 4),
                  Text('Başlangıç: ${b.day} ${_aylarKisa[b.month - 1]} ${b.year}', style: ikincil),
                ],
              ),
              const Spacer(),
              // Tamamlanan projede takvim sayacı anlamsız (bittikten sonra da
              // sayar), yalnızca planlanan süre gösterilir.
              if (tamamlandi)
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade400),
                    const SizedBox(width: 6),
                    Text(
                      'Tamamlandı · planlanan ${proje.toplamGun} gün',
                      style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              else
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: oran,
                          minHeight: 6,
                          backgroundColor: ThemeColors.border(context),
                          color: proje.sureAsildi ? Colors.redAccent : Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${proje.sureMetni} · %${(oran * 100).round()}',
                      style: TextStyle(
                        color: proje.sureAsildi ? Colors.redAccent : ThemeColors.textPrimary(context),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Takvim süresinin dolma oranı (0..1). İş ilerlemesi değildir.
  double _ilerlemeHesapla(Proje proje) {
    if (proje.toplamGun <= 0) return 0;
    return (proje.gecenGun / proje.toplamGun).clamp(0.0, 1.0);
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
