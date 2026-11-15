// Uçtan uca deneme: claude.ai'nin yaptığı gibi kaydolur, şifreyle izin alır,
// jeton alır ve MCP araçlarını çağırır. Sonuçları Python sunucusuyla
// (araclar/santiyepro_mcp.py, aynı bulut verisi) karşılaştırır.
//
//   ADRES=http://localhost:8787 SIFRE=... node test/uctan_uca.mjs
//   (PYTHON_KARSILASTIR=0 ile karşılaştırma atlanır)

import { spawnSync } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { deepStrictEqual } from 'node:assert';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ADRES = process.env.ADRES || 'http://localhost:8787';
const SIFRE = process.env.SIFRE;
if (!SIFRE) throw new Error('SIFRE gerekli');
const DONUS = 'https://claude.ai/api/mcp/auth_callback';
const b64url = (b) => b.toString('base64url');

function kontrol(kosul, mesaj) {
  if (!kosul) throw new Error('BAŞARISIZ: ' + mesaj);
  console.log('tamam:', mesaj);
}

// 1. Keşif
const ilk = await fetch(`${ADRES}/mcp`, { method: 'POST', body: '{}' });
kontrol(ilk.status === 401, 'jetonsuz /mcp isteği 401');
const kaynakMeta = await (await fetch(`${ADRES}/.well-known/oauth-protected-resource/mcp`)).json();
const yetkiMeta = await (await fetch(`${kaynakMeta.authorization_servers[0]}/.well-known/oauth-authorization-server`)).json();
kontrol(yetkiMeta.registration_endpoint && yetkiMeta.token_endpoint, 'yetki sunucusu bilgileri');

// 2. Kayıt (DCR)
const kayit = await (await fetch(yetkiMeta.registration_endpoint, {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ client_name: 'Deneme', redirect_uris: [DONUS], token_endpoint_auth_method: 'none', grant_types: ['authorization_code', 'refresh_token'], response_types: ['code'] }),
})).json();
kontrol(kayit.client_id, 'istemci kaydı');

// 3. Yetkilendirme sayfası
const dogrulayici = b64url(randomBytes(32));
const meydan = b64url(createHash('sha256').update(dogrulayici).digest());
const durum = b64url(randomBytes(8));
const yetkiUrl = `${yetkiMeta.authorization_endpoint}?` + new URLSearchParams({
  response_type: 'code', client_id: kayit.client_id, redirect_uri: DONUS, code_challenge: meydan,
  code_challenge_method: 'S256', state: durum, resource: kaynakMeta.resource,
});
const sayfa = await fetch(yetkiUrl, { redirect: 'manual' });
const html = await sayfa.text();
kontrol(sayfa.status === 200 && html.includes('Giriş şifresi'), 'şifre sayfası açıldı');
const handle = /name="handle" value="([^"]+)"/.exec(html)[1].replace(/&#(\d+);/g, (_, n) => String.fromCharCode(n));
const cerez = sayfa.headers.getSetCookie().map((c) => c.split(';')[0]).join('; ');

const gonder = (alanlar) => fetch(yetkiUrl, {
  method: 'POST', redirect: 'manual',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded', Cookie: cerez },
  body: new URLSearchParams(alanlar),
});
const yanlis = await gonder({ handle, sifre: 'yanlis', karar: 'izin' });
kontrol(yanlis.status === 401, 'yanlış şifre reddedildi');
const dogru = await gonder({ handle, sifre: SIFRE, karar: 'izin' });
const yon = new URL(dogru.headers.get('location') || 'http://x/');
kontrol(dogru.status === 302 && yon.origin + yon.pathname === DONUS && yon.searchParams.get('state') === durum, 'doğru şifreyle claude.ai’ye yönlendirildi');
const tekrar = await gonder({ handle, sifre: SIFRE, karar: 'izin' });
kontrol(tekrar.status >= 400, 'aynı form ikinci kez kullanılamıyor');

// 4. Jeton
const jetonY = await (await fetch(yetkiMeta.token_endpoint, {
  method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({ grant_type: 'authorization_code', code: yon.searchParams.get('code'), redirect_uri: DONUS, client_id: kayit.client_id, code_verifier: dogrulayici, resource: kaynakMeta.resource }),
})).json();
kontrol(jetonY.access_token, 'erişim jetonu alındı');

// 5. MCP
let no = 0;
async function rpc(method, params) {
  const y = await fetch(`${ADRES}/mcp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json, text/event-stream', Authorization: `Bearer ${jetonY.access_token}` },
    body: JSON.stringify({ jsonrpc: '2.0', id: ++no, method, params }),
  });
  if (y.status !== 200) throw new Error(`${method}: HTTP ${y.status} ${await y.text()}`);
  return (await y.json()).result;
}
const bas = await rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'deneme', version: '1' } });
kontrol(bas.serverInfo.name === 'santiyepro', 'initialize');
const araclar = (await rpc('tools/list')).tools.map((a) => a.name);
kontrol(araclar.length === 9, 'tools/list: ' + araclar.join(', '));
const sahte = await fetch(`${ADRES}/mcp`, { method: 'POST', headers: { Authorization: 'Bearer sahte' }, body: '{}' });
kontrol(sahte.status === 401, 'sahte jeton reddedildi');

const CAGRILAR = [
  ['santiyeler', {}],
  ['gunluk_kayitlar', { ay: '2026-10', en_fazla: 400 }],
  ['gunluk_kayitlar', {}],
  ['gunluk_kayitlar', { santiye: 'gera', baslangic: '2026-11-01', bitis: '2026-11-15' }],
  ['gunluk_kayitlar', { santiye: 'ka' }],
  ['gunluk_kayitlar', { ay: '2026-13' }],
  ['ozet', { ay: '2026-10' }],
  ['ozet', {}],
  ['ozet', { santiye: 'VATANPRESS', ay: '2026-11' }],
  ['ara', { metin: 'döşeme', santiye: 'gera' }],
  ['ara', { metin: 'BETON' }],
  ['ara', { metin: 'vinç', ay: '2026-10' }],
  ['hakedis_hatirlatmalari', {}],
  ['hakedisler', {}],
];
const worker = [];
for (const [ad, args] of CAGRILAR) {
  const r = await rpc('tools/call', { name: ad, arguments: args });
  const metin = r.content[0].text;
  worker.push(r.isError ? { hata: metin } : JSON.parse(metin));
}
kontrol(worker[6].genel_toplam.toplam_adam_gun === 521, 'Ekim özeti 521 adam-gün');

if (process.env.PYTHON_KARSILASTIR !== '0') {
  const betik = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../santiyepro_mcp.py');
  const girdi = CAGRILAR.map(([ad, args], i) => JSON.stringify({ jsonrpc: '2.0', id: i + 1, method: 'tools/call', params: { name: ad, arguments: args } })).join('\n') + '\n';
  const p = spawnSync('python', [betik], { input: girdi, encoding: 'utf-8', env: { ...process.env, PYTHONUTF8: '1', SANTIYEPRO_VERI: process.env.BOS_VERI || '' } });
  const python = p.stdout.trim().split('\n').map((s) => JSON.parse(s).result).map((r) => (r.isError ? { hata: r.content[0].text } : JSON.parse(r.content[0].text)));
  CAGRILAR.forEach(([ad, args], i) => {
    const a = structuredClone(worker[i]);
    const b = python[i];
    if (!b.hata && b.kaynak !== 'bulut') throw new Error('Python bulut yerine ' + b.kaynak + ' okudu: ' + (b.bulut_durumu || ''));
    deepStrictEqual(a, b, `${ad} ${JSON.stringify(args)}`);
    console.log('aynı:', ad, JSON.stringify(args));
  });
}
console.log('HEPSİ GEÇTİ');
