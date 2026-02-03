# ŞantiyePro Kurulum Dosyası (Setup) Oluşturma Rehberi

Bu rehber, **SantiyePro** uygulaması için `.exe` uzantılı bir kurulum (setup) dosyası oluşturmanıza yardımcı olacaktır.

## 1. Adım: Inno Setup İndirin ve Kurun
Kurulum dosyasını oluşturmak için **Inno Setup** adlı ücretsiz araca ihtiyacınız var.
1.  [jrsoftware.org](https://jrsoftware.org/isdl.php) adresine gidin.
2.  **"RandomSite"** linklerinden birine tıklayarak kurulumu indirin (`innosetup-6.x.x.exe`).
3.  İndirdiğiniz dosyayı çalıştırın ve bilgisayarınıza kurun.

## 2. Adım: Setup Scriptini Açın
1.  Şu klasöre gidin: `c:\Users\baris\santiyepro\installers\`
2.  **`setup.iss`** dosyasına çift tıklayın. Bu dosya Inno Setup ile açılacaktır.
    *   (Eğer sorarsa, "Inno Setup Compiler" uygulamasını seçin).

## 3. Adım: Derleyin (Compile)
Inno Setup açıldıktan sonra:
1.  Üst menüdeki **Build** menüsüne tıklayın.
2.  **Compile** seçeneğine tıklayın (veya klavyeden `Ctrl + F9` tuşuna basın).

## 4. Adım: Sonuç
İşlem tamamlandığında (birkaç saniye sürer):
*   Aynı klasörde (`installers` klasörü içinde) **`SantiyePro_Setup.exe`** adında yeni bir dosya oluşacaktır.
*   Bu dosya, uygulamanızın dağıtılabilir kurulum dosyasıdır. Bu dosyayı dilediğiniz bilgisayara taşıyıp kurabilirsiniz.

---
**Not:** Setup dosyasını oluşturmadan önce uygulamanın en son halinin derlendiğinden emin olun (`flutter build windows`). Biz bunu zaten yaptık.
