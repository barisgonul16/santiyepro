import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/rapor_pdf_service.dart';
import '../models/proje.dart';
import '../models/gunluk_kayit.dart';
import '../theme/theme_colors.dart';
import 'proje_detay_sayfa.dart';
import '../services/app_log.dart';

class GunlukRaporSayfaPage extends StatefulWidget {
  final List<Proje> projeler;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;

  const GunlukRaporSayfaPage({
    super.key,
    required this.projeler,
    required this.projeGunlukKayitlari,
  });

  @override
  State<GunlukRaporSayfaPage> createState() => _GunlukRaporSayfaPageState();
}

class _GunlukRaporSayfaPageState extends State<GunlukRaporSayfaPage> {
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _getDailyRecords(DateTime date) {
    List<Map<String, dynamic>> records = [];
    for (var proje in widget.projeler) {
      final kayitlar = widget.projeGunlukKayitlari[proje.id] ?? [];
      for (var kayit in kayitlar) {
        if (kayit.tarih.year == date.year &&
            kayit.tarih.month == date.month &&
            kayit.tarih.day == date.day) {
          records.add({
            'proje': proje,
            'kayit': kayit,
          });
        }
      }
    }
    return records;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.indigo,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pdfRaporu(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu tarihte rapora girecek kayıt yok.')),
      );
      return;
    }

    final ilerleme = ValueNotifier<String>('Rapor hazırlanıyor...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          color: ThemeColors.cardBackground(context),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.indigo),
                const SizedBox(height: 15),
                ValueListenableBuilder<String>(
                  valueListenable: ilerleme,
                  builder: (context, metin, _) => Text(
                    metin,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Uint8List? pdf;
    try {
      pdf = await GunlukRaporPdf.olustur(
        tarih: _selectedDate,
        kayitlar: [for (final r in records) (r['proje'] as Proje, r['kayit'] as GunlukKayit)],
        hazirlayan: FirebaseAuth.instance.currentUser?.displayName,
        ilerleme: (i, toplam) => ilerleme.value = 'Fotoğraflar alınıyor ($i / $toplam)',
      );
    } catch (e) {
      appLog('PDF rapor hatası: $e');
    } finally {
      if (mounted) Navigator.pop(context);
      ilerleme.dispose();
    }

    if (!mounted) return;
    if (pdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapor oluşturulamadı.'), backgroundColor: Colors.red),
      );
      return;
    }

    final dosyaAdi = 'Santiye_Raporu_${DateFormat('dd_MM_yyyy').format(_selectedDate)}.pdf';
    final boyutMb = (pdf.length / 1024 / 1024).toStringAsFixed(1);
    final rapor = pdf;

    await showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.cardBackground(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              title: Text('Rapor hazır', style: TextStyle(color: ThemeColors.textPrimary(ctx), fontWeight: FontWeight.bold)),
              subtitle: Text('$dosyaAdi · $boyutMb MB', style: TextStyle(color: ThemeColors.textSecondary(ctx))),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.lightBlueAccent),
              title: Text('Paylaş', style: TextStyle(color: ThemeColors.textPrimary(ctx))),
              subtitle: Text('WhatsApp, e-posta...', style: TextStyle(color: ThemeColors.textSecondary(ctx))),
              onTap: () async {
                Navigator.pop(ctx);
                await _raporuPaylas(rapor, dosyaAdi);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.greenAccent),
              title: Text('Kaydet', style: TextStyle(color: ThemeColors.textPrimary(ctx))),
              subtitle: Text('Cihazda bir klasöre', style: TextStyle(color: ThemeColors.textSecondary(ctx))),
              onTap: () async {
                Navigator.pop(ctx);
                await _raporuKaydet(rapor, dosyaAdi);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _raporuPaylas(Uint8List pdf, String dosyaAdi) async {
    try {
      final dosya = File('${(await getTemporaryDirectory()).path}/$dosyaAdi');
      await dosya.writeAsBytes(pdf, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(dosya.path, mimeType: 'application/pdf')],
        text: 'Günlük şantiye raporu - ${DateFormat('dd.MM.yyyy').format(_selectedDate)}',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşılamadı: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _raporuKaydet(Uint8List pdf, String dosyaAdi) async {
    try {
      // Telefonda dosyayı seçici yazar; masaüstünde yalnızca yolu döndürür.
      final mobil = Platform.isAndroid || Platform.isIOS;
      final yol = await FilePicker.platform.saveFile(
        dialogTitle: 'Raporu kaydet',
        fileName: dosyaAdi,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: mobil ? pdf : null,
      );
      if (yol == null) return;
      if (!mobil) {
        await File(yol.toLowerCase().endsWith('.pdf') ? yol : '$yol.pdf').writeAsBytes(pdf, flush: true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rapor kaydedildi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTurkishDate(DateTime date) {
    final aylar = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    return '${date.day} ${aylar[date.month - 1]} ${date.year}, ${gunler[date.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final records = _getDailyRecords(_selectedDate);
    final String dateStr = _formatTurkishDate(_selectedDate);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── TARİH SEÇİM ALANI ──
          Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1A237E).withValues(alpha: 0.4), const Color(0xFF0D47A1).withValues(alpha: 0.4)]
                    : [Colors.indigo.shade50, Colors.blue.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isDark ? Colors.indigo.withValues(alpha: 0.3) : Colors.indigo.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: isDark ? Colors.indigoAccent : Colors.indigo, size: 28),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seçilen Rapor Tarihi',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.indigo.shade900,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.edit_calendar, size: 16),
                  label: const Text('Tarih Seç'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          // ── RAPOR ÖNİZLEME ALANI ──
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.feed_outlined, color: isDark ? Colors.white24 : Colors.grey.shade400, size: 64),
                        const SizedBox(height: 15),
                        Text(
                          'Bu tarihte girilmiş şantiye kaydı bulunamadı.',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Günün Şantiye Kayıtları (${records.length} Şantiye)',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _pdfRaporu(records),
                              icon: const Icon(Icons.picture_as_pdf, size: 16),
                              label: const Text('PDF Rapor'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final Proje proje = records[index]['proje'];
                            final GunlukKayit kayit = records[index]['kayit'];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Şantiye Adı
                                    Text(
                                      proje.ad,
                                      style: TextStyle(
                                        color: isDark ? Colors.indigoAccent : Colors.indigo.shade800,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Divider(height: 20, color: ThemeColors.border(context)),

                                    // Kalıpçı & Demirci & Beton Satırı
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Kalıpçı
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.engineering, size: 14, color: Colors.orange),
                                                  SizedBox(width: 4),
                                                  Text('Kalıpçı Ekibi', style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 11)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${kayit.kalipci} Kişi',
                                                style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              if (kayit.kalipciYapilanIs.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  kayit.kalipciYapilanIs,
                                                  style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        // Demirci
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.hardware, size: 14, color: Colors.orange),
                                                  SizedBox(width: 4),
                                                  Text('Demirci Ekibi', style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 11)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${kayit.demirci} Kişi',
                                                style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              if (kayit.demirciYapilanIs.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  kayit.demirciYapilanIs,
                                                  style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        // Beton
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.opacity, size: 14, color: Colors.blueAccent),
                                                  SizedBox(width: 4),
                                                  Text('Beton', style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 11)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                kayit.beton.isEmpty ? '-' : kayit.beton,
                                                style: TextStyle(
                                                  color: kayit.beton.isEmpty ? Colors.white30 : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Ekipman & Yevmiye Bilgisi
                                    if (kayit.vincler.isNotEmpty || kayit.yevmiyeler.isNotEmpty) ...[
                                      const SizedBox(height: 15),
                                      Divider(height: 10, color: ThemeColors.border(context)),
                                      const SizedBox(height: 5),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Vinç Bilgileri
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.architecture, size: 14, color: Colors.teal),
                                                    SizedBox(width: 4),
                                                    Text('Vinç Kullanımı', style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 11)),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                if (kayit.vincler.isEmpty)
                                                  Text('-', style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 13))
                                                else
                                                  ...kayit.vincler.map((v) => Padding(
                                                        padding: const EdgeInsets.only(bottom: 2),
                                                        child: Text(
                                                          '${v.firmaAdi} (${v.baslangic}-${v.bitis})${v.aciklama.isEmpty ? '' : ' · ${v.aciklama}'}',
                                                          style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 12, fontWeight: FontWeight.w500),
                                                        ),
                                                      )),
                                              ],
                                            ),
                                          ),
                                          // Yevmiye Bilgileri
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.payments, size: 14, color: Colors.teal),
                                                    SizedBox(width: 4),
                                                    Text('Yevmiyeler', style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 11)),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                if (kayit.yevmiyeler.isEmpty)
                                                  Text('-', style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 13))
                                                else
                                                  ...kayit.yevmiyeler.map((y) => Padding(
                                                        padding: const EdgeInsets.only(bottom: 2),
                                                        child: Text(
                                                          '${y.ekipAdi} (${y.miktar} Y.)',
                                                          style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 12, fontWeight: FontWeight.w500),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      )),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],

                                    // Notlar
                                    if (kayit.notlar.isNotEmpty) ...[
                                      const SizedBox(height: 15),
                                      Divider(height: 10, color: ThemeColors.border(context)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.notes, size: 14, color: isDark ? Colors.indigoAccent : Colors.indigo),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Notlar',
                                            style: TextStyle(
                                              color: isDark ? Colors.white54 : Colors.black54,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        kayit.notlar,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],

                                    // Fotoğraflar Önizleme
                                    if (kayit.fotografYollari.isNotEmpty) ...[
                                      const SizedBox(height: 15),
                                      Divider(height: 10, color: ThemeColors.border(context)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.photo_library, size: 14, color: Colors.amber),
                                          SizedBox(width: 4),
                                          Text('Şantiye Fotoğrafları', style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 11)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 60,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: kayit.fotografYollari.length,
                                          itemBuilder: (context, fIndex) {
                                            final fPath = kayit.fotografYollari[fIndex];
                                            final isNetwork = fPath.startsWith('http://') || fPath.startsWith('https://');

                                            return GestureDetector(
                                              onTap: () {
                                                final photoList = kayit.fotografYollari.map((path) => <String, dynamic>{
                                                  'tarih': kayit.tarih,
                                                  'yol': path,
                                                }).toList();
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => FotografGoruntulePage(
                                                      fotograflar: photoList,
                                                      baslangicIndex: fIndex,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                margin: const EdgeInsets.only(right: 8),
                                                width: 60,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: ThemeColors.border(context)),
                                                  image: DecorationImage(
                                                    image: (isNetwork ? NetworkImage(fPath) : FileImage(File(fPath))) as ImageProvider,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
