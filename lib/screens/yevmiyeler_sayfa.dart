import 'package:flutter/material.dart';
import '../models/proje.dart';
import '../models/gunluk_kayit.dart';
import '../theme/theme_colors.dart';
import 'package:excel/excel.dart' as xls;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class YevmiyelerSayfaPage extends StatefulWidget {
  final List<Proje> projeler;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;
  final Function(String, int, GunlukKayit) onGunlukKayitGuncelle;
  final List<String> ekipler;
  final Function(List<String>) onEkiplerGuncelle;

  const YevmiyelerSayfaPage({
    super.key,
    required this.projeler,
    required this.projeGunlukKayitlari,
    required this.onGunlukKayitGuncelle,
    required this.ekipler,
    required this.onEkiplerGuncelle,
  });

  @override
  State<YevmiyelerSayfaPage> createState() => _YevmiyelerSayfaPageState();
}

class _YevmiyelerSayfaPageState extends State<YevmiyelerSayfaPage> {
  String _sortColumn = 'tarih'; // 'tarih', 'ekipAdi', 'yevmiye', 'projeAdi'
  bool _sortAscending = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _useMonthlyFilter = true;
  String _ekipFiltresi = '';
  final TextEditingController _ekipFiltreController = TextEditingController();

  final List<String> _aylar = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  List<Map<String, dynamic>> _getYevmiyeListesi() {
    List<Map<String, dynamic>> liste = [];

    for (var proje in widget.projeler) {
      final kayitlar = widget.projeGunlukKayitlari[proje.id] ?? [];
      for (int i = 0; i < kayitlar.length; i++) {
        final kayit = kayitlar[i];
        if (kayit.yevmiyeEkipAdi.isNotEmpty || kayit.yevmiyeMiktari > 0) {
          // Ay Filtresi
          if (_useMonthlyFilter) {
            if (kayit.tarih.year != _selectedYear || kayit.tarih.month != _selectedMonth) continue;
          } else {
            // Tarih Aralığı filtresi
            if (_filterStartDate != null && kayit.tarih.isBefore(_filterStartDate!)) continue;
            if (_filterEndDate != null && kayit.tarih.isAfter(_filterEndDate!.add(const Duration(days: 1)))) continue;
          }

          // Ekip Filtresi
          if (_ekipFiltresi.isNotEmpty) {
            if (!kayit.yevmiyeEkipAdi.toLowerCase().contains(_ekipFiltresi.toLowerCase())) continue;
          }

          liste.add({
            'projeId': proje.id,
            'kayitIndex': i,
            'kayit': kayit,
            'projeAdi': proje.ad,
            'tarih': kayit.tarih,
            'ekipAdi': kayit.yevmiyeEkipAdi,
            'yevmiye': kayit.yevmiyeMiktari,
            'aciklama': kayit.yevmiyeAciklama,
          });
        }
      }
    }

    // Sıralama
    liste.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'ekipAdi':
          cmp = (a['ekipAdi'] as String).toLowerCase().compareTo((b['ekipAdi'] as String).toLowerCase());
          break;
        case 'projeAdi':
          cmp = (a['projeAdi'] as String).toLowerCase().compareTo((b['projeAdi'] as String).toLowerCase());
          break;
        case 'yevmiye':
          cmp = (a['yevmiye'] as double).compareTo(b['yevmiye'] as double);
          break;
        case 'tarih':
        default:
          cmp = (a['tarih'] as DateTime).compareTo(b['tarih'] as DateTime);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return liste;
  }

  void _tarihFiltresiSec() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _filterStartDate != null && _filterEndDate != null
          ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.purple,
              onPrimary: Colors.white,
              surface: const Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterStartDate = picked.start;
        _filterEndDate = picked.end;
        _useMonthlyFilter = false;
      });
    }
  }

  void _filtreSifirla() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
      _useMonthlyFilter = false;
    });
  }

  void _sirala(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  Future<void> _excelAktar() async {
    final liste = _getYevmiyeListesi();
    if (liste.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktarılacak yevmiye kaydı bulunamadı.')),
      );
      return;
    }

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var excel = xls.Excel.createExcel();
      xls.Sheet sheetObject = excel['Yevmiyeler'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        xls.TextCellValue("Proje Adı"),
        xls.TextCellValue("Tarih"),
        xls.TextCellValue("Ekip Adı"),
        xls.TextCellValue("Yevmiye Adeti"),
        xls.TextCellValue("Açıklama"),
      ]);

      for (var item in liste) {
        final tarihStr = DateFormat('dd.MM.yyyy').format(item['tarih']);
        sheetObject.appendRow([
          xls.TextCellValue(item['projeAdi']),
          xls.TextCellValue(tarihStr),
          xls.TextCellValue(item['ekipAdi']),
          xls.DoubleCellValue(item['yevmiye']),
          xls.TextCellValue(item['aciklama']),
        ]);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = "Yevmiyeler_$timestamp.xlsx";
      final filePath = "$selectedDirectory/$fileName";
      
      final fileBytes = excel.save();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel başarıyla kaydedildi: $fileName'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _yevmiyeDuzenleDialog(Map<String, dynamic> item) {
    final ekipAdiController = TextEditingController(text: item['ekipAdi']);
    final miktarController = TextEditingController(text: item['yevmiye'].toString());
    final aciklamaController = TextEditingController(text: item['aciklama']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: const Text('Yevmiye Düzenle', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ekipAdiController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Ekip Adı', labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: miktarController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Yevmiye Adeti', labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: aciklamaController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Açıklama', labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              final oldKayit = item['kayit'] as GunlukKayit;
              final newKayit = GunlukKayit(
                tarih: oldKayit.tarih,
                kalipci: oldKayit.kalipci,
                demirci: oldKayit.demirci,
                diger: oldKayit.diger,
                kalipciYapilanIs: oldKayit.kalipciYapilanIs,
                demirciYapilanIs: oldKayit.demirciYapilanIs,
                notlar: oldKayit.notlar,
                beton: oldKayit.beton,
                fotografYollari: oldKayit.fotografYollari,
                vincFirmaAdi: oldKayit.vincFirmaAdi,
                vincBaslangic: oldKayit.vincBaslangic,
                vincBitis: oldKayit.vincBitis,
                vincMola: oldKayit.vincMola,
                yevmiyeEkipAdi: ekipAdiController.text,
                yevmiyeMiktari: double.tryParse(miktarController.text) ?? 0,
                yevmiyeAciklama: aciklamaController.text,
              );
              widget.onGunlukKayitGuncelle(item['projeId'], item['kayitIndex'], newKayit);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  void _yevmiyeSilOnay(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: const Text('Yevmiye Sil', style: TextStyle(color: Colors.white)),
        content: const Text('Bu yevmiye kaydını silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final oldKayit = item['kayit'] as GunlukKayit;
              final newKayit = GunlukKayit(
                tarih: oldKayit.tarih,
                kalipci: oldKayit.kalipci,
                demirci: oldKayit.demirci,
                diger: oldKayit.diger,
                kalipciYapilanIs: oldKayit.kalipciYapilanIs,
                demirciYapilanIs: oldKayit.demirciYapilanIs,
                notlar: oldKayit.notlar,
                beton: oldKayit.beton,
                fotografYollari: oldKayit.fotografYollari,
                vincFirmaAdi: oldKayit.vincFirmaAdi,
                vincBaslangic: oldKayit.vincBaslangic,
                vincBitis: oldKayit.vincBitis,
                vincMola: oldKayit.vincMola,
                yevmiyeEkipAdi: '',
                yevmiyeMiktari: 0,
                yevmiyeAciklama: '',
              );
              widget.onGunlukKayitGuncelle(item['projeId'], item['kayitIndex'], newKayit);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _ekipleriYonet() {
    final yeniEkipController = TextEditingController();
    List<String> tempEkipler = List.from(widget.ekipler);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: ThemeColors.cardBackground(context),
            title: Text('Ekipleri Yönet', style: TextStyle(color: ThemeColors.textPrimary(context))),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: yeniEkipController,
                          style: TextStyle(color: ThemeColors.textPrimary(context)),
                          decoration: InputDecoration(
                            hintText: 'Yeni ekip adı',
                            hintStyle: TextStyle(color: ThemeColors.textSecondary(context)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: ThemeColors.border(context))),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (yeniEkipController.text.isNotEmpty) {
                            setDialogState(() {
                              tempEkipler.add(yeniEkipController.text);
                              yeniEkipController.clear();
                            });
                            widget.onEkiplerGuncelle(tempEkipler);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        child: const Text('Ekle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: tempEkipler.isEmpty
                        ? Center(child: Text('Kayıtlı ekip yok.', style: TextStyle(color: ThemeColors.textSecondary(context))))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: tempEkipler.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(tempEkipler[index], style: TextStyle(color: ThemeColors.textPrimary(context))),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setDialogState(() {
                                      tempEkipler.removeAt(index);
                                    });
                                    widget.onEkiplerGuncelle(tempEkipler);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liste = _getYevmiyeListesi();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Yevmiye Takibi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: _ekipleriYonet,
            tooltip: 'Ekipleri Yönet',
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _tarihFiltresiSec,
            tooltip: 'Tarih Aralığı Filtresi',
          ),
          if (_filterStartDate != null || _useMonthlyFilter)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              onPressed: _filtreSifirla,
              tooltip: 'Filtreleri Kaldır',
            ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _excelAktar,
            tooltip: 'Excel\'e Aktar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Ay Seçici
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            color: const Color(0xFF004D40).withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Color(0xFF00796B), size: 20),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: _selectedMonth,
                  dropdownColor: const Color(0xFF2D2D2D),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  underline: const SizedBox(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedMonth = val;
                        _useMonthlyFilter = true;
                        _filterStartDate = null;
                        _filterEndDate = null;
                      });
                    }
                  },
                  items: List.generate(12, (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text(_aylar[index]),
                  )),
                ),
                const SizedBox(width: 15),
                DropdownButton<int>(
                  value: _selectedYear,
                  dropdownColor: const Color(0xFF2D2D2D),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  underline: const SizedBox(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedYear = val;
                        _useMonthlyFilter = true;
                        _filterStartDate = null;
                        _filterEndDate = null;
                      });
                    }
                  },
                  items: List.generate(10, (index) => DropdownMenuItem(
                    value: DateTime.now().year - 5 + index,
                    child: Text('${DateTime.now().year - 5 + index}'),
                  )),
                ),
                const Spacer(),
                if (_useMonthlyFilter)
                  Text(
                    '${_aylar[_selectedMonth - 1]} $_selectedYear Kayıtları',
                    style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          // Ekip Filtre Alanı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF004D40).withOpacity(0.05),
              border: const Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white54, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ekipFiltreController,
                    onChanged: (val) {
                      setState(() {
                        _ekipFiltresi = val;
                      });
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Ekip ismine göre filtrele...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_ekipFiltresi.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () {
                      setState(() {
                        _ekipFiltreController.clear();
                        _ekipFiltresi = '';
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          // Tablo Başlığı
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF004D40).withOpacity(0.3),
              border: const Border(bottom: BorderSide(color: Colors.white24)),
            ),
            child: Row(
              children: [
                _buildHeaderCell('Tarih', 'tarih', flex: 2),
                _buildHeaderCell('Proje Adı', 'projeAdi', flex: 3),
                _buildHeaderCell('Ekip Adı', 'ekipAdi', flex: 3),
                _buildHeaderCell('Adet', 'yevmiye', flex: 2),
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Yapılan İş',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          
          Expanded(
            child: liste.isEmpty
                ? Center(
                    child: Text(
                      'Kayıt bulunamadı.',
                      style: TextStyle(color: ThemeColors.textSecondary(context)),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: liste.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) {
                      final item = liste[index];
                      final tarihStr = DateFormat('dd.MM.yyyy').format(item['tarih']);

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                tarihStr,
                                style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item['projeAdi'],
                                style: TextStyle(color: Colors.blueAccent.shade100, fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item['ekipAdi'],
                                style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${item['yevmiye']}',
                                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item['aciklama'],
                                style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            PopupMenuButton(
                              icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                              padding: EdgeInsets.zero,
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Düzenle'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Sil', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _yevmiyeDuzenleDialog(item);
                                } else if (val == 'delete') {
                                  _yevmiyeSilOnay(item);
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, String column, {required int flex}) {
    final isSorted = _sortColumn == column;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _sirala(column),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (isSorted)
              Icon(
                _sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: Colors.purpleAccent,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
