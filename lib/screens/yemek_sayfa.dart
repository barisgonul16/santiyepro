import 'package:flutter/material.dart';
import '../models/proje.dart';
import '../models/gunluk_kayit.dart';
import '../theme/theme_colors.dart';
import 'package:excel/excel.dart' as xls;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class YemekSayfaPage extends StatefulWidget {
  final List<Proje> projeler;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;

  const YemekSayfaPage({
    super.key,
    required this.projeler,
    required this.projeGunlukKayitlari,
  });

  @override
  State<YemekSayfaPage> createState() => _YemekSayfaPageState();
}

class _YemekSayfaPageState extends State<YemekSayfaPage> {
  String _sortColumn = 'tarih'; // 'tarih', 'projeAdi', 'toplamYemek'
  bool _sortAscending = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _useMonthlyFilter = true;
  String? _secilenProjeId;

  final List<String> _aylar = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  List<Map<String, dynamic>> _getYemekListesi() {
    List<Map<String, dynamic>> liste = [];

    for (var proje in widget.projeler) {
      if (_secilenProjeId != null && _secilenProjeId != proje.id) continue;

      final kayitlar = widget.projeGunlukKayitlari[proje.id] ?? [];
      for (int i = 0; i < kayitlar.length; i++) {
        final kayit = kayitlar[i];
        final toplamYemek = kayit.yemekKalipci + kayit.yemekDemirci + kayit.yemekDiger;

        if (toplamYemek > 0) {
          // Ay Filtresi
          if (_useMonthlyFilter) {
            if (kayit.tarih.year != _selectedYear || kayit.tarih.month != _selectedMonth) continue;
          } else {
            // Tarih Aralığı filtresi
            if (_filterStartDate != null && kayit.tarih.isBefore(_filterStartDate!)) continue;
            if (_filterEndDate != null && kayit.tarih.isAfter(_filterEndDate!.add(const Duration(days: 1)))) continue;
          }

          liste.add({
            'projeId': proje.id,
            'projeAdi': proje.ad,
            'tarih': kayit.tarih,
            'kalipci': kayit.yemekKalipci,
            'demirci': kayit.yemekDemirci,
            'diger': kayit.yemekDiger,
            'toplamYemek': toplamYemek,
          });
        }
      }
    }

    // Sıralama
    liste.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'projeAdi':
          cmp = (a['projeAdi'] as String).toLowerCase().compareTo((b['projeAdi'] as String).toLowerCase());
          break;
        case 'toplamYemek':
          cmp = (a['toplamYemek'] as int).compareTo(b['toplamYemek'] as int);
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
              primary: Colors.orange,
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
      _secilenProjeId = null;
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
    final liste = _getYemekListesi();
    if (liste.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktarılacak yemek kaydı bulunamadı.')),
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
      xls.Sheet sheetObject = excel['Yemekler'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        xls.TextCellValue("Tarih"),
        xls.TextCellValue("Proje Adı"),
        xls.TextCellValue("Kalıpçı"),
        xls.TextCellValue("Demirci"),
        xls.TextCellValue("Diğer"),
        xls.TextCellValue("Toplam"),
      ]);

      for (var item in liste) {
        final tarihStr = DateFormat('dd.MM.yyyy').format(item['tarih']);
        sheetObject.appendRow([
          xls.TextCellValue(tarihStr),
          xls.TextCellValue(item['projeAdi']),
          xls.IntCellValue(item['kalipci']),
          xls.IntCellValue(item['demirci']),
          xls.IntCellValue(item['diger']),
          xls.IntCellValue(item['toplamYemek']),
        ]);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = "Yemekler_$timestamp.xlsx";
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

  @override
  Widget build(BuildContext context) {
    final liste = _getYemekListesi();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Yemek Takibi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _tarihFiltresiSec,
            tooltip: 'Tarih Aralığı Filtresi',
          ),
          if (_filterStartDate != null || _useMonthlyFilter || _secilenProjeId != null)
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
          // Filtre Alanı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            color: Colors.orange.withOpacity(0.1),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.orange, size: 20),
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
                        '${_aylar[_selectedMonth - 1]} $_selectedYear',
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Şantiye Filtresi
                Row(
                  children: [
                    const Icon(Icons.business, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<String?>(
                        value: _secilenProjeId,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2D2D2D),
                        hint: const Text('Tüm Şantiyeler', style: TextStyle(color: Colors.white70)),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        underline: const SizedBox(),
                        onChanged: (val) {
                          setState(() {
                            _secilenProjeId = val;
                          });
                        },
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tüm Şantiyeler'),
                          ),
                          ...widget.projeler.map((p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(p.ad),
                          )).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tablo Başlığı
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.3),
              border: const Border(bottom: BorderSide(color: Colors.white24)),
            ),
            child: Row(
              children: [
                _buildHeaderCell('Tarih', 'tarih', flex: 2),
                _buildHeaderCell('Şantiye', 'projeAdi', flex: 3),
                _buildHeaderCell('Kalıp', '', flex: 1, isSortable: false),
                _buildHeaderCell('Demir', '', flex: 1, isSortable: false),
                _buildHeaderCell('Diğer', '', flex: 1, isSortable: false),
                _buildHeaderCell('Top.', 'toplamYemek', flex: 1),
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
                              flex: 1,
                              child: Text(
                                '${item['kalipci']}',
                                style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${item['demirci']}',
                                style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${item['diger']}',
                                style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${item['toplamYemek']}',
                                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ── TOPLAM SATIRI ──
          if (liste.isNotEmpty)
            _buildToplamSatiri(liste),
        ],
      ),
    );
  }

  Widget _buildToplamSatiri(List<Map<String, dynamic>> liste) {
    final int toplamKalipci = liste.fold(0, (sum, item) => sum + (item['kalipci'] as int));
    final int toplamDemirci = liste.fold(0, (sum, item) => sum + (item['demirci'] as int));
    final int toplamDiger   = liste.fold(0, (sum, item) => sum + (item['diger']   as int));
    final int genelToplam   = liste.fold(0, (sum, item) => sum + (item['toplamYemek'] as int));

    // Başlık etiketi: aylık mı yoksa tarih aralığı mı?
    String donemEtiketi;
    if (_useMonthlyFilter) {
      donemEtiketi = '${_aylar[_selectedMonth - 1]} $_selectedYear';
    } else if (_filterStartDate != null && _filterEndDate != null) {
      final fmt = DateFormat('dd.MM.yyyy');
      donemEtiketi = '${fmt.format(_filterStartDate!)} – ${fmt.format(_filterEndDate!)}';
    } else {
      donemEtiketi = 'Tüm Dönem';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.18),
        border: const Border(
          top: BorderSide(color: Colors.orangeAccent, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'TOPLAM  ·  $donemEtiketi',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Row(
            children: [
              // Tarih + Şantiye alanının genişliğini (flex 2+3=5) dolduran boşluk
              const Expanded(flex: 5, child: SizedBox()),
              // Kalıpçı
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kalıpçı', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Text(
                      '$toplamKalipci',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Demirci
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Demirci', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Text(
                      '$toplamDemirci',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Diğer
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Diğer', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Text(
                      '$toplamDiger',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Genel Toplam
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Toplam', style: TextStyle(color: Colors.orangeAccent, fontSize: 10)),
                    Text(
                      '$genelToplam',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, String column, {required int flex, bool isSortable = true}) {
    final isSorted = _sortColumn == column;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: isSortable ? () => _sirala(column) : null,
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            if (isSortable && isSorted)
              Icon(
                _sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: Colors.orangeAccent,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
