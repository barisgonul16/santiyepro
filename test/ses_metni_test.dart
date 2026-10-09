import 'package:flutter_test/flutter_test.dart';
import 'package:santiyepro/services/ses_metni.dart';

void main() {
  test('normal konuşma: ara sonuçlar uzayarak gelir', () {
    final b = SesMetniBirlestirici('');
    expect(b.sonuc('gera'), 'gera');
    expect(b.sonuc('gera makinada'), 'gera makinada');
    expect(b.sonuc('gera makinada 5 kalıpçı', son: true), 'gera makinada 5 kalıpçı');
  });

  test('dinlemeden önce kutuda yazı varsa korunur', () {
    final b = SesMetniBirlestirici('  önceki not ');
    expect(b.sonuc('yeni cümle', son: true), 'önceki not yeni cümle');
  });

  test('tanıyıcı önceki kelimeleri düzeltince yazı tekrarlanmaz', () {
    final b = SesMetniBirlestirici('');
    b.sonuc('gerada beş');
    expect(b.sonuc('Gerada 5 kalıpçı'), 'Gerada 5 kalıpçı');
  });

  test('duraklayıp düşündükten sonra BOŞ sonuç gelirse yazı silinmez', () {
    final b = SesMetniBirlestirici('');
    b.sonuc('gera makinada 5 kalıpçı 2 demirci');
    expect(b.sonuc(''), 'gera makinada 5 kalıpçı 2 demirci');
    expect(b.sonuc('   '), 'gera makinada 5 kalıpçı 2 demirci');
  });

  test('duraklamadan sonra yalnızca yeni cümle gelirse öncekinin sonuna eklenir', () {
    final b = SesMetniBirlestirici('');
    b.sonuc('gera makinada 5 kalıpçı 2 demirci vardı');
    expect(b.sonuc('ka otomotivde 3 kalıpçı'), 'gera makinada 5 kalıpçı 2 demirci vardı ka otomotivde 3 kalıpçı');
    // Sonraki ara sonuçlar yalnızca yeni parçayı günceller.
    expect(b.sonuc('ka otomotivde 3 kalıpçı döşeme söküyor'),
        'gera makinada 5 kalıpçı 2 demirci vardı ka otomotivde 3 kalıpçı döşeme söküyor');
  });

  test('aynı kelimeyle başlayan ama çok daha kısa yeni cümle de yeni parça sayılır', () {
    final b = SesMetniBirlestirici('');
    b.sonuc('gerada 5 kalıpçı 2 demirci perde kalıbı yapıldı');
    expect(b.sonuc('gerada beton'), 'gerada 5 kalıpçı 2 demirci perde kalıbı yapıldı gerada beton');
  });

  test('kesinleşmiş (son) sonuçtan sonra gelen her şey yeni parçadır', () {
    final b = SesMetniBirlestirici('');
    b.sonuc('gera makinada 5 kalıpçı', son: true);
    expect(b.sonuc('gera makinada beton döküldü'), 'gera makinada 5 kalıpçı gera makinada beton döküldü');
    expect(b.sonuc('gera makinada beton döküldü ve vinç çalıştı', son: true),
        'gera makinada 5 kalıpçı gera makinada beton döküldü ve vinç çalıştı');
  });

  test('elle düzeltme yeni taban olur; sonraki konuşma onun sonuna eklenir', () {
    final b = SesMetniBirlestirici('');
    b.sonuc('gera makinada 5 kalıpçı');
    b.elleDegisti('Gera makinada 6 kalıpçı');
    expect(b.metin, 'Gera makinada 6 kalıpçı');
    expect(b.sonuc('ve 2 demirci'), 'Gera makinada 6 kalıpçı ve 2 demirci');
  });

  test('bitir: son ara sonuç kesinleşir', () {
    final b = SesMetniBirlestirici('a');
    b.sonuc('merhaba dünya');
    b.bitir();
    expect(b.metin, 'a merhaba dünya');
    expect(b.sonuc('merhaba dünya yine'), 'a merhaba dünya merhaba dünya yine');
  });
}
