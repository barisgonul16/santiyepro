// Malzeme takibi: şantiyeye gelen / giden / aktarılan malzeme.
//
// Veri uygulamanın `malzeme_hareketleri` koleksiyonu (lib/models/malzeme_hareketi.dart):
// [{id, tarih, malzeme, miktar, birim, kaynakProjeId, hedefProjeId, disYer,
//   irsaliyeNo, not, fotoYolu, kaynak}]
// hedef dolu / kaynak boş = geldi; kaynak dolu / hedef boş = gitti; ikisi de
// dolu = şantiyeden şantiyeye aktarma. Şantiyedeki miktar = gelen − giden.
//
// malzeme_ekle kaydı doğrudan yazmaz: öneri users/{uid}/data/claude_gelen/
// malzeme_onerileri/{id} belgesine gider, uygulamanın Malzemeler sayfası
// kullanıcıya gösterir, kullanıcı kaydedince eklenir.

import { KullaniciHatasi, sade, tarih as tarihCoz, aralik } from './araclar.js';
import { oneriYaz, oneriler, oneriSil, turkiyeSaati, MALZEME } from './firestore.js';

const EN_FAZLA = 40;

function yuvarla3(x) {
  return Math.round((x + Number.EPSILON) * 1000) / 1000;
}

function sayi(d) {
  const n = typeof d === 'number' ? d : Number(String(d ?? '').replace(',', '.'));
  return Number.isFinite(n) ? n : 0;
}

function anahtar(m) {
  return sade(String(m || '').trim()).replace(/\s+/g, ' ');
}

function tur(h) {
  if (h.kaynakProjeId && h.hedefProjeId) return 'aktarma';
  if (h.kaynakProjeId) return 'gitti';
  return 'geldi';
}

async function hareketler(veri) {
  const liste = await veri.al('malzeme_hareketleri', []);
  return (Array.isArray(liste) ? liste : []).filter(
    (h) => h && typeof h === 'object' && tarihCoz(h.tarih) && (h.kaynakProjeId || h.hedefProjeId),
  );
}

/** Bir şantiyenin stoku: malzeme+birim bazında gelen, giden, kalan. Alet
 * hareketleri (aletId) sayılmaz: aletin yeri `malzemeler` listesindeki projeId. */
function stok(liste, projeId) {
  const gruplar = new Map();
  for (const h of liste) {
    if (h.aletId || (h.kaynakProjeId !== projeId && h.hedefProjeId !== projeId)) continue;
    const a = `${anahtar(h.malzeme)}|${anahtar(h.birim)}`;
    const g = gruplar.get(a) || { malzeme: String(h.malzeme || '').trim(), birim: String(h.birim || '').trim(), gelen: 0, giden: 0, son_hareket: '' };
    if (h.hedefProjeId === projeId) g.gelen += sayi(h.miktar);
    if (h.kaynakProjeId === projeId) g.giden += sayi(h.miktar);
    const t = tarihCoz(h.tarih);
    if (t > g.son_hareket) g.son_hareket = t;
    gruplar.set(a, g);
  }
  return [...gruplar.values()]
    .map((g) => ({ ...g, gelen: yuvarla3(g.gelen), giden: yuvarla3(g.giden), kalan: yuvarla3(g.gelen - g.giden) }))
    .sort((x, y) => (anahtar(x.malzeme) < anahtar(y.malzeme) ? -1 : 1));
}

function bicim(h, adlar) {
  const ad = (id) => (id ? adlar[id] ?? 'silinmiş şantiye' : '');
  const t = tur(h);
  const s = {
    tarih: tarihCoz(h.tarih),
    tur: t,
    malzeme: h.malzeme ?? '',
    miktar: sayi(h.miktar),
    birim: h.birim ?? '',
    nereden: t === 'geldi' ? h.disYer || 'dışarıdan' : ad(h.kaynakProjeId),
    nereye: t === 'gitti' ? h.disYer || 'dışarı' : ad(h.hedefProjeId),
  };
  if (h.irsaliyeNo) s.irsaliye_no = h.irsaliyeNo;
  if (h.not) s.not = h.not;
  if (h.fotoYolu) s.fotografli = true;
  if (h.aletId) s.alet = true;
  return s;
}

async function aracMalzemeDurumu(veri, args) {
  const p = await veri.santiyeBul(args.santiye);
  const liste = await hareketler(veri);
  const santiyeler = p ? [p] : (await veri.projeler()).filter((x) => x.durum !== 'Tamamlandı' || liste.some((h) => h.kaynakProjeId === x.id || h.hedefProjeId === x.id));
  const tumu = Boolean(args.bitenler_dahil);
  const aletListesi = await veri.al('malzemeler', []);
  const aletler = (Array.isArray(aletListesi) ? aletListesi : []).filter((a) => a && typeof a === 'object');
  const sonuc = [];
  for (const s of santiyeler) {
    const kalemler = stok(liste, s.id).filter((k) => tumu || Math.abs(k.kalan) > 0.0005);
    const buradakiAletler = aletler.filter((a) => a.projeId === s.id).map((a) => ({ alet: a.ad ?? '', durum: a.durum ?? '' }));
    if (!p && !kalemler.length && !buradakiAletler.length) continue;
    const o = { santiye: s.ad ?? '', durum: s.durum ?? '', malzemeler: kalemler };
    if (buradakiAletler.length) o.aletler = buradakiAletler;
    sonuc.push(o);
  }
  return {
    bilgi: 'kalan = o şantiyeye gelen − oradan giden (kayıtlara göre). Eksi kalan, gelişi girilmemiş malzemedir.',
    hareket_sayisi: liste.length,
    santiyeler: sonuc,
  };
}

async function aracMalzemeHareketleri(veri, args) {
  const p = await veri.santiyeBul(args.santiye);
  const [ilk, son] = aralik(args);
  const aranan = anahtar(args.malzeme);
  const istenenTur = String(args.tur || '').trim();
  if (istenenTur && !['geldi', 'gitti', 'aktarma'].includes(istenenTur)) throw new KullaniciHatasi('tur "geldi", "gitti" ya da "aktarma" olmalı');
  const adlar = Object.fromEntries((await veri.projeler()).map((x) => [x.id, x.ad ?? '']));
  let liste = (await hareketler(veri)).filter((h) => {
    const t = tarihCoz(h.tarih);
    if ((ilk && t < ilk) || (son && t > son)) return false;
    if (p && h.kaynakProjeId !== p.id && h.hedefProjeId !== p.id) return false;
    if (istenenTur && tur(h) !== istenenTur) return false;
    if (aranan && !anahtar(`${h.malzeme} ${h.irsaliyeNo || ''} ${h.disYer || ''} ${h.not || ''}`).includes(aranan)) return false;
    return true;
  });
  liste.sort((a, b) => (tarihCoz(a.tarih) < tarihCoz(b.tarih) ? -1 : tarihCoz(a.tarih) > tarihCoz(b.tarih) ? 1 : 0));
  const enFazla = Math.max(1, Math.min(Math.round(sayi(args.en_fazla) || 100), 500));
  const kesildi = liste.length > enFazla;
  liste = liste.slice(-enFazla);
  return { hareket_sayisi: liste.length, kesildi, hareketler: liste.map((h) => bicim(h, adlar)) };
}

// ---------------------------------------------------------------- öneri

function yazi(d, ad, enCok = 500) {
  if (d === undefined || d === null) return '';
  if (typeof d !== 'string') throw new KullaniciHatasi(`${ad} yazı olmalı`);
  const y = d.trim();
  if (y.length > enCok) throw new KullaniciHatasi(`${ad} çok uzun (en çok ${enCok} karakter)`);
  return y;
}

async function hareketHazirla(veri, h, sira, bugun) {
  const yer = `hareketler[${sira}]`;
  if (!h || typeof h !== 'object' || Array.isArray(h)) throw new KullaniciHatasi(`${yer} bir nesne olmalı`);
  const t = yazi(h.tur, `${yer}.tur`);
  if (!['geldi', 'gitti', 'aktarma'].includes(t)) throw new KullaniciHatasi(`${yer}.tur "geldi", "gitti" ya da "aktarma" olmalı`);
  const ad = yazi(h.santiye, `${yer}.santiye`);
  if (!ad) throw new KullaniciHatasi(`${yer}.santiye gerekli`);
  const santiye = await veri.santiyeBul(ad);
  let hedef = null;
  if (t === 'aktarma') {
    const hAd = yazi(h.hedef_santiye, `${yer}.hedef_santiye`);
    if (!hAd) throw new KullaniciHatasi(`${yer}.hedef_santiye aktarmada gerekli`);
    hedef = await veri.santiyeBul(hAd);
    if (hedef.id === santiye.id) throw new KullaniciHatasi(`${yer}: nereden ve nereye aynı şantiye olamaz`);
  }
  const malzeme = yazi(h.malzeme, `${yer}.malzeme`, 200);
  if (!malzeme) throw new KullaniciHatasi(`${yer}.malzeme gerekli`);
  const miktar = typeof h.miktar === 'number' ? h.miktar : Number(String(h.miktar ?? '').replace(',', '.'));
  if (!Number.isFinite(miktar) || miktar <= 0 || miktar > 1e7) throw new KullaniciHatasi(`${yer}.miktar 0'dan büyük bir sayı olmalı`);
  let gun = bugun;
  if (h.tarih) {
    gun = tarihCoz(h.tarih);
    if (!gun || String(h.tarih).trim().length !== 10) throw new KullaniciHatasi(`${yer}.tarih "YYYY-MM-DD" biçiminde olmalı`);
    if (gun > bugun) throw new KullaniciHatasi(`${yer}.tarih gelecekte olamaz (bugün ${bugun})`);
  }
  return {
    tarih: gun,
    malzeme,
    miktar,
    birim: yazi(h.birim, `${yer}.birim`, 20) || 'adet',
    kaynakProjeId: t === 'geldi' ? '' : santiye.id,
    hedefProjeId: t === 'geldi' ? santiye.id : t === 'aktarma' ? hedef.id : '',
    disYer: t === 'aktarma' ? '' : yazi(h.firma_yer, `${yer}.firma_yer`, 200),
    irsaliyeNo: yazi(h.irsaliye_no, `${yer}.irsaliye_no`, 100),
    not: yazi(h.not, `${yer}.not`),
  };
}

async function aracMalzemeEkle(veri, args, env) {
  const liste = args.hareketler;
  if (!Array.isArray(liste) || !liste.length) throw new KullaniciHatasi('hareketler en az bir hareket içermeli');
  if (liste.length > EN_FAZLA) throw new KullaniciHatasi(`bir seferde en çok ${EN_FAZLA} hareket önerilebilir`);
  const bugun = turkiyeSaati(Date.now()).slice(0, 10);
  const hazir = [];
  for (const [i, h] of liste.entries()) hazir.push(await hareketHazirla(veri, h, i, bugun));
  const id = await oneriYaz(env, { hareketler: hazir }, yazi(args.aciklama, 'aciklama', 2000), MALZEME);
  const adlar = Object.fromEntries((await veri.projeler()).map((x) => [x.id, x.ad ?? '']));
  return {
    durum: 'onay_bekliyor',
    oneri_id: id,
    bilgi: 'Hareketler henüz eklenmedi. ŞantiyePro uygulamasında Malzemeler sayfasının üstünde "Claude\'dan malzeme '
      + 'hareketi onay bekliyor" kartı çıkar; kullanıcı Kaydet deyince eklenir.',
    hareketler: hazir.map((h) => bicim(h, adlar)),
  };
}

async function aracBekleyenMalzemeler(veri, args, env) {
  const adlar = Object.fromEntries((await veri.projeler()).map((x) => [x.id, x.ad ?? '']));
  const liste = await oneriler(env, MALZEME);
  return {
    bekleyen_sayisi: liste.length,
    oneriler: liste.map((o) => ({
      oneri_id: o.id,
      olusturma: turkiyeSaati(o.olusturma),
      aciklama: o.aciklama,
      hareketler: ((o.icerik && o.icerik.hareketler) || []).map((h) => bicim(h, adlar)),
    })),
  };
}

async function aracMalzemeOnerisiniGeriAl(veri, args, env) {
  const id = String(args.oneri_id || '').trim();
  if (!/^[A-Za-z0-9]{1,100}$/.test(id)) throw new KullaniciHatasi('oneri_id geçersiz (bekleyen_malzemeler ile bakın)');
  if (!(await oneriSil(env, id, MALZEME))) throw new KullaniciHatasi('Bu öneri bulunamadı: uygulamada zaten kaydedilmiş ya da silinmiş olabilir');
  return { durum: 'geri_alindi', oneri_id: id };
}

const SANTIYE = { type: 'string', description: 'Şantiye adı (parçası da olur, ör. "gera") ya da kimliği.' };

export const MALZEME_ARACLARI = [
  {
    name: 'malzeme_durumu',
    description: 'Şantiyelerde şu an hangi malzemeden ne kadar var (pano, dikme, kontrplak, demir...): gelen, giden, kalan '
      + 've son hareket tarihi; ayrıca o şantiyedeki aletler (Hilti, kırıcı...). Şantiye verilmezse devam eden tüm şantiyeler.',
    inputSchema: {
      type: 'object',
      properties: {
        santiye: { ...SANTIYE, description: SANTIYE.description + ' Boşsa tüm şantiyeler.' },
        bitenler_dahil: { type: 'boolean', description: 'Tamamı gitmiş (kalan 0) malzemeler de listelensin.' },
      },
    },
    annotations: { readOnlyHint: true },
    fonksiyon: aracMalzemeDurumu,
  },
  {
    name: 'malzeme_hareketleri',
    description: 'Malzeme giriş/çıkış defteri: hangi şantiyeye ne zaman ne geldi, ne gitti, şantiyeden şantiyeye ne '
      + 'taşındı (nereden, nereye, irsaliye no, not). Tarihe göre sıralı; çoksa en yeniler döner.',
    inputSchema: {
      type: 'object',
      properties: {
        santiye: { ...SANTIYE, description: SANTIYE.description + ' Boşsa tümü.' },
        malzeme: { type: 'string', description: 'Malzeme adında, irsaliye no, firma ya da notta aranacak metin.' },
        tur: { type: 'string', enum: ['geldi', 'gitti', 'aktarma'] },
        ay: { type: 'string', description: '"YYYY-MM"' },
        baslangic: { type: 'string', description: '"YYYY-MM-DD" (dahil)' },
        bitis: { type: 'string', description: '"YYYY-MM-DD" (dahil)' },
        en_fazla: { type: 'integer', description: 'Varsayılan 100, en çok 500.' },
      },
    },
    annotations: { readOnlyHint: true },
    fonksiyon: aracMalzemeHareketleri,
  },
  {
    name: 'malzeme_ekle',
    description: 'Malzeme hareketi ÖNERİR (şantiyeye malzeme geldi / şantiyeden gitti / şantiyeden şantiyeye aktarıldı). '
      + 'Hemen eklenmez: ŞantiyePro\'da Malzemeler sayfasında kullanıcının onayına düşer. Yalnızca kullanıcının '
      + 'söylediklerini yaz; söylenmeyen miktar ya da malzemeyi uydurma. Göndermeden önce kullanıcıya özetleyip onay al.',
    inputSchema: {
      type: 'object',
      properties: {
        hareketler: {
          type: 'array',
          description: 'Her malzeme kalemi için bir satır (aynı irsaliyedeki kalemler ayrı satır).',
          items: {
            type: 'object',
            properties: {
              tur: { type: 'string', enum: ['geldi', 'gitti', 'aktarma'], description: 'geldi: dışarıdan şantiyeye; gitti: şantiyeden dışarı (iade, depo); aktarma: şantiyeden şantiyeye' },
              santiye: { type: 'string', description: 'geldi: geldiği şantiye; gitti/aktarma: çıktığı şantiye' },
              hedef_santiye: { type: 'string', description: 'Yalnızca aktarmada: gittiği şantiye' },
              malzeme: { type: 'string', description: 'ör. "Trio pano 270x90", "dikme 3 m", "kontrplak 18 mm", "Ø12 demir"' },
              miktar: { type: 'number' },
              birim: { type: 'string', description: 'adet, m², m³, m, kg, ton, takım, paket, top (varsayılan adet)' },
              tarih: { type: 'string', description: '"YYYY-MM-DD"; boşsa bugün (Türkiye saati)' },
              firma_yer: { type: 'string', description: 'geldi: kimden geldi (tedarikçi, kiralama, depo); gitti: nereye gitti' },
              irsaliye_no: { type: 'string' },
              not: { type: 'string', description: 'plaka, teslim alan vb.' },
            },
            required: ['tur', 'santiye', 'malzeme', 'miktar'],
          },
        },
        aciklama: { type: 'string', description: 'Kullanıcının söylediğinin kısa hali; onay ekranında gösterilir.' },
      },
      required: ['hareketler'],
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
    fonksiyon: aracMalzemeEkle,
  },
  {
    name: 'bekleyen_malzemeler',
    description: 'malzeme_ekle ile önerilmiş, uygulamada henüz kaydedilmemiş malzeme hareketleri.',
    inputSchema: { type: 'object', properties: {} },
    annotations: { readOnlyHint: true },
    fonksiyon: aracBekleyenMalzemeler,
  },
  {
    name: 'malzeme_onerisini_geri_al',
    description: 'Henüz kaydedilmemiş bir malzeme önerisini geri alır (siler).',
    inputSchema: {
      type: 'object',
      properties: { oneri_id: { type: 'string', description: 'malzeme_ekle ya da bekleyen_malzemeler yanıtındaki oneri_id' } },
      required: ['oneri_id'],
    },
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true },
    fonksiyon: aracMalzemeOnerisiniGeriAl,
  },
];
