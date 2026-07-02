---
description: Uygulamayı Diğer Kullanıcılara Güncelleme Rehberi
---

Aşağıdaki adımları sırayla takip ederek yaptığımız tüm yenilikleri (Excel, Yeni Tasarım vb.) diğer kullanıcılara ulaştırabilirsiniz.

### 0. Git Kurulumu (Eğer "not a git repository" hatası alıyorsanız)

Eğer terminalden `git` komutlarını çalıştırdığınızda hata alıyorsanız, önce şu komutları tek tek çalıştırarak bu klasörü GitHub'a bağlayın:

```powershell
git init
git remote add origin https://github.com/barisgonul16/santiyepro.git
git branch -m main
# Eğer yukarıdaki adımlardan sonra 'push' yaparken hata alırsanız şu komutu çalıştırın:
git pull origin main --allow-unrelated-histories
```

Bundan sonra aşağıdaki adımlara geçebilirsiniz.

### 1. Uygulamayı Derleme (Build)

Uygulamanın yeni dosyalarını terminalden şu komutlarla oluşturun:

**Windows İçin (İki Yöntemden Biri Seçilebilir):**

*   **Yöntem A: Tek Dosyalık Kurulum Paketi (.msix - Önerilen)**
    ```powershell
    flutter build windows
    dart run msix:create
    ```
    *Kurulum dosyası burada oluşur:* `build/windows/x64/runner/Release/SantiyePro_v3.msix`
    *(Kullanıcılar bunu çift tıklatarak doğrudan bilgisayarlarına yükleyebilir. Tüm DLL bağımlılıklarını otomatik çözer.)*

*   **Yöntem B: Taşınabilir Klasör (.zip formatında)**
    ```powershell
    flutter build windows
    ```
    `build/windows/x64/runner/Release/` klasörünün tamamını (tüm `.dll` dosyaları ve `data` klasörüyle birlikte) sıkıştırarak bir `.zip` dosyası yapın.
    *(Kullanıcılar sadece `.exe` indirirse DLL hatası alır, bu yüzden klasörün tamamını ZIP olarak indirmelidirler.)*

**Android İçin (APK):**
```powershell
flutter build apk --split-per-abi
```
*Dosya burada oluşur:* `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (veya benzeri)

---

### 2. Kodları GitHub'a Gönderme

Yaptığımız değişiklikleri ve güncellediğimiz `version.json` dosyasını GitHub'a gönderin:

```powershell
git add .
git commit -m "v1.0.2+5: Excel ve Yeni Tasarım Güncellemesi"
git push -u origin main
```

---

### 3. GitHub Üzerinde Yeni Bir "Release" Oluşturma

Bu adım, diğer kullanıcılara "Yeni sürüm hazır!" uyarısının gitmesini sağlar.

1. GitHub'da **santiyepro** deponuzun ana sayfasına gidin.
2. Sağ taraftaki **"Releases"** bölümünden **"Create a new release"** butonuna basın.
3. **Choose a tag** kısmına `v1.0.2+5` yazın (Create new tag seçin).
4. Release başlığına `v1.0.2+5 Güncellemesi` yazın.
5. **Assets** (Dosyalar) kısmına derlediğiniz `.msix` (veya hazırladığınız `.zip` klasörünü) ve `.apk` dosyalarını sürükleyip bırakın. **(Önemli: Tek başına `.exe` dosyasını yüklemeyin, aksi takdirde DLL eksik hatası alınır.)**
6. **"Publish release"** butonuna basın.

---

**Sonuç:** Diğer kullanıcılar uygulamayı açtıklarında otomatik olarak yeni bir güncelleme olduğunu görecek ve "Güncelle" butonuna bastıklarında doğrudan GitHub'daki bu yeni dosyaya yönlendirilecekler.
