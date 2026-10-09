/// Konuşma tanımanın verdiği ara sonuçları, kutudaki yazıyı silmeden birleştirir.
///
/// Konuşma tanıma duraklayıp yeniden başlayabilir. O anda gelen sonuç ya boştur
/// ya da yalnızca yeni cümleyi içerir; bunu kutuya olduğu gibi yazmak o ana
/// kadar söylenenleri siler. Bu sınıf önceki kısmı korur:
/// - boş sonuçlar yok sayılır,
/// - "son" işaretli sonuç kesinleşir ve bir daha değişmez,
/// - yeni sonuç öncekinin devamı (düzeltilmiş hâli) değilse öncekini kesinleştirip
///   yenisini sonuna ekler.
class SesMetniBirlestirici {
  /// Kesinleşmiş metin (dinlemeden önce kutuda olanlar dahil).
  String _taban;

  /// Şu anki konuşma parçasının son ara sonucu.
  String _kismi = '';

  SesMetniBirlestirici(String baslangic) : _taban = baslangic.trim();

  /// Kutuda gösterilecek metin.
  String get metin => _birlestir(_taban, _kismi);

  /// Kullanıcı kutuyu elle değiştirdi: yazılan metin yeni taban olur.
  void elleDegisti(String yeniMetin) {
    _taban = yeniMetin.trim();
    _kismi = '';
  }

  /// Yeni bir ara sonuç geldi; kutuya yazılacak metni döndürür.
  String sonuc(String kelimeler, {bool son = false}) {
    final yeni = kelimeler.trim();
    if (yeni.isEmpty) return metin;

    if (_kismi.isNotEmpty && !_devami(_kismi, yeni)) {
      _taban = _birlestir(_taban, _kismi);
    }
    _kismi = yeni;

    if (son) {
      _taban = _birlestir(_taban, _kismi);
      _kismi = '';
    }
    return metin;
  }

  /// Dinleme bitti: son ara sonucu kesinleştirir.
  void bitir() {
    if (_kismi.isNotEmpty) {
      _taban = _birlestir(_taban, _kismi);
      _kismi = '';
    }
  }

  static String _birlestir(String a, String b) => [a, b].where((x) => x.isNotEmpty).join(' ');

  static String _kucuk(String s) => s.toLowerCase().replaceAll('İ', 'i').replaceAll('I', 'ı');

  /// [yeni], [eski] ara sonucunun devamı ya da düzeltilmiş hâli mi?
  /// Tanıyıcı önceki kelimeleri düzeltebilir ama başlangıç genelde aynı kalır;
  /// yeni bir cümle başka bir kelimeyle ya da çok daha kısa bir metinle başlar.
  static bool _devami(String eski, String yeni) {
    final e = _kucuk(eski), y = _kucuk(yeni);
    if (e.length >= 15 && y.length < e.length * 0.6) return false;
    final n = e.length < 3 ? e.length : 3;
    return y.startsWith(e.substring(0, n));
  }
}
