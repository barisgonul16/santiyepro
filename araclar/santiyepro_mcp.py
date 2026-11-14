"""ŞantiyePro MCP sunucusu (yalnızca okur).

Bilgisayardaki ŞantiyePro uygulamasının veri dosyalarını (Belgeler klasöründeki
JSON'lar) okuyup Claude'a araç olarak sunar: şantiyeler, günlük kayıtlar,
özetler, arama, hakediş hatırlatmaları ve hakedişler.

- Dosyalara HİÇBİR ŞEY yazmaz; uygulamanın bulut eşitlemesine karışmaz.
- Yalnızca Python standart kütüphanesi kullanılır; internete bağlanmaz.
- Veriler, bilgisayardaki uygulamanın en son eşitlendiği andaki kadar günceldir
  (her yanıtta "veri_tarihi" olarak bildirilir).

Veri klasörü: SANTIYEPRO_VERI ortam değişkeni, yoksa ~/Documents.
Çalıştırma: python santiyepro_mcp.py   (MCP stdio, satır başına bir JSON-RPC iletisi)
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


def _oku(ad, varsayilan):
    yol = os.path.join(veri_klasoru(), ad + '.json')
    try:
        with io.open(yol, encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        return varsayilan


def veri_tarihi():
    yol = os.path.join(veri_klasoru(), 'project_logs.json')
    try:
        return dt.datetime.fromtimestamp(os.path.getmtime(yol)).strftime('%Y-%m-%d %H:%M')
    except OSError:
        return None


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

TALIMAT = ('ŞantiyePro: bir kalıp-demir taşeronunun şantiye kayıtları (Türkçe). Veriler bilgisayardaki uygulamanın en son '
           'eşitlendiği ana kadardır (yanıttaki veri_tarihi); daha yeni kayıtlar için kullanıcının bilgisayardaki uygulamayı '
           'açması gerekir. Araçlar yalnızca okur; kayıt eklenemez ya da değiştirilemez.')


def arac_cagir(ad, args):
    for a in ARACLAR:
        if a['name'] == ad:
            sonuc = a['fonksiyon'](args or {})
            sonuc['veri_tarihi'] = veri_tarihi()
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
    calistir()
