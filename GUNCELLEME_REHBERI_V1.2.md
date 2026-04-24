# ŞantiyePro v1.2 GitHub Güncelleme Rehberi

Uygulamanın son sürümünü (v1.2) GitHub üzerinden yayınlamak için aşağıdaki adımları takip edebilirsiniz.

## 1. Değişiklikleri Kaydedin ve Etiketleyin

Terminalde (Proje dizininde: `C:\Users\baris\santiyepro`) şu komutları sırasıyla çalıştırın:

```bash
# 1. Tüm değişiklikleri ekle
git add .

# 2. Commit oluştur
git commit -m "v1.2 Güncellemesi: Vinç Takip Özelliği ve Optimizasyonlar"

# 3. Versiyon etiketi oluştur (Bu adım GitHub Actions'ı tetikler)
git tag v1.2

# 4. Değişiklikleri ve etiketi GitHub'a gönder
git push origin main
git push origin v1.2
```

## 2. GitHub Actions Takibi

1. GitHub deponuzdaki **"Actions"** sekmesine gidin.
2. **"Release"** workflow'unun başladığını göreceksiniz.
3. Bu işlem otomatik olarak şunları yapacaktır:
   - Android APK dosyasını oluşturur.
   - Windows EXE dosyasını oluşturur.
   - GitHub'da yeni bir **Release** (Yayın) oluşturur ve dosyaları oraya ekler.

## 3. Mobilde Güncelleme

Release tamamlandıktan sonra:
1. Telefondan GitHub sayfanıza gidin.
2. **Releases** bölümünden `app-release.apk` dosyasını indirin.
3. Dosyayı açarak güncellemeyi tamamlayın.

---
*Not: GitHub Actions'ın çalışabilmesi için deponuzda `GITHUB_TOKEN` yetkisinin olması gerekir (genellikle varsayılan olarak açıktır).*
