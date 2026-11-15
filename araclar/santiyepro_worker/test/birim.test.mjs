import { test } from 'node:test';
import { strictEqual, deepStrictEqual, rejects } from 'node:assert';
import { sade, tam, tarih, vincSaat, aralik, Veri, ARACLAR } from '../src/araclar.js';
import { turkiyeSaati } from '../src/firestore.js';

test('sade: Türkçe harf ve büyük/küçük harf', () => {
  strictEqual(sade('İŞ DÖŞEME Iğdır'), 'is doseme igdir');
});

test('tam: Python gibi yarımda çifte yuvarlar', () => {
  deepStrictEqual([tam(2.5), tam(3.5), tam('4'), tam('4,5'), tam(null)], [2, 4, 4, 0, 0]);
});

test('tarih ve aralık', () => {
  strictEqual(tarih('2026-10-31T00:00:00.000'), '2026-10-31');
  strictEqual(tarih('2026-02-30'), null);
  deepStrictEqual(aralik({ ay: '2026-02' }), ['2026-02-01', '2026-02-28']);
  deepStrictEqual(aralik({ ay: '2026-12' }), ['2026-12-01', '2026-12-31']);
});

test('vinç net saati: mola ve gece yarısı', () => {
  strictEqual(vincSaat('08:30', '15:00', 60), 5.5);
  strictEqual(vincSaat('22:00', '02:00', 0), 4);
  strictEqual(vincSaat('8', '15:00', 0), 0);
});

test('Türkiye saati', () => {
  strictEqual(turkiyeSaati(Date.UTC(2026, 10, 14, 14, 17)), '2026-11-14 17:17');
});

const veri = () => new Veri(async (ad) => ({
  projects: [{ id: 'p1', ad: 'Gera makina' }, { id: 'p2', ad: 'KA Otomotiv' }, { id: 'p3', ad: 'Yüner Gülka' }],
  project_logs: {
    p1: [{ tarih: '2026-10-21', kalipci: 8, beton: '1.kat döşeme', vincler: [{ firmaAdi: 'teknik', baslangic: '08:00', bitis: '15:30', mola: 60 }] }],
    p2: [{ tarih: '2026-10-24', kalipci: 3, hakedisNotu: ' bekleme ' }],
  },
})[ad] ?? null);

test('özet ve şantiye bulma', async () => {
  const ozet = ARACLAR.find((a) => a.name === 'ozet').fonksiyon;
  const s = await ozet(veri(), { ay: '2026-10' });
  strictEqual(s.genel_toplam.toplam_adam_gun, 11);
  strictEqual(s.santiyeler[0].vinc_saat, 6.5);
  strictEqual(s.santiyeler[1].hakedis_hatirlatma_sayisi, 1);
  await rejects(ozet(veri(), { santiye: 'ka' }), /birden çok/);
  await rejects(ozet(veri(), { santiye: 'yok' }), /adlı şantiye yok/);
});

// ---------------------------------------------------------------- kayıt önerme
import { YAZMA_ARACLARI } from '../src/yazma.js';

function sahteBulut() {
  const gonderilen = [];
  globalThis.fetch = async (url, secenek = {}) => {
    if (String(url).includes('securetoken')) return new Response(JSON.stringify({ id_token: 'j', expires_in: 3600 }));
    if (secenek.method === 'POST') {
      gonderilen.push(JSON.parse(secenek.body));
      return new Response(JSON.stringify({ name: 'projects/x/databases/(default)/documents/users/u/data/claude_gelen/oneriler/abc123' }));
    }
    return new Response('{}', { status: 404 });
  };
  return gonderilen;
}
const ENV = { FIREBASE_UID: 'u', FIREBASE_YENILEME: 'r' };
const kayitEkle = YAZMA_ARACLARI.find((a) => a.name === 'kayit_ekle').fonksiyon;

test('kayit_ekle: uygulamanın taslak biçiminde gelen kutusuna yazar', async () => {
  const gonderilen = sahteBulut();
  const s = await kayitEkle(veri(), {
    aciklama: 'gera bugün',
    kayitlar: [{
      santiye: 'gera', tarih: '2026-10-21', kalipci: 5, kalipci_isi: 'kolon kalıbı',
      ogle_yemegi: { toplam: 7 }, vincler: [{ firma: 'teknik', baslangic: '8:30', bitis: '15.00', mola_dk: 60 }],
      yevmiyeler: [{ ekip: 'Kalıpçı Muhammet', miktar: 0.5 }],
    }],
  }, ENV);
  strictEqual(s.durum, 'onay_bekliyor');
  strictEqual(s.oneri_id, 'abc123');
  const icerik = JSON.parse(gonderilen[0].fields.json.stringValue);
  const k = icerik.kayitlar[0];
  deepStrictEqual([k.projeId, k.soylenenAd, k.tarih, k.kalipci, k.kalipciIs, k.yemek, k.yemekKalipci], ['p1', 'Gera makina', '2026-10-21', 5, 'kolon kalıbı', 7, 0]);
  deepStrictEqual(k.vincler, [{ firma: 'teknik', baslangic: '08:30', bitis: '15:00', mola: 60, aciklama: '' }]);
  deepStrictEqual(k.yevmiyeler, [{ ekip: 'Kalıpçı Muhammet', miktar: 0.5, aciklama: '' }]);
  strictEqual(gonderilen[0].fields.aciklama.stringValue, 'gera bugün');
});

test('kayit_ekle: hatalı girişleri reddeder, hiçbir şey yazmaz', async () => {
  const gonderilen = sahteBulut();
  const dene = (k) => kayitEkle(veri(), { kayitlar: [k] }, ENV);
  await rejects(dene({ santiye: 'gera', tarih: '2099-01-01', kalipci: 1 }), /gelecekte/);
  await rejects(dene({ santiye: 'ka', kalipci: 1 }), /birden çok/);
  await rejects(dene({ santiye: 'gera' }), /yazılacak bir bilgi yok/);
  await rejects(dene({ santiye: 'gera', kalipci: 2.5 }), /tam sayı/);
  await rejects(dene({ santiye: 'gera', kalipci: -1 }), /0 ile 9999/);
  await rejects(dene({ santiye: 'gera', vincler: [{ firma: 'x', baslangic: '25:00' }] }), /SS:DD/);
  await rejects(dene({ santiye: 'gera', ogle_yemegi: { kalipci: 3, toplam: 5 } }), /ya ekip ekip/);
  await rejects(dene({ santiye: 'gera', yevmiyeler: [{ ekip: 'a', miktar: 0 }] }), /0'dan büyük/);
  await rejects(kayitEkle(veri(), { kayitlar: [] }, ENV), /en az bir/);
  strictEqual(gonderilen.length, 0);
});
