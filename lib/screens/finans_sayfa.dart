import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as pkr;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/fatura.dart';
import '../models/harcama.dart';
import '../models/proje.dart';
import '../services/image_service.dart';
import '../theme/theme_colors.dart';

class FinansSayfaPage extends StatefulWidget {
  final List<Fatura> faturalar;
  final List<Harcama> harcamalar;
  final List<Proje> projeler;
  final Function(Fatura) onFaturaEkle;
  final Function(int) onFaturaSil;
  final Function(int, Fatura) onFaturaGuncelle;
  final Function(Harcama) onHarcamaEkle;
  final Function(int) onHarcamaSil;
  final Function(int, Harcama) onHarcamaGuncelle;
  final VoidCallback onHesapSifirla;

  const FinansSayfaPage({
    super.key,
    required this.faturalar,
    required this.harcamalar,
    required this.projeler,
    required this.onFaturaEkle,
    required this.onFaturaSil,
    required this.onFaturaGuncelle,
    required this.onHarcamaEkle,
    required this.onHarcamaSil,
    required this.onHarcamaGuncelle,
    required this.onHesapSifirla,
  });

  @override
  State<FinansSayfaPage> createState() => _FinansSayfaPageState();
}

class _FinansSayfaPageState extends State<FinansSayfaPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: ThemeColors.cardBackground(context),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: ThemeColors.textSecondary(context),
            tabs: const [
              Tab(text: 'Faturalar'),
              Tab(text: 'Harcamalarım'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFaturaListesi(),
              _buildHarcamaListesi(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFaturaListesi() {
    // Şantiyelere göre gruplandır
    Map<String, List<Fatura>> gruplanmisFaturalar = {};
    for (var fatura in widget.faturalar) {
      if (!gruplanmisFaturalar.containsKey(fatura.firmaAdi)) {
        gruplanmisFaturalar[fatura.firmaAdi] = [];
      }
      gruplanmisFaturalar[fatura.firmaAdi]!.add(fatura);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            // Üst Bilgi Barı
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => _finansExcelAktar(isFatura: true), 
                    icon: const Icon(Icons.table_view, color: Colors.green),
                    tooltip: "Excel'e Aktar",
                  ),
                  IconButton(
                    onPressed: () => _finansAktar(isFatura: true), 
                    icon: const Icon(Icons.download, color: Colors.orange),
                    tooltip: "CSV ve Fotoğrafları Aktar",
                  ),
                ],
              ),
            ),
            // Klasör Yapısı
            Expanded(
              child: gruplanmisFaturalar.isEmpty
                  ? Center(child: Text("Fatura yok", style: TextStyle(color: ThemeColors.textSecondary(context))))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: gruplanmisFaturalar.length,
                      itemBuilder: (context, index) {
                        String santiyeAdi = gruplanmisFaturalar.keys.elementAt(index);
                        List<Fatura> faturalar = gruplanmisFaturalar[santiyeAdi]!;
                        
                        return Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: const Icon(Icons.folder, color: Colors.orange, size: 30),
                            title: Text(santiyeAdi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                            subtitle: Text("${faturalar.length} fatura", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            iconColor: Colors.white54,
                            collapsedIconColor: Colors.white54,
                            children: faturalar.map((fatura) {
                              final realIndex = widget.faturalar.indexOf(fatura);
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  onTap: () => _resimGoster(fatura.fotoYolu),
                                  title: Text(fatura.aciklama, style: const TextStyle(color: Colors.white70)),
                                  subtitle: Text("${fatura.tarih.day}/${fatura.tarih.month}/${fatura.tarih.year}", 
                                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                        onPressed: () {
                                          // Edit logic would go here
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                        onPressed: () => widget.onFaturaSil(realIndex),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: Colors.orange,
            onPressed: _yeniFaturaEkleDialog,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildHarcamaListesi() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            // Üst Bilgi Barı - Screenshot'a göre yeniden tasarlandı
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderInfoItem(
                        "Toplam Harcama",
                        "${_toplamHarcamaSadece().toStringAsFixed(2)} TL",
                        Colors.redAccent,
                      ),
                      _buildHeaderInfoItem(
                        "Alınan Para",
                        "${_toplamAlinanPara().toStringAsFixed(2)} TL",
                        Colors.greenAccent,
                      ),
                      _buildHeaderInfoItem(
                        "Net Durum",
                        "${(_toplamAlinanPara() - _toplamHarcamaSadece()).toStringAsFixed(2)} TL",
                        Colors.white,
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  InkWell(
                    onTap: widget.onHesapSifirla,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Hesabı Sıfırla",
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => _finansExcelAktar(isFatura: false),
                    icon: const Icon(Icons.table_view, color: Colors.green, size: 24),
                    tooltip: "Excel'e Aktar",
                  ),
                  IconButton(
                    onPressed: () => _finansAktar(isFatura: false),
                    icon: const Icon(Icons.download, color: Colors.orange, size: 24),
                    tooltip: "CSV/Foto Aktar",
                  ),
                ],
              ),
            ),
            // Liste
            Expanded(
              child: widget.harcamalar.isEmpty
                  ? Center(child: Text("Harcama yok", style: TextStyle(color: ThemeColors.textSecondary(context))))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: widget.harcamalar.length,
                      itemBuilder: (context, index) {
                        // En yeni en üstte
                        final sortedHarcamalar = List<Harcama>.from(widget.harcamalar)
                          ..sort((a, b) => b.tarih.compareTo(a.tarih));
                        final harcama = sortedHarcamalar[index];
                        final realIndex = widget.harcamalar.indexOf(harcama);

                        final isIncome = harcama.isReimbursement;

                        return ExpansionTile(
                          leading: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIncome ? Colors.greenAccent : Colors.redAccent,
                          ),
                          title: Text(harcama.aciklama, style: TextStyle(color: ThemeColors.textPrimary(context))),
                          subtitle: Text("${harcama.kategori} - ${harcama.tarih.day}.${harcama.tarih.month}.${harcama.tarih.year}",
                              style: TextStyle(color: ThemeColors.textSecondary(context))),
                          trailing: Text(
                            "${isIncome ? '+' : '-'}${harcama.tutar} TL", 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: isIncome ? Colors.greenAccent : Colors.redAccent
                            )
                          ),
                          children: [
                            if (harcama.fisYolu.isNotEmpty)
                              GestureDetector(
                                onTap: () => _resimGoster(harcama.fisYolu),
                                child: Container(
                                  height: 200,
                                  width: double.infinity,
                                  margin: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade800),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: ImageService.buildImage(harcama.fisYolu, fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                            ListTile(
                              title: const Text("Harcamayı Sil", style: TextStyle(color: Colors.red)),
                              trailing: const Icon(Icons.delete, color: Colors.red),
                              onTap: () => widget.onHarcamaSil(realIndex),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: Colors.redAccent,
            onPressed: () => _yeniHarcamaEkleDialog(),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  double _toplamFaturaTutar() {
    return widget.faturalar.fold(0, (sum, item) => sum + item.tutar);
  }

  double _toplamHarcamaSadece() {
    return widget.harcamalar
        .where((h) => !h.isReimbursement)
        .fold(0.0, (sum, item) => sum + item.tutar);
  }

  double _toplamAlinanPara() {
    return widget.harcamalar
        .where((h) => h.isReimbursement)
        .fold(0.0, (sum, item) => sum + item.tutar);
  }

  double _toplamHarcamaTutar() {
    return _toplamHarcamaSadece();
  }

  void _resimGoster(String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 500),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImageService.buildImage(path, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text("Kapat", style: TextStyle(color: Colors.black)),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _finansAktar({required bool isFatura}) async {
    final veri = isFatura ? widget.faturalar : widget.harcamalar;
    if (veri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktarılacak veri bulunamadı'), backgroundColor: Colors.orange),
      );
      return;
    }

    String? selectedDirectory = await pkr.FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    final typeStr = isFatura ? "Faturalar" : "Harcamalar";
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final klasorAdi = "${typeStr}_Aktarim_$timestamp";
    final hedefKlasor = Directory("$selectedDirectory/$klasorAdi");

    try {
      await hedefKlasor.create();
      
      // CSV Hazırla
      String csvData = isFatura 
          ? "Firma;Tarih;Tutar;KDV;Toplam;Açıklama\n"
          : "Tip;Kategori;Tarih;Tutar;Açıklama\n";

      for (var item in veri) {
        if (isFatura && item is Fatura) {
          csvData += "${item.firmaAdi};${item.tarih};${item.tutar};${item.kdv};${item.toplamTutar};${item.aciklama}\n";
          // Resim varsa kopyala
          if (item.fotoYolu != null && item.fotoYolu!.isNotEmpty) {
            try {
              final fotoFile = File(item.fotoYolu!);
              if (await fotoFile.exists()) {
                final yeniFotoAdi = "Fatura_${item.firmaAdi}_${DateTime.now().millisecondsSinceEpoch}.jpg";
                await fotoFile.copy("${hedefKlasor.path}/$yeniFotoAdi");
              }
            } catch (e) {
              debugPrint("Fatura fotoğraf kopyalama hatası: $e");
            }
          }
        } else if (!isFatura && item is Harcama) {
          final tip = item.isReimbursement ? "Alınan Para" : "Harcama";
          csvData += "$tip;${item.kategori};${item.tarih};${item.tutar};${item.aciklama}\n";
          // Resim varsa kopyala
          if (item.fisYolu.isNotEmpty) {
            try {
              final fotoFile = File(item.fisYolu);
              if (await fotoFile.exists()) {
                final yeniFotoAdi = "Gider_${item.aciklama}_${DateTime.now().millisecondsSinceEpoch}.jpg";
                await fotoFile.copy("${hedefKlasor.path}/$yeniFotoAdi");
              }
            } catch (e) {
              debugPrint("Gider fotoğraf kopyalama hatası: $e");
            }
          }
        }
      }

      final csvFile = File("${hedefKlasor.path}/$typeStr.csv");
      await csvFile.writeAsString(csvData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veriler ve fotoğraflar aktarıldı: ${hedefKlasor.path}'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _fotoSecVeYukle(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    String? secilenYol;

    await showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.cardBackground(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Kamera', style: TextStyle(color: Colors.white)),
              onTap: () async {
                final XFile? image = await picker.pickImage(source: ImageSource.camera);
                if (image != null) secilenYol = image.path;
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Galeri', style: TextStyle(color: Colors.white)),
              onTap: () async {
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) secilenYol = image.path;
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );

    if (secilenYol != null) {
      // Yükleme göstergesi
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      final url = await ImageService().uploadImage(secilenYol!);
      
      if (context.mounted) Navigator.pop(context); // Göstergeyi kapat
      return url ?? secilenYol; // Hata olursa yerel yolu döndür
    }
    return null;
  }

  void _yeniFaturaEkleDialog() {
    String? secilenProje = widget.projeler.isNotEmpty ? widget.projeler.first.ad : null;
    final aciklamaController = TextEditingController();
    String? fotoYolu;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(
            child: Text(
              "Yeni Fatura Ekle", 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            )
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final yol = await _fotoSecVeYukle(context);
                    if (yol != null) {
                      setState(() => fotoYolu = yol);
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D3D3D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: fotoYolu != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ImageService.buildImage(fotoYolu!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.camera_alt, color: Colors.white54, size: 40),
                              const SizedBox(height: 8),
                              const Text("Fotoğraf Ekle", style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF2C2C2C),
                  value: secilenProje,
                  decoration: const InputDecoration(
                    labelText: "Şantiye Seçin",
                    labelStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: widget.projeler.map((p) => DropdownMenuItem(
                    value: p.ad,
                    child: Text(p.ad, style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (val) => setState(() => secilenProje = val),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    // Alternative input logic could go here
                  },
                  child: const Text(
                    "veya Manuel Giriş",
                    style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: aciklamaController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Açıklama",
                    labelStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("İptal", style: TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (secilenProje != null) {
                          final yeniFatura = Fatura(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            firmaAdi: secilenProje!,
                            tarih: DateTime.now(),
                            tutar: 0,
                            kdv: 0,
                            toplamTutar: 0,
                            aciklama: aciklamaController.text,
                            fotoYolu: fotoYolu ?? '',
                          );
                          widget.onFaturaEkle(yeniFatura);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E2C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfoItem(String title, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _finansExcelAktar({required bool isFatura}) async {
    final veri = isFatura ? widget.faturalar : widget.harcamalar;
    if (veri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktarılacak veri bulunamadı'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      String? selectedDirectory;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        selectedDirectory = await pkr.FilePicker.platform.getDirectoryPath();
      } else {
        selectedDirectory = (await getExternalStorageDirectory())?.path;
      }
      if (selectedDirectory == null) return;

      final typeStr = isFatura ? "Faturalar" : "Harcamalarim";
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final folderName = "${typeStr}_Excel_Aktarim_$timestamp";
      final targetDirectory = Directory("$selectedDirectory/$folderName");
      await targetDirectory.create(recursive: true);

      var excel = xls.Excel.createExcel();
      xls.Sheet sheetObject = excel['Sheet1'];

      if (isFatura) {
        sheetObject.appendRow([
          xls.TextCellValue("Firma/Santiye Adı"),
          xls.TextCellValue("Tarih"),
          xls.TextCellValue("Açıklama"),
          xls.TextCellValue("Fotoğraf Dosyası"),
        ]);
        
        final photosDir = Directory("${targetDirectory.path}/fotograflar");
        await photosDir.create();

        for (var item in widget.faturalar) {
          String fotoAdi = "";
          if (item.fotoYolu.isNotEmpty) {
            try {
              final originalFile = File(item.fotoYolu);
              if (await originalFile.exists()) {
                fotoAdi = "fatura_${item.id}_${DateTime.now().millisecondsSinceEpoch}.jpg";
                await originalFile.copy("${photosDir.path}/$fotoAdi");
                fotoAdi = "fotograflar/$fotoAdi";
              }
            } catch (e) {
              debugPrint("Fotoğraf kopyalama hatası: $e");
            }
          }

          sheetObject.appendRow([
            xls.TextCellValue(item.firmaAdi),
            xls.TextCellValue(item.tarih.toString()),
            xls.TextCellValue(item.aciklama),
            xls.TextCellValue(fotoAdi),
          ]);
        }
      } else {
        sheetObject.appendRow([
          xls.TextCellValue("Tip"),
          xls.TextCellValue("Kategori"),
          xls.TextCellValue("Tarih"),
          xls.TextCellValue("Tutar"),
          xls.TextCellValue("Açıklama"),
        ]);
        for (var item in widget.harcamalar) {
          sheetObject.appendRow([
            xls.TextCellValue(item.isReimbursement ? "Alınan Para" : "Harcama"),
            xls.TextCellValue(item.kategori),
            xls.TextCellValue(item.tarih.toString()),
            xls.DoubleCellValue(item.tutar),
            xls.TextCellValue(item.aciklama),
          ]);
        }
      }

      final fileName = "$typeStr.xlsx";
      final file = File("${targetDirectory.path}/$fileName");
      
      final binData = excel.encode();
      if (binData != null) {
        await file.writeAsBytes(binData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel dosyası ve fotoğraflar kaydedildi: ${targetDirectory.path}'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      debugPrint("Excel aktarma hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _yeniHarcamaEkleDialog() {
    final aciklamaController = TextEditingController();
    final tutarController = TextEditingController();
    String kategori = "Genel";
    String? fotoYolu;
    bool isReimbursement = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Center(
            child: Text(
              "Yeni Harcama / Giriş", 
              style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold)
            )
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Harcama", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Switch(
                      value: isReimbursement,
                      onChanged: (val) => setState(() => isReimbursement = val),
                      activeColor: Colors.grey,
                      activeTrackColor: Colors.white24,
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.white24,
                    ),
                    const Text("Alınan Para", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () async {
                    final yol = await _fotoSecVeYukle(context);
                    if (yol != null) {
                      setState(() => fotoYolu = yol);
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D3D3D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: fotoYolu != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ImageService.buildImage(fotoYolu!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long, color: Colors.white54, size: 40),
                              const SizedBox(height: 8),
                              const Text("Fiş Ekle", style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: tutarController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Tutar (TL)",
                    labelStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  ),
                ),
                TextField(
                  controller: aciklamaController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Açıklama",
                    labelStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("İptal", style: TextStyle(color: Colors.deepPurpleAccent)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (tutarController.text.isNotEmpty) {
                          final yeniHarcama = Harcama(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            tarih: DateTime.now(),
                            tutar: double.tryParse(tutarController.text) ?? 0,
                            kategori: kategori,
                            aciklama: aciklamaController.text,
                            fisYolu: fotoYolu ?? '',
                            isReimbursement: isReimbursement,
                          );
                          widget.onHarcamaEkle(yeniHarcama);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E2C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
