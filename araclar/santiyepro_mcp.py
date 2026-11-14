"""ŞantiyePro MCP sunucusu (yalnızca okur).

ŞantiyePro verilerini okuyup Claude'a araç olarak sunar: şantiyeler, günlük
kayıtlar, özetler, arama, hakediş hatırlatmaları ve hakedişler.

Kaynak: buluttaki (Firestore) veri, telefondan girilenler dahil. Bulut
okunamazsa ya da giriş yapılmamışsa bilgisayardaki uygulamanın veri dosyaları
(Belgeler klasöründeki JSON'lar) kullanılır. İkisi de varsa hangisi daha yeniyse
o seçilir; her yanıtta "kaynak" ve "veri_tarihi" bildirilir.

- Ne buluta ne dosyalara HİÇBİR ŞEY yazmaz; uygulamanın eşitlemesine karışmaz.
- Yalnızca Python standart kütüphanesi kullanılır.

Veri klasörü: SANTIYEPRO_VERI ortam değişkeni, yoksa ~/Documents.
Bulut oturumu: SANTIYEPRO_OTURUM, yoksa ~/.santiyepro/mcp_oturum.json.
Komutlar:
  python santiyepro_mcp.py          MCP sunucusu (stdio, satır başına bir JSON-RPC iletisi)
  python santiyepro_mcp.py giris    tarayıcıda Google ile bir kez giriş (secrets.json gerekir)
  python santiyepro_mcp.py durum    verinin nereden ve hangi tarihten okunduğu
  python santiyepro_mcp.py cikis    bulut oturumunu siler
"""
import datetime as dt
import io
import json
import os
import sys

SURUM = '1.0.0'
PROTOKOL = '2025-06-18'


# ---------------------------------------------------------------- veri okuma

def veri_klasoru():
    return os.environ.get('SANTIYEPRO_VERI') or os.path.join(os.path.expanduser('~'), 'Documents')


def _yerel_oku(ad):
    """(veri, değişme zamanı ms) ya da dosya yoksa (None, 0)."""
    yol = os.path.join(veri_klasoru(), ad + '.json')
    try:
        zaman = int(os.path.getmtime(yol) * 1000)
        with io.open(yol, encoding='utf-8') as f:
            return json.load(f), zaman
    except FileNotFoundError:
        return None, 0


# ---------------------------------------------------------------- bulut (Firestore, yalnızca okur)
#
# Uygulama her koleksiyonu users/{uid}/data/{koleksiyon} belgesinde, "json"
# alanında metin olarak tutar ("updatedAt" alanı son yazma zamanıdır).
# Giriş bir kez yapılır (python santiyepro_mcp.py giris); Firebase yenileme
# anahtarı kullanıcının ev klasöründe saklanır, depoya girmez.

FIREBASE_PROJE = 'santiyepro-49515'
FIREBASE_ANAHTAR = 'AIzaSyCnWJIUcsiBrsZSdHndBeVHSIPCj4HlduE'  # uygulamanın Windows/web anahtarı (gizli değil)
_ZAMAN_ASIMI = 20
_ONBELLEK_SN = 60


class BulutHatasi(Exception):
    pass


def oturum_dosyasi():
    return os.environ.get('SANTIYEPRO_OTURUM') or os.path.join(os.path.expanduser('~'), '.santiyepro', 'mcp_oturum.json')


def oturum():
    try:
        with io.open(oturum_dosyasi(), encoding='utf-8') as f:
            d = json.load(f)
        return d if d.get('refresh_token') and d.get('uid') else None
    except (OSError, ValueError):
        return None


def _http(url, veri=None, basliklar=None, form=False):
    """JSON yanıtlı HTTP isteği. Hata durumunda BulutHatasi (sunucu mesajıyla)."""
    import urllib.error
    import urllib.parse
    import urllib.request
    govde = None
    basliklar = dict(basliklar or {})
    if veri is not None:
        if form:
            govde = urllib.parse.urlencode(veri).encode()
            basliklar['Content-Type'] = 'application/x-www-form-urlencoded'
        else:
            govde = json.dumps(veri).encode()
            basliklar['Content-Type'] = 'application/json'
    istek = urllib.request.Request(url, data=govde, headers=basliklar)
    try:
        with urllib.request.urlopen(istek, timeout=_ZAMAN_ASIMI) as y:
            return json.loads(y.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        try:
            ayrinti = json.loads(e.read().decode('utf-8'))
            ayrinti = ayrinti.get('error', ayrinti)
            if isinstance(ayrinti, dict):
                ayrinti = ayrinti.get('message') or ayrinti
        except ValueError:
            ayrinti = ''
        raise BulutHatasi('HTTP %s %s' % (e.code, ayrinti))
    except (urllib.error.URLError, OSError) as e:
        raise BulutHatasi('bağlantı kurulamadı (%s)' % getattr(e, 'reason', e))


_jeton = {'deger': None, 'bitis': 0.0}


def _kimlik_jetonu(o):
    """Firebase kimlik jetonu (1 saat geçerli); süresi dolunca yenileme anahtarıyla alınır."""
    import time
    if _jeton['deger'] and time.time() < _jeton['bitis']:
        return _jeton['deger']
    try:
        y = _http('https://securetoken.googleapis.com/v1/token?key=' + FIREBASE_ANAHTAR,
                  {'grant_type': 'refresh_token', 'refresh_token': o['refresh_token']}, form=True)
    except BulutHatasi as e:
        if 'TOKEN_EXPIRED' in str(e) or 'INVALID_REFRESH_TOKEN' in str(e) or 'USER_' in str(e):
            raise BulutHatasi('bulut oturumu geçersiz, yeniden giriş gerekli (python araclar/santiyepro_mcp.py giris)')
        raise
    _jeton['deger'] = y['id_token']
    _jeton['bitis'] = time.time() + int(y.get('expires_in', 3600)) - 120
    return _jeton['deger']


def _zaman_ms(rfc3339):
    """Firestore zaman damgası ("2026-11-14T08:05:01.123456Z") → ms."""
    if not rfc3339:
        return 0
    metin = rfc3339.rstrip('Z')
    ana, _, kesir = metin.partition('.')
    t = dt.datetime.strptime(ana, '%Y-%m-%dT%H:%M:%S').replace(tzinfo=dt.timezone.utc)
    return int(t.timestamp() * 1000) + int((kesir + '000')[:3])


def _bulut_oku(ad, o):
    """(veri, updatedAt ms) ya da belge yoksa (None, 0)."""
    url = ('https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/data/%s'
           % (FIREBASE_PROJE, o['uid'], ad))
    try:
        belge = _http(url, basliklar={'Authorization': 'Bearer ' + _kimlik_jetonu(o)})
    except BulutHatasi as e:
        if str(e).startswith('HTTP 404'):
            return None, 0
        raise
    alanlar = belge.get('fields') or {}
    metin = (alanlar.get('json') or {}).get('stringValue') or ''
    if not metin.strip():
        return None, 0
    zaman = _zaman_ms((alanlar.get('updatedAt') or {}).get('timestampValue')) or _zaman_ms(belge.get('updateTime'))
    return json.loads(metin), zaman


_onbellek = {}   # ad -> (okunma zamanı, veri, kaynak, ms)
_durum = {'bulut': None}  # son bulut hatası (yoksa None)


def onbellegi_temizle():
    _onbellek.clear()
    _jeton.update(deger=None, bitis=0.0)
    _durum['bulut'] = None


def _kaynak(ad):
    """Koleksiyonun en yeni hali: bulut ile bilgisayardaki dosyadan hangisi
    daha yeniyse o. Bulut okunamazsa bilgisayardaki dosya kullanılır."""
    import time
    simdi = time.time()
    k = _onbellek.get(ad)
    if k and simdi - k[0] < _ONBELLEK_SN:
        return k[1:]
    yerel, yerel_ms = _yerel_oku(ad)
    secim = (yerel, 'bilgisayar', yerel_ms)
    o = oturum()
    if o is None:
        _durum['bulut'] = 'buluta giriş yapılmamış (python araclar/santiyepro_mcp.py giris)'
    else:
        try:
            bulut, bulut_ms = _bulut_oku(ad, o)
            _durum['bulut'] = None
            if bulut is not None and (yerel is None or bulut_ms >= yerel_ms):
                secim = (bulut, 'bulut', bulut_ms)
        except (BulutHatasi, ValueError, KeyError) as e:
            _durum['bulut'] = 'bulut okunamadı, bilgisayardaki veri kullanıldı: %s' % e
    _onbellek[ad] = (simdi,) + secim
    return secim


def _oku(ad, varsayilan):
    veri = _kaynak(ad)[0]
    return varsayilan if veri is None else veri


def veri_bilgisi():
    """Yanıtlara eklenen kaynak bilgisi: günlük kayıtların nereden ve hangi
    andaki haliyle okunduğu."""
    _, kaynak, ms = _kaynak('project_logs')
    bilgi = {'veri_tarihi': dt.datetime.fromtimestamp(ms / 1000).strftime('%Y-%m-%d %H:%M') if ms else None,
             'kaynak': kaynak}
    if _durum['bulut']:
        bilgi['bulut_durumu'] = _durum['bulut']
    return bilgi


def veri_tarihi():
    return veri_bilgisi()['veri_tarihi']


# ---------------------------------------------------------------- bulut girişi (bir kez, tarayıcıyla)

def _gizli_bilgiler():
    yol = os.environ.get('SANTIYEPRO_SECRETS') or os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'secrets.json')
    try:
        with io.open(yol, encoding='utf-8') as f:
            d = json.load(f)
        return d['GOOGLE_CLIENT_ID'], d['GOOGLE_CLIENT_SECRET']
    except (OSError, ValueError, KeyError):
        raise SystemExit('Google istemci bilgileri okunamadı: %s (GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET)' % yol)


def giris():
    """Tarayıcıda Google ile giriş yapıp Firebase yenileme anahtarını saklar."""
    import base64
    import hashlib
    import http.server
    import secrets
    import urllib.parse
    import webbrowser

    istemci, gizli = _gizli_bilgiler()
    dogrulayici = secrets.token_urlsafe(64)
    meydan = base64.urlsafe_b64encode(hashlib.sha256(dogrulayici.encode()).digest()).rstrip(b'=').decode()
    durum = secrets.token_urlsafe(16)
    gelen = {}

    class Isleyici(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if 'code' not in q and 'error' not in q:
                self.send_response(404)
                self.end_headers()
                return
            gelen.update({a: v[0] for a, v in q.items()})
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            mesaj = 'Giriş alındı, bu sekmeyi kapatabilirsiniz.' if 'code' in q else 'Giriş iptal edildi.'
            self.wfile.write(('<h2 style="font-family:sans-serif">ŞantiyePro: %s</h2>' % mesaj).encode('utf-8'))

        def log_message(self, *a):
            pass

    sunucu = http.server.HTTPServer(('127.0.0.1', 0), Isleyici)
    sunucu.timeout = 300
    donus = 'http://127.0.0.1:%d' % sunucu.server_address[1]
    adres = 'https://accounts.google.com/o/oauth2/v2/auth?' + urllib.parse.urlencode({
        'client_id': istemci, 'redirect_uri': donus, 'response_type': 'code', 'scope': 'openid email',
        'code_challenge': meydan, 'code_challenge_method': 'S256', 'state': durum, 'prompt': 'select_account'})
    print('Tarayıcıda Google girişi açılıyor. Açılmazsa bu adresi açın:\n' + adres, flush=True)
    webbrowser.open(adres)
    while not gelen:
        sunucu.handle_request()
        if not gelen:
            raise SystemExit('5 dakika içinde giriş yapılmadı.')
    sunucu.server_close()
    if gelen.get('state') != durum or 'code' not in gelen:
        raise SystemExit('Giriş tamamlanmadı: %s' % gelen.get('error', 'durum uyuşmadı'))

    g = _http('https://oauth2.googleapis.com/token', {
        'code': gelen['code'], 'client_id': istemci, 'client_secret': gizli, 'redirect_uri': donus,
        'grant_type': 'authorization_code', 'code_verifier': dogrulayici}, form=True)
    f = _http('https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=' + FIREBASE_ANAHTAR, {
        'postBody': urllib.parse.urlencode({'id_token': g['id_token'], 'providerId': 'google.com'}),
        'requestUri': 'http://localhost', 'returnSecureToken': True})
    yol = oturum_dosyasi()
    os.makedirs(os.path.dirname(yol), exist_ok=True)
    with io.open(yol, 'w', encoding='utf-8') as d:
        json.dump({'uid': f['localId'], 'email': f.get('email', ''), 'refresh_token': f['refreshToken']}, d)
    print('Giriş yapıldı: %s\nOturum dosyası: %s' % (f.get('email', ''), yol))


_HARF = str.maketrans({'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', 'â': 'a', 'î': 'i', 'û': 'u'})


def sade(metin):
    """Büyük/küçük harf ve Türkçe harf farkı gözetmeden karşılaştırmak için."""
    return (metin or '').replace('I', 'ı').replace('İ', 'i').lower().translate(_HARF)


def _tarih(deger):
    try:
        return dt.date.fromisoformat(str(deger)[:10])
    except ValueError:
        return None


def _sayi(deger):
    try:
        return float(deger or 0)
    except (TypeError, ValueError):
        return 0.0


def _tam(deger):
    return int(round(_sayi(deger)))


def projeler():
    liste = _oku('projects', [])
    return [p for p in liste if isinstance(p, dict) and p.get('id')]


def kayitlar_sozlugu():
    d = _oku('project_logs', {})
    return d if isinstance(d, dict) else {}


def santiye_bul(ifade):
    """Ad (Türkçe harf/büyük-küçük harf farkı gözetmeden, parça da olur) ya da
    kimlikle şantiye bulur. Bulunamazsa ya da birden çok uyarsa ValueError."""
    tum = projeler()
    if not ifade:
        return None
    for p in tum:
        if p['id'] == ifade:
            return p
    aranan = sade(ifade)
    tam = [p for p in tum if sade(p.get('ad')) == aranan]
    if len(tam) == 1:
        return tam[0]
    uyan = [p for p in tum if aranan in sade(p.get('ad'))]
    if len(uyan) == 1:
        return uyan[0]
    adlar = ', '.join(p.get('ad', '') for p in (uyan or tum))
    if uyan:
        raise ValueError('"%s" birden çok şantiyeye uyuyor: %s' % (ifade, adlar))
    raise ValueError('"%s" adlı şantiye yok. Şantiyeler: %s' % (ifade, adlar))


def aralik(args):
    """'ay' (YYYY-MM) ya da 'baslangic'/'bitis' (YYYY-MM-DD) → (ilk, son) ya da (None, None)."""
    ay = (args.get('ay') or '').strip()
    if ay:
        try:
            yil, a = int(ay[:4]), int(ay[5:7])
            ilk = dt.date(yil, a, 1)
        except (ValueError, IndexError):
            raise ValueError('ay "YYYY-MM" biçiminde olmalı (ör. 2026-11)')
        son = (dt.date(yil + (a == 12), a % 12 + 1, 1) - dt.timedelta(days=1))
        return ilk, son
    ilk = _tarih(args['baslangic']) if args.get('baslangic') else None
    son = _tarih(args['bitis']) if args.get('bitis') else None
    if args.get('baslangic') and ilk is None or args.get('bitis') and son is None:
        raise ValueError('tarihler "YYYY-MM-DD" biçiminde olmalı')
    return ilk, son


def secili_kayitlar(args):
    """(proje, kayit, tarih) üçlüleri, tarihe göre sıralı."""
    p = santiye_bul(args.get('santiye'))
    ilk, son = aralik(args)
    hepsi = kayitlar_sozlugu()
    sonuc = []
    for proje in projeler():
        if p is not None and proje['id'] != p['id']:
            continue
        for k in hepsi.get(proje['id'], []) or []:
            if not isinstance(k, dict):
                continue
            t = _tarih(k.get('tarih'))
            if t is None or (ilk and t < ilk) or (son and t > son):
                continue
            sonuc.append((proje, k, t))
    sonuc.sort(key=lambda x: (x[2], sade(x[0].get('ad'))))
    return sonuc


# ---------------------------------------------------------------- kayıt biçimleri

def vinc_saat(baslangic, bitis, mola):
    try:
        b = [int(x) for x in str(baslangic).split(':')[:2]]
        s = [int(x) for x in str(bitis).split(':')[:2]]
    except ValueError:
        return 0.0
    if len(b) < 2 or len(s) < 2:
        return 0.0
    fark = (s[0] * 60 + s[1]) - (b[0] * 60 + b[1])
    if fark < 0:
        fark += 24 * 60
    net = fark - _tam(mola)
    return round(max(net, 0) / 60.0, 2)


def vincler(k):
    liste = k.get('vincler') or []
    if not liste and (k.get('vincFirmaAdi') or k.get('vincBaslangic')):
        liste = [{'firmaAdi': k.get('vincFirmaAdi', ''), 'baslangic': k.get('vincBaslangic', ''),
                  'bitis': k.get('vincBitis', ''), 'mola': k.get('vincMola', 0), 'aciklama': ''}]
    return [{'firma': v.get('firmaAdi', ''), 'baslangic': v.get('baslangic', ''), 'bitis': v.get('bitis', ''),
             'mola_dk': _tam(v.get('mola')), 'net_saat': vinc_saat(v.get('baslangic'), v.get('bitis'), v.get('mola')),
             'aciklama': v.get('aciklama', '')}
            for v in liste if isinstance(v, dict) and (v.get('firmaAdi') or v.get('baslangic'))]


def yevmiyeler(k):
    liste = k.get('yevmiyeler') or []
    if not liste and (k.get('yevmiyeEkipAdi') or _sayi(k.get('yevmiyeMiktari')) > 0):
        liste = [{'ekipAdi': k.get('yevmiyeEkipAdi', ''), 'miktar': k.get('yevmiyeMiktari', 0),
                  'aciklama': k.get('yevmiyeAciklama', '')}]
    return [{'ekip': y.get('ekipAdi', ''), 'miktar': _sayi(y.get('miktar')), 'aciklama': y.get('aciklama', '')}
            for y in liste if isinstance(y, dict) and (y.get('ekipAdi') or _sayi(y.get('miktar')) > 0)]


def ogunler(k):
    def ogun(on):
        return {'kalipci': _tam(k.get(on + 'Kalipci')), 'demirci': _tam(k.get(on + 'Demirci')),
                'diger': _tam(k.get(on + 'Diger'))}
    sonuc = {}
    for ad, on in (('kahvalti', 'kahvalti'), ('ogle', 'yemek'), ('aksam', 'aksam')):
        o = ogun(on)
        if sum(o.values()):
            sonuc[ad] = dict(o, toplam=sum(o.values()))
    return sonuc


def kayit_bicimi(proje, k, t):
    sonuc = {
        'santiye': proje.get('ad', ''),
        'tarih': t.isoformat(),
        'kalipci': _tam(k.get('kalipci')),
        'demirci': _tam(k.get('demirci')),
        'diger': _tam(k.get('diger')),
        'kalipci_isi': (k.get('kalipciYapilanIs') or '').strip(),
        'demirci_isi': (k.get('demirciYapilanIs') or '').strip(),
        'beton': (k.get('beton') or '').strip(),
        'notlar': (k.get('notlar') or '').strip(),
        'hakedis_hatirlatma': (k.get('hakedisNotu') or '').strip(),
        'yemek': ogunler(k),
        'vincler': vincler(k),
        'yevmiyeler': yevmiyeler(k),
        'fotograf_sayisi': len(k.get('fotografYollari') or []),
    }
    if k.get('hava') or k.get('havaDurdu'):
        sonuc['hava'] = {'durum': k.get('hava', ''), 'en_dusuk': k.get('havaMin'), 'en_yuksek': k.get('havaMax'),
                         'calisilamadi': bool(k.get('havaDurdu'))}
    # Boş alanlar yanıtı şişirmesin.
    return {a: d for a, d in sonuc.items() if d not in ('', [], {}, None)}


# ---------------------------------------------------------------- araçlar

def arac_santiyeler(args):
    hepsi = kayitlar_sozlugu()
    sonuc = []
    for p in projeler():
        tarihler = sorted(t for t in (_tarih(k.get('tarih')) for k in hepsi.get(p['id'], []) or [] if isinstance(k, dict)) if t)
        sonuc.append({
            'ad': p.get('ad', ''),
            'aciklama': p.get('aciklama', ''),
            'durum': p.get('durum', ''),
            'baslangic': str(p.get('baslangicTarihi', ''))[:10],
            'planlanan_gun': p.get('toplamGun'),
            'kahvalti_var': bool(p.get('kahvaltiVar')),
            'aksam_yemegi_var': bool(p.get('aksamVar')),
            'kayit_sayisi': len(tarihler),
            'ilk_kayit': tarihler[0].isoformat() if tarihler else None,
            'son_kayit': tarihler[-1].isoformat() if tarihler else None,
        })
    return {'santiyeler': sonuc, 'ekipler': _oku('ekipler', [])}


def arac_gunluk_kayitlar(args):
    secili = secili_kayitlar(args)
    en_fazla = max(1, min(_tam(args.get('en_fazla') or 60), 400))
    # En yeni kayıtlar önce kesilmesin: sondan alınır, tarih sırası korunur.
    kesildi = len(secili) > en_fazla
    secili = secili[-en_fazla:]
    return {'kayit_sayisi': len(secili), 'kesildi': kesildi,
            'kayitlar': [kayit_bicimi(p, k, t) for p, k, t in secili]}


def arac_ozet(args):
    secili = secili_kayitlar(args)
    gruplar = {}
    for p, k, t in secili:
        o = gruplar.setdefault(p['id'], {
            'santiye': p.get('ad', ''), 'kayitli_gun': 0, 'ilk': t.isoformat(), 'son': t.isoformat(),
            'kalipci_adam_gun': 0, 'demirci_adam_gun': 0, 'diger_adam_gun': 0,
            'vinc_saat': 0.0, 'vinc_gun': 0, 'yevmiye': 0.0,
            'yemek': {'kahvalti': 0, 'ogle': 0, 'aksam': 0},
            'beton_gunleri': [], 'hava_nedeniyle_durulan_gunler': [], 'hakedis_hatirlatma_sayisi': 0,
            'fotograf': 0,
        })
        o['kayitli_gun'] += 1
        o['son'] = t.isoformat()
        o['kalipci_adam_gun'] += _tam(k.get('kalipci'))
        o['demirci_adam_gun'] += _tam(k.get('demirci'))
        o['diger_adam_gun'] += _tam(k.get('diger'))
        v = vincler(k)
        o['vinc_saat'] = round(o['vinc_saat'] + sum(x['net_saat'] for x in v), 2)
        o['vinc_gun'] += 1 if v else 0
        o['yevmiye'] += sum(y['miktar'] for y in yevmiyeler(k))
        for ad, d in ogunler(k).items():
            o['yemek'][ad] += d['toplam']
        if (k.get('beton') or '').strip():
            o['beton_gunleri'].append({'tarih': t.isoformat(), 'beton': k['beton'].strip()})
        if k.get('havaDurdu'):
            o['hava_nedeniyle_durulan_gunler'].append(t.isoformat())
        if (k.get('hakedisNotu') or '').strip():
            o['hakedis_hatirlatma_sayisi'] += 1
        o['fotograf'] += len(k.get('fotografYollari') or [])
    for o in gruplar.values():
        o['toplam_adam_gun'] = o['kalipci_adam_gun'] + o['demirci_adam_gun'] + o['diger_adam_gun']
    ozetler = sorted(gruplar.values(), key=lambda o: sade(o['santiye']))
    genel = {a: sum(o[a] for o in ozetler) for a in
             ('kayitli_gun', 'kalipci_adam_gun', 'demirci_adam_gun', 'diger_adam_gun', 'toplam_adam_gun', 'yevmiye')}
    genel['vinc_saat'] = round(sum(o['vinc_saat'] for o in ozetler), 2)
    genel['yemek'] = {a: sum(o['yemek'][a] for o in ozetler) for a in ('kahvalti', 'ogle', 'aksam')}
    return {'santiyeler': ozetler, 'genel_toplam': genel}


_ARANAN_ALANLAR = (('kalipci_isi', 'kalipciYapilanIs'), ('demirci_isi', 'demirciYapilanIs'), ('beton', 'beton'),
                   ('notlar', 'notlar'), ('hakedis_hatirlatma', 'hakedisNotu'))


def arac_ara(args):
    aranan = sade((args.get('metin') or '').strip())
    if not aranan:
        raise ValueError('aranacak metin boş')
    bulunan = []
    for p, k, t in secili_kayitlar(args):
        alanlar = [(ad, (k.get(anahtar) or '').strip()) for ad, anahtar in _ARANAN_ALANLAR]
        alanlar += [('vinc', ('%s %s' % (v['firma'], v['aciklama'])).strip()) for v in vincler(k)]
        alanlar += [('yevmiye', ('%s %s' % (y['ekip'], y['aciklama'])).strip()) for y in yevmiyeler(k)]
        for ad, metin in alanlar:
            if metin and aranan in sade(metin):
                bulunan.append({'santiye': p.get('ad', ''), 'tarih': t.isoformat(), 'alan': ad, 'metin': metin})
    bulunan.sort(key=lambda b: b['tarih'], reverse=True)
    return {'sonuc_sayisi': len(bulunan), 'sonuclar': bulunan[:200]}


def arac_hakedis_hatirlatmalari(args):
    liste = [{'tarih': t.isoformat(), 'santiye': p.get('ad', ''), 'hatirlatma': k['hakedisNotu'].strip()}
             for p, k, t in secili_kayitlar(args) if (k.get('hakedisNotu') or '').strip()]
    return {'hatirlatma_sayisi': len(liste), 'hatirlatmalar': liste}


def arac_hakedisler(args):
    p = santiye_bul(args.get('santiye'))
    adlar = {x['id']: x.get('ad', '') for x in projeler()}
    sonuc = []
    for h in _oku('hakedisler', []):
        if not isinstance(h, dict) or (p is not None and h.get('projeId') != p['id']):
            continue
        kalemler = []
        for k in h.get('kalemler') or []:
            miktar, fiyat = _sayi(k.get('miktar')), _sayi(k.get('birimFiyat'))
            kalemler.append({'kalem': k.get('ad', ''), 'birim': k.get('birim', ''), 'miktar': miktar,
                             'birim_fiyat': fiyat or None, 'tutar': round(miktar * fiyat, 2) if fiyat else None,
                             'ekip': k.get('ekip', '')})
        sonuc.append({'santiye': adlar.get(h.get('projeId'), h.get('projeId')),
                      'donem_baslangic': str(h.get('baslangic', ''))[:10], 'donem_bitis': str(h.get('bitis', ''))[:10],
                      'kalemler': kalemler, 'not': h.get('not', ''),
                      'toplam_tutar': round(sum(k['tutar'] or 0 for k in kalemler), 2)})
    sonuc.sort(key=lambda h: h['donem_bitis'], reverse=True)
    return {'hakedis_sayisi': len(sonuc), 'hakedisler': sonuc}


_SANTIYE = {'type': 'string', 'description': 'Şantiye adı (parçası da olur, ör. "gera") ya da kimliği. Boşsa tüm şantiyeler.'}
_AY = {'type': 'string', 'description': 'Ay, "YYYY-MM" (ör. 2026-11). Verilirse başlangıç/bitiş yok sayılır.'}
_BAS = {'type': 'string', 'description': 'Başlangıç tarihi "YYYY-MM-DD" (dahil).'}
_BIT = {'type': 'string', 'description': 'Bitiş tarihi "YYYY-MM-DD" (dahil).'}
_SUZGEC = {'santiye': _SANTIYE, 'ay': _AY, 'baslangic': _BAS, 'bitis': _BIT}

ARACLAR = [
    {
        'name': 'santiyeler',
        'description': 'Tüm şantiyeleri (projeleri) listeler: durum, başlangıç, planlanan süre, kayıt sayısı, ilk/son kayıt '
                       'tarihi; ayrıca yevmiye ekipleri. Başka bir araçta şantiye adını bilmiyorsan önce bunu çağır.',
        'inputSchema': {'type': 'object', 'properties': {}},
        'fonksiyon': arac_santiyeler,
    },
    {
        'name': 'gunluk_kayitlar',
        'description': 'Günlük şantiye kayıtları (puantaj): çalışan sayıları (kalıpçı/demirci/diğer), yapılan işler, beton, '
                       'notlar, hakediş hatırlatması, hava, yemek (kahvaltı/öğle/akşam), vinç (net saat), yevmiye. '
                       'Tarihe göre sıralı; çok kayıt varsa en yeniler döner.',
        'inputSchema': {'type': 'object', 'properties': dict(_SUZGEC, en_fazla={
            'type': 'integer', 'description': 'En fazla kayıt sayısı (varsayılan 60, en çok 400).'})},
        'fonksiyon': arac_gunluk_kayitlar,
    },
    {
        'name': 'ozet',
        'description': 'Şantiye bazında toplamlar: kayıtlı gün, kalıpçı/demirci/diğer adam-gün, vinç saati ve günü, yevmiye, '
                       'öğünlere göre yemek, beton dökülen günler, hava nedeniyle çalışılamayan günler, hakediş hatırlatma '
                       'sayısı; ayrıca genel toplam. Puantaj, hakediş ve yemek mutabakatı soruları için.',
        'inputSchema': {'type': 'object', 'properties': _SUZGEC},
        'fonksiyon': arac_ozet,
    },
    {
        'name': 'ara',
        'description': 'Günlük kayıtların yazı alanlarında (işler, beton, notlar, hakediş hatırlatması, vinç, yevmiye) arar. '
                       'Büyük/küçük harf ve Türkçe harf farkı gözetmez.',
        'inputSchema': {'type': 'object', 'properties': dict(_SUZGEC, metin={'type': 'string', 'description': 'Aranacak metin.'}),
                        'required': ['metin']},
        'fonksiyon': arac_ara,
    },
    {
        'name': 'hakedis_hatirlatmalari',
        'description': 'Günlük kayıtlara yazılmış hakediş hatırlatmaları (ek iş, sözleşme dışı iş, bekleme vb.), tarih ve şantiyeyle.',
        'inputSchema': {'type': 'object', 'properties': _SUZGEC},
        'fonksiyon': arac_hakedis_hatirlatmalari,
    },
    {
        'name': 'hakedisler',
        'description': 'Uygulamada girilmiş hakediş dönemleri ve kalemleri (kalıp m², demir ton, beton m³, iskele vb.; miktar, '
                       'birim fiyat, tutar).',
        'inputSchema': {'type': 'object', 'properties': {'santiye': _SANTIYE}},
        'fonksiyon': arac_hakedisler,
    },
]

TALIMAT = ('ŞantiyePro: bir kalıp-demir taşeronunun şantiye kayıtları (Türkçe). Veriler buluttan (telefon ve bilgisayardan '
           'girilen her şey) okunur; bulut okunamazsa bilgisayardaki uygulamanın son eşitlendiği hali kullanılır. Yanıttaki '
           'kaynak ("bulut"/"bilgisayar") ve veri_tarihi bunu gösterir; bulut_durumu varsa kullanıcıya söyle. Araçlar '
           'yalnızca okur; kayıt eklenemez ya da değiştirilemez.')


def arac_cagir(ad, args):
    for a in ARACLAR:
        if a['name'] == ad:
            sonuc = a['fonksiyon'](args or {})
            sonuc.update(veri_bilgisi())
            return sonuc
    raise KeyError(ad)


# ---------------------------------------------------------------- MCP (JSON-RPC, stdio)

def isle(ileti):
    """Bir JSON-RPC iletisini işler; yanıt (dict) ya da bildirimse None döner."""
    yontem = ileti.get('method')
    kimlik = ileti.get('id')
    if kimlik is None:
        return None  # bildirim (ör. notifications/initialized)

    def cevap(sonuc):
        return {'jsonrpc': '2.0', 'id': kimlik, 'result': sonuc}

    def hata(kod, mesaj):
        return {'jsonrpc': '2.0', 'id': kimlik, 'error': {'code': kod, 'message': mesaj}}

    if yontem == 'initialize':
        istenen = (ileti.get('params') or {}).get('protocolVersion') or PROTOKOL
        return cevap({'protocolVersion': istenen, 'capabilities': {'tools': {}},
                      'serverInfo': {'name': 'santiyepro', 'version': SURUM}, 'instructions': TALIMAT})
    if yontem == 'ping':
        return cevap({})
    if yontem == 'tools/list':
        return cevap({'tools': [{k: v for k, v in a.items() if k != 'fonksiyon'} for a in ARACLAR]})
    if yontem == 'tools/call':
        p = ileti.get('params') or {}
        try:
            sonuc = arac_cagir(p.get('name'), p.get('arguments'))
            return cevap({'content': [{'type': 'text', 'text': json.dumps(sonuc, ensure_ascii=False)}]})
        except KeyError:
            return hata(-32602, 'Bilinmeyen araç: %s' % p.get('name'))
        except ValueError as e:
            return cevap({'content': [{'type': 'text', 'text': str(e)}], 'isError': True})
        except Exception as e:  # dosya bozuk vb.
            return cevap({'content': [{'type': 'text', 'text': 'Veri okunamadı: %s' % e}], 'isError': True})
    return hata(-32601, 'Desteklenmeyen yöntem: %s' % yontem)


def calistir(giris=None, cikis=None):
    giris = giris or io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8')
    cikis = cikis or io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', newline='\n')
    for satir in giris:
        satir = satir.strip()
        if not satir:
            continue
        try:
            ileti = json.loads(satir)
        except ValueError:
            yanit = {'jsonrpc': '2.0', 'id': None, 'error': {'code': -32700, 'message': 'JSON okunamadı'}}
        else:
            yanit = isle(ileti) if isinstance(ileti, dict) else None
        if yanit is not None:
            cikis.write(json.dumps(yanit, ensure_ascii=False) + '\n')
            cikis.flush()


if __name__ == '__main__':
    komut = sys.argv[1] if len(sys.argv) > 1 else ''
    if komut == 'giris':
        giris()
    elif komut == 'cikis':
        if os.path.exists(oturum_dosyasi()):
            os.remove(oturum_dosyasi())
        print('Bulut oturumu silindi.')
    elif komut == 'durum':
        print(json.dumps(veri_bilgisi(), ensure_ascii=False))
    else:
        calistir()
