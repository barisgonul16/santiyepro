# Uygulama Güncelleme ve Dağıtım Rehberi

Uygulamanızda yaptığınız değişiklikleri (tema düzeltmeleri, yeni özellikler vb.) kullanıcılara ulaştırmak için izlemeniz gereken adımlar aşağıdadır.

## 1. Adım: Versiyon Numarasını Artırma (Çok Önemli)
Her yeni güncellemede, cihazların bunun "yeni" bir sürüm olduğunu anlaması için versiyon numarasını değiştirmelisiniz.

1.  Projenizdeki **`pubspec.yaml`** dosyasını açın.
2.  `version:` satırını bulun (Genellikle 7-8. satırlardadır).
3.  `+` işaretinden sonraki sayıyı artırın.

**Örnek:**
*   Eski: `version: 1.0.0+1`
*   Yeni: `version: 1.0.0+2`

> **Not:** `+` işaretinden önceki kısım (1.0.0) kullanıcıya görünen isimdir, `+` işaretinden sonraki kısım (2) ise cihazın (Android/Windows) okuduğu teknik sürüm kodudur. Her güncellemede `+` sonrasını mutlaka 1 artırın.

## 2. Adım: Yeni Sürümü Derleme (Build)
Versiyonu artırdıktan sonra terminalde şu komutları sırasıyla çalıştırarak güncel paketleri oluşturun:

### Android (APK) İçin:
```bash
flutter build apk --release
```

### Bilgisayar (Windows) İçin:
```bash
flutter build windows --release
```

## 3. Adım: Dosyaları Hazırlama
Oluşan dosyaları bir araya getirmek için (önceki işlemimizde oluşturduğumuz gibi) şu PowerShell komutlarını kullanabilirsiniz:

```powershell
# Klasörleri temizle/oluştur
New-Item -ItemType Directory -Force -Path "SantiyePro_Guncelleme"
New-Item -ItemType Directory -Force -Path "SantiyePro_Guncelleme\Android"
New-Item -ItemType Directory -Force -Path "SantiyePro_Guncelleme\Windows"

# Yeni dosyaları kopyala
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "SantiyePro_Guncelleme\Android\SantiyePro_v2.apk"
Copy-Item "build\windows\x64\runner\Release\*" "SantiyePro_Guncelleme\Windows\" -Recurse -Force

# Klasörü aç
explorer "SantiyePro_Guncelleme"
```

## 4. Adım: Kullanıcılara Gönderme ve Yükleme

### Android Kullanıcıları İçin:
*   Oluşan `SantiyePro_v2.apk` dosyasını WhatsApp, Telegram veya Google Drive üzerinden kullanıcıya gönderin.
*   **Kullanıcı ne yapacak?**
    1.  Dosyayı indirip açacak.
    2.  Telefon **"Bu uygulamanın güncellemesini yüklemek istiyor musunuz?"** diye soracak.
    3.  **"Yükle"** veya **"Güncelle"** diyecek.
    4.  **Sonuç:** Uygulama güncellenir, *içindeki veriler (projeler, notlar vb.) SİLİNMEZ, korunur.*

### Bilgisayar Kullanıcıları İçin:
*   `SantiyePro_Guncelleme` klasöründeki `Windows` klasörünü (veya zipleyip) kullanıcıya gönderin.
*   **Kullanıcı ne yapacak?**
    1.  Eski klasörün yedeğini alabilir (opsiyonel).
    2.  Yeni klasördeki `SantiyePro.exe`'yi çalıştıracak.
    3.  **Not:** Windows sürümünde veriler genellikle `Belgelerim` veya `AppData` klasöründe saklandığı için, sadece `.exe`'nin olduğu klasörü değiştirmek verileri silmez. Ancak `sqlite` veritabanı dosyasını projenin içinde tutuyorsanız, yeni klasöre geçince veriler sıfırlanabilir.
    *   *Sizin projenizde veriler JSON/Database olarak nerede saklanıyor?* Varsayılan olarak `StorageService` dosyanızda path belirtilmediyse uygulamanın olduğu yere kaydedebilir. Bu durumda Windows kullanıcıları eski klasördeki `veri dosyalarını` (json, db vb.) yeni klasöre kopyalamalıdır.

## Özet
Manuel dağıtımda kural şudur: **Eski uygulamayı silip yenisini yüklemeyin, eskisinin ÜZERİNE kurun.** Böylece veriler kaybolmaz.
