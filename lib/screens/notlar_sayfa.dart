import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/not.dart';
import '../theme/theme_colors.dart';

class NotlarSayfaPage extends StatefulWidget {
  final List<Not> notlar;
  final Function(Not) onNotEkle;
  final Function(int) onNotSil;
  final Function(int, Not) onNotDuzenle;

  const NotlarSayfaPage({
    super.key,
    required this.notlar,
    required this.onNotEkle,
    required this.onNotSil,
    required this.onNotDuzenle,
  });

  @override
  State<NotlarSayfaPage> createState() => _NotlarSayfaPageState();
}

class _NotlarSayfaPageState extends State<NotlarSayfaPage> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening(Function(String) onResult) async {
    await _speechToText.listen(onResult: (result) => onResult(result.recognizedWords));
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _notEkleDialog(BuildContext context) {
    final baslikController = TextEditingController();
    final icerikController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: ThemeColors.cardBackground(context),
            title: const Text(
              'Yeni Not',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: baslikController,
                      style: TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Başlık',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Formatlama araç çubuğu
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.format_list_bulleted, color: ThemeColors.textSecondary(context), size: 20),
                            tooltip: 'Madde İşareti',
                            onPressed: () {
                              final text = icerikController.text;
                              final selection = icerikController.selection;
                              final newText = text.isEmpty 
                                  ? '• ' 
                                  : (text.endsWith('\n') ? '${text}• ' : '$text\n• ');
                              icerikController.text = newText;
                              icerikController.selection = TextSelection.fromPosition(
                                TextPosition(offset: newText.length),
                              );
                              setDialogState(() {});
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.check_box_outline_blank, color: ThemeColors.textSecondary(context), size: 20),
                            tooltip: 'Yapılacak Madde',
                            onPressed: () {
                              final text = icerikController.text;
                              final newText = text.isEmpty 
                                  ? '☐ ' 
                                  : (text.endsWith('\n') ? '$text☐ ' : '$text\n☐ ');
                              icerikController.text = newText;
                              icerikController.selection = TextSelection.fromPosition(
                                TextPosition(offset: newText.length),
                              );
                              setDialogState(() {});
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.check_box, color: Colors.green, size: 20),
                            tooltip: 'Tamamlandı',
                            onPressed: () {
                              final text = icerikController.text;
                              final newText = text.isEmpty 
                                  ? '☑ ' 
                                  : (text.endsWith('\n') ? '$text☑ ' : '$text\n☑ ');
                              icerikController.text = newText;
                              icerikController.selection = TextSelection.fromPosition(
                                TextPosition(offset: newText.length),
                              );
                              setDialogState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        TextField(
                          controller: icerikController,
                          style: TextStyle(color: Colors.white),
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Not İçeriği',
                            alignLabelWithHint: true,
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.orange),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                             // _speechEnabled kontrolü
                             if (!_speechEnabled) return;
                             
                             if (_speechToText.isListening) {
                               _stopListening();
                               setDialogState(() {});
                             } else {
                               _startListening((text) {
                                 setDialogState(() {
                                    // Mevcut metne ekleme yap (sonuna ekle)
                                    final existing = icerikController.text;
                                    if (existing.isEmpty) {
                                       icerikController.text = text;
                                    } else {
                                       icerikController.text = '$existing $text';
                                    }
                                    // İmleci sona taşı
                                    icerikController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: icerikController.text.length),
                                    );
                                 });
                               });
                               setDialogState(() {});
                             }
                          },
                          icon: Icon(
                            _speechToText.isListening ? Icons.mic_off : Icons.mic,
                            color: _speechToText.isListening ? Colors.red : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (baslikController.text.isNotEmpty) {
                    widget.onNotEkle(
                      Not(
                        baslik: baslikController.text,
                        icerik: icerikController.text,
                        olusturmaTarihi: DateTime.now(),
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('Kaydet'),
              ),
            ],
          );
        });
      },
    );
  }

  void _notDuzenleDialog(BuildContext context, int index, Not not) {
    final baslikController = TextEditingController(text: not.baslik);
    final icerikController = TextEditingController(text: not.icerik);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: ThemeColors.cardBackground(context),
            title: const Text(
              'Notu Düzenle',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: baslikController,
                      style: TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Başlık',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Formatlama araç çubuğu
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.format_list_bulleted, color: ThemeColors.textSecondary(context), size: 20),
                            tooltip: 'Madde İşareti',
                            onPressed: () {
                              final text = icerikController.text;
                              final newText = text.isEmpty 
                                  ? '• ' 
                                  : (text.endsWith('\n') ? '${text}• ' : '$text\n• ');
                              icerikController.text = newText;
                              icerikController.selection = TextSelection.fromPosition(
                                TextPosition(offset: newText.length),
                              );
                              setDialogState(() {});
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.check_box_outline_blank, color: ThemeColors.textSecondary(context), size: 20),
                            tooltip: 'Yapılacak Madde',
                            onPressed: () {
                              final text = icerikController.text;
                              final newText = text.isEmpty 
                                  ? '☐ ' 
                                  : (text.endsWith('\n') ? '$text☐ ' : '$text\n☐ ');
                              icerikController.text = newText;
                              icerikController.selection = TextSelection.fromPosition(
                                TextPosition(offset: newText.length),
                              );
                              setDialogState(() {});
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.check_box, color: Colors.green, size: 20),
                            tooltip: 'Tamamlandı',
                            onPressed: () {
                              final text = icerikController.text;
                              final newText = text.isEmpty 
                                  ? '☑ ' 
                                  : (text.endsWith('\n') ? '$text☑ ' : '$text\n☑ ');
                              icerikController.text = newText;
                              icerikController.selection = TextSelection.fromPosition(
                                TextPosition(offset: newText.length),
                              );
                              setDialogState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                     Stack(
                      alignment: Alignment.topRight,
                      children: [
                        TextField(
                          controller: icerikController,
                          style: TextStyle(color: Colors.white),
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Not İçeriği',
                            alignLabelWithHint: true,
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.orange),
                            ),
                          ),
                        ),
                         IconButton(
                          onPressed: () {
                             if (!_speechEnabled) return;
                             if (_speechToText.isListening) {
                               _stopListening();
                               setDialogState(() {});
                             } else {
                               _startListening((text) {
                                 setDialogState(() {
                                    // Mevcut metne ekleme yap (sonuna ekle)
                                    final existing = icerikController.text;
                                    if (existing.isEmpty) {
                                       icerikController.text = text;
                                    } else {
                                       icerikController.text = '$existing $text';
                                    }
                                    // İmleci sona taşı
                                    icerikController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: icerikController.text.length),
                                    );
                                 });
                               });
                               setDialogState(() {});
                             }
                          },
                          icon: Icon(
                            _speechToText.isListening ? Icons.mic_off : Icons.mic,
                            color: _speechToText.isListening ? Colors.red : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (baslikController.text.isNotEmpty) {
                    widget.onNotDuzenle(
                      index,
                      Not(
                        baslik: baslikController.text,
                        icerik: icerikController.text,
                        olusturmaTarihi: not.olusturmaTarihi,
                        guncellenmeTarihi: DateTime.now(),
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('Güncelle'),
              ),
            ],
          );
        });
      },
    );
  }

  void _notSilDialog(BuildContext context, int index, String baslik) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: const Text(
          'Notu Sil',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '"$baslik" notunu silmek istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onNotSil(index);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  String _formatTarih(DateTime tarih) {
    final aylar = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    return '${tarih.day} ${aylar[tarih.month - 1]} ${tarih.year} ${tarih.hour.toString().padLeft(2, '0')}:${tarih.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.note, color: Colors.orange, size: 28),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Notlarım',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: ThemeColors.textPrimary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _notEkleDialog(context),
                icon: Icon(Icons.add, size: 18),
                label: const Text('Yeni Not'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Toplam ${widget.notlar.length} not',
            style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 14),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: widget.notlar.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_add,
                          size: 80,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Henüz not eklenmemiş',
                          style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 18),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Yeni not eklemek için yukarıdaki butona tıklayın',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = 3;
                      if (constraints.maxWidth < 600) {
                        crossAxisCount = 1;
                      } else if (constraints.maxWidth < 900) {
                        crossAxisCount = 2;
                      }
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: crossAxisCount == 1 ? 2.0 : 1.2,
                        ),
                        itemCount: widget.notlar.length,
                        itemBuilder: (context, index) {
                          final not = widget.notlar[index];
                          return _buildNotKart(context, index, not);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotKart(BuildContext context, int index, Not not) {
    return InkWell(
      onTap: () => _showNotDetay(context, not, index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ThemeColors.cardBackground(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    not.baslik,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.textPrimary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.white54),
                  color: const Color(0xFF3d3d3d),
                  onSelected: (value) {
                    if (value == 'duzenle') {
                      _notDuzenleDialog(context, index, not);
                    } else if (value == 'sil') {
                      _notSilDialog(context, index, not.baslik);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'duzenle',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.orange, size: 20),
                          SizedBox(width: 10),
                          Text('Düzenle', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'sil',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 10),
                          Text('Sil', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                not.icerik,
                style: TextStyle(
                  color: ThemeColors.textSecondary(context),
                  fontSize: 14,
                  height: 1.4,
                ),
                overflow: TextOverflow.fade,
              ),
            ),
            const Divider(color: Colors.white24, height: 20),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.white38,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    not.guncellenmeTarihi != null
                        ? 'Güncellendi: ${_formatTarih(not.guncellenmeTarihi!)}'
                        : 'Oluşturuldu: ${_formatTarih(not.olusturmaTarihi)}',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNotDetay(BuildContext context, Not not, int index) {
    String currentIcerik = not.icerik;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Satırları parse et ve checkbox'ları interaktif yap
          Widget buildInteractiveContent() {
            final lines = currentIcerik.split('\n');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.map((line) {
                // Checkbox satırı mı kontrol et
                if (line.startsWith('☐ ') || line.startsWith('☑ ')) {
                  final isChecked = line.startsWith('☑');
                  final text = line.substring(2);
                  return InkWell(
                    onTap: () {
                      // Toggle checkbox
                      final newLine = isChecked ? '☐ $text' : '☑ $text';
                      currentIcerik = currentIcerik.replaceFirst(line, newLine);
                      setDialogState(() {});
                      
                      // Notu güncelle
                      widget.onNotDuzenle(
                        index,
                        Not(
                          baslik: not.baslik,
                          icerik: currentIcerik,
                          olusturmaTarihi: not.olusturmaTarihi,
                          guncellenmeTarihi: DateTime.now(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                            color: isChecked ? Colors.green : Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              text,
                              style: TextStyle(
                                color: isChecked ? Colors.white38 : Colors.white70,
                                fontSize: 16,
                                height: 1.4,
                                decoration: isChecked ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                // Normal satır veya madde işareti
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    line,
                    style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 16, height: 1.4),
                  ),
                );
              }).toList(),
            );
          }
          
          return Dialog(
            backgroundColor: ThemeColors.cardBackground(context),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          not.baslik,
                          style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 22, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: Colors.white)),
                    ],
                  ),
                  Text(
                    not.guncellenmeTarihi != null
                        ? 'Güncellendi: ${_formatTarih(not.guncellenmeTarihi!)}'
                        : 'Oluşturuldu: ${_formatTarih(not.olusturmaTarihi)}',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: buildInteractiveContent(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _notDuzenleDialog(context, index, Not(
                            baslik: not.baslik,
                            icerik: currentIcerik,
                            olusturmaTarihi: not.olusturmaTarihi,
                            guncellenmeTarihi: not.guncellenmeTarihi,
                          ));
                        },
                        icon: Icon(Icons.edit, color: Colors.orange),
                        label: const Text('Düzenle'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
