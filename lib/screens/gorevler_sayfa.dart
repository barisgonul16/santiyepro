import 'package:flutter/material.dart';
import '../models/gorev.dart';
import '../models/hatirlatici.dart';
import '../theme/theme_colors.dart';

class GorevlerSayfaPage extends StatefulWidget {
  final List<Gorev> gorevler;
  final List<Hatirlatici> hatirlaticilar;
  final Function(Gorev) onGorevEkle;
  final Function(int) onGorevSil;
  final Function(int) onGorevTamamla;
  final Function(int, Gorev) onGorevDuzenle;

  const GorevlerSayfaPage({
    super.key,
    required this.gorevler,
    required this.hatirlaticilar,
    required this.onGorevEkle,
    required this.onGorevSil,
    required this.onGorevTamamla,
    required this.onGorevDuzenle,
  });

  @override
  State<GorevlerSayfaPage> createState() => _GorevlerSayfaPageState();
}


class _GorevlerSayfaPageState extends State<GorevlerSayfaPage> {
  DateTime secilenAy = DateTime.now();
  DateTime? secilenGun;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        
        if (isMobile) {
          return _buildMobileLayout();
        } else {
          return _buildDesktopLayout();
        }
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _gorevEkleDialog,
        backgroundColor: Colors.purple,
        child: Icon(Icons.add),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Görevler',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ThemeColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 15),
              _buildCompactTakvim(),
              const SizedBox(height: 15),
              _buildGorevListesiMobile(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Görevler',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _gorevEkleDialog,
                      icon: Icon(Icons.add),
                      label: Text('Görev Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Expanded(child: _buildTakvim()),
              ],
            ),
          ),
          const SizedBox(width: 30),
          Expanded(flex: 1, child: _buildGorevListesi()),
        ],
      ),
    );
  }

  Widget _buildCompactTakvim() {
    final yil = secilenAy.year;
    final ay = secilenAy.month;
    final ilkGun = DateTime(yil, ay, 1);
    final sonGun = DateTime(yil, ay + 1, 0);
    final baslangicGunu = ilkGun.weekday % 7;

    final aylar = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final gunler = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Ay navigasyonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    secilenAy = DateTime(yil, ay - 1, 1);
                  });
                },
                icon: Icon(Icons.chevron_left, color: ThemeColors.textPrimary(context), size: 24),
              ),
              Text(
                '${aylar[ay - 1]} $yil',
                style: TextStyle(
                  color: ThemeColors.textPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    secilenAy = DateTime(yil, ay + 1, 1);
                  });
                },
                icon: Icon(Icons.chevron_right, color: ThemeColors.textPrimary(context), size: 24),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Gün başlıkları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: gunler
                .map((g) => Text(
                      g,
                      style: TextStyle(
                        color: ThemeColors.textTertiary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          // Takvim günleri - Wrap kullanarak
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final gunNo = index - baslangicGunu + 1;
              if (gunNo < 1 || gunNo > sonGun.day) {
                return const SizedBox();
              }

              final tarih = DateTime(yil, ay, gunNo);
              final bugun = DateTime.now();
              final bugunMu = tarih.year == bugun.year &&
                  tarih.month == bugun.month &&
                  tarih.day == bugun.day;
              final seciliMi = secilenGun != null &&
                  tarih.year == secilenGun!.year &&
                  tarih.month == secilenGun!.month &&
                  tarih.day == secilenGun!.day;

              final gorevSayisi = widget.gorevler
                  .where((g) =>
                      g.tarih.year == tarih.year &&
                      g.tarih.month == tarih.month &&
                      g.tarih.day == tarih.day)
                  .length;
              
              // Takvim hatırlatıcıları (cal_ prefix ile başlayanlar)
              final hatirlaticiSayisi = widget.hatirlaticilar
                  .where((h) =>
                      h.tarih.year == tarih.year &&
                      h.tarih.month == tarih.month &&
                      h.tarih.day == tarih.day &&
                      h.id.startsWith('cal_'))
                  .length;
              
              final toplamSayisi = gorevSayisi + hatirlaticiSayisi;


              return InkWell(
                onTap: () {
                  setState(() {
                    secilenGun = tarih;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: seciliMi
                        ? Colors.purple
                        : (bugunMu ? Colors.purple.withOpacity(0.3) : Colors.transparent),
                    border: Border.all(color: Colors.white24, width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$gunNo',
                          style: TextStyle(
                            color: ThemeColors.textPrimary(context),
                            fontSize: 14,
                            fontWeight: seciliMi || bugunMu ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (toplamSayisi > 0)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: hatirlaticiSayisi > 0 && gorevSayisi == 0 
                                  ? Colors.blue 
                                  : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$toplamSayisi',
                                style: TextStyle(
                                  color: ThemeColors.textPrimary(context),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGorevListesiMobile() {
    final seciliGorevler = secilenGun == null
        ? <Gorev>[]
        : widget.gorevler
              .where((g) =>
                  g.tarih.year == secilenGun!.year &&
                  g.tarih.month == secilenGun!.month &&
                  g.tarih.day == secilenGun!.day)
              .toList()
              ..sort((a, b) => (a.saat.hour * 60 + a.saat.minute).compareTo(b.saat.hour * 60 + b.saat.minute));

    // Takvimden gelen hatırlatıcıları bul
    final seciliHatirlaticilar = secilenGun == null
        ? <Hatirlatici>[]
        : widget.hatirlaticilar
              .where((h) =>
                  h.tarih.year == secilenGun!.year &&
                  h.tarih.month == secilenGun!.month &&
                  h.tarih.day == secilenGun!.day &&
                  h.id.startsWith('cal_'))
              .toList()
              ..sort((a, b) => (a.saat.hour * 60 + a.saat.minute).compareTo(b.saat.hour * 60 + b.saat.minute));

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            secilenGun == null
                ? 'Bir gün seçin'
                : '${secilenGun!.day}/${secilenGun!.month}/${secilenGun!.year}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 15),
          if (secilenGun == null)
            Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Takvimden bir gün seçin',
                  style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 14),
                ),
              ),
            )
          else if (seciliGorevler.isEmpty && seciliHatirlaticilar.isEmpty)
            Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Bu günde görev veya etkinlik yok',
                  style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 14),
                ),
              ),
            ),
          
          if (secilenGun != null && (seciliGorevler.isNotEmpty || seciliHatirlaticilar.isNotEmpty)) ...[
            // Önce Takvim Etkinlikleri
            if (seciliHatirlaticilar.isNotEmpty) ...[
              Text(
                'Takvim Etkinlikleri',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ...seciliHatirlaticilar.map((hatirlatici) => _buildHatirlaticiKartMobile(hatirlatici)),
              const SizedBox(height: 12),
              if (seciliGorevler.isNotEmpty)
                const Divider(color: Colors.white10),
            ],

            // Sonra Uygulama Görevleri
            if (seciliGorevler.isNotEmpty) ...[
              if (seciliHatirlaticilar.isNotEmpty)
                const SizedBox(height: 12),
              Text(
                'Görevler',
                style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ...seciliGorevler.map((gorev) {
                final gorevIndex = widget.gorevler.indexOf(gorev);
                return _buildGorevKartMobile(gorevIndex, gorev);
              }),
            ],
          ]
        ],
      ),
    );
  }

  Widget _buildHatirlaticiKartMobile(Hatirlatici hatirlatici) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2a3a), // Mavi tonlu
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hatirlatici.baslik,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
              ),
              Text(
                '${hatirlatici.saat.hour.toString().padLeft(2, '0')}:${hatirlatici.saat.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          if (hatirlatici.aciklama.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              hatirlatici.aciklama,
              style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildGorevKartMobile(int index, Gorev gorev) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gorev.tamamlandi ? const Color(0xFF1a3d1a) : const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(8),
        border: gorev.tamamlandi
            ? Border.all(color: Colors.green.withOpacity(0.5), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  gorev.ad,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.textPrimary(context),
                    decoration: gorev.tamamlandi ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Text(
                '${gorev.saat.hour.toString().padLeft(2, '0')}:${gorev.saat.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSmallButton(
                  gorev.tamamlandi ? Icons.refresh : Icons.check,
                  gorev.tamamlandi ? 'Geri Al' : 'Tamamla',
                  Colors.green,
                  () => widget.onGorevTamamla(index),
                ),
                const SizedBox(width: 6),
                _buildSmallButton(
                  Icons.edit,
                  'Düzenle',
                  Colors.orange,
                  () => _gorevDuzenleDialog(index, gorev),
                ),
                const SizedBox(width: 6),
                _buildSmallButton(
                  Icons.delete,
                  'Sil',
                  Colors.red,
                  () => _gorevSilDialog(index, gorev.ad),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildTakvim() {
    final yil = secilenAy.year;
    final ay = secilenAy.month;
    final ilkGun = DateTime(yil, ay, 1);
    final sonGun = DateTime(yil, ay + 1, 0);
    final baslangicGunu = ilkGun.weekday % 7;

    final aylar = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    secilenAy = DateTime(yil, ay - 1, 1);
                  });
                },
                icon: Icon(Icons.chevron_left, color: ThemeColors.textPrimary(context), size: 30),
              ),
              Text(
                '${aylar[ay - 1]} $yil',
                style: TextStyle(
                  color: ThemeColors.textPrimary(context),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    secilenAy = DateTime(yil, ay + 1, 1);
                  });
                },
                icon: Icon(Icons.chevron_right, color: ThemeColors.textPrimary(context), size: 30),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: gunler
                .map((g) => Expanded(
                      child: Center(
                        child: Text(
                          g,
                          style: TextStyle(
                            color: ThemeColors.textTertiary(context),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final gunNo = index - baslangicGunu + 1;
                if (gunNo < 1 || gunNo > sonGun.day) {
                  return Container();
                }

                final tarih = DateTime(yil, ay, gunNo);
                final bugun = DateTime.now();
                final bugunMu = tarih.year == bugun.year &&
                    tarih.month == bugun.month &&
                    tarih.day == bugun.day;
                final seciliMi = secilenGun != null &&
                    tarih.year == secilenGun!.year &&
                    tarih.month == secilenGun!.month &&
                    tarih.day == secilenGun!.day;

                final gorevSayisi = widget.gorevler
                    .where((g) =>
                        g.tarih.year == tarih.year &&
                        g.tarih.month == tarih.month &&
                        g.tarih.day == tarih.day)
                    .length;

                // Takvim hatırlatıcıları (cal_ prefix ile başlayanlar)
                final hatirlaticiSayisi = widget.hatirlaticilar
                    .where((h) =>
                        h.tarih.year == tarih.year &&
                        h.tarih.month == tarih.month &&
                        h.tarih.day == tarih.day &&
                        h.id.startsWith('cal_'))
                    .length;
                
                final toplamSayisi = gorevSayisi + hatirlaticiSayisi;

                return InkWell(
                  onTap: () {
                    setState(() {
                      secilenGun = tarih;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: seciliMi
                          ? Colors.purple
                          : (bugunMu ? Colors.purple.withOpacity(0.3) : Colors.transparent),
                      border: Border.all(color: Colors.white24, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '$gunNo',
                            style: TextStyle(
                              color: ThemeColors.textPrimary(context),
                              fontSize: 16,
                              fontWeight: seciliMi || bugunMu ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (toplamSayisi > 0)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: hatirlaticiSayisi > 0 && gorevSayisi == 0 
                                    ? Colors.blue 
                                    : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$toplamSayisi',
                                style: TextStyle(
                                  color: ThemeColors.textPrimary(context),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
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

  Widget _buildGorevListesi() {
    final seciliGorevler = secilenGun == null
        ? <Gorev>[]
        : widget.gorevler
              .where((g) =>
                  g.tarih.year == secilenGun!.year &&
                  g.tarih.month == secilenGun!.month &&
                  g.tarih.day == secilenGun!.day)
              .toList()
              ..sort((a, b) => (a.saat.hour * 60 + a.saat.minute).compareTo(b.saat.hour * 60 + b.saat.minute));

    // Takvimden gelen hatırlatıcıları bul
    final seciliHatirlaticilar = secilenGun == null
        ? <Hatirlatici>[]
        : widget.hatirlaticilar
              .where((h) =>
                  h.tarih.year == secilenGun!.year &&
                  h.tarih.month == secilenGun!.month &&
                  h.tarih.day == secilenGun!.day &&
                  h.id.startsWith('cal_'))
              .toList()
              ..sort((a, b) => (a.saat.hour * 60 + a.saat.minute).compareTo(b.saat.hour * 60 + b.saat.minute));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            secilenGun == null
                ? 'Bir gün seçin'
                : '${secilenGun!.day}/${secilenGun!.month}/${secilenGun!.year}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 20),
          if (secilenGun == null)
            Expanded(
              child: Center(
                child: Text(
                  'Takvimden bir gün seçin',
                  style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 16),
                ),
              ),
            )
          else if (seciliGorevler.isEmpty && seciliHatirlaticilar.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Bu günde görev veya etkinlik yok',
                  style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 16),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  // Önce Takvim Etkinlikleri
                  if (seciliHatirlaticilar.isNotEmpty) ...[
                    Text(
                      'Takvim Etkinlikleri',
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    ...seciliHatirlaticilar.map((hatirlatici) => _buildHatirlaticiKart(hatirlatici)),
                    const SizedBox(height: 20),
                    if (seciliGorevler.isNotEmpty)
                      const Divider(color: Colors.white10),
                  ],

                  // Sonra Uygulama Görevleri
                  if (seciliGorevler.isNotEmpty) ...[
                    if (seciliHatirlaticilar.isNotEmpty)
                      const SizedBox(height: 20),
                    Text(
                      'Görevler',
                      style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    ...seciliGorevler.map((gorev) {
                      final gorevIndex = widget.gorevler.indexOf(gorev);
                      return _buildGorevKart(gorevIndex, gorev);
                    }),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHatirlaticiKart(Hatirlatici hatirlatici) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2a3a), // Mavi tonlu
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event, color: Colors.blue, size: 20),
              const SizedBox(width: 10),
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
              Text(
                '${hatirlatici.saat.hour.toString().padLeft(2, '0')}:${hatirlatici.saat.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (hatirlatici.aciklama.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              hatirlatici.aciklama,
              style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildGorevKart(int index, Gorev gorev) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: gorev.tamamlandi ? const Color(0xFF1a3d1a) : const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(8),
        border: gorev.tamamlandi
            ? Border.all(color: Colors.green.withOpacity(0.5), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  gorev.ad,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.textPrimary(context),
                    decoration: gorev.tamamlandi ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Text(
                '${gorev.saat.hour.toString().padLeft(2, '0')}:${gorev.saat.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => widget.onGorevTamamla(index),
                  icon: Icon(gorev.tamamlandi ? Icons.refresh : Icons.check, size: 16),
                  label: Text(
                    gorev.tamamlandi ? 'Geri Al' : 'Tamamla',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _gorevDuzenleDialog(index, gorev),
                  icon: Icon(Icons.edit, size: 16),
                  label: Text('Düzenle', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _gorevSilDialog(index, gorev.ad),
                  icon: Icon(Icons.delete, size: 16),
                  label: Text('Sil', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _gorevEkleDialog() {
    final adController = TextEditingController();
    DateTime? secilenTarih;
    TimeOfDay? secilenSaat;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: ThemeColors.cardBackground(context),
          title: Text('Yeni Görev', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: adController,
                  style: TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Görev Adı',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
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
                        ? 'Görev Tarihi Seç'
                        : '${secilenTarih!.day}/${secilenTarih!.month}/${secilenTarih!.year}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    minimumSize: const Size(double.infinity, 50),
                  ),
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
                        ? 'Görev Saati Seç'
                        : '${secilenSaat!.hour.toString().padLeft(2, '0')}:${secilenSaat!.minute.toString().padLeft(2, '0')}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (adController.text.isNotEmpty && secilenTarih != null && secilenSaat != null) {
                  widget.onGorevEkle(
                    Gorev(ad: adController.text, tarih: secilenTarih!, saat: secilenSaat!),
                  );
                  Navigator.pop(context);
                  this.setState(() {
                    secilenGun = secilenTarih;
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _gorevDuzenleDialog(int index, Gorev gorev) {
    final adController = TextEditingController(text: gorev.ad);
    DateTime? secilenTarih = gorev.tarih;
    TimeOfDay? secilenSaat = gorev.saat;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: ThemeColors.cardBackground(context),
          title: Text('Görevi Düzenle', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: adController,
                  style: TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Görev Adı',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: secilenTarih,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
                    );
                    if (picked != null) setState(() => secilenTarih = picked);
                  },
                  icon: Icon(Icons.calendar_today),
                  label: Text('${secilenTarih!.day}/${secilenTarih!.month}/${secilenTarih!.year}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    minimumSize: const Size(double.infinity, 50),
                  ),
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (adController.text.isNotEmpty) {
                  widget.onGorevDuzenle(
                    index,
                    Gorev(
                      ad: adController.text,
                      tarih: secilenTarih!,
                      saat: secilenSaat!,
                      tamamlandi: gorev.tamamlandi,
                    ),
                  );
                  Navigator.pop(context);
                  this.setState(() {});
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  void _gorevSilDialog(int index, String ad) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: Text('Görevi Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '"$ad" görevini silmek istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onGorevSil(index);
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Sil'),
          ),
        ],
      ),
    );
  }
}
