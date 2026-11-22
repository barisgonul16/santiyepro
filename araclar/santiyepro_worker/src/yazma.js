// Kayıt önerme araçları. Claude kaydı doğrudan yazmaz: öneri gelen kutusuna
// gider, ŞantiyePro uygulaması açılınca "Claude'dan kayıt var" der, kullanıcı
// sesle kayıttaki onay ekranında görüp düzeltir ve kaydeder.
//
// Öneri biçimi, uygulamanın sesle kayıtta kullandığı JSON ile aynıdır
// (lib/services/ai_kayit_service.dart, AiKayitService.taslaklariCoz):
// {"kayitlar":[{"projeId","soylenenAd","tarih","kalipci",...,"hakedis",
//   "yemek","yemekKalipci",...,"vincler":[{firma,baslangic,bitis,mola,aciklama}],
//   "yevmiyeler":[{ekip,miktar,aciklama}]}],"anlasilmayan":""}

import { KullaniciHatasi, tarih as tarihCoz } from './araclar.js';
import { oneriYaz, oneriler, oneriSil, turkiyeSaati } from './firestore.js';

const EN_FAZLA_KAYIT = 20;

function sayiAl(deger, ad, { ondalik = false } = {}) {
  if (deger === undefined || deger === null || deger === '') return 0;
  const n = typeof deger === 'number' ? deger : Number(String(deger).replace(',', '.'));
  if (!Number.isFinite(n) || n < 0 || n > 9999) throw new KullaniciHatasi(`${ad} 0 ile 9999 arasında bir sayı olmalı`);
  if (!ondalik && !Number.isInteger(n)) throw new KullaniciHatasi(`${ad} tam sayı olmalı`);
  return n;
}

function yaziAl(deger, ad) {
  if (deger === undefined || deger === null) return '';
  if (typeof deger !== 'string') throw new KullaniciHatasi(`${ad} yazı olmalı`);
  const y = deger.trim();
  if (y.length > 2000) throw new KullaniciHatasi(`${ad} çok uzun (en çok 2000 karakter)`);
  return y;
}

function saatAl(deger, ad) {
  const y = yaziAl(deger, ad);
  if (!y) return '';
  const m = /^(\d{1,2})[:.](\d{2})$/.exec(y);
  if (!m || Number(m[1]) > 23 || Number(m[2]) > 59) throw new KullaniciHatasi(`${ad} "SS:DD" biçiminde olmalı (ör. 08:30)`);
  return `${m[1].padStart(2, '0')}:${m[2]}`;
}

const HAVA_DURUMLARI = ['acik', 'bulutlu', 'sis', 'yagmur', 'kar', 'firtina'];
const HAVA_ADLARI = { acik: 'açık', bulutlu: 'bulutlu', sis: 'sisli', yagmur: 'yağmurlu', kar: 'karlı', firtina: 'fırtınalı' };

function havaAl(deger, ad) {
  const y = yaziAl(deger, ad);
  if (y && !HAVA_DURUMLARI.includes(y)) throw new KullaniciHatasi(`${ad} şunlardan biri olmalı: ${HAVA_DURUMLARI.join(', ')}`);
  return y;
}

/** Sıcaklık (°C); verilmediyse null. Eksi olabilir. */
function sicaklikAl(deger, ad) {
  if (deger === undefined || deger === null || deger === '') return null;
  const n = typeof deger === 'number' ? deger : Number(String(deger).replace(',', '.'));
  if (!Number.isFinite(n) || n < -60 || n > 60) throw new KullaniciHatasi(`${ad} -60 ile 60 arasında bir sıcaklık (°C) olmalı`);
  return Math.round(n);
}

function ogunAl(o, ad) {
  if (o === undefined || o === null) return { kalipci: 0, demirci: 0, diger: 0, toplam: 0 };
  if (typeof o !== 'object' || Array.isArray(o)) throw new KullaniciHatasi(`${ad} bir nesne olmalı`);
  const s = {
    kalipci: sayiAl(o.kalipci, `${ad}.kalipci`),
    demirci: sayiAl(o.demirci, `${ad}.demirci`),
    diger: sayiAl(o.diger, `${ad}.diger`),
    toplam: sayiAl(o.toplam, `${ad}.toplam`),
  };
  if (s.toplam && s.kalipci + s.demirci + s.diger) {
    throw new KullaniciHatasi(`${ad}: ya ekip ekip (kalipci/demirci/diger) ya da yalnızca toplam verin`);
  }
  return s;
}

/** Bir kaydı doğrular ve uygulamanın taslak biçimine çevirir. */
async function kayitHazirla(veri, k, sira, bugun) {
  const yer = `kayitlar[${sira}]`;
  if (!k || typeof k !== 'object' || Array.isArray(k)) throw new KullaniciHatasi(`${yer} bir nesne olmalı`);
  const ad = yaziAl(k.santiye, `${yer}.santiye`);
  if (!ad) throw new KullaniciHatasi(`${yer}.santiye gerekli`);
  const proje = await veri.santiyeBul(ad);

  let gun = bugun;
  if (k.tarih) {
    gun = tarihCoz(k.tarih);
    if (!gun || String(k.tarih).trim().length !== 10) throw new KullaniciHatasi(`${yer}.tarih "YYYY-MM-DD" biçiminde olmalı`);
    if (gun > bugun) throw new KullaniciHatasi(`${yer}.tarih gelecekte olamaz (bugün ${bugun})`);
  }

  const ogle = ogunAl(k.ogle_yemegi, `${yer}.ogle_yemegi`);
  const kahvalti = ogunAl(k.kahvalti, `${yer}.kahvalti`);
  const aksam = ogunAl(k.aksam_yemegi, `${yer}.aksam_yemegi`);

  const vincler = [];
  for (const [i, v] of (Array.isArray(k.vincler) ? k.vincler : []).entries()) {
    const vy = `${yer}.vincler[${i}]`;
    if (!v || typeof v !== 'object') throw new KullaniciHatasi(`${vy} bir nesne olmalı`);
    const satir = {
      firma: yaziAl(v.firma, `${vy}.firma`),
      baslangic: saatAl(v.baslangic, `${vy}.baslangic`),
      bitis: saatAl(v.bitis, `${vy}.bitis`),
      mola: sayiAl(v.mola_dk, `${vy}.mola_dk`),
      aciklama: yaziAl(v.aciklama, `${vy}.aciklama`),
    };
    if (!satir.firma && !satir.baslangic && !satir.aciklama) throw new KullaniciHatasi(`${vy}: firma, başlangıç saati ya da açıklamadan biri gerekli`);
    vincler.push(satir);
  }

  const yevmiyeler = [];
  for (const [i, y] of (Array.isArray(k.yevmiyeler) ? k.yevmiyeler : []).entries()) {
    const yy = `${yer}.yevmiyeler[${i}]`;
    if (!y || typeof y !== 'object') throw new KullaniciHatasi(`${yy} bir nesne olmalı`);
    const satir = { ekip: yaziAl(y.ekip, `${yy}.ekip`), miktar: sayiAl(y.miktar, `${yy}.miktar`, { ondalik: true }), aciklama: yaziAl(y.aciklama, `${yy}.aciklama`) };
    if (!(satir.miktar > 0)) throw new KullaniciHatasi(`${yy}.miktar 0'dan büyük olmalı (yarım gün 0.5)`);
    yevmiyeler.push(satir);
  }

  const taslak = {
    projeId: proje.id,
    soylenenAd: proje.ad ?? ad,
    tarih: gun,
    kalipci: sayiAl(k.kalipci, `${yer}.kalipci`),
    demirci: sayiAl(k.demirci, `${yer}.demirci`),
    diger: sayiAl(k.diger, `${yer}.diger`),
    kalipciIs: yaziAl(k.kalipci_isi, `${yer}.kalipci_isi`),
    demirciIs: yaziAl(k.demirci_isi, `${yer}.demirci_isi`),
    beton: yaziAl(k.beton, `${yer}.beton`),
    notlar: yaziAl(k.notlar, `${yer}.notlar`),
    hakedis: yaziAl(k.hakedis_notu, `${yer}.hakedis_notu`),
    yemek: ogle.toplam, yemekKalipci: ogle.kalipci, yemekDemirci: ogle.demirci, yemekDiger: ogle.diger,
    kahvalti: kahvalti.toplam, kahvaltiKalipci: kahvalti.kalipci, kahvaltiDemirci: kahvalti.demirci, kahvaltiDiger: kahvalti.diger,
    aksam: aksam.toplam, aksamKalipci: aksam.kalipci, aksamDemirci: aksam.demirci, aksamDiger: aksam.diger,
    hava: havaAl(k.hava, `${yer}.hava`),
    havaMin: sicaklikAl(k.en_dusuk_sicaklik, `${yer}.en_dusuk_sicaklik`),
    havaMax: sicaklikAl(k.en_yuksek_sicaklik, `${yer}.en_yuksek_sicaklik`),
    havaDurdu: k.hava_nedeniyle_calisilamadi === true,
    vincler,
    yevmiyeler,
  };
  const dolu = Object.entries(taslak).some(([a, d]) => !['projeId', 'soylenenAd', 'tarih'].includes(a)
    && (Array.isArray(d) ? d.length : (typeof d === 'number' && ['havaMin', 'havaMax'].includes(a)) || d));
  if (!dolu) throw new KullaniciHatasi(`${yer}: yazılacak bir bilgi yok (çalışan sayısı, iş, beton, not, hava, yemek, vinç ya da yevmiye)`);
  return taslak;
}

/** Kullanıcıya/Claude'a gösterilen kısa özet. */
function taslakOzeti(t) {
  const parca = [];
  const sayilar = [['kalıpçı', t.kalipci], ['demirci', t.demirci], ['diğer', t.diger]].filter(([, s]) => s).map(([a, s]) => `${s} ${a}`);
  if (sayilar.length) parca.push(sayilar.join(', '));
  if (t.kalipciIs) parca.push(`kalıpçı işi: ${t.kalipciIs}`);
  if (t.demirciIs) parca.push(`demirci işi: ${t.demirciIs}`);
  if (t.beton) parca.push(`beton: ${t.beton}`);
  if (t.notlar) parca.push(`not: ${t.notlar}`);
  if (t.hakedis) parca.push(`hakediş notu: ${t.hakedis}`);
  const sicaklik = t.havaMin !== null && t.havaMax !== null && t.havaMin !== t.havaMax
    ? `${t.havaMin}°/${t.havaMax}°` : (t.havaMax ?? t.havaMin) !== null ? `${t.havaMax ?? t.havaMin}°` : '';
  const hava = [HAVA_ADLARI[t.hava] ?? '', sicaklik, t.havaDurdu ? 'hava nedeniyle çalışılamadı' : ''].filter(Boolean).join(', ');
  if (hava) parca.push(`hava: ${hava}`);
  const yemek = (on, ad, toplam) => {
    const s = (t[on + 'Kalipci'] || 0) + (t[on + 'Demirci'] || 0) + (t[on + 'Diger'] || 0) + (toplam || 0);
    if (s) parca.push(`${ad}: ${s}`);
  };
  yemek('kahvalti', 'kahvaltı', t.kahvalti);
  yemek('yemek', 'öğle yemeği', t.yemek);
  yemek('aksam', 'akşam yemeği', t.aksam);
  for (const v of t.vincler || []) parca.push(`vinç: ${[v.firma, v.baslangic && v.bitis ? `${v.baslangic}-${v.bitis}` : '', v.aciklama].filter(Boolean).join(' ')}`);
  for (const y of t.yevmiyeler || []) parca.push(`yevmiye: ${y.ekip} ${y.miktar}${y.aciklama ? ' (' + y.aciklama + ')' : ''}`);
  return { santiye: t.soylenenAd, tarih: t.tarih, ozet: parca.join('; ') };
}

async function aracKayitEkle(veri, args, env) {
  const liste = args.kayitlar;
  if (!Array.isArray(liste) || !liste.length) throw new KullaniciHatasi('kayitlar en az bir kayıt içermeli');
  if (liste.length > EN_FAZLA_KAYIT) throw new KullaniciHatasi(`bir seferde en çok ${EN_FAZLA_KAYIT} kayıt önerilebilir`);
  const bugun = turkiyeSaati(Date.now()).slice(0, 10);
  const taslaklar = [];
  for (const [i, k] of liste.entries()) taslaklar.push(await kayitHazirla(veri, k, i, bugun));
  const aciklama = yaziAl(args.aciklama, 'aciklama');
  const id = await oneriYaz(env, { kayitlar: taslaklar, anlasilmayan: '' }, aciklama);
  return {
    durum: 'onay_bekliyor',
    oneri_id: id,
    bilgi: 'Kayıtlar henüz eklenmedi. ŞantiyePro uygulaması açılınca (ya da buluttan yenilenince) ana sayfada "Claude\'dan kayıt" '
      + 'kartı çıkar; kullanıcı onay ekranında kontrol edip kaydedince eklenir. O güne kayıt varsa sayılar yenisiyle değişir, '
      + 'yazılar sona eklenir, vinç ve yevmiye satırları eklenir.',
    kayitlar: taslaklar.map(taslakOzeti),
  };
}

async function aracBekleyenKayitlar(veri, args, env) {
  const liste = await oneriler(env);
  return {
    bekleyen_sayisi: liste.length,
    oneriler: liste.map((o) => ({
      oneri_id: o.id,
      olusturma: turkiyeSaati(o.olusturma),
      aciklama: o.aciklama,
      kayitlar: ((o.icerik && o.icerik.kayitlar) || []).map(taslakOzeti),
    })),
  };
}

async function aracOneriGeriAl(veri, args, env) {
  const id = String(args.oneri_id || '').trim();
  if (!/^[A-Za-z0-9]{1,100}$/.test(id)) throw new KullaniciHatasi('oneri_id geçersiz (bekleyen_kayitlar ile bakın)');
  const silindi = await oneriSil(env, id);
  if (!silindi) throw new KullaniciHatasi('Bu öneri bulunamadı: uygulamada zaten onaylanmış ya da silinmiş olabilir');
  return { durum: 'geri_alindi', oneri_id: id };
}

const SAYI = (aciklama) => ({ type: 'integer', minimum: 0, description: aciklama });
const OGUN = (ad) => ({
  type: 'object',
  description: `${ad} yiyen kişi sayısı. Ekip ekip söylendiyse kalipci/demirci/diger, ekip söylenmeden tek sayı söylendiyse yalnızca toplam.`,
  properties: { kalipci: SAYI('Kalıpçı'), demirci: SAYI('Demirci'), diger: SAYI('Diğer'), toplam: SAYI('Ekip ayrımı yoksa toplam') },
});

export const YAZMA_ARACLARI = [
  {
    name: 'kayit_ekle',
    description: 'Günlük şantiye kaydı ÖNERİR (puantaj, yapılan iş, beton, not, hakediş notu, hava, yemek, vinç, yevmiye). Kayıt '
      + 'hemen eklenmez: ŞantiyePro uygulamasında kullanıcının onayına düşer, kullanıcı kontrol edip kaydeder. '
      + 'Yalnızca kullanıcının açıkça söylediklerini yaz; söylenmeyen sayı ya da işi uydurma, boş bırak. Şantiye adı '
      + 'emin değilsen önce santiyeler aracına bak. O güne zaten kayıt varsa: verilen sayılar eskisinin yerine geçer, '
      + 'yazılar sona eklenir, vinç/yevmiye satırları eklenir. Göndermeden önce kayıtları kullanıcıya özetleyip onay al.',
    inputSchema: {
      type: 'object',
      properties: {
        kayitlar: {
          type: 'array',
          description: 'Her şantiye ve gün için bir kayıt.',
          items: {
            type: 'object',
            properties: {
              santiye: { type: 'string', description: 'Şantiye adı (parçası da olur, ör. "gera").' },
              tarih: { type: 'string', description: '"YYYY-MM-DD". Boşsa bugün (Türkiye saati). Gelecek tarih olamaz.' },
              kalipci: SAYI('O gün çalışan kalıpçı sayısı'),
              demirci: SAYI('O gün çalışan demirci sayısı'),
              diger: SAYI('Kalıpçı/demirci dışı çalışan (düz işçi vb.) sayısı'),
              kalipci_isi: { type: 'string', description: 'Kalıpçıların yaptığı iş' },
              demirci_isi: { type: 'string', description: 'Demircilerin yaptığı iş' },
              beton: { type: 'string', description: 'Dökülen beton (yeri, varsa miktarı)' },
              notlar: { type: 'string', description: 'Diğer önemli bilgiler (yemek sayısı buraya yazılmaz)' },
              hakedis_notu: { type: 'string', description: 'Hakedişte hatırlanacaklar: ek iş, bekleme, sözleşme dışı iş' },
              hava: {
                type: 'string',
                enum: HAVA_DURUMLARI,
                description: 'Hava durumu: acik (açık/güneşli), bulutlu (bulutlu/kapalı), sis, yagmur (yağmur/çise/sağanak), kar, '
                  + 'firtina (fırtına/gök gürültülü). Yalnızca söylendiyse; o günün kayıtlı havasının yerine geçer (düzeltme için de kullanılır).',
              },
              en_dusuk_sicaklik: { type: 'integer', minimum: -60, maximum: 60, description: 'En düşük sıcaklık °C (yalnızca söylendiyse)' },
              en_yuksek_sicaklik: { type: 'integer', minimum: -60, maximum: 60, description: 'En yüksek sıcaklık °C (yalnızca söylendiyse)' },
              hava_nedeniyle_calisilamadi: { type: 'boolean', description: 'Hava yüzünden iş durduysa true' },
              ogle_yemegi: OGUN('Öğle yemeği'),
              kahvalti: OGUN('Kahvaltı'),
              aksam_yemegi: OGUN('Akşam yemeği'),
              vincler: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    firma: { type: 'string' },
                    baslangic: { type: 'string', description: '"SS:DD", 24 saat' },
                    bitis: { type: 'string', description: '"SS:DD", 24 saat' },
                    mola_dk: SAYI('Mola, dakika'),
                    aciklama: { type: 'string' },
                  },
                },
              },
              yevmiyeler: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    ekip: { type: 'string', description: 'Yevmiye ekibi (santiyeler aracındaki ekipler listesinden)' },
                    miktar: { type: 'number', description: 'Yevmiye sayısı (yarım gün 0.5)' },
                    aciklama: { type: 'string' },
                  },
                  required: ['miktar'],
                },
              },
            },
            required: ['santiye'],
          },
        },
        aciklama: { type: 'string', description: 'Kullanıcının söylediğinin kısa hali; onay ekranında gösterilir.' },
      },
      required: ['kayitlar'],
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
    fonksiyon: aracKayitEkle,
  },
  {
    name: 'bekleyen_kayitlar',
    description: 'kayit_ekle ile önerilmiş, uygulamada henüz onaylanmamış ya da silinmemiş kayıtlar.',
    inputSchema: { type: 'object', properties: {} },
    annotations: { readOnlyHint: true },
    fonksiyon: aracBekleyenKayitlar,
  },
  {
    name: 'kayit_onerisini_geri_al',
    description: 'Henüz onaylanmamış bir kayıt önerisini geri alır (siler). Onaylanmış kayıtlar buradan silinemez.',
    inputSchema: {
      type: 'object',
      properties: { oneri_id: { type: 'string', description: 'bekleyen_kayitlar ya da kayit_ekle yanıtındaki oneri_id' } },
      required: ['oneri_id'],
    },
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true },
    fonksiyon: aracOneriGeriAl,
  },
];
