# Git Kullanım Rehberi: Temiz Kaydetme ve Geri Dönme

Bu rehber, projenizde yaptığınız değişiklikleri nasıl güvenli bir şekilde kaydedeceğinizi ve bir şeyler ters gittiğinde nasıl eski halini döndüreceğinizi öğretir.

## 1. Değişiklikleri Kaydetme (Commit)

Bir özelliği bitirdiğinizde veya önemli bir düzeltme yaptığınızda mutlaka "kayıt" (commit) oluşturun.

### Adım 1: Durumu Kontrol Et
Hangi dosyaların değiştiğini görmek için:
```powershell
git status
```

### Adım 2: Değişiklikleri Hazırlayın
Tüm dosyaları kayıt listesine eklemek için:
```powershell
git add .
```

### Adım 3: Kayıt Oluşturun (Mesajla)
Yaptığınız işi kısa ve öz bir şekilde açıklayın:
```powershell
git commit -m "v1.0.4+10: Uygulama ikonu güncellendi ve versiyon artırıldı"
```

---

## 2. İşlemleri Geri Alma (Rollback)

Eğer son yaptığınız değişiklikler (henüz kayıt etmediğiniz) hatalıysa şu komutları kullanın:

### Henüz Kayıt Etmediğiniz Değişiklikleri Silmek (Sıfırlamak)
Dosyaları en son "commit" anındaki tertemiz haline döndürür:
```powershell
git checkout .
```

### Yeni Oluşturulan (Takip Edilmeyen) Dosyaları Silmek
Eğer yeni dosyalar/klasörler eklediyseniz ve bunları silmek istiyorsanız:
```powershell
git clean -fd
```

### Son Yapılan Kaydı (Commit) İptal Etmek
Eğer kayıt oluşturdunuz ama hata fark ettiyseniz, kaydı geri alıp dosyaları düzenlemeye açık bırakmak için:
```powershell
git reset --soft HEAD~1
```

---

## 3. Geçmişe Bakma

Neler yaptığınızı ve hangi sürümde olduğunuzu görmek için:
```powershell
git log --oneline --graph --all
```

---

## Altın Kurallar (Best Practices)
1. **Küçük ve Sık Kaydedin:** Büyük bir özelliği bitirmeyi beklemeyin. Her anlamlı adımda kayıt oluşturun.
2. **Anlamlı Mesajlar Yazın:** "Güncelleme" yerine "Puantaj tablosuna toplam satırı eklendi" gibi açıklayıcı olun.
3. **Denemelerden Önce Kaydedin:** Riskli bir şeye başlamadan önce mutlaka o anki halini kayıt altına alın. Böylece istediğiniz zaman o ana dönebilirsiniz.
