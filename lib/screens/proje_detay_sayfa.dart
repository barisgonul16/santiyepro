import 'package:flutter/material.dart';
import '../models/proje.dart';
import '../models/gunluk_kayit.dart';
import 'package:file_picker/file_picker.dart' as pkr;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as paylas;
import '../services/image_service.dart';
import 'package:excel/excel.dart' as xls;
import '../theme/theme_colors.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/app_log.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VincFormControllers {
  final firmaAdiController = TextEditingController();
  final baslangicController = TextEditingController();
  final bitisController = TextEditingController();
  final molaController = TextEditingController();
  final aciklamaController = TextEditingController();

  VincFormControllers({String firma = '', String baslangic = '', String bitis = '', String mola = '', String aciklama = ''}) {
    firmaAdiController.text = firma;
    baslangicController.text = baslangic;
    bitisController.text = bitis;
    molaController.text = mola;
    aciklamaController.text = aciklama;
  }

  void dispose() {
    firmaAdiController.dispose();
    baslangicController.dispose();
    bitisController.dispose();
    molaController.dispose();
    aciklamaController.dispose();
  }
}

class YevmiyeFormControllers {
  String? secilenEkipAdi;
  final miktarController = TextEditingController();
  final aciklamaController = TextEditingController();

  YevmiyeFormControllers({String? ekip, String miktar = '', String aciklama = ''}) {
    secilenEkipAdi = ekip;
    miktarController.text = miktar;
    aciklamaController.text = aciklama;
  }

  void dispose() {
    miktarController.dispose();
    aciklamaController.dispose();
  }
}

class ProjeDetaySayfa extends StatefulWidget {
  final Proje proje;
  final List<GunlukKayit> gunlukKayitlar;
  final Function(GunlukKayit) onKayitEkle;
  final Function(int, GunlukKayit) onKayitGuncelle;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;
  final List<String> ekipler;
  /// Açılışta gösterilecek sekme: 0 Genel, 1 Giriş (bugünün formu), 2 Puantaj.
  final int baslangicSekmesi;

  const ProjeDetaySayfa({
    super.key,
    required this.proje,
    required this.gunlukKayitlar,
    required this.onKayitEkle,
    required this.onKayitGuncelle,
    required this.projeGunlukKayitlari,
    required this.ekipler,
    this.baslangicSekmesi = 0,
  });

  @override
  State<ProjeDetaySayfa> createState() => _ProjeDetaySayfaState();
}

class _ProjeDetaySayfaState extends State<ProjeDetaySayfa>
    with SingleTickerProviderStateMixin {
  final _imageService = ImageService();

  // --- Genel Bakış State Değişkenleri ---
  DateTime secilenTarih = DateTime.now();
  // Takvimde gösterilen ay. Seçili günden ayrı tutulur: ay değiştirmek
  // formdaki günü değiştirmemeli, yoksa formdaki bilgiler başka bir güne
  // kaydedilir.
  DateTime _gosterilenAy = DateTime(DateTime.now().year, DateTime.now().month);
  // Son yüklenen/kaydedilen form içeriği; kaydedilmemiş değişikliği
  // anlamak için şimdiki içerikle karşılaştırılır.
  String _kayitliImza = '';

  // --- Sesle yazma ---
  final SpeechToText _ses = SpeechToText();
  bool _sesHazir = false;
  TextEditingController? _dinlenen; // şu an sesle doldurulan kutu
  String _dinlemeOncesi = ''; // dinleme başlamadan önce kutudaki metin
  final kalipciController = TextEditingController();
  final demirciController = TextEditingController();
  final digerController = TextEditingController();
  final kalipciIsController = TextEditingController();
  final demirciIsController = TextEditingController();
  final notlarController = TextEditingController();
  final betonController = TextEditingController();
  List<String> fotograflar = [];

  // --- Yemek State Değişkenleri ---
  final yemekKalipciController = TextEditingController();
  final yemekDemirciController = TextEditingController();
  final yemekDigerController = TextEditingController();
  bool isYemekKalipciManuel = false;
  bool isYemekDemirciManuel = false;
  bool isYemekDigerManuel = false;

  // --- Vinç State Değişkenleri ---
  final List<VincFormControllers> _vincFormList = [];

  // --- Yevmiye State Değişkenleri ---
  final List<YevmiyeFormControllers> _yevmiyeFormList = [];

  // --- Puantaj State Değişkenleri ---
  late TabController _tabController;
  late DateTime puantajBaslangicTarihi;
  late DateTime puantajBitisTarihi;
  String tarihFiltreSecenegi =
      'proje_baslangic'; // 'ay', 'ozel' veya 'proje_baslangic' (Tümü)
  DateTime? _puantajAyi; // tarihFiltreSecenegi == 'ay' iken seçili ay
  int _puantajSekmesi = 0; // 0 İşçiler, 1 Vinç, 2 Yevmiye
  // Özel tarih aralığında seçilen ama henüz "Göster"e basılmamış tarihler.
  late DateTime _ozelBaslangic;
  late DateTime _ozelBitis;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.baslangicSekmesi);

    // Puantaj varsayılan tarihleri
    puantajBaslangicTarihi = widget.proje.baslangicTarihi;
    puantajBitisTarihi = DateTime.now();
    _ozelBaslangic = puantajBaslangicTarihi;
    _ozelBitis = puantajBitisTarihi;

    _yukleKayit();
  }

  @override
  void dispose() {
    if (_sesHazir) _ses.cancel(); // hiç kullanılmadıysa eklentiye dokunma
    _tabController.dispose();
    kalipciController.dispose();
    demirciController.dispose();
    digerController.dispose();
    kalipciIsController.dispose();
    demirciIsController.dispose();
    notlarController.dispose();
    betonController.dispose();
    yemekKalipciController.dispose();
    yemekDemirciController.dispose();
    yemekDigerController.dispose();
    for (var ctrl in _vincFormList) {
      ctrl.dispose();
    }
    for (var ctrl in _yevmiyeFormList) {
      ctrl.dispose();
    }
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
    
    isYemekKalipciManuel = false;
    isYemekDemirciManuel = false;
    isYemekDigerManuel = false;
    yemekKalipciController.text = kayit.yemekKalipci.toString();
    yemekDemirciController.text = kayit.yemekDemirci.toString();
    yemekDigerController.text = kayit.yemekDiger.toString();
    kalipciIsController.text = kayit.kalipciYapilanIs;
    demirciIsController.text = kayit.demirciYapilanIs;
    notlarController.text = kayit.notlar;
    betonController.text = kayit.beton;
    fotograflar = List.from(kayit.fotografYollari);

    // Vinç listesini temizle ve yükle
    for (var ctrl in _vincFormList) {
      ctrl.dispose();
    }
    _vincFormList.clear();

    if (kayit.vincler.isNotEmpty) {
      for (var v in kayit.vincler) {
        _vincFormList.add(VincFormControllers(
          firma: v.firmaAdi,
          baslangic: v.baslangic,
          bitis: v.bitis,
          mola: v.mola > 0 ? v.mola.toString() : '',
          aciklama: v.aciklama,
        ));
      }
    } else {
      _vincFormList.add(VincFormControllers());
    }

    // Yevmiye listesini temizle ve yükle
    for (var ctrl in _yevmiyeFormList) {
      ctrl.dispose();
    }
    _yevmiyeFormList.clear();

    if (kayit.yevmiyeler.isNotEmpty) {
      for (var y in kayit.yevmiyeler) {
        _yevmiyeFormList.add(YevmiyeFormControllers(
          ekip: y.ekipAdi.isNotEmpty ? y.ekipAdi : null,
          miktar: y.miktar > 0 ? y.miktar.toString() : '',
          aciklama: y.aciklama,
        ));
      }
    } else {
      _yevmiyeFormList.add(YevmiyeFormControllers());
    }

    _kayitliImza = _formImzasi();
    if (mounted) setState(() {});
  }

  /// Formun o anki içeriğinin karşılaştırılabilir metin hali.
  String _formImzasi() => jsonEncode([
        kalipciController.text, demirciController.text, digerController.text,
        yemekKalipciController.text, yemekDemirciController.text, yemekDigerController.text,
        kalipciIsController.text, demirciIsController.text,
        notlarController.text, betonController.text,
        fotograflar,
        _vincFormList
            .map((v) => [v.firmaAdiController.text, v.baslangicController.text,
                         v.bitisController.text, v.molaController.text,
                         v.aciklamaController.text])
            .toList(),
        _yevmiyeFormList
            .map((y) => [y.secilenEkipAdi ?? '', y.miktarController.text,
                         y.aciklamaController.text])
            .toList(),
      ]);

  bool get _kaydedilmemisDegisiklikVar => _formImzasi() != _kayitliImza;

  /// Formda kaydedilmemiş değişiklik varsa kullanıcıya sorar.
  /// true dönerse işleme (gün değiştirme, sayfadan çıkma) devam edilebilir.
  Future<bool> _degisiklikleriOnayla() async {
    if (!_kaydedilmemisDegisiklikVar) return true;
    final secim = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydedilmemiş değişiklik var'),
        content: Text(
          '${DateFormat('dd.MM.yyyy').format(secilenTarih)} tarihli formda '
          'kaydetmediğin bilgiler var. Ne yapalım?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'vazgec'), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'at'),
            child: const Text('Kaydetmeden geç', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'kaydet'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (secim == 'at') return true;
    if (secim == 'kaydet') return await _kaydet();
    return false;
  }

  Future<void> _tarihDegistir(DateTime yeniTarih) async {
    final ayniGun = yeniTarih.year == secilenTarih.year &&
        yeniTarih.month == secilenTarih.month &&
        yeniTarih.day == secilenTarih.day;
    if (!ayniGun && !await _degisiklikleriOnayla()) return;
    if (!mounted) return;
    setState(() {
      secilenTarih = yeniTarih;
      _gosterilenAy = DateTime(yeniTarih.year, yeniTarih.month);
      if (!ayniGun) _yukleKayit();
    });
    // Veri Girişi sekmesine geç (index 1)
    _tabController.animateTo(1);
  }

  void _ayDegistir(DateTime yeniTarih) {
    // Yalnızca takvimin gösterdiği ay değişir; formdaki gün aynı kalır.
    setState(() {
      _gosterilenAy = DateTime(yeniTarih.year, yeniTarih.month);
    });
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
              title: Text('Kamera', style: TextStyle(color: ThemeColors.textPrimary(context))),
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
              title: Text('Galeri', style: TextStyle(color: ThemeColors.textPrimary(context))),
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

  /// Mikrofon düğmesi: kutuya sesle yazar. Kutuda metin varsa sonuna ekler.
  /// Aynı düğmeye tekrar basmak ya da birkaç saniye susmak dinlemeyi bitirir.
  Future<void> _sesleYaz(TextEditingController controller) async {
    if (_dinlenen != null) {
      final ayniKutu = identical(_dinlenen, controller);
      await _ses.stop();
      if (mounted) setState(() => _dinlenen = null);
      if (ayniKutu) return;
    }
    if (!_sesHazir) {
      try {
        _sesHazir = await _ses.initialize(
          onStatus: (durum) {
            if ((durum == 'done' || durum == 'notListening') && mounted && _dinlenen != null) {
              setState(() => _dinlenen = null);
            }
          },
          onError: (hata) {
            appLog('Sesle yazma hatası: ${hata.errorMsg}');
            if (mounted && _dinlenen != null) setState(() => _dinlenen = null);
          },
        );
      } catch (e) {
        appLog('Sesle yazma başlatılamadı: $e');
        _sesHazir = false;
      }
    }
    if (!mounted) return;
    if (!_sesHazir) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesle yazma kullanılamıyor. Mikrofon iznini ve cihazın ses tanıma ayarını kontrol edin.')),
      );
      return;
    }
    _dinlemeOncesi = controller.text.trimRight();
    setState(() => _dinlenen = controller);
    try {
      // Türkçe varsa Türkçe, yoksa cihazın varsayılan dili.
      final diller = await _ses.locales();
      final turkce = diller.where((d) => d.localeId.toLowerCase().startsWith('tr')).toList();
      await _ses.listen(
        // ignore: deprecated_member_use
        localeId: turkce.isNotEmpty ? turkce.first.localeId : null,
        // ignore: deprecated_member_use
        listenFor: const Duration(seconds: 60),
        // ignore: deprecated_member_use
        pauseFor: const Duration(seconds: 4),
        onResult: (sonuc) {
          if (!identical(_dinlenen, controller)) return;
          final soylenen = sonuc.recognizedWords.trim();
          final metin = [_dinlemeOncesi, soylenen].where((x) => x.isNotEmpty).join(' ');
          controller.value = TextEditingValue(
            text: metin,
            selection: TextSelection.collapsed(offset: metin.length),
          );
        },
      );
    } catch (e) {
      appLog('Dinleme başlatılamadı: $e');
      if (mounted) setState(() => _dinlenen = null);
    }
  }

  Future<void> _fotografKaldir(int index) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fotoğraf kaldırılsın mı?'),
        content: const Text('Fotoğraf bu günün kaydından çıkarılır. Kaydet\'e basınca kalıcı olur.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (onay == true && mounted && index < fotograflar.length) {
      setState(() => fotograflar.removeAt(index));
    }
  }

  /// Formu kaydeder. Kayıt yazıldıysa true döner (fotoğraf yüklenemese bile;
  /// yüklenemeyen fotoğraflar cihazdaki yollarıyla kayda girer).
  Future<bool> _kaydet() async {
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
      int hataliYukleme = 0;

      for (String p in fotograflar) {
        if (!ImageService.isNetworkUrl(p)) {
          appLog("LOG: Fotoğraf yükleniyor: $p");
          String? url = await _imageService.uploadImage(p);
          if (url != null) {
            yuklenenYollar.add(url);
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
        yemekKalipci: int.tryParse(yemekKalipciController.text) ?? 0,
        yemekDemirci: int.tryParse(yemekDemirciController.text) ?? 0,
        yemekDiger: int.tryParse(yemekDigerController.text) ?? 0,
        kalipciYapilanIs: kalipciIsController.text,
        demirciYapilanIs: demirciIsController.text,
        notlar: notlarController.text,
        beton: betonController.text,
        fotografYollari: List.from(fotograflar),
        vincler: _vincFormList
            .where((v) =>
                v.firmaAdiController.text.isNotEmpty ||
                v.baslangicController.text.isNotEmpty ||
                v.bitisController.text.isNotEmpty)
            .map((v) => VincBilgisi(
                  firmaAdi: v.firmaAdiController.text,
                  baslangic: v.baslangicController.text,
                  bitis: v.bitisController.text,
                  mola: int.tryParse(v.molaController.text) ?? 0,
                  aciklama: v.aciklamaController.text.trim(),
                ))
            .toList(),
        yevmiyeler: _yevmiyeFormList
            .where((y) => (y.secilenEkipAdi ?? '').isNotEmpty || y.miktarController.text.isNotEmpty)
            .map((y) => YevmiyeBilgisi(
                  ekipAdi: y.secilenEkipAdi ?? '',
                  miktar: double.tryParse(y.miktarController.text) ?? 0.0,
                  aciklama: y.aciklamaController.text,
                ))
            .toList(),
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
      _kayitliImza = _formImzasi();

      if (mounted) {
        Navigator.pop(context); // Bekleme diyaloğunu kapat

        // Yüklenemeyen fotoğraflar cihazda kalır ve kayda cihazdaki yollarıyla
        // girer. Kaydet'e yeniden basmak yalnızca bunları tekrar yüklemeyi dener.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hataliYukleme > 0
                ? 'Kayıt kaydedildi, ama $hataliYukleme fotoğraf buluta yüklenemedi. '
                  'Fotoğraflar bu cihazda duruyor; internet varken tekrar dene.'
                : 'Kayıt kaydedildi'),
            backgroundColor: hataliYukleme > 0 ? Colors.orange.shade800 : Colors.green,
            duration: Duration(seconds: hataliYukleme > 0 ? 8 : 3),
            action: hataliYukleme > 0
                ? SnackBarAction(
                    label: 'TEKRAR DENE',
                    textColor: Colors.white,
                    onPressed: _kaydet,
                  )
                : null,
          ),
        );
      }
      return true;
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
      return false;
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
        backgroundColor: ThemeColors.cardBackground(context),
        title: Text('Excel ve Fotoğraflar', style: TextStyle(color: ThemeColors.textPrimary(context))),
        content: TextField(
          controller: fileNameController,
          style: TextStyle(color: ThemeColors.textPrimary(context)),
          decoration: InputDecoration(
            labelText: 'Dosya Adı (Uzantısız)',
            labelStyle: TextStyle(color: ThemeColors.textSecondary(context)),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: ThemeColors.textTertiary(context))),
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
    String? selectedDirectory = await pkr.FilePicker.platform.getDirectoryPath();

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

      xls.Sheet vincSheet = excel['Vinç'];
      vincSheet.appendRow([
        xls.TextCellValue("Tarih"),
        xls.TextCellValue("Firma Adı"),
        xls.TextCellValue("Başlangıç"),
        xls.TextCellValue("Bitiş"),
        xls.TextCellValue("Mola (dk)"),
        xls.TextCellValue("Net Çalışma (saat)"),
        xls.TextCellValue("Açıklama"),
      ]);

      xls.Sheet yevmiyeSheet = excel['Yevmiye'];
      yevmiyeSheet.appendRow([
        xls.TextCellValue("Tarih"),
        xls.TextCellValue("Ekip Adı"),
        xls.TextCellValue("Yevmiye"),
        xls.TextCellValue("Açıklama"),
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
            appLog("Foto kopyalama hatası: $e");
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
        
        if (kayit.vincler.isNotEmpty) {
          for (var v in kayit.vincler) {
            if (v.firmaAdi.isNotEmpty || v.baslangic.isNotEmpty) {
              final netSaat = _hesaplaVincNetSaat(v.baslangic, v.bitis, v.mola);
              vincSheet.appendRow([
                xls.TextCellValue(tarihStr),
                xls.TextCellValue(v.firmaAdi),
                xls.TextCellValue(v.baslangic),
                xls.TextCellValue(v.bitis),
                xls.IntCellValue(v.mola),
                xls.TextCellValue(netSaat),
                xls.TextCellValue(v.aciklama),
              ]);
            }
          }
        } else if (kayit.vincFirmaAdi.isNotEmpty || kayit.vincBaslangic.isNotEmpty) {
          final netSaat = _hesaplaVincNetSaat(kayit.vincBaslangic, kayit.vincBitis, kayit.vincMola);
          vincSheet.appendRow([
            xls.TextCellValue(tarihStr),
            xls.TextCellValue(kayit.vincFirmaAdi),
            xls.TextCellValue(kayit.vincBaslangic),
            xls.TextCellValue(kayit.vincBitis),
            xls.IntCellValue(kayit.vincMola),
            xls.TextCellValue(netSaat),
          ]);
        }

        // Yevmiye Bilgilerini Ekle
        if (kayit.yevmiyeler.isNotEmpty) {
          for (var y in kayit.yevmiyeler) {
            if (y.ekipAdi.isNotEmpty || y.miktar > 0) {
              yevmiyeSheet.appendRow([
                xls.TextCellValue(tarihStr),
                xls.TextCellValue(y.ekipAdi),
                xls.DoubleCellValue(y.miktar),
                xls.TextCellValue(y.aciklama),
              ]);
            }
          }
        } else if (kayit.yevmiyeEkipAdi.isNotEmpty || kayit.yevmiyeMiktari > 0) {
          yevmiyeSheet.appendRow([
            xls.TextCellValue(tarihStr),
            xls.TextCellValue(kayit.yevmiyeEkipAdi),
            xls.DoubleCellValue(kayit.yevmiyeMiktari),
            xls.TextCellValue(kayit.yevmiyeAciklama),
          ]);
        }
        
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
        backgroundColor: ThemeColors.cardBackground(context),
        title: Text('Tüm Bilgileri Aktar', style: TextStyle(color: ThemeColors.textPrimary(context))),
        content: TextField(
          controller: fileNameController,
          style: TextStyle(color: ThemeColors.textPrimary(context)),
          decoration: InputDecoration(
            labelText: 'Dosya Adı (Uzantısız)',
            labelStyle: TextStyle(color: ThemeColors.textSecondary(context)),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: ThemeColors.textTertiary(context))),
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
    String? selectedDirectory = await pkr.FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    // Tüm bilgileri içeren CSV oluştur
    String csvData = "\uFEFFPROJE BİLGİLERİ\n";
    csvData += "Proje Adı;${widget.proje.ad}\n";
    csvData += "Başlangıç Tarihi;${widget.proje.baslangicTarihi.day}.${widget.proje.baslangicTarihi.month}.${widget.proje.baslangicTarihi.year}\n";
    csvData += "Toplam Gün;${widget.proje.toplamGun}\n";
    csvData += "Durum;${widget.proje.durum}\n";
    csvData += "Açıklama;${widget.proje.aciklama}\n\n";

    
    csvData += "GÜNLÜK KAYITLAR\n";
    csvData += "Tarih;Kalıpçı;Demirci;Diğer;Toplam;Kalıpçı İş;Demirci İş;Notlar;Beton;Fotoğraf Sayısı;Vinç Firma;Vinç Başlangıç;Vinç Bitiş;Vinç Mola\n";

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
      csvData += "${kayit.fotografYollari.length};";
      final vFirma = kayit.vincler.isNotEmpty ? kayit.vincler.map((v) => v.firmaAdi).join(', ') : kayit.vincFirmaAdi;
      final vBaslangic = kayit.vincler.isNotEmpty ? kayit.vincler.map((v) => v.baslangic).join(', ') : kayit.vincBaslangic;
      final vBitis = kayit.vincler.isNotEmpty ? kayit.vincler.map((v) => v.bitis).join(', ') : kayit.vincBitis;
      final vMola = kayit.vincler.isNotEmpty ? kayit.vincler.map((v) => v.mola.toString()).join(', ') : kayit.vincMola.toString();

      csvData += "${vFirma.replaceAll(';', ',')};";
      csvData += "$vBaslangic;";
      csvData += "$vBitis;";
      csvData += "$vMola\n";
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
            backgroundColor: ThemeColors.cardBackground(context),
            title: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange),
                SizedBox(width: 10),
                Text('WiFi Bağlantısı Yok', style: TextStyle(color: ThemeColors.textPrimary(context))),
              ],
            ),
            content: Text(
              'WiFi bağlantısı bulunamadı. Fotoğraf aktarımı mobil veri kullanabilir ve yüksek miktarda veri harcayabilir.\n\nDevam etmek istiyor musunuz?',
              style: TextStyle(color: ThemeColors.textSecondary(context)),
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
    String? selectedDirectory = await pkr.FilePicker.platform.getDirectoryPath();
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
          appLog("LOG: Aktarma basliyor: $kaynak");
          if (ImageService.isNetworkUrl(kaynak)) {
            appLog("LOG: Network URL tespit edildi, indiriliyor...");
            // URL ise indir
            final bytes = await _imageService.downloadImage(kaynak);
            if (bytes != null) {
              appLog("LOG: Indirme basarili, yaziliyor: $hedefYol");
              await File(hedefYol).writeAsBytes(bytes);
              basarili++;
            } else {
              appLog("LOG: Indirme basarisiz: $kaynak");
              hatali++;
            }
          } else {
            appLog("LOG: Yerel dosya tespit edildi: $kaynak");
            // Yerel dosya ise kopyala
            final kaynakDosya = File(kaynak);
            if (await kaynakDosya.exists()) {
              await kaynakDosya.copy(hedefYol);
              basarili++;
            } else {
              appLog("LOG: Yerel dosya bulunamadi (Muhtemelen mobil yolu): $kaynak");
              // Windows'ta olup mobildeki yerel yolu kopyalamaya çalışıyorsa burada durur
              hatali++;
            }
          }
        } catch (e) {
          appLog("LOG: Aktarma hatası ($yeniAd): $e");
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
              title: Text('Puantaj ve Fotoğraflar (Excel)', style: TextStyle(color: ThemeColors.textPrimary(context))),
              subtitle: Text('Excel tablosu ve fotoğraf klasörü', style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _excelVeFotograflariAktar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: Text('Tüm Proje Bilgileri', style: TextStyle(color: ThemeColors.textPrimary(context))),
              subtitle: Text('Proje detayları ve tüm günlük kayıtlar', style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _tumBilgileriAktar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.orange),
              title: Text('Sadece Fotoğraflar', style: TextStyle(color: ThemeColors.textPrimary(context))),
              subtitle: Text('Tarihli dosya isimleriyle', style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12)),
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
    // Geri tuşu/okuyla çıkarken kaydedilmemiş form varsa sorulur.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _degisiklikleriOnayla() && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: _buildSayfa(context),
    );
  }

  Widget _buildSayfa(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Önceki gün',
                  icon: const Icon(Icons.chevron_left, color: Colors.blue, size: 30),
                  onPressed: () => _tarihDegistir(DateTime(
                      secilenTarih.year, secilenTarih.month, secilenTarih.day - 1)),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final secilen = await showDatePicker(
                        context: context,
                        initialDate: secilenTarih,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (secilen != null) _tarihDegistir(secilen);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Text(
                            '${secilenTarih.day} ${aylar[secilenTarih.month - 1]} ${secilenTarih.year}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            const ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'][secilenTarih.weekday - 1],
                            style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Sonraki gün',
                  icon: const Icon(Icons.chevron_right, color: Colors.blue, size: 30),
                  onPressed: () => _tarihDegistir(DateTime(
                      secilenTarih.year, secilenTarih.month, secilenTarih.day + 1)),
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
                  _buildMobileInputItem("Kalıpçı Yapılan İş", kalipciIsController, sesli: true),
                  const SizedBox(height: 8),
                  _buildMobileInputItem("Demirci Yapılan İş", demirciIsController, sesli: true),
                  const SizedBox(height: 8),
                  _buildMobileInputItem("Notlar", notlarController, maxLines: 2, sesli: true),
                  const SizedBox(height: 8),
                  _buildMobileInputItem("Beton", betonController, sesli: true),
                  const SizedBox(height: 15),
                  // Vinç Bilgileri
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.construction, color: Colors.orange, size: 18),
                            const SizedBox(width: 6),
                            Text('Vinç Bilgileri', style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            )),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.orange, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _vincFormList.add(VincFormControllers());
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            if (_vincFormList.any((v) =>
                                v.firmaAdiController.text.isNotEmpty ||
                                v.baslangicController.text.isNotEmpty ||
                                v.bitisController.text.isNotEmpty ||
                                v.molaController.text.isNotEmpty))
                              GestureDetector(
                                onTap: () async {
                                  final onay = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: ThemeColors.cardBackground(context),
                                      title: Text('Vinç Bilgilerini Sil', style: TextStyle(color: ThemeColors.textPrimary(context))),
                                      content: Text('Bu gün için girilen tüm vinç bilgileri silinecek. Onaylıyor musunuz?', style: TextStyle(color: ThemeColors.textSecondary(context))),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('İptal'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Sil', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (onay == true) {
                                    setState(() {
                                      for (var ctrl in _vincFormList) {
                                        ctrl.dispose();
                                      }
                                      _vincFormList.clear();
                                      _vincFormList.add(VincFormControllers());
                                    });
                                  }
                                },
                                child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._vincFormList.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final ctrl = entry.value;
                          return Column(
                            key: ValueKey(ctrl),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (idx > 0) ...[
                                const SizedBox(height: 10),
                                Divider(color: Colors.orange.withOpacity(0.3)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${idx + 1}. Vinç', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          ctrl.dispose();
                                          _vincFormList.removeAt(idx);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                              _buildMobileInputItem("Firma Adı", ctrl.firmaAdiController),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: ctrl.baslangicController.text.isNotEmpty
                                            ? TimeOfDay(
                                                hour: int.parse(ctrl.baslangicController.text.split(':')[0]),
                                                minute: int.parse(ctrl.baslangicController.text.split(':')[1]),
                                              )
                                            : const TimeOfDay(hour: 8, minute: 0),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          ctrl.baslangicController.text =
                                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                        });
                                      }
                                    },
                                    child: AbsorbPointer(
                                      child: _buildMobileInputItem("Başlangıç", ctrl.baslangicController),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: ctrl.bitisController.text.isNotEmpty
                                            ? TimeOfDay(
                                                hour: int.parse(ctrl.bitisController.text.split(':')[0]),
                                                minute: int.parse(ctrl.bitisController.text.split(':')[1]),
                                              )
                                            : const TimeOfDay(hour: 18, minute: 0),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          ctrl.bitisController.text =
                                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                        });
                                      }
                                    },
                                    child: AbsorbPointer(
                                      child: _buildMobileInputItem("Bitiş", ctrl.bitisController),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMobileInputItem("Mola (dk)", ctrl.molaController, isNumeric: true),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              _buildMobileInputItem("Açıklama", ctrl.aciklamaController, sesli: true),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Yevmiye Bilgileri
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payments, color: Colors.purple, size: 18),
                            const SizedBox(width: 6),
                            Text('Yevmiye Bilgileri', style: TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            )),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.purple, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _yevmiyeFormList.add(YevmiyeFormControllers());
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            if (_yevmiyeFormList.any((y) =>
                                (y.secilenEkipAdi ?? '').isNotEmpty ||
                                y.miktarController.text.isNotEmpty ||
                                y.aciklamaController.text.isNotEmpty))
                              GestureDetector(
                                onTap: () async {
                                  final onay = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: ThemeColors.cardBackground(context),
                                      title: Text('Yevmiye Bilgilerini Sil', style: TextStyle(color: ThemeColors.textPrimary(context))),
                                      content: Text('Bu gün için girilen yevmiye bilgileri silinecek. Onaylıyor musunuz?', style: TextStyle(color: ThemeColors.textSecondary(context))),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('İptal'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Sil', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (onay == true) {
                                    setState(() {
                                      for (var ctrl in _yevmiyeFormList) {
                                        ctrl.dispose();
                                      }
                                      _yevmiyeFormList.clear();
                                      _yevmiyeFormList.add(YevmiyeFormControllers());
                                    });
                                  }
                                },
                                child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._yevmiyeFormList.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final ctrl = entry.value;
                          return Column(
                            key: ValueKey(ctrl),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (idx > 0) ...[
                                const SizedBox(height: 10),
                                Divider(color: Colors.purple.withOpacity(0.3)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${idx + 1}. Yevmiye', style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          ctrl.dispose();
                                          _yevmiyeFormList.removeAt(idx);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                              Row(children: [
                                Expanded(child: _buildEkipDropdownForIndex(ctrl)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildMobileInputItem("Yevmiye", ctrl.miktarController, isNumeric: true)),
                              ]),
                              const SizedBox(height: 8),
                              _buildMobileInputItem("Açıklama", ctrl.aciklamaController, sesli: true),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Yemek Kartı Eklentisi
                  Card(
                    color: ThemeColors.cardBackground(context),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.restaurant, color: Colors.orangeAccent, size: 20),
                              const SizedBox(width: 8),
                              Text('Yemek Sayıları', style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMobileInputItem("Kalıpçı Y.", yemekKalipciController, isNumeric: true, onChanged: (val) {
                                  isYemekKalipciManuel = true;
                                }),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMobileInputItem("Demirci Y.", yemekDemirciController, isNumeric: true, onChanged: (val) {
                                  isYemekDemirciManuel = true;
                                }),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMobileInputItem("Diğer Y.", yemekDigerController, isNumeric: true, onChanged: (val) {
                                  isYemekDigerManuel = true;
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _fotografEkle,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Fotoğraf Ekle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.lightBlueAccent,
                            side: const BorderSide(color: Colors.lightBlueAccent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                               'tarih': secilenTarih,
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
                         if (!ImageService.isNetworkUrl(fotograflar[index]))
                           const Positioned(
                             left: 4,
                             bottom: 4,
                             child: Tooltip(
                               message: 'Buluta yüklenmedi',
                               child: CircleAvatar(
                                 radius: 11,
                                 backgroundColor: Colors.black87,
                                 child: Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 14),
                               ),
                             ),
                           ),
                         Positioned(
                           top: 0,
                           right: 0,
                           child: Material(
                             color: Colors.transparent,
                             child: InkWell(
                               customBorder: const CircleBorder(),
                               onTap: () => _fotografKaldir(index),
                               child: Padding(
                                 padding: const EdgeInsets.all(3),
                                 child: Container(
                                   padding: const EdgeInsets.all(4),
                                   decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                   child: const Icon(Icons.close, color: Colors.white, size: 16),
                                 ),
                               ),
                             ),
                           ),
                         ),
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
                  _buildSureGostergesi(genislik: 90),
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
          const SizedBox(height: 10),
          _buildOzetPaneli(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- Genel sekmesi özet parçaları ---

  /// Takvim süresi: geçen gün / toplam gün. Süre aşıldıysa kırmızı.
  Widget _buildSureGostergesi({double genislik = 90}) {
    final proje = widget.proje;
    final oran = proje.toplamGun > 0
        ? (proje.gecenGun / proje.toplamGun).clamp(0.0, 1.0)
        : 0.0;
    final renk = proje.sureAsildi ? Colors.redAccent : Colors.blue;
    return Tooltip(
      message: 'Başlangıçtan bu yana geçen gün / planlanan toplam gün',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            proje.sureMetni,
            style: TextStyle(color: proje.sureAsildi ? Colors.redAccent : ThemeColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: genislik,
            child: LinearProgressIndicator(
              value: oran,
              minHeight: 5,
              backgroundColor: ThemeColors.border(context),
              color: renk,
            ),
          ),
        ],
      ),
    );
  }

  /// Takvimde gösterilen ayın özeti, son kayıtlar ve son fotoğraflar.
  Widget _buildOzetPaneli() {
    const aylar = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final ayKayitlari = widget.gunlukKayitlar
        .where((k) => k.tarih.year == _gosterilenAy.year && k.tarih.month == _gosterilenAy.month)
        .toList();
    final ozet = _PuantajOzeti.hesapla(ayKayitlari, _vincSatirlari, _yevmiyeSatirlari, _hesaplaVincNetSaat);

    final sirali = List<GunlukKayit>.from(widget.gunlukKayitlar)
      ..sort((a, b) => b.tarih.compareTo(a.tarih));
    final sonKayitlar = sirali.take(5).toList();
    final sonFotograflar = <Map<String, dynamic>>[];
    for (final k in sirali) {
      for (final yol in k.fotografYollari) {
        if (yol.trim().isNotEmpty) sonFotograflar.add({'tarih': k.tarih, 'yol': yol});
      }
      if (sonFotograflar.length >= 12) break;
    }

    final baslikStili = TextStyle(color: ThemeColors.textPrimary(context), fontSize: 15, fontWeight: FontWeight.bold);

    return Card(
      color: ThemeColors.cardBackground(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${aylar[_gosterilenAy.month - 1]} ${_gosterilenAy.year} özeti', style: baslikStili),
            const SizedBox(height: 10),
            if (ayKayitlari.isEmpty)
              Text('Bu ay kayıt yok.', style: TextStyle(color: ThemeColors.textSecondary(context)))
            else
              _buildOzetIzgarasi(ozet),
            const SizedBox(height: 16),
            Text('Son kayıtlar', style: baslikStili),
            const SizedBox(height: 6),
            if (sonKayitlar.isEmpty)
              Text('Henüz kayıt yok.', style: TextStyle(color: ThemeColors.textSecondary(context)))
            else
              ...sonKayitlar.map(_buildSonKayitSatiri),
            if (sonFotograflar.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('Son fotoğraflar', style: baslikStili)),
                  TextButton(onPressed: _galeriGoster, child: const Text('Tümü')),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sonFotograflar.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) => InkWell(
                    onTap: () => _fotografBuyut(context, sonFotograflar, i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: ImageService.buildImage(sonFotograflar[i]['yol'], width: 72, height: 72),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSonKayitSatiri(GunlukKayit k) {
    final ozetMetin = [
      if (k.kalipciYapilanIs.trim().isNotEmpty) k.kalipciYapilanIs.trim(),
      if (k.demirciYapilanIs.trim().isNotEmpty) k.demirciYapilanIs.trim(),
      if (k.notlar.trim().isNotEmpty) k.notlar.trim(),
    ].join(' · ');
    final ekip = [
      if (k.kalipci > 0) '${k.kalipci} kalıpçı',
      if (k.demirci > 0) '${k.demirci} demirci',
      if (k.diger > 0) '${k.diger} diğer',
    ].join(', ');
    return InkWell(
      onTap: () => _tarihDegistir(k.tarih),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 50,
              child: Text(DateFormat('dd.MM').format(k.tarih),
                  style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ekip.isNotEmpty)
                    Text(ekip, style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 13)),
                  if (ozetMetin.isNotEmpty)
                    Text(ozetMetin,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13)),
                ],
              ),
            ),
            if (k.fotografYollari.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo, size: 14, color: ThemeColors.textTertiary(context)),
                    Text(' ${k.fotografYollari.length}', style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Kayıtlardaki vinç satırları (eski tek-vinç alanları dahil).
  List<Map<String, dynamic>> _vincSatirlari(Iterable<GunlukKayit> kayitlar) {
    final satirlar = <Map<String, dynamic>>[];
    for (var kayit in kayitlar) {
      if (kayit.vincler.isNotEmpty) {
        for (var v in kayit.vincler) {
          if (v.firmaAdi.isNotEmpty || v.baslangic.isNotEmpty) {
            satirlar.add({
              'tarih': kayit.tarih,
              'firmaAdi': v.firmaAdi,
              'baslangic': v.baslangic,
              'bitis': v.bitis,
              'mola': v.mola,
              'aciklama': v.aciklama,
            });
          }
        }
      } else if (kayit.vincFirmaAdi.isNotEmpty || kayit.vincBaslangic.isNotEmpty) {
        satirlar.add({
          'tarih': kayit.tarih,
          'firmaAdi': kayit.vincFirmaAdi,
          'baslangic': kayit.vincBaslangic,
          'bitis': kayit.vincBitis,
          'mola': kayit.vincMola,
          'aciklama': '',
        });
      }
    }
    return satirlar;
  }

  /// Kayıtlardaki yevmiye satırları (eski tek-yevmiye alanları dahil).
  List<Map<String, dynamic>> _yevmiyeSatirlari(Iterable<GunlukKayit> kayitlar) {
    final satirlar = <Map<String, dynamic>>[];
    for (var kayit in kayitlar) {
      if (kayit.yevmiyeler.isNotEmpty) {
        for (var y in kayit.yevmiyeler) {
          if (y.ekipAdi.isNotEmpty || y.miktar > 0) {
            satirlar.add({
              'tarih': kayit.tarih,
              'ekipAdi': y.ekipAdi,
              'miktar': y.miktar,
              'aciklama': y.aciklama,
            });
          }
        }
      } else if (kayit.yevmiyeEkipAdi.isNotEmpty || kayit.yevmiyeMiktari > 0) {
        satirlar.add({
          'tarih': kayit.tarih,
          'ekipAdi': kayit.yevmiyeEkipAdi,
          'miktar': kayit.yevmiyeMiktari,
          'aciklama': kayit.yevmiyeAciklama,
        });
      }
    }
    return satirlar;
  }

  /// [sesli]: kutunun sağına mikrofon düğmesi koyar ve uzun metin satırlara
  /// sarılır (sesle yazılan cümleler tek satıra sığmaz).
  Widget _buildMobileInputItem(String label, TextEditingController controller, {int maxLines = 1, bool isNumeric = false, bool sesli = false, Function(String)? onChanged}) {
    final dinliyor = sesli && identical(_dinlenen, controller);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(color: ThemeColors.textPrimary(context)),
          minLines: sesli ? maxLines : null,
          maxLines: sesli ? 5 : maxLines,
          keyboardType: isNumeric ? TextInputType.number : (sesli ? TextInputType.multiline : TextInputType.text),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            filled: true,
            fillColor: dinliyor ? Colors.red.withOpacity(0.12) : Colors.black12,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            hintText: dinliyor ? 'Dinliyorum, konuşun...' : null,
            hintStyle: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 13),
            suffixIcon: sesli
                ? IconButton(
                    tooltip: dinliyor ? 'Dinlemeyi bitir' : 'Sesle yaz',
                    icon: Icon(
                      dinliyor ? Icons.stop_circle : Icons.mic,
                      color: dinliyor ? Colors.redAccent : Colors.orange,
                    ),
                    onPressed: () => _sesleYaz(controller),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildEkipDropdownForIndex(YevmiyeFormControllers ctrl) {
    final ekipAdlari = List<String>.from(widget.ekipler)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    
    // Eğer seçilen ekip adı listede yoksa null yap (eski kayıtlar için)
    if (ctrl.secilenEkipAdi != null && !ekipAdlari.contains(ctrl.secilenEkipAdi)) {
      if (ctrl.secilenEkipAdi!.isNotEmpty) {
        ekipAdlari.insert(0, ctrl.secilenEkipAdi!);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Ekip Adı", style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: ctrl.secilenEkipAdi,
              isExpanded: true,
              hint: Text(
                ekipAdlari.isEmpty ? 'Henüz ekip yok' : 'Ekip seçin...',
                style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 14),
              ),
              dropdownColor: ThemeColors.cardBackground(context),
              style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 14),
              icon: Icon(Icons.arrow_drop_down, color: ThemeColors.textSecondary(context)),
              isDense: true,
              items: ekipAdlari.map((ekip) => DropdownMenuItem<String>(
                value: ekip,
                child: Text(ekip),
              )).toList(),
              onChanged: ekipAdlari.isEmpty ? null : (val) {
                setState(() {
                  ctrl.secilenEkipAdi = val;
                });
              },
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildDesktopGenelBakis() {
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ThemeColors.cardBackground(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildSureGostergesi(genislik: 130),
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
          // Takvim (solda) ve ay özeti (sağda)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
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
                const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(child: _buildOzetPaneli()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _puantajFiltresiSec(String secenek, {DateTime? ay}) {
    final simdi = DateTime.now();
    setState(() {
      tarihFiltreSecenegi = secenek;
      switch (secenek) {
        case 'ay':
          _puantajAyi = ay;
          puantajBaslangicTarihi = DateTime(ay!.year, ay.month, 1);
          puantajBitisTarihi = DateTime(ay.year, ay.month + 1, 0);
        case 'proje_baslangic':
          puantajBaslangicTarihi = widget.proje.baslangicTarihi;
          puantajBitisTarihi = simdi;
        case 'ozel':
          // Tablo, kullanıcı tarihleri seçip "Göster"e basana kadar değişmez.
          _ozelBaslangic = puantajBaslangicTarihi;
          _ozelBitis = puantajBitisTarihi;
      }
    });
  }

  void _ozelAraligiGoster() {
    if (_ozelBitis.isBefore(_ozelBaslangic)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitiş tarihi başlangıçtan önce olamaz.')),
      );
      return;
    }
    setState(() {
      puantajBaslangicTarihi = _ozelBaslangic;
      puantajBitisTarihi = _ozelBitis;
    });
  }

  /// Ay seçimi: dokununca proje başlangıcından (ya da ilk kayıttan) bu aya
  /// kadar aylar listelenir. Diğer seçeneklerle aynı görünümde bir düğme.
  Widget _buildAySecici() {
    const aylar = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final simdi = DateTime.now();
    var ilk = DateTime(widget.proje.baslangicTarihi.year, widget.proje.baslangicTarihi.month);
    for (final k in widget.gunlukKayitlar) {
      final ay = DateTime(k.tarih.year, k.tarih.month);
      if (ay.isBefore(ilk)) ilk = ay;
    }
    final secenekler = <DateTime>[];
    for (var ay = DateTime(simdi.year, simdi.month);
        !ay.isBefore(ilk);
        ay = DateTime(ay.year, ay.month - 1)) {
      secenekler.add(ay);
    }
    final secili = tarihFiltreSecenegi == 'ay' && _puantajAyi != null;
    final yaziRengi = secili ? Colors.black87 : ThemeColors.textPrimary(context);
    return PopupMenuButton<DateTime>(
      tooltip: 'Ay seç',
      color: ThemeColors.cardBackground(context),
      onSelected: (ay) => _puantajFiltresiSec('ay', ay: ay),
      itemBuilder: (_) => [
        for (final ay in secenekler)
          PopupMenuItem(
            value: ay,
            child: Text('${aylar[ay.month - 1]} ${ay.year}',
                style: TextStyle(color: ThemeColors.textPrimary(context))),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: secili ? Colors.cyan : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: secili ? Colors.cyan : ThemeColors.textTertiary(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 18, color: yaziRengi),
            const SizedBox(width: 6),
            Text(
              secili ? '${aylar[_puantajAyi!.month - 1]} ${_puantajAyi!.year}' : 'Ay seç',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: yaziRengi, fontWeight: FontWeight.w600),
            ),
            Icon(Icons.arrow_drop_down, color: yaziRengi),
          ],
        ),
      ),
    );
  }

  /// Toplamlar: sade kutular, büyük beyaz sayı ve altında gri açıklama.
  Widget _buildOzetIzgarasi(_PuantajOzeti ozet, {bool fotografGoster = true}) {
    final kutular = <List<Object>>[
      [Icons.event_available, '${ozet.kayitGunu}', 'kayıtlı gün'],
      [Icons.construction, '${ozet.kalipci}', 'kalıpçı (adam-gün)'],
      [Icons.hardware, '${ozet.demirci}', 'demirci (adam-gün)'],
      if (ozet.diger > 0) [Icons.groups, '${ozet.diger}', 'diğer (adam-gün)'],
      [Icons.functions, '${ozet.toplamAdamGun}', 'toplam adam-gün'],
      [Icons.precision_manufacturing, _PuantajOzeti.sayi(ozet.vincSaat), 'vinç saati', if (ozet.vincGun > 0) '(${ozet.vincGun} gün)'],
      [Icons.payments, _PuantajOzeti.sayi(ozet.yevmiye), 'yevmiye'],
      if (fotografGoster) [Icons.photo_camera, '${ozet.fotograf}', 'fotoğraf'],
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const bosluk = 6.0;
        final sutun = constraints.maxWidth < 500 ? 3 : 4;
        final genislik = (constraints.maxWidth - bosluk * (sutun - 1)) / sutun;
        return Wrap(
          spacing: bosluk,
          runSpacing: bosluk,
          children: [
            for (final k in kutular)
              Container(
                width: genislik,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: ThemeColors.isDark(context) ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dar kutuda "235.2 (40 gün)" taşmasın diye gerekirse küçülür.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Icon(k[0] as IconData, size: 16, color: ThemeColors.textTertiary(context)),
                          const SizedBox(width: 6),
                          Text(k[1] as String,
                              style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
                          if (k.length > 3) ...[
                            const SizedBox(width: 4),
                            Text(k[3] as String,
                                style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(k[2] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // --- Yardımcı Metod ---
  String _hesaplaVincNetSaat(String baslangic, String bitis, int molaDakika) {
    if (baslangic.isEmpty || bitis.isEmpty) return "0.0";
    try {
      final bParts = baslangic.split(':');
      final btParts = bitis.split(':');
      final bSaat = int.parse(bParts[0]);
      final bDakika = int.parse(bParts[1]);
      final btSaat = int.parse(btParts[0]);
      final btDakika = int.parse(btParts[1]);

      final bToplamDk = bSaat * 60 + bDakika;
      final btToplamDk = btSaat * 60 + btDakika;

      int farkDk = btToplamDk - bToplamDk;
      if (farkDk < 0) farkDk += 24 * 60; // Ertesi güne sarkma

      final netDk = farkDk - molaDakika;
      if (netDk <= 0) return "0.0";

      return (netDk / 60.0).toStringAsFixed(1);
    } catch (e) {
      return "0.0";
    }
  }

  // --- 2. SEKME: PUANTAJ VE TABLO ---
  Widget _buildPuantajTab() {
    final kayitlar = _getPuantajKayitlari();
    final ozet = _PuantajOzeti.hesapla(kayitlar, _vincSatirlari, _yevmiyeSatirlari, _hesaplaVincNetSaat);
    final tarihBicimi = DateFormat('dd.MM.yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtre: ay seçimi, Tümü, Özel tarih aralığı
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: ThemeColors.cardBackground(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildAySecici(),
                          ChoiceChip(
                            label: const Text('Özel tarih'),
                            selected: tarihFiltreSecenegi == 'ozel',
                            onSelected: (_) => _puantajFiltresiSec('ozel'),
                            visualDensity: VisualDensity.compact,
                          ),
                          ChoiceChip(
                            label: const Text('Tümü'),
                            selected: tarihFiltreSecenegi == 'proje_baslangic',
                            onSelected: (_) => _puantajFiltresiSec('proje_baslangic'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _aktarmaMenusuGoster,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Aktar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (tarihFiltreSecenegi == 'ozel') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(context: context, initialDate: _ozelBaslangic, firstDate: DateTime(2000), lastDate: DateTime(2100), helpText: 'Başlangıç tarihi');
                            if (picked != null) setState(() => _ozelBaslangic = picked);
                          },
                          child: Text(tarihBicimi.format(_ozelBaslangic)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('-', style: TextStyle(color: ThemeColors.textPrimary(context))),
                      ),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(context: context, initialDate: _ozelBitis, firstDate: DateTime(2000), lastDate: DateTime(2100), helpText: 'Bitiş tarihi');
                            if (picked != null) setState(() => _ozelBitis = picked);
                          },
                          child: Text(tarihBicimi.format(_ozelBitis)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _ozelAraligiGoster,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        child: const Text('Göster'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Gösterilen: ${tarihBicimi.format(puantajBaslangicTarihi)} - ${tarihBicimi.format(puantajBitisTarihi)}',
                  style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Seçili aralığın toplamları: tabloların en altına inmeden görünsün
          _buildOzetIzgarasi(ozet, fotografGoster: false),

          const SizedBox(height: 8),
          // Tablo seçimi ve tablo: sayfayla birlikte kayar, ekrana sığar
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('İşçiler'), icon: Icon(Icons.engineering, size: 18)),
                ButtonSegment(value: 1, label: Text('Vinç'), icon: Icon(Icons.precision_manufacturing, size: 18)),
                ButtonSegment(value: 2, label: Text('Yevmiye'), icon: Icon(Icons.payments, size: 18)),
              ],
              selected: {_puantajSekmesi},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _puantajSekmesi = s.first),
            ),
          ),
          const SizedBox(height: 8),
          if (_puantajSekmesi == 0)
            _isciTablosu(kayitlar)
          else if (_puantajSekmesi == 1)
            _vincTablosu(kayitlar)
          else
            _yevmiyeTablosu(kayitlar),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  static const _gunKisa = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  /// Tablo hücresi için tarih: "26.09.26" ve altında gün adı.
  String _tabloTarihi(DateTime t) =>
      '${DateFormat('dd.MM.yy').format(t)}\n${_gunKisa[t.weekday - 1]}';

  String _sifirsiz(num n) => n == 0 ? '–' : _PuantajOzeti.sayi(n.toDouble());

  Widget _isciTablosu(List<GunlukKayit> kayitlar) {
    final ozet = _PuantajOzeti.hesapla(kayitlar, _vincSatirlari, _yevmiyeSatirlari, _hesaplaVincNetSaat);
    return _basitTablo(
      basliklar: const ['Tarih', 'Kalıpçı', 'Demirci', 'Diğer', 'Toplam'],
      flexler: const [3, 2, 2, 2, 2],
      sayisal: const [false, true, true, true, true],
      vurguluSutun: 4,
      satirlar: [
        for (final k in kayitlar)
          [
            _tabloTarihi(k.tarih),
            _sifirsiz(k.kalipci),
            _sifirsiz(k.demirci),
            _sifirsiz(k.diger),
            _sifirsiz(k.kalipci + k.demirci + k.diger),
          ],
      ],
      toplam: ['TOPLAM', '${ozet.kalipci}', '${ozet.demirci}', '${ozet.diger}', '${ozet.toplamAdamGun}'],
      bosMetin: 'Bu aralıkta kayıt yok.',
    );
  }

  Widget _vincTablosu(List<GunlukKayit> kayitlar) {
    final satirlar = _vincSatirlari(kayitlar);
    double toplam = 0;
    final hucreler = <List<String>>[];
    final aciklamalar = <String>[];
    final gunler = <String>{};
    for (final v in satirlar) {
      final DateTime t = v['tarih'];
      gunler.add('${t.year}-${t.month}-${t.day}');
      final net = double.tryParse(_hesaplaVincNetSaat(v['baslangic'], v['bitis'], v['mola'])) ?? 0;
      toplam += net;
      final int mola = v['mola'];
      hucreler.add([
        _tabloTarihi(v['tarih']),
        (v['firmaAdi'] as String).isEmpty ? '–' : v['firmaAdi'],
        '${v['baslangic']}–${v['bitis']}${mola > 0 ? '\nmola $mola dk' : ''}',
        '${_PuantajOzeti.sayi(net)} sa',
      ]);
      aciklamalar.add((v['aciklama'] as String).trim());
    }
    // Telefonda beşinci sütun saatleri ve firma adını ikiye bölüyor; orada
    // açıklama satırın altında tam genişlikte, geniş ekranda ayrı sütunda.
    return LayoutBuilder(
      builder: (context, constraints) {
        final genis = constraints.maxWidth >= 560;
        return _basitTablo(
          basliklar: [...const ['Tarih', 'Firma', 'Saat', 'Net'], if (genis) 'Açıklama'],
          flexler: [...const [3, 4, 4, 2], if (genis) 6],
          sayisal: [...const [false, false, false, true], if (genis) false],
          vurguluSutun: 3,
          satirlar: [
            for (int i = 0; i < hucreler.length; i++)
              [...hucreler[i], if (genis) (aciklamalar[i].isEmpty ? '–' : aciklamalar[i])],
          ],
          altSatirlar: genis ? null : aciklamalar,
          toplam: ['TOPLAM', '${gunler.length} gün', '', '${_PuantajOzeti.sayi(toplam)} sa', if (genis) ''],
          bosMetin: 'Bu aralıkta vinç kaydı yok.',
        );
      },
    );
  }

  Widget _yevmiyeTablosu(List<GunlukKayit> kayitlar) {
    final satirlar = _yevmiyeSatirlari(kayitlar);
    final toplam = satirlar.fold<double>(0, (t, y) => t + (y['miktar'] as num).toDouble());
    return _basitTablo(
      basliklar: const ['Tarih', 'Ekip', 'Adet', 'Açıklama'],
      flexler: const [3, 4, 2, 5],
      sayisal: const [false, false, true, false],
      vurguluSutun: 2,
      satirlar: [
        for (final y in satirlar)
          [
            _tabloTarihi(y['tarih']),
            (y['ekipAdi'] as String).isEmpty ? '–' : y['ekipAdi'],
            _PuantajOzeti.sayi((y['miktar'] as num).toDouble()),
            (y['aciklama'] as String).isEmpty ? '–' : y['aciklama'],
          ],
      ],
      toplam: ['TOPLAM', '', _PuantajOzeti.sayi(toplam), ''],
      bosMetin: 'Bu aralıkta yevmiye kaydı yok.',
    );
  }

  /// Ekran genişliğine sığan sade tablo. Hücre metnindeki ikinci satır
  /// (\n sonrası) küçük ve gri yazılır. Toplam satırı tablonun başında durur
  /// ki uzun listede aşağı inmeden görülsün.
  Widget _basitTablo({
    required List<String> basliklar,
    required List<int> flexler,
    required List<bool> sayisal,
    required int vurguluSutun,
    required List<List<String>> satirlar,
    required List<String> toplam,
    required String bosMetin,
    List<String>? altSatirlar,
  }) {
    final birincil = ThemeColors.textPrimary(context);
    final ikincil = ThemeColors.textSecondary(context);
    final zemin = ThemeColors.cardBackground(context);
    final cizgi = ThemeColors.border(context);

    Widget hucre(String metin, int i, {bool baslik = false, bool toplamSatiri = false}) {
      final parcalar = metin.split('\n');
      final hizala = sayisal[i] ? CrossAxisAlignment.end : CrossAxisAlignment.start;
      final vurgu = i == vurguluSutun || toplamSatiri;
      return Expanded(
        flex: flexler[i],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            crossAxisAlignment: hizala,
            children: [
              Text(
                parcalar.first,
                textAlign: sayisal[i] ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                  color: baslik ? ikincil : (toplamSatiri ? Colors.lightBlueAccent : birincil),
                  fontSize: baslik ? 12 : 14,
                  fontWeight: baslik || vurgu ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              for (final ek in parcalar.skip(1))
                Text(ek, style: TextStyle(color: ikincil, fontSize: 11)),
            ],
          ),
        ),
      );
    }

    Widget satir(List<String> hucreler, {Color? renk, bool baslik = false, bool toplamSatiri = false}) {
      return Container(
        color: renk,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < hucreler.length; i++)
              hucre(hucreler[i], i, baslik: baslik, toplamSatiri: toplamSatiri),
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: zemin,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cizgi),
      ),
      child: Column(
        children: [
          satir(basliklar, baslik: true, renk: Colors.black.withOpacity(0.25)),
          if (satirlar.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(bosMetin, style: TextStyle(color: ikincil)),
            )
          else ...[
            satir(toplam, toplamSatiri: true, renk: Colors.blue.withOpacity(0.10)),
            for (int i = 0; i < satirlar.length; i++) ...[
              satir(satirlar[i], renk: i.isOdd ? Colors.white.withOpacity(0.03) : null),
              // Satıra ait tam genişlikte not (ör. vinç açıklaması)
              if (altSatirlar != null && altSatirlar[i].isNotEmpty)
                Container(
                  width: double.infinity,
                  color: i.isOdd ? Colors.white.withOpacity(0.03) : null,
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes, size: 14, color: ikincil),
                      const SizedBox(width: 6),
                      Expanded(child: Text(altSatirlar[i], style: TextStyle(color: ikincil, fontSize: 13))),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  // --- Yardımcı Widgetlar (Aynı Kalıyor) ---
  void _galeriGoster() {
    List<Map<String, dynamic>> tumFotograflar = [];
    if (widget.gunlukKayitlar != null) {
      for (var kayit in widget.gunlukKayitlar) {
        if (kayit.fotografYollari != null) {
          for (var foto in kayit.fotografYollari) {
            if (foto != null && foto.toString().trim().isNotEmpty) {
              tumFotograflar.add({'tarih': kayit.tarih, 'yol': foto.toString()});
            }
          }
        }
      }
    }
    tumFotograflar.sort((a, b) {
      final tA = a['tarih'];
      final tB = b['tarih'];
      if (tA is DateTime && tB is DateTime) {
        return tB.compareTo(tA);
      }
      if (tA is DateTime) return -1;
      if (tB is DateTime) return 1;
      return 0;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: ThemeColors.background(context),
          appBar: AppBar(
            title: const Text('Proje Galerisi'),
            backgroundColor: ThemeColors.headerBackground(context),
          ),
          body: tumFotograflar.isEmpty
              ? Center(child: Text('Henüz fotoğraf eklenmemiş', style: TextStyle(color: ThemeColors.textTertiary(context))))
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
                    if (index < 0 || index >= tumFotograflar.length) return const SizedBox();
                    final foto = tumFotograflar[index];
                    final yol = (foto['yol'] ?? '').toString();
                    final tarih = foto['tarih'];
                    final tarihStr = tarih is DateTime
                        ? DateFormat('dd.MM.yyyy').format(tarih)
                        : (tarih != null ? tarih.toString() : '');
                    return InkWell(
                      onTap: () => _fotografBuyut(context, tumFotograflar, index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ImageService.buildImage(yol, fit: BoxFit.cover),
                            if (!ImageService.isNetworkUrl(yol))
                              const Positioned(
                                top: 4,
                                right: 4,
                                child: Tooltip(
                                  message: 'Buluta yüklenmedi',
                                  child: CircleAvatar(
                                    radius: 11,
                                    backgroundColor: Colors.black87,
                                    child: Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 14),
                                  ),
                                ),
                              ),
                            if (tarihStr.isNotEmpty)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                                  color: Colors.black.withOpacity(0.65),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.calendar_today, color: Colors.amber, size: 10),
                                      const SizedBox(width: 3),
                                      Text(
                                        tarihStr,
                                        style: TextStyle(
                                          color: ThemeColors.textPrimary(context),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
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
    if (tumFotograflar.isEmpty) return;
    final safeIndex = baslangicIndex.clamp(0, tumFotograflar.length - 1);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FotografGoruntulePage(
          fotograflar: tumFotograflar,
          baslangicIndex: safeIndex,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: TextStyle(color: ThemeColors.textPrimary(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: ThemeColors.textTertiary(context)),
        filled: true,
        fillColor: ThemeColors.background(context),
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
    final yil = _gosterilenAy.year;
    final ay = _gosterilenAy.month;
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
              icon: Icon(Icons.chevron_left, color: ThemeColors.textPrimary(context)),
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
              icon: Icon(Icons.chevron_right, color: ThemeColors.textPrimary(context)),
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
                        color: ThemeColors.textTertiary(context),
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
              // Dolgu "kayıt var" bilgisini, çerçeve "bugün" bilgisini taşır;
              // böylece bugünün kaydının girilip girilmediği de görünür.
              return Expanded(
                child: InkWell(
                  onTap: () => _tarihDegistir(tarih),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    height: Platform.isWindows ? 40 : 35,
                    decoration: BoxDecoration(
                      color: secili
                          ? Colors.blue
                          : (kayitVar ? Colors.green.shade800 : Colors.transparent),
                      borderRadius: BorderRadius.circular(4),
                      border: bugun
                          ? Border.all(color: Colors.lightGreenAccent, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$gunNo',
                        style: TextStyle(
                          color: (secili || kayitVar)
                              ? Colors.white
                              : ThemeColors.textPrimary(context),
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
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _takvimAciklama(Colors.green.shade800, null, 'Kayıt var'),
            const SizedBox(width: 14),
            _takvimAciklama(Colors.transparent, Colors.lightGreenAccent, 'Bugün'),
            const SizedBox(width: 14),
            _takvimAciklama(Colors.blue, null, 'Seçili gün'),
          ],
        ),
      ],
    );
  }

  Widget _takvimAciklama(Color dolgu, Color? cerceve, String etiket) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: dolgu,
            borderRadius: BorderRadius.circular(3),
            border: cerceve != null ? Border.all(color: cerceve, width: 2) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(etiket, style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
      ],
    );
  }

  Widget _buildDesktopInputWithLabel(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        _buildTextField(controller, hint),
      ],
    );
  }
}

class FotografGoruntulePage extends StatefulWidget {
  final List<Map<String, dynamic>> fotograflar;
  final int baslangicIndex;

  const FotografGoruntulePage({
    super.key,
    required this.fotograflar,
    required this.baslangicIndex,
  });

  @override
  State<FotografGoruntulePage> createState() => _FotografGoruntulePageState();
}

class _FotografGoruntulePageState extends State<FotografGoruntulePage> {
  late int mevcutIndex;
  late PageController _pageController;
  bool _showAppBar = true;
  bool _paylasiliyor = false;

  /// Fotoğrafı telefonun paylaşma menüsüyle gönderir (WhatsApp, e-posta...).
  /// Buluttaki fotoğraf önce geçici klasöre indirilir.
  Future<void> _paylas(int index) async {
    final item = widget.fotograflar[index];
    final yol = (item['yol'] ?? '').toString();
    final tarihStr = _formatTarih(item['tarih']);
    setState(() => _paylasiliyor = true);
    try {
      String dosyaYolu = yol;
      if (ImageService.isNetworkUrl(yol)) {
        final yanit = await http.get(Uri.parse(yol)).timeout(const Duration(seconds: 60));
        if (yanit.statusCode != 200) {
          throw Exception('Fotoğraf indirilemedi (${yanit.statusCode})');
        }
        final uzanti = yol.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
        final ad = 'santiyepro_${tarihStr.replaceAll('.', '-')}_${index + 1}.$uzanti';
        final dosya = File('${(await getTemporaryDirectory()).path}/$ad');
        await dosya.writeAsBytes(yanit.bodyBytes, flush: true);
        dosyaYolu = dosya.path;
      } else if (!await File(yol).exists()) {
        throw Exception('Fotoğraf bu cihazda bulunamadı');
      }
      await paylas.SharePlus.instance.share(paylas.ShareParams(
        files: [paylas.XFile(dosyaYolu)],
        text: tarihStr.isNotEmpty ? 'Şantiye fotoğrafı – $tarihStr' : null,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşılamadı: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _paylasiliyor = false);
    }
  }

  String _formatTarih(dynamic tarih) {
    if (tarih == null) return '';
    if (tarih is DateTime) {
      return DateFormat('dd.MM.yyyy').format(tarih);
    }
    if (tarih is String) {
      try {
        final parsed = DateTime.parse(tarih);
        return DateFormat('dd.MM.yyyy').format(parsed);
      } catch (_) {
        return tarih;
      }
    }
    return tarih.toString();
  }

  @override
  void initState() {
    super.initState();
    if (widget.fotograflar.isEmpty) {
      mevcutIndex = 0;
      _pageController = PageController();
    } else {
      mevcutIndex = widget.baslangicIndex.clamp(0, widget.fotograflar.length - 1);
      _pageController = PageController(initialPage: mevcutIndex);
    }
    try {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } catch (_) {}
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fotograflar.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black45,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text('Görüntülenecek fotoğraf yok', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final safeIndex = mevcutIndex.clamp(0, widget.fotograflar.length - 1);
    final String tarihStr = _formatTarih(widget.fotograflar[safeIndex]['tarih']);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showAppBar && (!isLandscape) 
          ? AppBar(
              backgroundColor: Colors.black45,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                '${safeIndex + 1} / ${widget.fotograflar.length}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              actions: [
                IconButton(
                  tooltip: 'Paylaş',
                  icon: _paylasiliyor
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.share, color: Colors.white),
                  onPressed: _paylasiliyor ? null : () => _paylas(safeIndex),
                ),
                if (tarihStr.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.amber, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              tarihStr,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showAppBar = !_showAppBar;
          });
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.fotograflar.length,
              onPageChanged: (index) {
                if (mounted) {
                  setState(() {
                    mevcutIndex = index;
                  });
                }
              },
              itemBuilder: (context, index) {
                if (index < 0 || index >= widget.fotograflar.length) return const SizedBox();
                final item = widget.fotograflar[index];
                final yol = (item['yol'] ?? '').toString();
                return Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: ImageService.buildImage(
                      yol,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                );
              },
            ),

            // Fotoğraf Üzerine Tarih Rozeti (Overlay Badge directly over photo)
            if (tarihStr.isNotEmpty && _showAppBar)
              Positioned(
                bottom: isLandscape ? 20 : 35,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.6), width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.amber, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          tarihStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (!ImageService.isNetworkUrl((widget.fotograflar[safeIndex]['yol'] ?? '').toString())) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 16),
                          const SizedBox(width: 4),
                          const Text('Buluta yüklenmedi', style: TextStyle(color: Colors.orangeAccent, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            // Portre modunda okları göster, manzara modunda gizle
            if (!isLandscape && safeIndex > 0)
              Positioned(
                left: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: () {
                      if (_pageController.hasClients) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 40),
                  ),
                ),
              ),
            if (!isLandscape && safeIndex < widget.fotograflar.length - 1)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: () {
                      if (_pageController.hasClients) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 40),
                  ),
                ),
              ),
            // Manzara modunda geri çıkış butonu
            if (isLandscape && !_showAppBar)
              Positioned(
                top: 20,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bir kayıt kümesinin (ay ya da puantaj aralığı) toplamları.
class _PuantajOzeti {
  final int kayitGunu;
  final int kalipci;
  final int demirci;
  final int diger;
  final int fotograf;
  final double vincSaat;
  /// Vinç kaydı olan farklı gün sayısı.
  final int vincGun;
  final double yevmiye;

  const _PuantajOzeti({
    required this.kayitGunu,
    required this.kalipci,
    required this.demirci,
    required this.diger,
    required this.fotograf,
    required this.vincSaat,
    required this.vincGun,
    required this.yevmiye,
  });

  int get toplamAdamGun => kalipci + demirci + diger;

  static _PuantajOzeti hesapla(
    List<GunlukKayit> kayitlar,
    List<Map<String, dynamic>> Function(Iterable<GunlukKayit>) vincSatirlari,
    List<Map<String, dynamic>> Function(Iterable<GunlukKayit>) yevmiyeSatirlari,
    String Function(String, String, int) vincNetSaat,
  ) {
    final vincler = vincSatirlari(kayitlar);
    final vincGunleri = <String>{
      for (final v in vincler)
        '${(v['tarih'] as DateTime).year}-${(v['tarih'] as DateTime).month}-${(v['tarih'] as DateTime).day}',
    };
    return _PuantajOzeti(
      vincGun: vincGunleri.length,
      kayitGunu: kayitlar.length,
      kalipci: kayitlar.fold(0, (t, k) => t + k.kalipci),
      demirci: kayitlar.fold(0, (t, k) => t + k.demirci),
      diger: kayitlar.fold(0, (t, k) => t + k.diger),
      fotograf: kayitlar.fold(0, (t, k) => t + k.fotografYollari.length),
      vincSaat: vincler.fold(
          0.0,
          (t, v) => t + (double.tryParse(vincNetSaat(v['baslangic'], v['bitis'], v['mola'])) ?? 0.0)),
      yevmiye: yevmiyeSatirlari(kayitlar).fold(0.0, (t, y) => t + (y['miktar'] as num).toDouble()),
    );
  }

  /// Tam sayıysa ondalıksız, değilse tek ondalıkla yazar (5 / 5.5).
  static String sayi(double d) =>
      d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
}
