import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../models/proje.dart';
import '../models/gunluk_kayit.dart';
import '../theme/theme_colors.dart';

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

  Future<void> _exportToWord(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktarılacak günlük rapor kaydı bulunmamaktadır.')),
      );
      return;
    }

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          color: Color(0xFF2A2A2A),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.indigo),
                SizedBox(height: 15),
                Text(
                  'Rapor Hazırlanıyor...\n(Fotoğraflar yükleniyor, lütfen bekleyin)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final String tarihStr = DateFormat('dd.MM.yyyy').format(_selectedDate);
      final String dosyaTarihStr = DateFormat('dd_MM_yyyy').format(_selectedDate);

      StringBuffer tableRows = StringBuffer();

      for (var record in records) {
        final Proje proje = record['proje'];
        final GunlukKayit kayit = record['kayit'];

        // Kalıpçı
        String kalipciHtml = '-';
        if (kayit.kalipci > 0 || kayit.kalipciYapilanIs.isNotEmpty) {
          kalipciHtml = '';
          if (kayit.kalipci > 0) kalipciHtml += '<b>Sayı:</b> ${kayit.kalipci} Kişi<br>';
          if (kayit.kalipciYapilanIs.isNotEmpty) kalipciHtml += '<b>İş:</b> ${kayit.kalipciYapilanIs}';
        }

        // Demirci
        String demirciHtml = '-';
        if (kayit.demirci > 0 || kayit.demirciYapilanIs.isNotEmpty) {
          demirciHtml = '';
          if (kayit.demirci > 0) demirciHtml += '<b>Sayı:</b> ${kayit.demirci} Kişi<br>';
          if (kayit.demirciYapilanIs.isNotEmpty) demirciHtml += '<b>İş:</b> ${kayit.demirciYapilanIs}';
        }

        // Beton
        String betonHtml = kayit.beton.isEmpty ? '-' : kayit.beton;

        // Vinç
        String vincHtml = '-';
        if (kayit.vincler.isNotEmpty) {
          vincHtml = kayit.vincler.map((v) =>
            '• <b>${v.firmaAdi}</b><br>&nbsp;&nbsp;${v.baslangic} – ${v.bitis}, Mola: ${v.mola}dk'
          ).join('<br>');
        }

        // Yevmiye
        String yevmiyeHtml = '-';
        if (kayit.yevmiyeler.isNotEmpty) {
          yevmiyeHtml = kayit.yevmiyeler.map((y) =>
            '• <b>${y.ekipAdi}</b>: ${y.miktar} Yevmiye<br>&nbsp;&nbsp;${y.aciklama}'
          ).join('<br>');
        }

        // Fotoğraflar (Base64 gömülü)
        String fotografHtml = '-';
        if (kayit.fotografYollari.isNotEmpty) {
          StringBuffer fb = StringBuffer();
          for (var path in kayit.fotografYollari) {
            try {
              List<int> imageBytes;
              if (path.startsWith('http://') || path.startsWith('https://')) {
                final response = await http.get(Uri.parse(path));
                if (response.statusCode == 200) {
                  imageBytes = response.bodyBytes;
                } else continue;
              } else {
                final imgFile = File(path);
                if (await imgFile.exists()) {
                  imageBytes = await imgFile.readAsBytes();
                } else continue;
              }
              final b64 = base64Encode(imageBytes);
              // Uzantıya göre MIME tipi
              String mime = 'image/jpeg';
              if (path.toLowerCase().endsWith('.png')) mime = 'image/png';
              if (path.toLowerCase().endsWith('.webp')) mime = 'image/webp';
              fb.write('<img src="data:$mime;base64,$b64" onclick="openModal(this.src)" style="max-width:180px;max-height:160px;margin:3px;border:1px solid #ccc;border-radius:4px;cursor:pointer;transition:transform 0.2s;" onmouseover="this.style.transform=\'scale(1.05)\'" onmouseout="this.style.transform=\'scale(1)\'" title="Büyütmek için tıklayın" />');
            } catch (e) {
              print('Resim hatası: $e');
            }
          }
          if (fb.isNotEmpty) fotografHtml = fb.toString();
        }

        final String notlarHtml = kayit.notlar.isEmpty ? '-' : kayit.notlar.replaceAll('\n', '<br>');

        tableRows.write('''
          <tr>
            <td class="santiye">📍 ${proje.ad}</td>
            <td>$kalipciHtml</td>
            <td>$demirciHtml</td>
            <td>$betonHtml</td>
            <td>$vincHtml</td>
            <td>$yevmiyeHtml</td>
            <td>$notlarHtml</td>
            <td class="foto">$fotografHtml</td>
          </tr>
        ''');
      }

      final String html = '''<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Günlük Şantiye Raporu – $tarihStr</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Segoe UI', Arial, sans-serif; background: #f4f6fb; padding: 20px; color: #222; }
    .header { text-align: center; margin-bottom: 24px; }
    .header h1 { font-size: 22px; color: #1A237E; letter-spacing: 1px; }
    .header p { color: #555; font-size: 13px; margin-top: 4px; }
    table { width: 100%; border-collapse: collapse; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 12px rgba(0,0,0,0.10); }
    thead th { background: #1A237E; color: white; padding: 10px 8px; font-size: 12px; text-align: left; }
    tbody tr { border-bottom: 1px solid #e8eaf0; }
    tbody tr:hover { background: #f0f4ff; }
    td { padding: 10px 8px; font-size: 12px; vertical-align: top; line-height: 1.5; }
    .santiye { font-weight: bold; background: #f5f7ff; color: #1A237E; white-space: nowrap; }
    .foto { min-width: 120px; }
    .footer { text-align: center; margin-top: 18px; font-size: 11px; color: #aaa; }
    /* Büyütme Modalı */
    .modal { display: none; position: fixed; z-index: 9999; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.85); align-items: center; justify-content: center; }
    .modal img { max-width: 92%; max-height: 92%; border-radius: 8px; box-shadow: 0 4px 20px rgba(0,0,0,0.5); }
    .modal-close { position: absolute; top: 15px; right: 25px; color: white; font-size: 35px; font-weight: bold; cursor: pointer; }
  </style>
</head>
<body>
  <div class="header">
    <h1>🏗️ GÜNLÜK ŞANTİYE RAPORU</h1>
    <p>Rapor Tarihi: <b>$tarihStr</b> &nbsp;|&nbsp; Toplam Şantiye: <b>${records.length}</b></p>
  </div>
  <table>
    <thead>
      <tr>
        <th>Şantiye</th>
        <th>Kalıpçı Ekibi</th>
        <th>Demirci Ekibi</th>
        <th>Beton</th>
        <th>Vinç</th>
        <th>Yevmiye</th>
        <th>Notlar</th>
        <th>Fotoğraflar</th>
      </tr>
    </thead>
    <tbody>
      $tableRows
    </tbody>
  </table>
  <div class="footer">SantiyePro – $tarihStr tarihli rapor</div>

  <!-- Fotoğraf Büyütme Penceresi -->
  <div id="imgModal" class="modal" onclick="closeModal()">
    <span class="modal-close" onclick="closeModal()">&times;</span>
    <img id="modalImg" src="" alt="Büyütülmüş Görsel">
  </div>

  <script>
    function openModal(src) {
      document.getElementById('modalImg').src = src;
      document.getElementById('imgModal').style.display = 'flex';
    }
    function closeModal() {
      document.getElementById('imgModal').style.display = 'none';
    }
  </script>
</body>
</html>''';

      final String fileName = 'Santiye_Raporu_$dosyaTarihStr.html';
      final String filePath = '$selectedDirectory/$fileName';
      await File(filePath).writeAsString(html, encoding: utf8);

      if (mounted) Navigator.pop(context);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Flexible(child: Text('Rapor Oluşturuldu!', style: TextStyle(color: Colors.white, fontSize: 16))),
              ],
            ),
            content: Text(
              'Dosya: $fileName\nKonum: $selectedDirectory\n\n📱 Mobilden görmek için dosyayı telefona gönderin ve Chrome / Safari ile açın.\n🖥️ PC\'de çift tıklayarak tarayıcıda açın.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rapor hatası: $e'), backgroundColor: Colors.red),
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
                    ? [const Color(0xFF1A237E).withOpacity(0.4), const Color(0xFF0D47A1).withOpacity(0.4)]
                    : [Colors.indigo.shade50, Colors.blue.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isDark ? Colors.indigo.withOpacity(0.3) : Colors.indigo.withOpacity(0.1),
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
                              onPressed: () => _exportToWord(records),
                              icon: const Icon(Icons.description, size: 16),
                              label: const Text('Word Raporu İndir'),
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
                                    const Divider(height: 20, color: Colors.white12),

                                    // Kalıpçı & Demirci & Beton Satırı
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Kalıpçı
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.engineering, size: 14, color: Colors.orange),
                                                  SizedBox(width: 4),
                                                  Text('Kalıpçı Ekibi', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${kayit.kalipci} Kişi',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              if (kayit.kalipciYapilanIs.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  kayit.kalipciYapilanIs,
                                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                                              const Row(
                                                children: [
                                                  Icon(Icons.hardware, size: 14, color: Colors.orange),
                                                  SizedBox(width: 4),
                                                  Text('Demirci Ekibi', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${kayit.demirci} Kişi',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              if (kayit.demirciYapilanIs.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  kayit.demirciYapilanIs,
                                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                                              const Row(
                                                children: [
                                                  Icon(Icons.opacity, size: 14, color: Colors.blueAccent),
                                                  SizedBox(width: 4),
                                                  Text('Beton', style: TextStyle(color: Colors.white54, fontSize: 11)),
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
                                      const Divider(height: 10, color: Colors.white10),
                                      const SizedBox(height: 5),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Vinç Bilgileri
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Row(
                                                  children: [
                                                    Icon(Icons.architecture, size: 14, color: Colors.teal),
                                                    SizedBox(width: 4),
                                                    Text('Vinç Kullanımı', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                if (kayit.vincler.isEmpty)
                                                  const Text('-', style: TextStyle(color: Colors.white30, fontSize: 13))
                                                else
                                                  ...kayit.vincler.map((v) => Padding(
                                                        padding: const EdgeInsets.only(bottom: 2),
                                                        child: Text(
                                                          '${v.firmaAdi} (${v.baslangic}-${v.bitis})',
                                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
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
                                                const Row(
                                                  children: [
                                                    Icon(Icons.payments, size: 14, color: Colors.teal),
                                                    SizedBox(width: 4),
                                                    Text('Yevmiyeler', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                if (kayit.yevmiyeler.isEmpty)
                                                  const Text('-', style: TextStyle(color: Colors.white30, fontSize: 13))
                                                else
                                                  ...kayit.yevmiyeler.map((y) => Padding(
                                                        padding: const EdgeInsets.only(bottom: 2),
                                                        child: Text(
                                                          '${y.ekipAdi} (${y.miktar} Y.)',
                                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
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
                                      const Divider(height: 10, color: Colors.white10),
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
                                      const Divider(height: 10, color: Colors.white10),
                                      const SizedBox(height: 8),
                                      const Row(
                                        children: [
                                          Icon(Icons.photo_library, size: 14, color: Colors.amber),
                                          SizedBox(width: 4),
                                          Text('Şantiye Fotoğrafları', style: TextStyle(color: Colors.white54, fontSize: 11)),
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

                                            return Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              width: 60,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.white12),
                                                image: DecorationImage(
                                                  image: (isNetwork ? NetworkImage(fPath) : FileImage(File(fPath))) as ImageProvider,
                                                  fit: BoxFit.cover,
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
