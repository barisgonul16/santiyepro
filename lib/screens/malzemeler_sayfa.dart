import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/malzeme.dart';
import '../theme/theme_colors.dart';

class MalzemelerSayfaPage extends StatefulWidget {
  final List<Malzeme> malzemeler;
  final Function(Malzeme) onMalzemeEkle;
  final Function(int, Malzeme) onMalzemeGuncelle;
  final Function(int) onMalzemeSil;

  const MalzemelerSayfaPage({
    super.key,
    required this.malzemeler,
    required this.onMalzemeEkle,
    required this.onMalzemeGuncelle,
    required this.onMalzemeSil,
  });

  @override
  State<MalzemelerSayfaPage> createState() => _MalzemelerSayfaPageState();
}

class _MalzemelerSayfaPageState extends State<MalzemelerSayfaPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Uses Main scaffold bg
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.orange,
        child: Icon(Icons.add),
      ),
      body: widget.malzemeler.isEmpty
          ? Center(
              child: Text(
                "Henüz malzeme eklenmemiş",
                style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: widget.malzemeler.length,
              itemBuilder: (context, index) {
                final malzeme = widget.malzemeler[index];
                Color statusColor = Colors.green;
                if (malzeme.durum.toLowerCase().contains("tamir")) statusColor = Colors.red;
                if (malzeme.durum.toLowerCase().contains("depo")) statusColor = Colors.blue;

                return Card(
                  color: const Color(0xFF2D2D2D),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: malzeme.fotoYolu.isNotEmpty
                        ? SizedBox(
                            width: 60,
                            height: 60,
                            child: Image.file(File(malzeme.fotoYolu), fit: BoxFit.cover),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: Colors.white10,
                            child: Icon(Icons.build, color: Colors.white54),
                          ),
                    title: Text(malzeme.ad, style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.white54),
                            const SizedBox(width: 4),
                            Expanded(child: Text(malzeme.konum, style: TextStyle(color: Colors.white70))),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.info, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(malzeme.durum, style: TextStyle(color: statusColor)),
                          ],
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => _showAddEditDialog(malzeme: malzeme, index: index),
                    ),
                    onLongPress: () {
                         showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: ThemeColors.cardBackground(context),
                            title: const Text('Sil', style: TextStyle(color: Colors.white)),
                            content: Text('${malzeme.ad} silinsin mi?', style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () {
                                  widget.onMalzemeSil(index);
                                  Navigator.pop(context);
                                },
                                child: const Text('Sil'),
                              ),
                            ],
                          ),
                        );
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> _pickImage(ImagePicker picker, Function(XFile) onPicked) async {
    if (Platform.isWindows) {
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) onPicked(picked);
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D2D),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Kamera', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(source: ImageSource.camera);
                if (picked != null) onPicked(picked);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Galeri', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) onPicked(picked);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddEditDialog({Malzeme? malzeme, int? index}) async {
    final picker = ImagePicker();
    XFile? photo;
    final nameCtrl = TextEditingController(text: malzeme?.ad ?? '');
    final locationCtrl = TextEditingController(text: malzeme?.konum ?? '');
    final statusCtrl = TextEditingController(text: malzeme?.durum ?? '');
    
    if (malzeme != null && malzeme.fotoYolu.isNotEmpty) {
      // Note: XFile from path logic if needed, but we store string path mostly.
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: Text(malzeme == null ? "Yeni Malzeme" : "Malzeme Düzenle", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    await _pickImage(picker, (file) => setState(() => photo = file));
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.white10,
                    child: photo != null
                        ? Image.file(File(photo!.path), fit: BoxFit.cover)
                        : (malzeme != null && malzeme.fotoYolu.isNotEmpty)
                            ? Image.file(File(malzeme.fotoYolu), fit: BoxFit.cover)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [Icon(Icons.camera_alt, color: ThemeColors.textTertiary(context), size: 30), Text("Fotoğraf", style: TextStyle(color: Colors.white54))],
                              ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(controller: nameCtrl, style: TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Malzeme Adı (Örn: Hilti)", labelStyle: TextStyle(color: Colors.white70))),
                TextField(controller: locationCtrl, style: TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Konum (Örn: Şantiye A)", labelStyle: TextStyle(color: Colors.white70))),
                TextField(controller: statusCtrl, style: TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Durum (Örn: Tamirde, Çalışıyor)", labelStyle: TextStyle(color: Colors.white70))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  final newPath = photo?.path ?? (malzeme?.fotoYolu ?? '');
                  final newItem = Malzeme(
                    id: malzeme?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    ad: nameCtrl.text,
                    konum: locationCtrl.text,
                    durum: statusCtrl.text,
                    fotoYolu: newPath,
                  );

                  if (malzeme == null) {
                    widget.onMalzemeEkle(newItem);
                  } else {
                    widget.onMalzemeGuncelle(index!, newItem);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text("Kaydet"),
            )
          ],
        ),
      ),
    );
  }
}
