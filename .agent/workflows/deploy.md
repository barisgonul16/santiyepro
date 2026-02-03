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
```

Bundan sonra aşağıdaki adımlara geçebilirsiniz.

### 1. Uygulamayı Derleme (Build)

Uygulamanın yeni dosyalarını terminalden şu komutlarla oluşturun:

**Windows İçin:**
```powershell
flutter build windows
```
*Dosya burada oluşur:* `build/windows/x64/runner/Release/santiyepro.exe`

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
git push
```

---

### 3. GitHub Üzerinde Yeni Bir "Release" Oluşturma

Bu adım, diğer kullanıcılara "Yeni sürüm hazır!" uyarısının gitmesini sağlar.

1. GitHub'da **santiyepro** deponuzun ana sayfasına gidin.
2. Sağ taraftaki **"Releases"** bölümünden **"Create a new release"** butonuna basın.
3. **Choose a tag** kısmına `v1.0.2+5` yazın (Create new tag seçin).
4. Release başlığına `v1.0.2+5 Güncellemesi` yazın.
5. **Assets** (Dosyalar) kısmına derlediğiniz `.exe` ve `.apk` dosyalarını sürükleyip bırakın.
6. **"Publish release"** butonuna basın.

---

**Sonuç:** Diğer kullanıcılar uygulamayı açtıklarında otomatik olarak yeni bir güncelleme olduğunu görecek ve "Güncelle" butonuna bastıklarında doğrudan GitHub'daki bu yeni dosyaya yönlendirilecekler.
