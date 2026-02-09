import 'package:flutter/material.dart';
import '../models/proje.dart';
import '../models/gunluk_kayit.dart';
import 'package:file_picker/file_picker.dart' as pkr;
import 'package:path_provider/path_provider.dart'; // Dosya kaydı için gerekli paket
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../services/image_service.dart';
import 'package:excel/excel.dart' as xls;
import '../theme/theme_colors.dart';



class ProjeDetaySayfa extends StatefulWidget {
  final Proje proje;
  final List<GunlukKayit> gunlukKayitlar;
  final Function(GunlukKayit) onKayitEkle;
  final Function(int, GunlukKayit) onKayitGuncelle;

  const ProjeDetaySayfa({
    super.key,
    required this.proje,
    required this.gunlukKayitlar,
    required this.onKayitEkle,
    required this.onKayitGuncelle,
  });

  @override
  State<ProjeDetaySayfa> createState() => _ProjeDetaySayfaState();
}

class _ProjeDetaySayfaState extends State<ProjeDetaySayfa>
    with SingleTickerProviderStateMixin {
  final _imageService = ImageService();

  // --- Genel Bakış State Değişkenleri ---
  DateTime secilenTarih = DateTime.now();
  final kalipciController = TextEditingController();
  final demirciController = TextEditingController();
  final digerController = TextEditingController();
  final kalipciIsController = TextEditingController();
  final demirciIsController = TextEditingController();
  final notlarController = TextEditingController();
  final betonController = TextEditingController();
  List<String> fotograflar = [];

  // --- Puantaj State Değişkenleri ---
  late TabController _tabController;
  late DateTime puantajBaslangicTarihi;
  late DateTime puantajBitisTarihi;
  String tarihFiltreSecenegi =
      'proje_baslangic'; // 'proje_baslangic' veya 'ozel'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Puantaj varsayılan tarihleri
    puantajBaslangicTarihi = widget.proje.baslangicTarihi;
    puantajBitisTarihi = DateTime.now();

    _yukleKayit();
  }

  @override
  void dispose() {
    _tabController.dispose();
    kalipciController.dispose();
    demirciController.dispose();
    digerController.dispose();
    kalipciIsController.dispose();
    demirciIsController.dispose();
    notlarController.dispose();
    betonController.dispose();
    super.dispose();
  }

  void _yukleKayit() {
    final kayit = widget.gunlukKayitlar.firstWhere(
      (k) =>
          k.tarih.year == secilenTarih.year &&
          k.tarih.month == secilenTarih.month &&
          k.tarih.day == secilenTarih.day,
      orElse: () => GunlukKayit(tarih: secilenTarih),
    );

    kalipciController.text = kayit.kalipci.toString();
    demirciController.text = kayit.demirci.toString();
    digerController.text = kayit.diger.toString();
    kalipciIsController.text = kayit.kalipciYapilanIs;
    demirciIsController.text = kayit.demirciYapilanIs;
    notlarController.text = kayit.notlar;
    betonController.text = kayit.beton;
    fotograflar = List.from(kayit.fotografYollari);
    if (mounted) setState(() {});
  }

  void _tarihDegistir(DateTime yeniTarih) {
    setState(() {
      secilenTarih = yeniTarih;
      _yukleKayit();
    });
    // Veri Girişi sekmesine geç (index 1)
    _tabController.animateTo(1);
  }

  void _ayDegistir(DateTime yeniTarih) {
    setState(() {
      secilenTarih = yeniTarih;
    });
    // Sekme değiştirme YOK - Genel sekmesinde kalır
  }

  Future<void> _fotografEkle() async {
    final picker = ImagePicker();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.cardBackground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Kamera', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await picker.pickImage(source: ImageSource.camera);
                if (photo != null) {
                  setState(() => fotograflar.add(photo.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Galeri', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final List<XFile>? images = await picker.pickMultiImage();
                if (images != null && images.isNotEmpty) {
                  setState(() {
                    fotograflar.addAll(images.map((img) => img.path));
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _kaydet() async {
    // Yükleme sırasında bekletme göster
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      // Fotoğrafları Firebase Storage'a yükle
      List<String> yuklenenYollar = [];
      int basariliYukleme = 0;
      int hataliYukleme = 0;

      for (String p in fotograflar) {
        if (!ImageService.isNetworkUrl(p)) {
          print("LOG: Fotoğraf yükleniyor: $p");
          String? url = await _imageService.uploadImage(p);
          if (url != null) {
            yuklenenYollar.add(url);
            basariliYukleme++;
          } else {
            yuklenenYollar.add(p); // Yükleme başarısız olursa yerel yolu tut
            hataliYukleme++;
          }
        } else {
          yuklenenYollar.add(p);
        }
      }

      // State'i güncellenen URL'lerle yenile
      setState(() {
        fotograflar = yuklenenYollar;
      });

      final yeniKayit = GunlukKayit(
        tarih: secilenTarih,
        kalipci: int.tryParse(kalipciController.text) ?? 0,
        demirci: int.tryParse(demirciController.text) ?? 0,
        diger: int.tryParse(digerController.text) ?? 0,
        kalipciYapilanIs: kalipciIsController.text,
        demirciYapilanIs: demirciIsController.text,
        notlar: notlarController.text,
        beton: betonController.text,
        fotografYollari: List.from(fotograflar),
      );

      final mevcutIndex = widget.gunlukKayitlar.indexWhere(
        (k) =>
            k.tarih.year == secilenTarih.year &&
            k.tarih.month == secilenTarih.month &&
            k.tarih.day == secilenTarih.day,
      );

      if (mevcutIndex >= 0) {
        // Mevcut kaydı GÜNCELLE
        widget.onKayitGuncelle(mevcutIndex, yeniKayit);
      } else {
        // Yeni kayıt EKLE
        widget.onKayitEkle(yeniKayit);
      }

      if (mounted) {
        Navigator.pop(context); // Bekleme diyaloğunu kapat
        
        String message = 'Kayıt başarıyla kaydedildi';
        if (hataliYukleme > 0) {
          message += '\n($hataliYukleme fotoğraf buluta yüklenemedi)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: hataliYukleme > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 4),
            action: hataliYukleme > 0 ? SnackBarAction(
              label: 'DETAY',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Yükleme Sorunu'),
                    content: const Text('Bazı fotoğraflar buluta yüklenemedi. '
                        'Lütfen internet bağlantınızı ve Firebase Storage (Bulut Depolama) '
                        'ayarlarınızın (Rules) açık olduğunu kontrol edin.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('TAMAM'))
                    ],
                  ),
                );
              },
            ) : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Bekleme diyaloğunu kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Puantaj Yardımcı Fonksiyonları ---
  List<GunlukKayit> _getPuantajKayitlari() {
    // Tarihe göre filtrele
    final filtrelenmis = widget.gunlukKayitlar.where((k) {
      // Saatleri sıfırlayarak sadece gün bazlı karşılaştırma yapalım
      final kayitTarihi = DateTime(k.tarih.year, k.tarih.month, k.tarih.day);
      final baslangic = DateTime(
        puantajBaslangicTarihi.year,
        puantajBaslangicTarihi.month,
        puantajBaslangicTarihi.day,
      );
      final bitis = DateTime(
        puantajBitisTarihi.year,
        puantajBitisTarihi.month,
        puantajBitisTarihi.day,
      );

      return (kayitTarihi.isAfter(baslangic) ||
              kayitTarihi.isAtSameMomentAs(baslangic)) &&
          (kayitTarihi.isBefore(bitis) || kayitTarihi.isAtSameMomentAs(bitis));
    }).toList();

    // Tarihe göre sırala (Yeniden eskiye veya eskiden yeniye)
    filtrelenmis.sort((a, b) => b.tarih.compareTo(a.tarih));
    return filtrelenmis;
  }

  Future<void> _excelVeFotograflariAktar() async {
    final kayitlar = _getPuantajKayitlari();

    // Varsayılan dosya adı
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final projeAdiDuzenli = widget.proje.ad.replaceAll(' ', '_');
    String varsayilanAd = "Puantaj_${projeAdiDuzenli}_$timestamp";

    final TextEditingController fileNameController =
        TextEditingController(text: varsayilanAd);

    // 1. Dosya ismini sor
    String? dosyaAdi = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('Excel ve Fotoğraflar', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: fileNameController,
          style: TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Dosya Adı (Uzantısız)',
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (fileNameController.text.isNotEmpty) {
                Navigator.pop(context, fileNameController.text);
              }
            },
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );

    if (dosyaAdi == null) return; // İptal edildi

    // 2. Klasör seç
    String? selectedDirectory = await (pkr.FilePicker as dynamic).platform.getDirectoryPath();

    if (selectedDirectory == null) return;

    // Bekleme göster
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      // Excel Oluştur
      var excel = xls.Excel.createExcel();
      xls.Sheet sheetObject = excel['Puantaj'];
      excel.delete('Sheet1'); // Varsayılanı sil

      // Başlıklar
      sheetObject.appendRow([
        xls.TextCellValue("Tarih"),
        xls.TextCellValue("Kalıpçı"),
        xls.TextCellValue("Demirci"),
        xls.TextCellValue("Diğer"),
        xls.TextCellValue("Toplam"),
        xls.TextCellValue("Yapılan İşler (Kalıpçı)"),
        xls.TextCellValue("Yapılan İşler (Demirci)"),
        xls.TextCellValue("Notlar"),
        xls.TextCellValue("Beton"),
        xls.TextCellValue("Fotoğraf Dosyaları"),
      ]);

      // Fotoğraf Klasörü Hazırla
      final fotoKlasorAdi = "${dosyaAdi}_Fotograflar";
      final fotoKlasorYolu = "$selectedDirectory/$fotoKlasorAdi";
      final fotoDir = Directory(fotoKlasorYolu);
      if (!await fotoDir.exists()) {
        await fotoDir.create(recursive: true);
      }

      int fotoSayac = 0;

      for (var kayit in kayitlar) {
        final tarihStr = "${kayit.tarih.day.toString().padLeft(2, '0')}.${kayit.tarih.month.toString().padLeft(2, '0')}.${kayit.tarih.year}";
        final toplam = kayit.kalipci + kayit.demirci + kayit.diger;

        // Fotoğrafları kopyala ve isimlerini biriktir
        List<String> kopyalananFotolar = [];
        for (int i = 0; i < kayit.fotografYollari.length; i++) {
          final kaynak = kayit.fotografYollari[i];
          String uzanti = "jpg";
          if (kaynak.contains('.')) {
             final lastPart = kaynak.split('.').last.split('?').first.toLowerCase();
             if (['png', 'jpg', 'jpeg', 'webp'].contains(lastPart)) uzanti = lastPart;
          }
          
          final yeniAd = "${tarihStr}_${(i+1).toString().padLeft(2, '0')}.$uzanti";
          final hedefYol = "$fotoKlasorYolu/$yeniAd";

          try {
            if (ImageService.isNetworkUrl(kaynak)) {
              final bytes = await _imageService.downloadImage(kaynak);
              if (bytes != null) await File(hedefYol).writeAsBytes(bytes);
            } else {
              final f = File(kaynak);
              if (await f.exists()) await f.copy(hedefYol);
            }
            kopyalananFotolar.add(yeniAd);
            fotoSayac++;
          } catch (e) {
            print("Foto kopyalama hatası: $e");
          }
        }

        sheetObject.appendRow([
          xls.TextCellValue(tarihStr),
          xls.IntCellValue(kayit.kalipci),
          xls.IntCellValue(kayit.demirci),
          xls.IntCellValue(kayit.diger),
          xls.IntCellValue(toplam),
          xls.TextCellValue(kayit.kalipciYapilanIs),
          xls.TextCellValue(kayit.demirciYapilanIs),
          xls.TextCellValue(kayit.notlar),
          xls.TextCellValue(kayit.beton),
          xls.TextCellValue(kopyalananFotolar.join(", ")),
        ]);
        
        // Tarih hücresi formatı (İsteğe bağlı, kütüphane desteğine göre)
        // sheetObject.cell(CellIndex.indexByString("A${sheetObject.maxRows}")).cellStyle = CellStyle(numberFormat: NumFormat.standard_14);
      }

      // Dosyayı Kaydet
      final fileBytes = excel.save();
      final tamDosyaAdi = "$dosyaAdi.xlsx";
      final dosyaYolu = "$selectedDirectory/$tamDosyaAdi";
      
      if (fileBytes != null) {
        File(dosyaYolu)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
      }

      if (mounted) {
        Navigator.pop(context); // Dialog kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel ve $fotoSayac fotoğraf kaydedildi:\n$dosyaYolu'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'TAMAM',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // WiFi bağlantısını kontrol et (basit NetworkInterface kontrolü)
  Future<bool> _isWifiConnected() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        // WiFi genelde 'wlan' veya 'Wi-Fi' içerir
        if (interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('wi-fi') ||
            interface.name.toLowerCase().contains('wifi')) {
          return true;
        }
      }
      // Eğer herhangi bir ağ bağlantısı varsa da kabul et
      return interfaces.isNotEmpty;
    } catch (e) {
      return true; // Hata durumunda devam et
    }
  }

  // Tüm proje bilgilerini Excel'e aktar
  Future<void> _tumBilgileriAktar() async {
    final kayitlar = widget.gunlukKayitlar;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final projeAdiDuzenli = widget.proje.ad.replaceAll(' ', '_');
    String varsayilanAd = "Proje_${projeAdiDuzenli}_$timestamp";

    final TextEditingController fileNameController =
        TextEditingController(text: varsayilanAd);

    String? dosyaAdi = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('Tüm Bilgileri Aktar', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: fileNameController,
          style: TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Dosya Adı (Uzantısız)',
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (fileNameController.text.isNotEmpty) {
                Navigator.pop(context, fileNameController.text);
              }
            },
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );

    if (dosyaAdi == null) return;

    // 2. Klasör seç
    String? selectedDirectory = await (pkr.FilePicker as dynamic).platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    // Tüm bilgileri içeren CSV oluştur
    String csvData = "\uFEFFPROJE BİLGİLERİ\n";
    csvData += "Proje Adı;${widget.proje.ad}\n";
    csvData += "Başlangıç Tarihi;${widget.proje.baslangicTarihi.day}.${widget.proje.baslangicTarihi.month}.${widget.proje.baslangicTarihi.year}\n";
    csvData += "Toplam Gün;${widget.proje.toplamGun}\n";
    csvData += "Durum;${widget.proje.durum}\n";
    csvData += "Açıklama;${widget.proje.aciklama}\n\n";

    
    csvData += "GÜNLÜK KAYITLAR\n";
    csvData += "Tarih;Kalıpçı;Demirci;Diğer;Toplam;Kalıpçı İş;Demirci İş;Notlar;Beton;Fotoğraf Sayısı\n";

    // Tarihe göre sırala
    final sortedKayitlar = List<GunlukKayit>.from(kayitlar);
    sortedKayitlar.sort((a, b) => a.tarih.compareTo(b.tarih));

    for (var kayit in sortedKayitlar) {
      final tarihStr = "${kayit.tarih.day}.${kayit.tarih.month}.${kayit.tarih.year}";
      final toplam = kayit.kalipci + kayit.demirci + kayit.diger;
      csvData += "$tarihStr;${kayit.kalipci};${kayit.demirci};${kayit.diger};$toplam;";
      csvData += "${kayit.kalipciYapilanIs.replaceAll(';', ',')};";
      csvData += "${kayit.demirciYapilanIs.replaceAll(';', ',')};";
      csvData += "${kayit.notlar.replaceAll(';', ',')};";
      csvData += "${kayit.beton.replaceAll(';', ',')};";
      csvData += "${kayit.fotografYollari.length}\n";
    }

    try {
      final tamDosyaAdi = "$dosyaAdi.csv";
      final dosyaYolu = "$selectedDirectory/$tamDosyaAdi";

      final file = File(dosyaYolu);
      await file.writeAsString(csvData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tüm Bilgiler Kaydedildi:\n$dosyaYolu'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydetme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Sadece fotoğrafları aktar (tarihli dosya isimleriyle)
  Future<void> _fotograflariAktar() async {
    // WiFi kontrolü
    bool isConnected = await _isWifiConnected();
    if (!isConnected) {
      if (mounted) {
        final devamEt = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF333333),
            title: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange),
                SizedBox(width: 10),
                Text('WiFi Bağlantısı Yok', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: const Text(
              'WiFi bağlantısı bulunamadı. Fotoğraf aktarımı mobil veri kullanabilir ve yüksek miktarda veri harcayabilir.\n\nDevam etmek istiyor musunuz?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Devam Et'),
              ),
            ],
          ),
        );

        if (devamEt != true) return;
      }
    }

    // Tüm fotoğrafları topla
    List<Map<String, dynamic>> tumFotograflar = [];
    for (var kayit in widget.gunlukKayitlar) {
      for (var foto in kayit.fotografYollari) {
        tumFotograflar.add({'tarih': kayit.tarih, 'yol': foto});
      }
    }

    if (tumFotograflar.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aktarılacak fotoğraf bulunamadı'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Klasör seç
    String? selectedDirectory = await (pkr.FilePicker as dynamic).platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    // Proje klasörü oluştur
    final projeAdiDuzenli = widget.proje.ad.replaceAll(' ', '_').replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final klasorAdi = "${projeAdiDuzenli}_Fotograflar_$timestamp";
    final hedefKlasor = Directory("$selectedDirectory/$klasorAdi");
    
    try {
      await hedefKlasor.create(recursive: true);

      int basarili = 0;
      int hatali = 0;

      for (int i = 0; i < tumFotograflar.length; i++) {
        final foto = tumFotograflar[i];
        final tarih = foto['tarih'] as DateTime;
        final kaynak = foto['yol'] as String;

        // Tarihli dosya adı oluştur (sıralı görünecek şekilde)
        final tarihStr = "${tarih.year}-${tarih.month.toString().padLeft(2, '0')}-${tarih.day.toString().padLeft(2, '0')}";
        final saatStr = "${tarih.hour.toString().padLeft(2, '0')}${tarih.minute.toString().padLeft(2, '0')}";
        
        // Uzantıyı belirle (URL'lerde query string olabilir)
        String uzanti = "jpg";
        if (kaynak.contains('.')) {
          final parts = kaynak.split('.');
          final lastPart = parts.last.split('?').first.toLowerCase();
          if (['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(lastPart)) {
            uzanti = lastPart;
          }
        }
        
        final yeniAd = "${tarihStr}_${saatStr}_${(i + 1).toString().padLeft(3, '0')}.$uzanti";
        final hedefYol = "${hedefKlasor.path}/$yeniAd";

        try {
          print("LOG: Aktarma basliyor: $kaynak");
          if (ImageService.isNetworkUrl(kaynak)) {
            print("LOG: Network URL tespit edildi, indiriliyor...");
            // URL ise indir
            final bytes = await _imageService.downloadImage(kaynak);
            if (bytes != null) {
              print("LOG: Indirme basarili, yaziliyor: $hedefYol");
              await File(hedefYol).writeAsBytes(bytes);
              basarili++;
            } else {
              print("LOG: Indirme basarisiz: $kaynak");
              hatali++;
            }
          } else {
            print("LOG: Yerel dosya tespit edildi: $kaynak");
            // Yerel dosya ise kopyala
            final kaynakDosya = File(kaynak);
            if (await kaynakDosya.exists()) {
              await kaynakDosya.copy(hedefYol);
              basarili++;
            } else {
              print("LOG: Yerel dosya bulunamadi (Muhtemelen mobil yolu): $kaynak");
              // Windows'ta olup mobildeki yerel yolu kopyalamaya çalışıyorsa burada durur
              hatali++;
            }
          }
        } catch (e) {
          print("LOG: Aktarma hatası ($yeniAd): $e");
          hatali++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$basarili fotoğraf aktarıldı${hatali > 0 ? ", $hatali hata" : ""}\n${hedefKlasor.path}'),
            backgroundColor: hatali > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aktarma hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Aktarma menüsünü göster
  void _aktarmaMenusuGoster() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.cardBackground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ThemeColors.divider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Aktarma Seçenekleri',
              style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: Text('Puantaj ve Fotoğraflar (Excel)', style: TextStyle(color: Colors.white)),
              subtitle: Text('Excel tablosu ve fotoğraf klasörü', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _excelVeFotograflariAktar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Tüm Proje Bilgileri', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Proje detayları ve tüm günlük kayıtlar', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _tumBilgileriAktar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.orange),
              title: const Text('Sadece Fotoğraflar', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Tarihli dosya isimleriyle', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _fotograflariAktar();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Ana Build Metodu ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          widget.proje.ad,
          style: TextStyle(color: ThemeColors.textPrimary(context)),
        ),
        iconTheme: IconThemeData(color: ThemeColors.icon(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.photo_library, color: Colors.blueAccent),
            tooltip: 'Galeri',
            onPressed: _galeriGoster,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: ThemeColors.textSecondary(context),
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 20), text: "Genel"),
            Tab(icon: Icon(Icons.edit_note, size: 20), text: "Giriş"),
            Tab(icon: Icon(Icons.table_chart, size: 20), text: "Puantaj"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildGenelBakisTab(), _buildVeriGirisiTab(), _buildPuantajTab()],
      ),
    );
  }

  // --- 1. SEKME: GENEL BAKIŞ ---
  Widget _buildGenelBakisTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return _buildMobileGenelBakis();
        } else {
          return _buildDesktopGenelBakis();
        }
      },
    );
  }

  // --- 2. SEKME: VERİ GİRİŞİ ---
  Widget _buildVeriGirisiTab() {
    final aylar = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seçilen Tarih Başlığı
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue),
                const SizedBox(width: 10),
                Text(
                  '${secilenTarih.day} ${aylar[secilenTarih.month - 1]} ${secilenTarih.year}',
                  style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _tabController.animateTo(0); // Genel Bakış sekmesine git
                  },
                  child: const Text('Takvimden Seç', style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          
          // Giriş Formu
          Card(
            color: ThemeColors.cardBackground(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: _buildMobileInputItem("Kalıpçı", kalipciController, isNumeric: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMobileInputItem("Demirci", demirciController, isNumeric: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMobileInputItem("Diğer", digerController, isNumeric: true)),
                  ]),
                  const SizedBox(height: 8),
                  _buildMobileInputItem("Kalıpçı Yapılan İş", kalipciIsController),
                  const SizedBox(height: 8),
                  _buildMobileInputItem("Demirci Yapılan İş", demirciIsController),
                  const SizedBox(height: 8),
                  _buildMobileInputItem("Notlar", notlarController, maxLines: 2),
                  const SizedBox(height: 8),
                  _buildMobileInputItem("Beton", betonController),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _fotografEkle,
                          icon: Icon(Icons.camera_alt),
                          label: const Text('Foto'),

                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12)
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _kaydet,
                          icon: Icon(Icons.save),
                          label: const Text('Kaydet'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12)
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Seçilen Fotoğraflar
          if (fotograflar.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Seçilenler', style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 14)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: fotograflar.length,
                itemBuilder: (context, index) {
                   return Container(
                     width: 80,
                     margin: const EdgeInsets.only(right: 8),
                     child: Stack(
                       children: [
                         GestureDetector(
                           onTap: () {
                             // Create photo list for viewing
                             final photosList = fotograflar.asMap().entries.map((e) => <String, dynamic>{
                               'tarih': DateTime.now(),
                               'yol': e.value,
                             }).toList();
                             _fotografBuyut(context, photosList, index);
                           },
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(8),
                             child: SizedBox(
                               width: 80,
                               height: 80,
                               child: ImageService.buildImage(
                                 fotograflar[index],
                                 fit: BoxFit.cover,
                               ),
                             ),
                           ),
                         ),
                         Positioned(top: 2, right: 2, child: InkWell(onTap: () => setState(() => fotograflar.removeAt(index)), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Icon(Icons.close, color: ThemeColors.textPrimary(context), size: 12)))),
                       ],
                     ),
                   );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileGenelBakis() {
    final ilerleme = _ilerlemeHesapla();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Project Title & Stats
          Card(
            color: ThemeColors.cardBackground(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.proje.ad, style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Kayıt: ${widget.gunlukKayitlar.length}', style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: LinearProgressIndicator(
                          value: ilerleme / 100,
                          backgroundColor: Colors.white24,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${ilerleme.toInt()}%', style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          
          Text(
            'Bilgi girmek istediğiniz tarihi seçin:',
            style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // Calendar (Full Width)
          Card(
            color: ThemeColors.cardBackground(context),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _buildTakvim(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMobileInputItem(String label, TextEditingController controller, {int maxLines = 1, bool isNumeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          style: TextStyle(color: ThemeColors.textPrimary(context)),
          maxLines: maxLines,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            filled: true,
            fillColor: Colors.black12,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopGenelBakis() {
    final ilerleme = _ilerlemeHesapla();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Bilgi Kartları
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: ThemeColors.cardBackground(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.proje.ad,
                    style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Container(
                width: 180,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ThemeColors.cardBackground(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Toplam Kayıt:',
                      style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 13),
                    ),
                    Text(
                      '${widget.gunlukKayitlar.length}',
                      style: TextStyle(
                        color: ThemeColors.textPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 120,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ThemeColors.cardBackground(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: ilerleme / 100,
                        backgroundColor: Colors.white24,
                        color: Colors.blue,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${ilerleme.toInt()}%',
                      style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                onPressed: _galeriGoster,
                icon: Icon(Icons.photo_library, size: 18),
                label: const Text('Galeri'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Takvim (Tam Ekran)
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: ThemeColors.cardBackground(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ThemeColors.border(context)),
                ),
                child: _buildTakvim(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. SEKME: PUANTAJ VE TABLO ---
  Widget _buildPuantajTab() {
    final kayitlar = _getPuantajKayitlari();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtre Kartı
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: ThemeColors.cardBackground(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.filter_list, color: ThemeColors.textPrimary(context), size: 20),
                          const SizedBox(width: 8),
                          Text("Tarih Aralığı:", style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButton<String>(
                        value: tarihFiltreSecenegi,
                        dropdownColor: const Color(0xFF3d3d3d),
                        style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 13),
                        isExpanded: true,
                        underline: Container(height: 1, color: Colors.blue),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              tarihFiltreSecenegi = val;
                              if (val == 'proje_baslangic') {
                                puantajBaslangicTarihi = widget.proje.baslangicTarihi;
                                puantajBitisTarihi = DateTime.now();
                              }
                            });
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: 'proje_baslangic', child: Text("Proje Başlangıcı - Bugün")),
                          DropdownMenuItem(value: 'ozel', child: Text("Özel Tarih Seçimi")),
                        ],
                      ),
                      if (tarihFiltreSecenegi == 'ozel') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: puantajBaslangicTarihi,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) setState(() => puantajBaslangicTarihi = picked);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                                child: Text("${puantajBaslangicTarihi.day}.${puantajBaslangicTarihi.month}.${puantajBaslangicTarihi.year}", style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Text("-", style: TextStyle(color: Colors.white))),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: puantajBitisTarihi,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) setState(() => puantajBitisTarihi = picked);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                                child: Text("${puantajBitisTarihi.day}.${puantajBitisTarihi.month}.${puantajBitisTarihi.year}", style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _aktarmaMenusuGoster,
                          icon: Icon(Icons.download, size: 18),
                          label: const Text("Aktar", style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                    ],
                  );
                }
                // Desktop layout
                return Row(
                  children: [
                    const Icon(Icons.filter_list, color: Colors.white),
                    const SizedBox(width: 10),
                    Text("Tarih Aralığı:", style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 20),
                    DropdownButton<String>(
                      value: tarihFiltreSecenegi,
                      dropdownColor: const Color(0xFF3d3d3d),
                      style: TextStyle(color: Colors.white),
                      underline: Container(height: 1, color: Colors.blue),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            tarihFiltreSecenegi = val;
                            if (val == 'proje_baslangic') {
                              puantajBaslangicTarihi = widget.proje.baslangicTarihi;
                              puantajBitisTarihi = DateTime.now();
                            }
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'proje_baslangic', child: Text("Proje Başlangıcı - Bugün")),
                        DropdownMenuItem(value: 'ozel', child: Text("Özel Tarih Seçimi")),
                      ],
                    ),
                    const SizedBox(width: 20),
                    if (tarihFiltreSecenegi == 'ozel') ...[
                      ElevatedButton.icon(
                        icon: Icon(Icons.calendar_today, size: 16),
                        label: Text("${puantajBaslangicTarihi.day}.${puantajBaslangicTarihi.month}.${puantajBaslangicTarihi.year}"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: puantajBaslangicTarihi, firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (picked != null) setState(() => puantajBaslangicTarihi = picked);
                        },
                      ),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("-", style: TextStyle(color: Colors.white))),
                      ElevatedButton.icon(
                        icon: Icon(Icons.calendar_today, size: 16),
                        label: Text("${puantajBitisTarihi.day}.${puantajBitisTarihi.month}.${puantajBitisTarihi.year}"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: puantajBitisTarihi, firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (picked != null) setState(() => puantajBitisTarihi = picked);
                        },
                      ),
                    ],
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _aktarmaMenusuGoster,
                      icon: Icon(Icons.download),
                      label: const Text("Aktar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),

                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Tablo Alanı
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: ThemeColors.cardBackground(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(15),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.white24),
                    child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      const Color(0xFF1a1a1a),
                    ),
                    dataRowColor: MaterialStateProperty.resolveWith<Color>((
                      Set<MaterialState> states,
                    ) {
                      return Colors.transparent; // Satır renkleri
                    }),
                    columns: [
                      DataColumn(
                        label: Text(
                          'Tarih',
                          style: TextStyle(
                            color: ThemeColors.textPrimary(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Kalıpçı',
                          style: TextStyle(
                            color: ThemeColors.textPrimary(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Text(
                          'Demirci',
                          style: TextStyle(
                            color: ThemeColors.textPrimary(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Text(
                          'Diğer',
                          style: TextStyle(
                            color: ThemeColors.textPrimary(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Text(
                          'Toplam',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        numeric: true,
                      ),
                    ],
                    rows: [
                      ...kayitlar.map((kayit) {
                        final toplam =
                            kayit.kalipci + kayit.demirci + kayit.diger;
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                "${kayit.tarih.day}.${kayit.tarih.month}.${kayit.tarih.year}",
                                style: TextStyle(color: ThemeColors.textPrimary(context)),
                              ),
                            ),
                            DataCell(
                              Text(
                                kayit.kalipci.toString(),
                                style: TextStyle(color: ThemeColors.textSecondary(context)),
                              ),
                            ),
                            DataCell(
                              Text(
                                kayit.demirci.toString(),
                                style: TextStyle(color: ThemeColors.textSecondary(context)),
                              ),
                            ),
                            DataCell(
                              Text(
                                kayit.diger.toString(),
                                style: TextStyle(color: ThemeColors.textSecondary(context)),
                              ),
                            ),
                            DataCell(
                              Text(
                                toplam.toString(),
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                      // Toplam Satırı
                      if (kayitlar.isNotEmpty)
                        DataRow(
                          color: MaterialStateProperty.all(Colors.blue.withOpacity(0.05)),
                          cells: [
                            DataCell(
                              Text(
                                "TOPLAM",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                kayitlar.fold(0, (sum, item) => sum + item.kalipci).toString(),
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                kayitlar.fold(0, (sum, item) => sum + item.demirci).toString(),
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                kayitlar.fold(0, (sum, item) => sum + item.diger).toString(),
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                kayitlar.fold(0, (sum, item) => sum + item.kalipci + item.demirci + item.diger).toString(),
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Yardımcı Widgetlar (Aynı Kalıyor) ---
  void _galeriGoster() {
    List<Map<String, dynamic>> tumFotograflar = [];
    for (var kayit in widget.gunlukKayitlar) {
      for (var foto in kayit.fotografYollari) {
        tumFotograflar.add({'tarih': kayit.tarih, 'yol': foto});
      }
    }
    tumFotograflar.sort(
      (a, b) => (b['tarih'] as DateTime).compareTo(a['tarih'] as DateTime),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF1a1a1a),
          appBar: AppBar(
            title: const Text('Proje Galerisi'),
            backgroundColor: const Color(0xFF0d0d0d),
          ),
          body: tumFotograflar.isEmpty
              ? const Center(child: Text('Henüz fotoğraf eklenmemiş', style: TextStyle(color: Colors.white54)))
              : GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: tumFotograflar.length,
                  itemBuilder: (context, index) {
                    final foto = tumFotograflar[index];
                    final yol = foto['yol'] as String;
                    return InkWell(
                      onTap: () => _fotografBuyut(context, tumFotograflar, index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ImageService.buildImage(yol, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _fotografBuyut(
    BuildContext context,
    List<Map<String, dynamic>> tumFotograflar,
    int baslangicIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FotografGoruntulePage(
          fotograflar: tumFotograflar,
          baslangicIndex: baslangicIndex,
        ),
      ),
    );
  }

  double _ilerlemeHesapla() {
    final toplamGun = widget.proje.toplamGun;
    final gecenGun = DateTime.now()
        .difference(widget.proje.baslangicTarihi)
        .inDays;
    if (toplamGun == 0) return 0;
    return (gecenGun / toplamGun * 100).clamp(0, 100);
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white30),
        filled: true,
        fillColor: const Color(0xFF1a1a1a),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildTakvim() {
    final simdi = DateTime.now();
    final yil = secilenTarih.year;
    final ay = secilenTarih.month;
    final ilkGun = DateTime(yil, ay, 1);
    final sonGun = DateTime(yil, ay + 1, 0);
    // Dart weekday: 1=Pazartesi, 7=Pazar
    // Takvim dizisi: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'] (0-6)
    // Pazartesi için 0, Pazar için 6 olmalı
    final baslangicGunu = ilkGun.weekday - 1;
    final aylar = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    final gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => _ayDegistir(DateTime(yil, ay - 1, 1)),
              icon: Icon(Icons.chevron_left, color: Colors.white),
            ),
            Text(
              '${aylar[ay - 1]} $yil',
              style: TextStyle(
                color: ThemeColors.textPrimary(context),
                fontSize: Platform.isWindows ? 18 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: () => _ayDegistir(DateTime(yil, ay + 1, 1)),
              icon: Icon(Icons.chevron_right, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => _tarihDegistir(DateTime.now()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade800,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 40),
          ),
          child: const Text('Bugün'),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: gunler
              .map(
                (g) => Expanded(
                  child: Center(
                    child: Text(
                      g,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: Platform.isWindows ? 12 : 10,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        ...List.generate(6, (haftaIndex) {
          return Row(
            children: List.generate(7, (gunIndex) {
              final gunNo = haftaIndex * 7 + gunIndex - baslangicGunu + 1;
              if (gunNo < 1 || gunNo > sonGun.day)
                return Expanded(child: Container());
              final tarih = DateTime(yil, ay, gunNo);
              final secili =
                  tarih.day == secilenTarih.day &&
                  tarih.month == secilenTarih.month &&
                  tarih.year == secilenTarih.year;
              final bugun =
                  tarih.day == simdi.day &&
                  tarih.month == simdi.month &&
                  tarih.year == simdi.year;
              final kayitVar = widget.gunlukKayitlar.any(
                (k) =>
                    k.tarih.day == tarih.day &&
                    k.tarih.month == tarih.month &&
                    k.tarih.year == tarih.year,
              );
              return Expanded(
                child: InkWell(
                  onTap: () => _tarihDegistir(tarih),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    height: Platform.isWindows ? 40 : 35,
                    decoration: BoxDecoration(
                      color: secili
                          ? Colors.blue
                          : (bugun
                                ? Colors.lightGreen
                                : (kayitVar
                                      ? Colors.green.shade800
                                      : Colors.transparent)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '$gunNo',
                        style: TextStyle(
                          color: (secili || kayitVar) 
                              ? Colors.white 
                              : (bugun 
                                  ? Colors.black 
                                  : ThemeColors.textPrimary(context)),
                          fontSize: Platform.isWindows ? 14 : 12,
                          fontWeight: secili || bugun ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }

  Widget _buildDesktopInputWithLabel(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        _buildTextField(controller, hint),
      ],
    );
  }
}

class _FotografGoruntulePage extends StatefulWidget {
  final List<Map<String, dynamic>> fotograflar;
  final int baslangicIndex;

  const _FotografGoruntulePage({
    required this.fotograflar,
    required this.baslangicIndex,
  });

  @override
  State<_FotografGoruntulePage> createState() => _FotografGoruntulePageState();
}

class _FotografGoruntulePageState extends State<_FotografGoruntulePage> {
  late int mevcutIndex;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    mevcutIndex = widget.baslangicIndex;
  }

  void _oncekiFoto() {
    if (mevcutIndex > 0)
      setState(() {
        mevcutIndex--;
        _transformationController.value = Matrix4.identity();
      });
  }

  void _sonrakiFoto() {
    if (mevcutIndex < widget.fotograflar.length - 1)
      setState(() {
        mevcutIndex++;
        _transformationController.value = Matrix4.identity();
      });
  }

  @override
  Widget build(BuildContext context) {
    final mevcutFoto = widget.fotograflar[mevcutIndex];
    final tarih = mevcutFoto['tarih'] as DateTime;
    final yol = mevcutFoto['yol'] as String;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: ThemeColors.textPrimary(context), size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${mevcutIndex + 1} / ${widget.fotograflar.length}',
          style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 16),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Text(
                '${tarih.day}/${tarih.month}/${tarih.year}',
                style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              child: ImageService.buildImage(
                yol,
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (mevcutIndex > 0)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _oncekiFoto,
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white54,
                    size: 40,
                  ),
                ),
              ),
            ),
          if (mevcutIndex < widget.fotograflar.length - 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _sonrakiFoto,
                  icon: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white54,
                    size: 40,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
