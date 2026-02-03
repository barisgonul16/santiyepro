import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/pratik_bilgi.dart';
import '../theme/theme_colors.dart';

class PratikBilgilerSayfaPage extends StatefulWidget {
  final List<PratikBilgi> customPratikBilgiler;
  final Function(PratikBilgi) onEkle;

  final Function(int, PratikBilgi) onGuncelle;
  final Function(int) onSil;

  const PratikBilgilerSayfaPage({
    super.key,
    this.customPratikBilgiler = const [],
    required this.onEkle,
    required this.onGuncelle,
    required this.onSil,
  });

  @override
  State<PratikBilgilerSayfaPage> createState() =>
      _PratikBilgilerSayfaPageState();
}

class _PratikBilgilerSayfaPageState extends State<PratikBilgilerSayfaPage> {
  int? _selectedSection;

  // --- Tahvil State ---
  int _selectedProjectDiameter = 16;
  int _selectedProjectCount = 1;
  int _targetDiameter = 14;
  final List<int> _diameters = [8, 10, 12, 14, 16, 18, 20, 22, 25, 28, 32];

  // --- Autocad State ---
  List<Map<String, String>> _autocadCommands = [
    {'key': 'A', 'cmd': 'Arc', 'desc': 'Yay çizer'},
    {'key': 'AA', 'cmd': 'Area', 'desc': 'Alan hesaplar'},
    {'key': 'B', 'cmd': 'Block', 'desc': 'Blok oluşturur'},
    {'key': 'C', 'cmd': 'Circle', 'desc': 'Daire çizer'},
    {'key': 'CO', 'cmd': 'Copy', 'desc': 'Nesneleri kopyalar'},
    {'key': 'DI', 'cmd': 'Dist', 'desc': 'Ölçü alır'},
    {'key': 'E', 'cmd': 'Erase', 'desc': 'Silme yapar'},
    {'key': 'EX', 'cmd': 'Extend', 'desc': 'Çizgileri uzatır'},
    {'key': 'F', 'cmd': 'Fillet', 'desc': 'Köşeleri yuvarlatır'},
    {'key': 'H', 'cmd': 'Hatch', 'desc': 'Tarama yapar'},
    {'key': 'L', 'cmd': 'Line', 'desc': 'Çizgi çizer'},
    {'key': 'LI', 'cmd': 'List', 'desc': 'Özellikleri listeler'},
    {'key': 'M', 'cmd': 'Move', 'desc': 'Nesneleri taşır'},
    {'key': 'MI', 'cmd': 'Mirror', 'desc': 'Aynalama yapar'},
    {'key': 'O', 'cmd': 'Offset', 'desc': 'Öteleme yapar'},
    {'key': 'PL', 'cmd': 'Polyline', 'desc': 'Birleşik çizgi çizer'},
    {'key': 'REC', 'cmd': 'Rectangle', 'desc': 'Dikdörtgen çizer'},
    {'key': 'RO', 'cmd': 'Rotate', 'desc': 'Döndürür'},
    {'key': 'SC', 'cmd': 'Scale', 'desc': 'Ölçeklendirir'},
    {'key': 'TR', 'cmd': 'Trim', 'desc': 'Fazlalıkları budar'},
    {'key': 'X', 'cmd': 'Explode', 'desc': 'Patlatma yapar'},
  ];

  // --- Malzeme Listesi State ---
  // Tablo 1: Trio Kalıp
  List<String> _table1Headers = ['TRİO KALIP', '360', '330', '300', '150', '120'];
  List<List<String>> _table1Rows = [
    ['150', '', '', '', '', ''],
    ['120', '', '', '', '', ''],
    ['90', '', '', '', '', ''],
    ['75', '', '', '', '', ''],
    ['60', '', '', '', '', ''],
    ['45', '', '', '', '', ''],
  ];

  // Tablo 2: Trio Köşe Kalıp
  List<String> _table2Headers = [
    'Trio Köşe(330)',
    '30',
    '35',
    '40',
    '50',
    '60'
  ];
  List<List<String>> _table2Rows = [
    ['25', '', '', '', '', ''],
    ['30', '', '', '', '', ''],
    ['35', '', '', '', '', ''],
    ['40', '', '', '', '', ''],
    ['50', '', '', '', '', ''],
    ['Mafsallı 30', '', '', '', '', ''],
  ];

  final List<Map<String, dynamic>> _sections = [
    {
      'id': 0,
      'title': 'Pratik Bilgiler',
      'icon': Icons.lightbulb,
      'color': Colors.orange,
      'description': 'Metraj kabulleri, oranlar ve adam/gün değerleri',
    },
    {
      'id': 1,
      'title': 'Tahvil',
      'icon': Icons.construction,
      'color': Colors.blueGrey,
      'description': 'Demir donatı tahvil hesaplayıcısı',
    },
    {
      'id': 2,
      'title': 'Beton',
      'icon': Icons.square_foot,
      'color': Colors.blue,
      'description': 'Beton karışım oranları tablosu',
    },
    {
      'id': 3,
      'title': 'Malzeme Listesi',
      'icon': Icons.list_alt,
      'color': Colors.teal,
      'description': 'Düzenlenebilir kalıp ve malzeme listeleri',
    },
    {
      'id': 4,
      'title': 'Autocad Bilgiler',
      'icon': Icons.computer,
      'color': Colors.redAccent,
      'description': 'Kısayollar ve komutlar (Düzenlenebilir)',
    },
    {
      'id': 5,
      'title': 'Kalıp Hesabı',
      'icon': Icons.calculate,
      'color': Colors.purple,
      'description': 'Kalıp metrajı ve malzeme hesapları',
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (_selectedSection != null) {
      return WillPopScope(
        onWillPop: () async {
          setState(() {
            _selectedSection = null;
          });
          return false;
        },
        child: Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedSection = null;
                      });
                    },
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    _sections[_selectedSection!]['icon'],
                    color: _sections[_selectedSection!]['color'],
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _sections[_selectedSection!]['title'],
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.textPrimary(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedSection == 0)
                    IconButton(
                      onPressed: () => _showAddPratikBilgiDialog(context),
                      icon: Icon(Icons.add_circle, color: Colors.orange, size: 32),
                      tooltip: 'Yeni Bilgi Ekle',
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildSectionContent(_selectedSection!),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Removed per user request
          /*
          const Text(
            'Bilgiler',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'İnşaat sahasında ihtiyacınız olan teknik veriler ve hesaplayıcılar',
            style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 14),
          ),
          const SizedBox(height: 30),
          */
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Mobile View: Use ListView to prevent overflow and "squashed" cards
                if (constraints.maxWidth < 600) {
                   return ListView.builder(
                     itemCount: _sections.length,
                     itemBuilder: (context, index) {
                       return Padding(
                         padding: const EdgeInsets.only(bottom: 15),
                         child: _buildMenuCard(_sections[index]),
                       );
                     },
                   );
                }

                // Desktop/Tablet View: Use GridView
                int crossAxisCount = constraints.maxWidth < 900 ? 2 : 3;
                double childAspectRatio = 1.2;

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: _sections.length,
                  itemBuilder: (context, index) {
                    final section = _sections[index];
                    return _buildMenuCard(section);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(Map<String, dynamic> section) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSection = section['id'];
          });
        },
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ThemeColors.cardBackground(context),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: (section['color'] as Color).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (section['color'] as Color).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  section['icon'],
                  color: section['color'],
                  size: 32,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                section['title'],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeColors.textPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                section['description'],
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeColors.textTertiary(context),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContent(int sectionId) {
    switch (sectionId) {
      case 0: // Pratik Bilgiler (Güncellendi)
        return Column(
          children: [
            _buildInfoBox(
              'Pratik Metraj Kabulleri',
              '''
• Beton: 0,380 m³/m²
• Demir: 34 kg/m²
• Hasır Çelik: 2,97 kg/m²

1 m²'ye Kaç Kilo Demir Gider?
• Temellerde: 35-45 kg
• Asmolen Döşemelerde: 30-35 kg
• Normal Kat Döşemelerinde: 25-30 kg
• Çatılarda: 15-20 kg

Diğer Oranlar:
• Beton/Demir Oranı: 0,100
• Demirin Özgül Ağırlığı: 7.85 gr/cm³
• Tuğla Duvar: 0.150 m³/m²
• Betonarme Kalıbı: 2.60 m³/m²

Betonarme Hesap Kabulleri:
• Temel hesaplıyorsanız: 1 m³ x 75-85 kg
• Diğer elemanlarda: 1 m³ x 55-75 kg''',
              Icons.calculate_outlined,
              Colors.orange,
            ),
            const SizedBox(height: 20),
            _buildInfoBox(
              'Adam / Gün Verimleri',
              '''
• Beton Kalıbı: 10 m²/adam
• Kalıp İskelesi: 60 m³/adam (Sadece yapılması)
• Demir Tezgah: 1 ton/adam
• Demir Montaj: 500 kg/adam''',
              Icons.people_alt,
              Colors.green,
            ),
            const SizedBox(height: 30),

            // Custom Notes (Displayed at the bottom now)
            if (widget.customPratikBilgiler.isNotEmpty)
              ...List.generate(widget.customPratikBilgiler.length, (index) {
                final info = widget.customPratikBilgiler[index];
                return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Stack(
                      children: [
                        _buildInfoBox(
                          info.baslik,
                          info.icerik,
                          Icons.note,
                          Colors.cyan,
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: ThemeColors.textSecondary(context), size: 20),
                                onPressed: () {
                                  // Edit logic
                                  _showAddPratikBilgiDialog(context, existingInfo: info, index: index);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  // Delete logic with confirmation
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF2D2D2D),
                                      title: const Text('Sil', style: TextStyle(color: Colors.white)),
                                      content: const Text('Bu bilgiyi silmek istiyor musunuz?', style: TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () {
                                            widget.onSil(index); 
                                            Navigator.pop(context);
                                          },
                                          child: const Text('Sil'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
              }),


          ],
        );

      case 1: // Tahvil (Hesaplayıcı Eklendi)
        return Column(
          children: [
            _buildTahvilCalculator(),
            const SizedBox(height: 30),
            // Eski tablo referans olarak kalabilir veya kaldırılabilir.
            // Kullanıcı "1. fotoğrafdaki gibi tahvil uygulaması yap" dediği için
            // sadece uygulamayı koyuyorum, tabloyu alta referans ekliyorum.
          ],
        );

      case 2: // Beton (Tablo Eklendi)
        return Column(
          children: [
            _buildBetonReceteTable(),
          ],
        );

      case 3: // Malzeme Listesi (Dinamik Tablolar)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEditableTable(
              title: 'Trio Kalıp Malzeme Listesi',
              headers: _table1Headers,
              rows: _table1Rows,
              onHeadersChanged: (newHeaders) {
                setState(() => _table1Headers = newHeaders);
              },
              onRowsChanged: (newRows) {
                setState(() => _table1Rows = newRows);
              },
            ),
            const SizedBox(height: 30),
            _buildEditableTable(
              title: 'Trio Köşe Kalıp Listesi',
              headers: _table2Headers,
              rows: _table2Rows,
              onHeadersChanged: (newHeaders) {
                setState(() => _table2Headers = newHeaders);
              },
              onRowsChanged: (newRows) {
                setState(() => _table2Rows = newRows);
              },
            ),
          ],
        );

      case 4: // Autocad Bilgiler (CRUD Listesi)
        return _buildAutocadSection();

      case 5: // Kalıp Hesabı (Mevcut Durum)
        return Column(
          children: [
            _buildInfoBox(
              'Kolon Kalıbı',
              'Kolon Yüzey Alanı = Kolon Çevresi × Yükseklik\nÖrnek: 50x50 kolon, 3m yükseklik\nÇevre = (0.5 + 0.5) × 2 = 2m\nAlan = 2m × 3m = 6 m²',
              Icons.view_column,
              Colors.purple,
            ),
            const SizedBox(height: 20),
            _buildInfoBox(
              'Kiriş Kalıbı',
              'Kiriş Yan Yüzeyleri + Kiriş Altı\nÖrnek: 25x50 kiriş\nYanlar = 0.50m × 2 = 1m\nAlt = 0.25m\nToplam Çevre = 1.25m\n10m boyunda kiriş için = 1.25 × 10 = 12.5 m²',
              Icons.table_bar,
              Colors.purpleAccent,
            ),
            const SizedBox(height: 20),
            _buildInfoBox(
              'Döşeme Kalıbı',
              'Döşeme Alanı = En × Boy\n(Düşülen kolon boşlukları ihmal edilebilir veya düşülebilir)\nGenelde döşeme alanı + kiriş kanatları toplam kalıp metrajını verir.',
              Icons.aspect_ratio,
              Colors.deepPurple,
            ),
          ],
        );
      default:
        return const Center(child: Text('İçerik bulunamadı'));
    }
  }

  // --- Widget Builders ---

  Widget _buildInfoBox(
      String title, String content, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              content,
              style: TextStyle(
                color: ThemeColors.textSecondary(context),
                height: 1.6,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Tahvil Hesaplayıcı ---
  Widget _buildTahvilCalculator() {
    // Hesaplamalar
    double pArea1 = (math.pi * math.pow(_selectedProjectDiameter / 2, 2));
    double totalPArea = pArea1 * _selectedProjectCount;
    double tArea1 = (math.pi * math.pow(_targetDiameter / 2, 2));
    int requiredCount = (totalPArea / tArea1).ceil();
    double totalTArea = requiredCount * tArea1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demir Donatı Tahvili',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          const SizedBox(height: 20),
          // Projedeki Donatı
          Text(
            'Projedeki Donatı Bilgileri',
            style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 16),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 500) {
                 // Mobile Layout (Stacked)
                 return Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      _buildDropdown(
                        'Çap (Ø)',
                        _selectedProjectDiameter,
                        _diameters,
                        (val) => setState(() => _selectedProjectDiameter = val!),
                      ),
                      const SizedBox(height: 15),
                      const Text('Adet', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 5),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          ),
                          controller: TextEditingController(
                              text: _selectedProjectCount.toString())
                            ..selection = TextSelection.fromPosition(
                                TextPosition(
                                    offset: _selectedProjectCount
                                        .toString()
                                        .length)),
                          onChanged: (val) {
                            if (val.isNotEmpty) {
                              setState(() {
                                _selectedProjectCount = int.tryParse(val) ?? 1;
                              });
                            }
                          },
                        ),
                      ),
                   ],
                 );
              }

              // Desktop/Wide Layout (Row)
              return Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      'Çap (Ø)',
                      _selectedProjectDiameter,
                      _diameters,
                      (val) => setState(() => _selectedProjectDiameter = val!),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Adet', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 5),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10),
                            ),
                            controller: TextEditingController(
                                text: _selectedProjectCount.toString())
                              ..selection = TextSelection.fromPosition(
                                  TextPosition(
                                      offset: _selectedProjectCount
                                          .toString()
                                          .length)),
                            onChanged: (val) {
                              if (val.isNotEmpty) {
                                setState(() {
                                  _selectedProjectCount = int.tryParse(val) ?? 1;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // İstenen Donatı
          const Text(
            'Tahvil Yapılması İstenen Donatı Çapı',
            style: TextStyle(color: Colors.blueAccent, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _buildDropdown(
            'Hedef Çap (Ø)',
            _targetDiameter,
            _diameters,
            (val) => setState(() => _targetDiameter = val!),
          ),
          const SizedBox(height: 25),
          const Divider(color: Colors.white24),
          const SizedBox(height: 15),
          // Sonuçlar
          _buildResultRow('As Proje Donatısı:',
              '${totalPArea.toStringAsFixed(2)} mm²', Colors.white54),
          const SizedBox(height: 10),
          _buildResultRow(
              'As Tahvil Donatısı:',
              '${totalTArea.toStringAsFixed(2)} mm² ($requiredCount x Ø$_targetDiameter)',
              Colors.redAccent),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withOpacity(0.5)),
            ),
            child: Text(
              'SONUÇ: $_selectedProjectCount Adet Ø$_selectedProjectDiameter yerine $requiredCount adet Ø$_targetDiameter kullanılabilir.',
              style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, int value, List<int> items,
      void Function(int?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF3d3d3d),
              style: TextStyle(color: Colors.white),
              items: items.map((int val) {
                return DropdownMenuItem<int>(
                  value: val,
                  child: Text('Ø$val'),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 15)),
        Text(value,
            style: TextStyle(
                color: valueColor, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  // --- Beton Reçete Tablosu ---
  // --- Beton Reçete Tablosu ---
  Widget _buildBetonReceteTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Mobile View: Cards for each Concrete Class (C25, C30...)
        if (constraints.maxWidth < 600) {
          final classes = ['C25', 'C30', 'C35', 'C40', 'C45'];
          final data = {
            'C25': {'Çimento': '330', 'Su': '180', 'S/Ç': '0.55', 'Kum': '750', 'Çakıl': '1050', 'Katkı': '1.5'},
            'C30': {'Çimento': '380', 'Su': '180', 'S/Ç': '0.47', 'Kum': '700', 'Çakıl': '1000', 'Katkı': '2.5'},
            'C35': {'Çimento': '420', 'Su': '170', 'S/Ç': '0.40', 'Kum': '650', 'Çakıl': '950', 'Katkı': '3.5'},
            'C40': {'Çimento': '480', 'Su': '170', 'S/Ç': '0.35', 'Kum': '600', 'Çakıl': '900', 'Katkı': '4.5'},
            'C45': {'Çimento': '520', 'Su': '165', 'S/Ç': '0.32', 'Kum': '550', 'Çakıl': '850', 'Katkı': '5.0'},
          };

          return Column(
            children: classes.map((className) {
              final values = data[className]!;
              return Card(
                color: Colors.white10,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beton Sınıfı: $className',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Divider(color: Colors.white24),
                      ...values.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: TextStyle(color: Colors.white70)),
                            Text(e.value, style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )).toList(),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }

        // Desktop View: Original Table
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              color: ThemeColors.cardBackground(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.blue.withOpacity(0.2)),
              columns: [
                DataColumn(label: Text('Bileşen', style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold))),
                DataColumn(label: Text('C25', style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold))),
                DataColumn(label: Text('C30', style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold))),
                DataColumn(label: Text('C35', style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold))),
                DataColumn(label: Text('C40', style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold))),
                DataColumn(label: Text('C45', style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold))),
              ],
              rows: [
                DataRow(cells: [
                  DataCell(Text('Çimento', style: TextStyle(color: Colors.white70))),
                  DataCell(Text('330', style: TextStyle(color: Colors.white))),
                  DataCell(Text('380', style: TextStyle(color: Colors.white))),
                  DataCell(Text('420', style: TextStyle(color: Colors.white))),
                  DataCell(Text('480', style: TextStyle(color: Colors.white))),
                  DataCell(Text('520', style: TextStyle(color: Colors.white))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Su', style: TextStyle(color: Colors.white70))),
                  DataCell(Text('180', style: TextStyle(color: Colors.white))),
                  DataCell(Text('180', style: TextStyle(color: Colors.white))),
                  DataCell(Text('170', style: TextStyle(color: Colors.white))),
                  DataCell(Text('170', style: TextStyle(color: Colors.white))),
                  DataCell(Text('165', style: TextStyle(color: Colors.white))),
                ]),
                DataRow(cells: [
                  DataCell(Text('S/Ç Oranı', style: TextStyle(color: Colors.white70))),
                  DataCell(Text('0.55', style: TextStyle(color: Colors.white))),
                  DataCell(Text('0.47', style: TextStyle(color: Colors.white))),
                  DataCell(Text('0.40', style: TextStyle(color: Colors.white))),
                  DataCell(Text('0.35', style: TextStyle(color: Colors.white))),
                  DataCell(Text('0.32', style: TextStyle(color: Colors.white))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Kum', style: TextStyle(color: Colors.white70))),
                  DataCell(Text('750', style: TextStyle(color: Colors.white))),
                  DataCell(Text('700', style: TextStyle(color: Colors.white))),
                  DataCell(Text('650', style: TextStyle(color: Colors.white))),
                  DataCell(Text('600', style: TextStyle(color: Colors.white))),
                  DataCell(Text('550', style: TextStyle(color: Colors.white))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Çakıl', style: TextStyle(color: Colors.white70))),
                  DataCell(Text('1050', style: TextStyle(color: Colors.white))),
                  DataCell(Text('1000', style: TextStyle(color: Colors.white))),
                  DataCell(Text('950', style: TextStyle(color: Colors.white))),
                  DataCell(Text('900', style: TextStyle(color: Colors.white))),
                  DataCell(Text('850', style: TextStyle(color: Colors.white))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Katkı (Lt)', style: TextStyle(color: Colors.white70))),
                  DataCell(Text('1.5', style: TextStyle(color: Colors.white))),
                  DataCell(Text('2.5', style: TextStyle(color: Colors.white))),
                  DataCell(Text('3.5', style: TextStyle(color: Colors.white))),
                  DataCell(Text('4.5', style: TextStyle(color: Colors.white))),
                  DataCell(Text('5.0', style: TextStyle(color: Colors.white))),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Dinamik Düzenlenebilir Tablo ---
  Widget _buildEditableTable({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    required Function(List<String>) onHeadersChanged,
    required Function(List<List<String>>) onRowsChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.add_circle_outline, color: Colors.green),
                    tooltip: 'Sütun Ekle',
                    onPressed: () {
                      _showAddColumnDialog(
                          context, headers, rows, onHeadersChanged, onRowsChanged);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.playlist_add, color: Colors.blue),
                    tooltip: 'Satır Ekle',
                    onPressed: () {
                      // Yeni boş satır ekle
                      List<String> newRow = List.filled(headers.length, '');
                      // Satır başlığı için default değer
                      newRow[0] = 'Yeni';
                      onRowsChanged([...rows, newRow]);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              // Mobile View: Card List
              if (constraints.maxWidth < 600) {
                 return Column(
                    children: List.generate(rows.length, (rowIndex) {
                      return Dismissible(
                        key: UniqueKey(),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          List<List<String>> newRows = List.from(rows)..removeAt(rowIndex);
                          onRowsChanged(newRows);
                        },
                        child: Card(
                          color: Colors.white10,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(headers.length, (colIndex) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 100,
                                        child: Text(
                                          '${headers[colIndex]}:',
                                          style: TextStyle(
                                            color: ThemeColors.textSecondary(context),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                           initialValue: rows[rowIndex][colIndex],
                                           style: TextStyle(color: Colors.white),
                                           decoration: const InputDecoration.collapsed(hintText: '-'),
                                           onChanged: (val) {
                                             rows[rowIndex][colIndex] = val;
                                             onRowsChanged(rows);
                                           },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      );
                    }),
                 );
              }

              // Desktop View: DataTable
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  horizontalMargin: 10,
                  border: TableBorder.all(color: Colors.grey.shade600, width: 1),
                  headingRowColor:
                      MaterialStateProperty.all(Colors.teal.shade800),
                  columns: List.generate(headers.length, (index) {
                    return DataColumn(
                      label: InkWell(
                        onDoubleTap: () {
                          _showEditHeaderDialog(context, headers, index, (newVal) {
                            List<String> newHeaders = List.from(headers);
                            newHeaders[index] = newVal;
                            onHeadersChanged(newHeaders);
                          });
                        },
                        onLongPress: () {
                           if (index > 0) {
                             _showDeleteColumnDialog(context, headers[index], () {
                                List<String> newHeaders = List.from(headers)..removeAt(index);
                                List<List<String>> newRows = rows.map((row) {
                                  var r = List<String>.from(row);
                                  if (r.length > index) r.removeAt(index);
                                  return r;
                                }).toList();
                                onHeadersChanged(newHeaders);
                                onRowsChanged(newRows);
                             });
                           }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                headers[index],
                                style: TextStyle(
                                    color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold),
                              ),
                              if (index > 0)
                                const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  rows: List.generate(rows.length, (rowIndex) {
                    return DataRow(
                      cells: List.generate(rows[rowIndex].length, (colIndex) {
                        final cellValue = rows[rowIndex][colIndex];
                        final isEmpty = cellValue.trim().isEmpty;
                        final bgColor = isEmpty ? Colors.red.shade100 : Colors.white;
                        final txtColor = Colors.black;
    
                        return DataCell(
                          Container(
                            color: bgColor,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.centerLeft,
                            width: 80,
                            height: double.infinity,
                            child: TextFormField(
                              initialValue: cellValue,
                              style: TextStyle(color: txtColor, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(border: InputBorder.none),
                              onChanged: (val) {
                                rows[rowIndex][colIndex] = val;
                                onRowsChanged(rows);
                              },
                            ),
                          ),
                        );
                      }),
                      onLongPress: () {
                         _showDeleteRowDialog(context, () {
                            List<List<String>> newRows = List.from(rows)..removeAt(rowIndex);
                            onRowsChanged(newRows);
                         });
                      }
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 5),
          const Text(
            '* Hücreleri düzenlemek için tıklayın. Sütun/Satır işlemleri için ikonları veya uzun basmayı kullanın.',
            style: TextStyle(color: Colors.white30, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _showAddColumnDialog(
      BuildContext context,
      List<String> headers,
      List<List<String>> rows,
      Function(List<String>) onHeadersChanged,
      Function(List<List<String>>) onRowsChanged) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('Sütun Ekle', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              labelText: 'Başlık',
              labelStyle: TextStyle(color: Colors.white54)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onHeadersChanged([...headers, controller.text]);
                // Mevcut satırlara boş hücre ekle
                List<List<String>> newRows = rows.map((row) {
                  return [...row, ''];
                }).toList();
                onRowsChanged(newRows);
                Navigator.pop(context);
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showEditHeaderDialog(BuildContext context, List<String> headers,
      int index, Function(String) onSave) {
    final controller = TextEditingController(text: headers[index]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('Başlığı Düzenle', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showDeleteColumnDialog(BuildContext context, String columnName, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('Sütunu Sil', style: TextStyle(color: Colors.white)),
        content: Text("'$columnName' sütununu silmek istiyor musunuz?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showDeleteRowDialog(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('Satırı Sil', style: TextStyle(color: Colors.white)),
        content: const Text("Bu satırı silmek istiyor musunuz?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // --- Autocad Bölümü ---
  Widget _buildAutocadSection() {
    // Listeyi isme göre sırala


    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Komutlar & Kısayollar',
              style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _showAutocadEditDialog(context, null);
              },
              icon: Icon(Icons.add, size: 18),
              label: const Text('Ekle'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            ),
          ],
        ),
        const SizedBox(height: 15),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _autocadCommands.length,
          itemBuilder: (context, index) {
            final item = _autocadCommands[index];
            return Card(
              color: ThemeColors.cardBackground(context),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.redAccent.withOpacity(0.2),
                  child: Text(
                    item['key']!,
                    style: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(item['cmd']!,
                    style: TextStyle(
                        color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold)),
                subtitle: Text(item['desc']!,
                    style: TextStyle(color: Colors.white54)),
                trailing: PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Colors.white54),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Düzenle'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Sil', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  onSelected: (value) {
                     if (value == 'edit') {
                       _showAutocadEditDialog(context, index);
                     } else {
                       setState(() {
                         _autocadCommands.removeAt(index);
                       });
                     }
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAutocadEditDialog(BuildContext context, int? index) {
    bool isEditing = index != null;
    final item = isEditing ? _autocadCommands[index!] : {'key': '', 'cmd': '', 'desc': ''};
    final keyCtrl = TextEditingController(text: item['key']);
    final cmdCtrl = TextEditingController(text: item['cmd']);
    final descCtrl = TextEditingController(text: item['desc']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: Text(isEditing ? 'Komutu Düzenle' : 'Yeni Komut', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              style: TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Kısayol',
                  labelStyle: TextStyle(color: Colors.white54)),
            ),
            TextField(
              controller: cmdCtrl,
              style: TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Komut Adı',
                  labelStyle: TextStyle(color: Colors.white54)),
            ),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
               if (keyCtrl.text.isNotEmpty && cmdCtrl.text.isNotEmpty) {
                 setState(() {
                   final newItem = {
                     'key': keyCtrl.text,
                     'cmd': cmdCtrl.text,
                     'desc': descCtrl.text
                   };
                   if (isEditing) {
                     _autocadCommands[index!] = newItem;
                   } else {
                     _autocadCommands.add(newItem);
                   }
                 });
                 Navigator.pop(context);

                 }
              },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showAddPratikBilgiDialog(BuildContext context, {PratikBilgi? existingInfo, int? index}) {
    final titleController = TextEditingController(text: existingInfo?.baslik ?? '');
    final contentController = TextEditingController(text: existingInfo?.icerik ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: Text(existingInfo == null ? 'Yeni Pratik Bilgi Ekle' : 'Bilgiyi Düzenle', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             TextField(
               controller: titleController,
               decoration: const InputDecoration(labelText: 'Başlık', labelStyle: TextStyle(color: Colors.white70)),
               style: TextStyle(color: Colors.white),
             ),
             const SizedBox(height: 10),
             TextField(
               controller: contentController,
               decoration: const InputDecoration(labelText: 'İçerik', labelStyle: TextStyle(color: Colors.white70)),
               style: TextStyle(color: Colors.white),
               maxLines: 3,
             ),
          ],
        ),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(context),
             child: const Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                if (existingInfo != null) {
                  // Edit
                  final updatedInfo = PratikBilgi(
                    id: existingInfo.id,
                    baslik: titleController.text,
                    icerik: contentController.text,
                  );
                  // onGuncelle callback needs to be passed or handled.
                  // Since we only have onEkle, we need to add onGuncelle to the widget or assume onEkle updates if ID exists logic?
                  // Usually customPratikBilgiler is a list in parent.
                  // Wait, PratikBilgilerSayfaPage constructor definition needs verification.
                  // For now, let's assume valid callback or user needs to add it.
                  // User asked for "Edit/Delete". But the widget might not have callbacks for it yet.
                  // I will add onGuncelle and onSil to PratikBilgilerSayfaPage widget definition.
                  widget.onGuncelle(index!, updatedInfo);
                } else {
                   final newInfo = PratikBilgi(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    baslik: titleController.text,
                    icerik: contentController.text,
                  );
                  widget.onEkle(newInfo);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Ekle'),
          )
        ],
      ),
    );
  }
}
