# ŞantiyePro MCP sunucusu (Cloudflare Workers)

`araclar/santiyepro_mcp.py` ile aynı okuma araçları, internette: telefondaki ve
bilgisayardaki Claude buna claude.ai özel bağlayıcısı olarak bağlanır. Veriyi
buluttan (Firestore) alır. Cloudflare Workers ücretsiz katmanında çalışır (kart
gerekmez).

Kayıt önerme (`src/yazma.js`): `kayit_ekle`, `bekleyen_kayitlar`,
`kayit_onerisini_geri_al`. Claude uygulamanın verisine ASLA yazmaz; öneri
`users/{uid}/data/claude_gelen/oneriler/{id}` belgesine gider (sesle kayıttaki
taslak JSON'u). Uygulama ana sayfada "Claude'dan kayıt onay bekliyor" kartını
gösterir, kullanıcı onay ekranında düzeltip kaydeder ve öneri silinir
(`lib/services/claude_gelen_kutusu.dart`). Böylece açık bir uygulamanın tek
parça yüklediği eski liste Claude'un yazdığını ezemez.

Malzeme takibi (`src/malzeme.js`): `malzeme_durumu` (şantiyede şu an ne var:
gelen − giden), `malzeme_hareketleri` (giriş/çıkış defteri) okur;
`malzeme_ekle`, `bekleyen_malzemeler`, `malzeme_onerisini_geri_al` aynı
öneri düzeniyle çalışır ama ayrı klasöre yazar:
`users/{uid}/data/claude_gelen/malzeme_onerileri/{id}` (`{"hareketler":[...]}`).
Ayrı klasör şart: malzemeyi bilmeyen eski uygulama sürümleri günlük kayıt
klasöründeki okuyamadığı öneriyi siliyor. Uygulama bunları Malzemeler
sayfasının üstünde gösterir. Python sunucusunda (`santiyepro_mcp.py`) malzeme
araçları yok.

- Adres: `https://santiyepro-mcp.baris-gonul16.workers.dev/mcp`
- Giriş: claude.ai bağlanırken bir şifre sorar (`GIRIS_SIFRESI` secretı;
  bilgisayarda `~/.santiyepro/mcp_giris_sifresi.txt`).

## Secretlar

| Ad | Ne |
|---|---|
| `GIRIS_SIFRESI` | claude.ai bağlanırken sorulan şifre |
| `FIREBASE_UID` | `~/.santiyepro/mcp_oturum.json` içindeki `uid` |
| `FIREBASE_YENILEME` | aynı dosyadaki `refresh_token` |

Firebase oturumu geçersiz olursa: `python araclar/santiyepro_mcp.py giris`,
ardından `npx wrangler secret put FIREBASE_YENILEME` (yeni `refresh_token`).

## Komutlar (bu klasörde)

```
npm test                 birim testleri
npx wrangler dev         yerelde çalıştır (.dev.vars gerekir, depoya girmez)
npx wrangler deploy      yayına al
ADRES=... SIFRE=... node test/uctan_uca.mjs   uçtan uca deneme + Python ile karşılaştırma
```
