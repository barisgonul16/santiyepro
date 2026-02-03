# GitHub Üzerinden Otomatik Güncelleme Rehberi

Uygulamanızın internet üzerinden otomatik olarak güncellenmesi için GitHub'ın ücretsiz özelliklerini kullanacağız. Aşağıdaki adımları sırasıyla uygulayınız.

## 1. Hazırlık (GitHub Hesabı)
1.  [GitHub.com](https://github.com) adresine gidin.
2.  Ücretsiz bir hesap oluşturun (veya varsa giriş yapın).

## 2. Proje Alanı (Repository) Oluşturma
1.  Sağ üst köşedeki `+` simgesine tıklayıp **"New repository"** deyin.
2.  **Repository name:** Proje adınızı yazın (Örn: `santiyepro`).
3.  **Public** seçeneğini işaretleyin (Ücretsiz sürümde private repolarda dosya indirme bağlantıları zorlaşabilir).
4.  **Create repository** butonuna basın.

## 3. Kod İçindeki Ayarları Güncelleme
Oluşturduğunuz bu alana göre uygulamanızdaki `update_service.dart` dosyasını düzenlemeniz gerekiyor.

1.  VS Code'da `lib/services/update_service.dart` dosyasını açın.
2.  Aşağıdaki satırları kendi kullanıcı adınız ve proje adınızla değiştirin:

```dart
static const String _githubUser = "sizin_kullanici_adiniz"; // Örn: baris123
static const String _repoName = "proje_adiniz";           // Örn: santiyepro
```

3.  Bu değişikliği yaptıktan sonra uygulamanızı **tekrar derleyin** (`flutter build apk` / `flutter build windows`).

## 4. Versiyon Dosyası (version.json) Oluşturma
Masaüstünüzde `version.json` adında bir metin dosyası oluşturun ve içini şununla doldurun:

```json
{
  "version": "1.0.0+2",
  "notes": "Bu güncelleme ile tema sorunları giderildi ve performans artırıldı."
}
```
> **Önemli:** Buradaki `version` değeri, uygulamanızın `pubspec.yaml` dosyasındaki versiyondan **YÜKSEK** olmalıdır.

## 5. Dosyaları Yükleme (Release Oluşturma)
Her yeni güncelleme yayınlayacağınızda bu adımı yapacaksınız:

1.  GitHub'daki proje sayfanıza gidin.
2.  Sağ taraftaki **Releases** başlığına tıklayın, sonra **"Draft a new release"** (veya Create a new release) deyin.
3.  **Choose a tag:** Yeni bir versiyon etiketi yazın (Örn: `v1.2`).
4.  **Release title:** Başlık yazın (Örn: `Versiyon 1.2`).
5.  **Attach binaries:** Oluşturduğunuz `APK` ve `EXE` (zip) dosyalarını buraya sürükleyip bırakın.
6.  **Publish release** butonuna basın.

## 6. version.json Dosyasını Yükleme
Uygulamanız güncellemeyi bu dosyadan kontrol eder.

1.  GitHub proje anasayfanıza gidin.
2.  **Add file** -> **Upload files** seçeneğine tıklayın.
3.  Hazırladığınız `version.json` dosyasını sürükleyin.
4.  **Commit changes** butonuna basın.

🎉 **Tebrikler!**
Artık biri uygulamanızı açtığında, sistem GitHub'daki `version.json` dosyasına bakacak. Eğer oradaki numara telefondakinden yüksekse, kullanıcıya "Güncelleme Var" uyarısı verecek ve "İndir" butonuna basınca GitHub Releases sayfasına yönlendirecek.
