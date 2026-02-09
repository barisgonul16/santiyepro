import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as pkr;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as sf;
import '../models/fatura.dart';
import '../models/harcama.dart';
import '../models/proje.dart';
import '../services/image_service.dart';
import '../services/storage_service.dart';
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
  final Function(bool, {bool? isFatura}) onHesapSifirla; // bool isArchive: true = sadece hesap, false = komple sil, optional isFatura: true = fatura, false = harcama, null = hepsi

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
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThemeColors.cardBackground(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                   _buildHeaderInfoItem(
                    "Toplam Fatura",
                    "${widget.faturalar.length} Adet",
                    Colors.orange,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _finansExcelAktar(isFatura: true), 
                    icon: const Icon(Icons.download, color: Colors.green),
                    tooltip: "Excel'e Aktar",
                  ),
                  IconButton(
                    onPressed: () => _showArchivesDialog(),
                    icon: const Icon(Icons.history, color: Colors.blue),
                    tooltip: "Arşivler",
                  ),
                  IconButton(
                    onPressed: () => _showResetOptionsDialog(true),
                    icon: const Icon(Icons.refresh, color: Colors.orange),
                    tooltip: "Faturaları Sıfırla",
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
                            title: Text(santiyeAdi, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ThemeColors.textPrimary(context))),
                            subtitle: Text("${faturalar.length} fatura", style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12)),
                            iconColor: ThemeColors.textTertiary(context),
                            collapsedIconColor: ThemeColors.textTertiary(context),
                            children: faturalar.map((fatura) {
                              final realIndex = widget.faturalar.indexOf(fatura);
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ThemeColors.cardBackground(context),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  onTap: () => _resimGoster(fatura.fotoYolu),
                                  title: Text(fatura.aciklama, style: TextStyle(color: ThemeColors.textSecondary(context))),
                                  subtitle: Text("${fatura.tarih.day}/${fatura.tarih.month}/${fatura.tarih.year}", 
                                      style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 11)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
            // Üst Bilgi Barı
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThemeColors.cardBackground(context),
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
                        ThemeColors.textPrimary(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.black12, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _showArchivesDialog(),
                        child: const Row(
                          children: [
                            Icon(Icons.history, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text("Arşivler", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 30),
                      InkWell(
                        onTap: () => _showResetOptionsDialog(false),
                        child: const Row(
                          children: [
                            Icon(Icons.refresh, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text("Hesabı Sıfırla", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
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
                    icon: const Icon(Icons.download, color: Colors.green, size: 24),
                    tooltip: "Excel'e Aktar",
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

  Future<void> _finansExcelAktar({required bool isFatura}) async {
    final veri = isFatura ? widget.faturalar : widget.harcamalar;
    if (veri.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktarılacak veri bulunamadı'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    String? selectedDirectory = await pkr.FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    final typeStr = isFatura ? "Faturalar" : "Harcamalar";
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final klasorAdi = "${typeStr}_Aktarim_$timestamp";
    final hedefKlasor = Directory("$selectedDirectory/$klasorAdi");

    // Bekleme göster
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    int successCount = 0;
    int photoSuccessCount = 0;
    int photoErrorCount = 0;
    List<String> errorLogs = [];

    try {
      await hedefKlasor.create(recursive: true);
      
      // Syncfusion Excel Oluştur
      final sf.Workbook workbook = sf.Workbook();
      final sf.Worksheet sheet = workbook.worksheets[0];
      sheet.name = typeStr;

      if (isFatura) {
        // BAŞLIKLAR
        sheet.getRangeByIndex(1, 1).setText("Firma/Şantiye");
        sheet.getRangeByIndex(1, 2).setText("Tarih");
        sheet.getRangeByIndex(1, 3).setText("Toplam");
        sheet.getRangeByIndex(1, 4).setText("Açıklama");
        sheet.getRangeByIndex(1, 5).setText("Fotoğraf");
        sheet.getRangeByIndex(1, 6).setText("Dosya Adı");

        int photoCount = 0;
        for (int i = 0; i < veri.length; i++) {
          final item = veri[i];
          final row = i + 2;
          if (item is Fatura) {
            final tarihStr = "${item.tarih.day}.${item.tarih.month.toString().padLeft(2, '0')}.${item.tarih.year}";
            
            sheet.getRangeByIndex(row, 1).setText(item.firmaAdi);
            sheet.getRangeByIndex(row, 2).setText(tarihStr);
            sheet.getRangeByIndex(row, 3).setNumber(item.toplamTutar);
            sheet.getRangeByIndex(row, 4).setText(item.aciklama);

            if (item.fotoYolu.isNotEmpty) {
              try {
                final bytes = await (ImageService.isNetworkUrl(item.fotoYolu) 
                    ? ImageService().downloadImage(item.fotoYolu) 
                    : File(item.fotoYolu).readAsBytes());
                
                if (bytes != null) {
                  photoCount++;
                  final String sheetName = "F-$photoCount";
                  final sf.Worksheet photoSheet = workbook.worksheets.addWithName(sheetName);
                  
                  photoSheet.getRangeByIndex(1, 1).setText("${item.firmaAdi} - $tarihStr");
                  photoSheet.getRangeByIndex(1, 1).cellStyle.bold = true;
                  photoSheet.pictures.addStream(2, 1, bytes);
                  
                  // Ana sayfadan bu sayfaya link ver
                  final sf.Range range = sheet.getRangeByIndex(row, 5);
                  final sf.Hyperlink hyperlink = sheet.hyperlinks.add(range, sf.HyperlinkType.workbook, "'$sheetName'!A1");
                  hyperlink.textToDisplay = "RESMİ GÖR";
                  
                  final safeFirma = item.firmaAdi.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
                  final uzanti = item.fotoYolu.split('.').last.split('?').first.toLowerCase();
                  final fotoAdi = "fatura_${safeFirma}_$tarihStr.$photoCount.$uzanti";
                  sheet.getRangeByIndex(row, 6).setText(fotoAdi);
                  
                  await File("${hedefKlasor.path}/$fotoAdi").writeAsBytes(bytes);
                  photoSuccessCount++;
                }
              } catch (e) {
                photoErrorCount++;
                errorLogs.add("Hata (${item.firmaAdi}): $e");
              }
            }
            successCount++;
          }
        }
      } else {
        // HARCAMALAR
        sheet.getRangeByIndex(1, 1).setText("Tarih");
        sheet.getRangeByIndex(1, 2).setText("Tip");
        sheet.getRangeByIndex(1, 3).setText("Kategori");
        sheet.getRangeByIndex(1, 4).setText("Tutar");
        sheet.getRangeByIndex(1, 5).setText("Açıklama");
        sheet.getRangeByIndex(1, 6).setText("Bakiye");
        sheet.getRangeByIndex(1, 7).setText("Fotoğraf");
        sheet.getRangeByIndex(1, 8).setText("Dosya Adı");

        final sortedList = List<Harcama>.from(widget.harcamalar)
          ..sort((a, b) => a.tarih.compareTo(b.tarih));

        double cumulative = 0.0;
        int photoCount = 0;
        for (int i = 0; i < sortedList.length; i++) {
          final item = sortedList[i];
          final row = i + 2;
          final amount = item.tutar;
          item.isReimbursement ? cumulative += amount : cumulative -= amount;
          
          final tarihStr = "${item.tarih.day}.${item.tarih.month.toString().padLeft(2, '0')}.${item.tarih.year}";
          
          sheet.getRangeByIndex(row, 1).setText(tarihStr);
          sheet.getRangeByIndex(row, 2).setText(item.isReimbursement ? "Alınan Para" : "Harcama");
          sheet.getRangeByIndex(row, 3).setText(item.kategori);
          sheet.getRangeByIndex(row, 4).setNumber(amount);
          sheet.getRangeByIndex(row, 5).setText(item.aciklama);
          sheet.getRangeByIndex(row, 6).setNumber(cumulative);

          if (item.fisYolu.isNotEmpty) {
            try {
              final bytes = await (ImageService.isNetworkUrl(item.fisYolu) 
                  ? ImageService().downloadImage(item.fisYolu) 
                  : File(item.fisYolu).readAsBytes());
              
              if (bytes != null) {
                photoCount++;
                final String sheetName = "H-$photoCount";
                final sf.Worksheet photoSheet = workbook.worksheets.addWithName(sheetName);

                photoSheet.getRangeByIndex(1, 1).setText("${item.aciklama} - $tarihStr");
                photoSheet.getRangeByIndex(1, 1).cellStyle.bold = true;
                photoSheet.pictures.addStream(2, 1, bytes);

                final sf.Range range = sheet.getRangeByIndex(row, 7);
                final sf.Hyperlink hyperlink = sheet.hyperlinks.add(range, sf.HyperlinkType.workbook, "'$sheetName'!A1");
                hyperlink.textToDisplay = "RESMİ GÖR";

                final safeAciklama = item.aciklama.length > 20 
                    ? item.aciklama.substring(0, 20).replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
                    : item.aciklama.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
                final uzanti = item.fisYolu.split('.').last.split('?').first.toLowerCase();
                final fotoAdi = "harcama_${safeAciklama}_$tarihStr.$photoCount.$uzanti";
                sheet.getRangeByIndex(row, 8).setText(fotoAdi);

                await File("${hedefKlasor.path}/$fotoAdi").writeAsBytes(bytes);
                photoSuccessCount++;
              }
            } catch (e) {
              photoErrorCount++;
              errorLogs.add("Hata (${item.aciklama}): $e");
            }
          }
          successCount++;
        }
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();
      
      final excelFile = File("${hedefKlasor.path}/$typeStr.xlsx");
      await excelFile.writeAsBytes(bytes);

      if (mounted) {
        Navigator.pop(context); // Dialog kapat
        
        String resultMsg = '$successCount kayıt Excel\'e aktarıldı.\n';
        if (photoSuccessCount > 0) resultMsg += '$photoSuccessCount fotoğraf başarıyla kopyalandı.\n';
        if (photoErrorCount > 0) resultMsg += '$photoErrorCount fotoğraf kopyalanamadı.';
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(photoErrorCount > 0 ? "İşlem Tamamlandı (Bazı Hatalar Var)" : "İşlem Başarılı"),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(resultMsg),
                  if (photoErrorCount > 0) ...[
                    const Divider(),
                    const Text("Hata Detayları:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ...errorLogs.map((e) => Text("- $e", style: const TextStyle(fontSize: 12, color: Colors.red))),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(child: const Text("TAMAM"), onPressed: () => Navigator.pop(context)),
              TextButton(
                child: const Text("KLASÖRÜ AÇ"), 
                onPressed: () {
                   Navigator.pop(context);
                   launchUrl(Uri.file(hedefKlasor.path));
                }
              ),
            ],
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kritik Hata: $e'), backgroundColor: Colors.red),
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
          style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 11),
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
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF2C2C2C),
                  value: kategori,
                  decoration: const InputDecoration(
                    labelText: "Kategori",
                    labelStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: ["Genel", "Yemek", "Malzeme", "İşçilik", "Diğer"].map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(cat, style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => kategori = val);
                  },
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

  void _showResetOptionsDialog(bool isFatura) {
    final title = isFatura ? "Fatura Hesabı Sıfırlama" : "Harcama Hesabı Sıfırlama";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bu işlem sadece seçili kategoriyi etkiler. Lütfen bir seçenek belirleyin:",
              style: TextStyle(color: ThemeColors.textSecondary(context)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onHesapSifirla(true, isFatura: isFatura); 
              },
              child: const Row(
                children: [
                   Icon(Icons.history, color: Colors.white),
                   SizedBox(width: 10),
                   Expanded(child: Text("Yeni Dönem Başlat\n(Eskileri Arşivle)", style: TextStyle(color: Colors.white), textAlign: TextAlign.left)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog(isFatura);
              },
              child: const Row(
                children: [
                   Icon(Icons.delete_forever, color: Colors.white),
                   SizedBox(width: 10),
                   Expanded(child: Text("Kalıcı Olarak Sil", style: TextStyle(color: Colors.white), textAlign: TextAlign.left)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
             child: Text("İptal", style: TextStyle(color: ThemeColors.textSecondary(context))),
             onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(bool isFatura) {
    final category = isFatura ? "fatura" : "harcama";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("DİKKAT!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(
          "Tüm $category kayıtları kalıcı olarak silinecek.\nDevam etmek istiyor musunuz?",
          style: TextStyle(color: ThemeColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
             child: Text("Vazgeç", style: TextStyle(color: ThemeColors.textSecondary(context))),
             onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("EVET, SİL", style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              widget.onHesapSifirla(false, isFatura: isFatura);
            },
          ),
        ],
      ),
    );
  }

  void _showArchivesDialog() async {
    final archives = await StorageService().getArchives();
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: const Text("Finans Arşivleri", style: TextStyle(color: Colors.white)),
        content: archives.isEmpty 
          ? const Text("Henüz arşivlenmiş veri bulunmuyor.", style: TextStyle(color: Colors.white70))
          : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: archives.length,
                itemBuilder: (context, index) {
                  final archive = archives[index];
                  final date = archive['date'] as DateTime;
                  final dateStr = "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}";
                  
                  return ListTile(
                    leading: Icon(
                      archive['type'] == 'Faturalar' ? Icons.receipt_long : Icons.payments,
                      color: Colors.orange,
                    ),
                    title: Text("${archive['type']} Arşivi", style: const TextStyle(color: Colors.white)),
                    subtitle: Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      _viewArchiveData(archive);
                    },
                    trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                  );
                },
              ),
            ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Kapat")),
        ],
      ),
    );
  }

  void _viewArchiveData(Map<String, dynamic> archive) async {
    final data = await StorageService().loadArchiveData(archive['filename']);
    final isFatura = archive['type'] == 'Faturalar';
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.background(context),
        title: Text("${archive['type']} (${(archive['date'] as DateTime).year})", style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
               Text("${data.length} kayıt bulundu", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
               const Divider(),
               Expanded(
                 child: ListView.builder(
                   itemCount: data.length,
                   itemBuilder: (context, index) {
                     final item = data[index];
                     if (isFatura) {
                       return ListTile(
                         title: Text(item['firmaAdi'] ?? '', style: const TextStyle(color: Colors.white)),
                         subtitle: Text(item['aciklama'] ?? '', style: const TextStyle(color: Colors.white54)),
                         trailing: Text("${item['toplamTutar']} TL", style: const TextStyle(color: Colors.greenAccent)),
                       );
                     } else {
                        final isInc = item['isReimbursement'] == true;
                        return ListTile(
                         title: Text(item['aciklama'] ?? '', style: const TextStyle(color: Colors.white)),
                         subtitle: Text(item['kategori'] ?? '', style: const TextStyle(color: Colors.white54)),
                         trailing: Text(
                           "${isInc ? '+' : '-'}${item['tutar']} TL", 
                           style: TextStyle(color: isInc ? Colors.greenAccent : Colors.redAccent)
                         ),
                       );
                     }
                   },
                 ),
               ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Geri", style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
  }
}
