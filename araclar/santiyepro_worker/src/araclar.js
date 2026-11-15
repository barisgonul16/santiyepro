// ŞantiyePro araçları (yalnızca okur). araclar/santiyepro_mcp.py ile aynı
// mantık ve aynı yanıt biçimi; veri `oku(ad)` ile dışarıdan verilir, böylece
// hem Worker'da (Firestore) hem testte (sahte veri) çalışır.

export class KullaniciHatasi extends Error {}

const HARF = { ç: 'c', ğ: 'g', ı: 'i', ö: 'o', ş: 's', ü: 'u', â: 'a', î: 'i', û: 'u' };

/** Büyük/küçük harf ve Türkçe harf farkı gözetmeden karşılaştırmak için. */
export function sade(metin) {
  return String(metin || '')
    .replaceAll('I', 'ı')
    .replaceAll('İ', 'i')
    .toLowerCase()
    .replace(/[çğıöşüâîû]/g, (h) => HARF[h]);
}

/** "YYYY-MM-DD" (geçerli bir gün) ya da null. Python'daki date.fromisoformat(str[:10]). */
export function tarih(deger) {
  if (deger === null || deger === undefined) return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(deger).slice(0, 10));
  if (!m) return null;
  const [y, a, g] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const d = new Date(Date.UTC(y, a - 1, g));
  if (y < 1 || d.getUTCFullYear() !== y || d.getUTCMonth() !== a - 1 || d.getUTCDate() !== g) return null;
  return m[0];
}

export function sayi(deger) {
  if (!deger) return 0;
  if (typeof deger === 'boolean') return deger ? 1 : 0;
  if (typeof deger === 'string' && !deger.trim()) return 0;
  const n = Number(deger);
  return Number.isFinite(n) ? n : 0;
}

/** Python round(): yarımda çifte yuvarlar (2.5 → 2, 3.5 → 4). */
function cifteYuvarla(x) {
  const t = Math.floor(x);
  const f = x - t;
  if (f > 0.5) return t + 1;
  if (f < 0.5) return t;
  return t % 2 === 0 ? t : t + 1;
}

export function tam(deger) {
  return cifteYuvarla(sayi(deger));
}

function yuvarla2(x) {
  return Math.round((x + Number.EPSILON) * 100) / 100;
}

function metin(deger) {
  return typeof deger === 'string' ? deger.trim() : '';
}

function kucuktur(a, b) {
  return a < b ? -1 : a > b ? 1 : 0;
}

export class Veri {
  /** oku(ad) → koleksiyonun verisi ya da yoksa null (Promise). */
  constructor(oku) {
    this._oku = oku;
    this._bellek = new Map();
  }

  async al(ad, varsayilan) {
    if (!this._bellek.has(ad)) this._bellek.set(ad, this._oku(ad));
    const v = await this._bellek.get(ad);
    return v === null || v === undefined ? varsayilan : v;
  }

  async projeler() {
    const liste = await this.al('projects', []);
    return Array.isArray(liste) ? liste.filter((p) => p && typeof p === 'object' && p.id) : [];
  }

  async kayitlarSozlugu() {
    const d = await this.al('project_logs', {});
    return d && typeof d === 'object' && !Array.isArray(d) ? d : {};
  }

  /** Ad (Türkçe harf/büyük-küçük harf farkı gözetmeden, parça da olur) ya da kimlikle şantiye. */
  async santiyeBul(ifade) {
    const tum = await this.projeler();
    if (!ifade) return null;
    for (const p of tum) if (p.id === ifade) return p;
    const aranan = sade(ifade);
    const tamUyan = tum.filter((p) => sade(p.ad) === aranan);
    if (tamUyan.length === 1) return tamUyan[0];
    const uyan = tum.filter((p) => sade(p.ad).includes(aranan));
    if (uyan.length === 1) return uyan[0];
    const adlar = (uyan.length ? uyan : tum).map((p) => p.ad || '').join(', ');
    if (uyan.length) throw new KullaniciHatasi(`"${ifade}" birden çok şantiyeye uyuyor: ${adlar}`);
    throw new KullaniciHatasi(`"${ifade}" adlı şantiye yok. Şantiyeler: ${adlar}`);
  }

  /** (proje, kayıt, tarih) üçlüleri, tarihe göre sıralı. */
  async seciliKayitlar(args) {
    const p = await this.santiyeBul(args.santiye);
    const [ilk, son] = aralik(args);
    const hepsi = await this.kayitlarSozlugu();
    const sonuc = [];
    for (const proje of await this.projeler()) {
      if (p !== null && proje.id !== p.id) continue;
      const liste = hepsi[proje.id];
      for (const k of Array.isArray(liste) ? liste : []) {
        if (!k || typeof k !== 'object') continue;
        const t = tarih(k.tarih);
        if (t === null || (ilk && t < ilk) || (son && t > son)) continue;
        sonuc.push([proje, k, t]);
      }
    }
    sonuc.sort((a, b) => kucuktur(a[2], b[2]) || kucuktur(sade(a[0].ad), sade(b[0].ad)));
    return sonuc;
  }
}

/** 'ay' (YYYY-MM) ya da 'baslangic'/'bitis' (YYYY-MM-DD) → [ilk, son] (yoksa null). */
export function aralik(args) {
  const ay = String(args.ay || '').trim();
  if (ay) {
    const yil = Number(ay.slice(0, 4));
    const a = Number(ay.slice(5, 7));
    if (!/^\d{4}$/.test(ay.slice(0, 4)) || !/^\d{1,2}$/.test(ay.slice(5, 7).trim()) || a < 1 || a > 12 || yil < 1) {
      throw new KullaniciHatasi('ay "YYYY-MM" biçiminde olmalı (ör. 2026-11)');
    }
    const ilk = new Date(Date.UTC(yil, a - 1, 1)).toISOString().slice(0, 10);
    const son = new Date(Date.UTC(yil, a, 0)).toISOString().slice(0, 10);
    return [ilk, son];
  }
  const ilk = args.baslangic ? tarih(args.baslangic) : null;
  const son = args.bitis ? tarih(args.bitis) : null;
  if ((args.baslangic && ilk === null) || (args.bitis && son === null)) {
    throw new KullaniciHatasi('tarihler "YYYY-MM-DD" biçiminde olmalı');
  }
  return [ilk, son];
}

// ---------------------------------------------------------------- kayıt biçimleri

function saatDakika(deger) {
  const parcalar = String(deger ?? '').split(':').slice(0, 2);
  if (!parcalar.every((x) => /^\s*[+-]?\d+\s*$/.test(x))) return null;
  return parcalar.map((x) => parseInt(x, 10));
}

export function vincSaat(baslangic, bitis, mola) {
  const b = saatDakika(baslangic);
  const s = saatDakika(bitis);
  if (!b || !s || b.length < 2 || s.length < 2) return 0;
  let fark = s[0] * 60 + s[1] - (b[0] * 60 + b[1]);
  if (fark < 0) fark += 24 * 60;
  const net = fark - tam(mola);
  return yuvarla2(Math.max(net, 0) / 60);
}

export function vincler(k) {
  let liste = Array.isArray(k.vincler) ? k.vincler : [];
  if (!liste.length && (k.vincFirmaAdi || k.vincBaslangic)) {
    liste = [{ firmaAdi: k.vincFirmaAdi ?? '', baslangic: k.vincBaslangic ?? '', bitis: k.vincBitis ?? '', mola: k.vincMola ?? 0, aciklama: '' }];
  }
  return liste
    .filter((v) => v && typeof v === 'object' && (v.firmaAdi || v.baslangic))
    .map((v) => ({
      firma: v.firmaAdi ?? '',
      baslangic: v.baslangic ?? '',
      bitis: v.bitis ?? '',
      mola_dk: tam(v.mola),
      net_saat: vincSaat(v.baslangic, v.bitis, v.mola),
      aciklama: v.aciklama ?? '',
    }));
}

export function yevmiyeler(k) {
  let liste = Array.isArray(k.yevmiyeler) ? k.yevmiyeler : [];
  if (!liste.length && (k.yevmiyeEkipAdi || sayi(k.yevmiyeMiktari) > 0)) {
    liste = [{ ekipAdi: k.yevmiyeEkipAdi ?? '', miktar: k.yevmiyeMiktari ?? 0, aciklama: k.yevmiyeAciklama ?? '' }];
  }
  return liste
    .filter((y) => y && typeof y === 'object' && (y.ekipAdi || sayi(y.miktar) > 0))
    .map((y) => ({ ekip: y.ekipAdi ?? '', miktar: sayi(y.miktar), aciklama: y.aciklama ?? '' }));
}

export function ogunler(k) {
  const sonuc = {};
  for (const [ad, on] of [['kahvalti', 'kahvalti'], ['ogle', 'yemek'], ['aksam', 'aksam']]) {
    const o = { kalipci: tam(k[on + 'Kalipci']), demirci: tam(k[on + 'Demirci']), diger: tam(k[on + 'Diger']) };
    const toplam = o.kalipci + o.demirci + o.diger;
    if (toplam) sonuc[ad] = { ...o, toplam };
  }
  return sonuc;
}

function bos(d) {
  if (d === '' || d === null || d === undefined) return true;
  if (Array.isArray(d)) return d.length === 0;
  if (typeof d === 'object') return Object.keys(d).length === 0;
  return false;
}

export function kayitBicimi(proje, k, t) {
  const sonuc = {
    santiye: proje.ad ?? '',
    tarih: t,
    kalipci: tam(k.kalipci),
    demirci: tam(k.demirci),
    diger: tam(k.diger),
    kalipci_isi: metin(k.kalipciYapilanIs),
    demirci_isi: metin(k.demirciYapilanIs),
    beton: metin(k.beton),
    notlar: metin(k.notlar),
    hakedis_hatirlatma: metin(k.hakedisNotu),
    yemek: ogunler(k),
    vincler: vincler(k),
    yevmiyeler: yevmiyeler(k),
    fotograf_sayisi: Array.isArray(k.fotografYollari) ? k.fotografYollari.length : 0,
  };
  if (k.hava || k.havaDurdu) {
    sonuc.hava = { durum: k.hava ?? '', en_dusuk: k.havaMin ?? null, en_yuksek: k.havaMax ?? null, calisilamadi: Boolean(k.havaDurdu) };
  }
  // Boş alanlar yanıtı şişirmesin.
  return Object.fromEntries(Object.entries(sonuc).filter(([, d]) => !bos(d)));
}

// ---------------------------------------------------------------- araçlar

async function aracSantiyeler(veri) {
  const hepsi = await veri.kayitlarSozlugu();
  const sonuc = [];
  for (const p of await veri.projeler()) {
    const liste = Array.isArray(hepsi[p.id]) ? hepsi[p.id] : [];
    const tarihler = liste
      .filter((k) => k && typeof k === 'object')
      .map((k) => tarih(k.tarih))
      .filter(Boolean)
      .sort();
    sonuc.push({
      ad: p.ad ?? '',
      aciklama: p.aciklama ?? '',
      durum: p.durum ?? '',
      baslangic: String(p.baslangicTarihi ?? '').slice(0, 10),
      planlanan_gun: p.toplamGun ?? null,
      kahvalti_var: Boolean(p.kahvaltiVar),
      aksam_yemegi_var: Boolean(p.aksamVar),
      kayit_sayisi: tarihler.length,
      ilk_kayit: tarihler.length ? tarihler[0] : null,
      son_kayit: tarihler.length ? tarihler[tarihler.length - 1] : null,
    });
  }
  return { santiyeler: sonuc, ekipler: await veri.al('ekipler', []) };
}

async function aracGunlukKayitlar(veri, args) {
  let secili = await veri.seciliKayitlar(args);
  const enFazla = Math.max(1, Math.min(tam(args.en_fazla || 60), 400));
  // En yeni kayıtlar önce kesilmesin: sondan alınır, tarih sırası korunur.
  const kesildi = secili.length > enFazla;
  secili = secili.slice(-enFazla);
  return { kayit_sayisi: secili.length, kesildi, kayitlar: secili.map(([p, k, t]) => kayitBicimi(p, k, t)) };
}

async function aracOzet(veri, args) {
  const gruplar = new Map();
  for (const [p, k, t] of await veri.seciliKayitlar(args)) {
    if (!gruplar.has(p.id)) {
      gruplar.set(p.id, {
        santiye: p.ad ?? '', kayitli_gun: 0, ilk: t, son: t,
        kalipci_adam_gun: 0, demirci_adam_gun: 0, diger_adam_gun: 0,
        vinc_saat: 0, vinc_gun: 0, yevmiye: 0,
        yemek: { kahvalti: 0, ogle: 0, aksam: 0 },
        beton_gunleri: [], hava_nedeniyle_durulan_gunler: [], hakedis_hatirlatma_sayisi: 0,
        fotograf: 0,
      });
    }
    const o = gruplar.get(p.id);
    o.kayitli_gun += 1;
    o.son = t;
    o.kalipci_adam_gun += tam(k.kalipci);
    o.demirci_adam_gun += tam(k.demirci);
    o.diger_adam_gun += tam(k.diger);
    const v = vincler(k);
    o.vinc_saat = yuvarla2(o.vinc_saat + v.reduce((s, x) => s + x.net_saat, 0));
    o.vinc_gun += v.length ? 1 : 0;
    o.yevmiye += yevmiyeler(k).reduce((s, y) => s + y.miktar, 0);
    for (const [ad, d] of Object.entries(ogunler(k))) o.yemek[ad] += d.toplam;
    if (metin(k.beton)) o.beton_gunleri.push({ tarih: t, beton: metin(k.beton) });
    if (k.havaDurdu) o.hava_nedeniyle_durulan_gunler.push(t);
    if (metin(k.hakedisNotu)) o.hakedis_hatirlatma_sayisi += 1;
    o.fotograf += Array.isArray(k.fotografYollari) ? k.fotografYollari.length : 0;
  }
  for (const o of gruplar.values()) o.toplam_adam_gun = o.kalipci_adam_gun + o.demirci_adam_gun + o.diger_adam_gun;
  const ozetler = [...gruplar.values()].sort((a, b) => kucuktur(sade(a.santiye), sade(b.santiye)));
  const genel = {};
  for (const a of ['kayitli_gun', 'kalipci_adam_gun', 'demirci_adam_gun', 'diger_adam_gun', 'toplam_adam_gun', 'yevmiye']) {
    genel[a] = ozetler.reduce((s, o) => s + o[a], 0);
  }
  genel.vinc_saat = yuvarla2(ozetler.reduce((s, o) => s + o.vinc_saat, 0));
  genel.yemek = {};
  for (const a of ['kahvalti', 'ogle', 'aksam']) genel.yemek[a] = ozetler.reduce((s, o) => s + o.yemek[a], 0);
  return { santiyeler: ozetler, genel_toplam: genel };
}

const ARANAN_ALANLAR = [
  ['kalipci_isi', 'kalipciYapilanIs'], ['demirci_isi', 'demirciYapilanIs'], ['beton', 'beton'],
  ['notlar', 'notlar'], ['hakedis_hatirlatma', 'hakedisNotu'],
];

async function aracAra(veri, args) {
  const aranan = sade(String(args.metin || '').trim());
  if (!aranan) throw new KullaniciHatasi('aranacak metin boş');
  const bulunan = [];
  for (const [p, k, t] of await veri.seciliKayitlar(args)) {
    const alanlar = ARANAN_ALANLAR.map(([ad, anahtar]) => [ad, metin(k[anahtar])]);
    for (const v of vincler(k)) alanlar.push(['vinc', `${v.firma} ${v.aciklama}`.trim()]);
    for (const y of yevmiyeler(k)) alanlar.push(['yevmiye', `${y.ekip} ${y.aciklama}`.trim()]);
    for (const [ad, m] of alanlar) {
      if (m && sade(m).includes(aranan)) bulunan.push({ santiye: p.ad ?? '', tarih: t, alan: ad, metin: m });
    }
  }
  // Tarihe göre azalan; aynı gündekiler bulunduğu sırada kalır (Python'daki gibi kararlı).
  bulunan.sort((a, b) => kucuktur(b.tarih, a.tarih));
  return { sonuc_sayisi: bulunan.length, sonuclar: bulunan.slice(0, 200) };
}

async function aracHakedisHatirlatmalari(veri, args) {
  const liste = (await veri.seciliKayitlar(args))
    .filter(([, k]) => metin(k.hakedisNotu))
    .map(([p, k, t]) => ({ tarih: t, santiye: p.ad ?? '', hatirlatma: metin(k.hakedisNotu) }));
  return { hatirlatma_sayisi: liste.length, hatirlatmalar: liste };
}

async function aracHakedisler(veri, args) {
  const p = await veri.santiyeBul(args.santiye);
  const adlar = Object.fromEntries((await veri.projeler()).map((x) => [x.id, x.ad ?? '']));
  const sonuc = [];
  const hepsi = await veri.al('hakedisler', []);
  for (const h of Array.isArray(hepsi) ? hepsi : []) {
    if (!h || typeof h !== 'object' || (p !== null && h.projeId !== p.id)) continue;
    const kalemler = (Array.isArray(h.kalemler) ? h.kalemler : []).map((k) => {
      const miktar = sayi(k.miktar);
      const fiyat = sayi(k.birimFiyat);
      return {
        kalem: k.ad ?? '', birim: k.birim ?? '', miktar,
        birim_fiyat: fiyat || null, tutar: fiyat ? yuvarla2(miktar * fiyat) : null,
        ekip: k.ekip ?? '',
      };
    });
    sonuc.push({
      santiye: h.projeId in adlar ? adlar[h.projeId] : h.projeId ?? null,
      donem_baslangic: String(h.baslangic ?? '').slice(0, 10),
      donem_bitis: String(h.bitis ?? '').slice(0, 10),
      kalemler,
      not: h.not ?? '',
      toplam_tutar: yuvarla2(kalemler.reduce((s, k) => s + (k.tutar || 0), 0)),
    });
  }
  sonuc.sort((a, b) => kucuktur(b.donem_bitis, a.donem_bitis));
  return { hakedis_sayisi: sonuc.length, hakedisler: sonuc };
}

const SANTIYE = { type: 'string', description: 'Şantiye adı (parçası da olur, ör. "gera") ya da kimliği. Boşsa tüm şantiyeler.' };
const AY = { type: 'string', description: 'Ay, "YYYY-MM" (ör. 2026-11). Verilirse başlangıç/bitiş yok sayılır.' };
const BAS = { type: 'string', description: 'Başlangıç tarihi "YYYY-MM-DD" (dahil).' };
const BIT = { type: 'string', description: 'Bitiş tarihi "YYYY-MM-DD" (dahil).' };
const SUZGEC = { santiye: SANTIYE, ay: AY, baslangic: BAS, bitis: BIT };

export const ARACLAR = [
  {
    name: 'santiyeler',
    description: 'Tüm şantiyeleri (projeleri) listeler: durum, başlangıç, planlanan süre, kayıt sayısı, ilk/son kayıt '
      + 'tarihi; ayrıca yevmiye ekipleri. Başka bir araçta şantiye adını bilmiyorsan önce bunu çağır.',
    inputSchema: { type: 'object', properties: {} },
    fonksiyon: aracSantiyeler,
  },
  {
    name: 'gunluk_kayitlar',
    description: 'Günlük şantiye kayıtları (puantaj): çalışan sayıları (kalıpçı/demirci/diğer), yapılan işler, beton, '
      + 'notlar, hakediş hatırlatması, hava, yemek (kahvaltı/öğle/akşam), vinç (net saat), yevmiye. '
      + 'Tarihe göre sıralı; çok kayıt varsa en yeniler döner.',
    inputSchema: {
      type: 'object',
      properties: { ...SUZGEC, en_fazla: { type: 'integer', description: 'En fazla kayıt sayısı (varsayılan 60, en çok 400).' } },
    },
    fonksiyon: aracGunlukKayitlar,
  },
  {
    name: 'ozet',
    description: 'Şantiye bazında toplamlar: kayıtlı gün, kalıpçı/demirci/diğer adam-gün, vinç saati ve günü, yevmiye, '
      + 'öğünlere göre yemek, beton dökülen günler, hava nedeniyle çalışılamayan günler, hakediş hatırlatma '
      + 'sayısı; ayrıca genel toplam. Puantaj, hakediş ve yemek mutabakatı soruları için.',
    inputSchema: { type: 'object', properties: SUZGEC },
    fonksiyon: aracOzet,
  },
  {
    name: 'ara',
    description: 'Günlük kayıtların yazı alanlarında (işler, beton, notlar, hakediş hatırlatması, vinç, yevmiye) arar. '
      + 'Büyük/küçük harf ve Türkçe harf farkı gözetmez.',
    inputSchema: { type: 'object', properties: { ...SUZGEC, metin: { type: 'string', description: 'Aranacak metin.' } }, required: ['metin'] },
    fonksiyon: aracAra,
  },
  {
    name: 'hakedis_hatirlatmalari',
    description: 'Günlük kayıtlara yazılmış hakediş hatırlatmaları (ek iş, sözleşme dışı iş, bekleme vb.), tarih ve şantiyeyle.',
    inputSchema: { type: 'object', properties: SUZGEC },
    fonksiyon: aracHakedisHatirlatmalari,
  },
  {
    name: 'hakedisler',
    description: 'Uygulamada girilmiş hakediş dönemleri ve kalemleri (kalıp m², demir ton, beton m³, iskele vb.; miktar, '
      + 'birim fiyat, tutar).',
    inputSchema: { type: 'object', properties: { santiye: SANTIYE } },
    fonksiyon: aracHakedisler,
  },
];

export const TALIMAT = 'ŞantiyePro: bir kalıp-demir taşeronunun şantiye kayıtları (Türkçe). Veriler buluttan (telefon ve '
  + 'bilgisayardan girilen her şey) okunur. Yanıttaki veri_tarihi verinin buluta en son yazıldığı anı (Türkiye saati) '
  + 'gösterir. Okuma araçları veriyi değiştirmez. kayit_ekle kaydı doğrudan yazmaz, öneri olarak uygulamaya gönderir: '
  + 'kullanıcı ŞantiyePro uygulamasında onaylayınca eklenir. Göndermeden önce kaydı kullanıcıya özetle ve onayını al; '
  + 'gönderdikten sonra "uygulamada onay bekliyor" de, "kaydedildi" deme. Var olan kayıtlar silinemez.';
