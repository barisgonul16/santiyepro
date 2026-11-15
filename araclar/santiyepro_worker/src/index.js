// ŞantiyePro MCP sunucusu, Cloudflare Workers. Okur; kayıt yalnızca ÖNERİR
// (src/yazma.js: öneri uygulamada kullanıcı onayıyla eklenir).
//
// /mcp       MCP (Streamable HTTP, JSON yanıtlı, oturumsuz) — OAuth jetonu ister
// /authorize şifre sayfası: claude.ai bağlanırken bir kez GIRIS_SIFRESI sorulur
// /token, /register, /.well-known/*  OAuth kütüphanesinin uç noktaları
//
// Secretlar: GIRIS_SIFRESI, FIREBASE_UID, FIREBASE_YENILEME. Değişken: KAYNAK_URL
// (bu Worker'ın /mcp adresi, ör. https://santiyepro-mcp.<hesap>.workers.dev/mcp).

import { OAuthProvider, AuthorizationError, CimdFetchError } from '@cloudflare/workers-oauth-provider';
import { ARACLAR as OKUMA_ARACLARI, TALIMAT, Veri, KullaniciHatasi } from './araclar.js';
import { YAZMA_ARACLARI } from './yazma.js';
import { MALZEME_ARACLARI } from './malzeme.js';
import { bulutOku, turkiyeSaati } from './firestore.js';

const SURUM = '1.3.0';

const ARACLAR = [
  ...OKUMA_ARACLARI.map((a) => ({ ...a, annotations: { readOnlyHint: true } })),
  ...YAZMA_ARACLARI,
  ...MALZEME_ARACLARI,
];
const PROTOKOL = '2025-06-18';

// ---------------------------------------------------------------- MCP

async function aracCagir(env, ad, args) {
  const arac = ARACLAR.find((a) => a.name === ad);
  if (!arac) return null;
  const veri = new Veri(async (koleksiyon) => (await bulutOku(env, koleksiyon)).veri);
  const sonuc = await arac.fonksiyon(veri, args && typeof args === 'object' ? args : {}, env);
  // Malzeme araçlarında verinin tarihi malzeme defterinden.
  const kayitlar = await bulutOku(env, ad.startsWith('malzeme') ? 'malzeme_hareketleri' : 'project_logs');
  sonuc.veri_tarihi = turkiyeSaati(kayitlar.ms);
  sonuc.kaynak = 'bulut';
  return sonuc;
}

export async function isle(ileti, env) {
  if (!ileti || typeof ileti !== 'object' || Array.isArray(ileti)) {
    return { jsonrpc: '2.0', id: null, error: { code: -32600, message: 'Geçersiz istek' } };
  }
  const { method: yontem, id: kimlik } = ileti;
  if (kimlik === undefined || kimlik === null) return null; // bildirim (ör. notifications/initialized)
  const cevap = (result) => ({ jsonrpc: '2.0', id: kimlik, result });
  const hata = (code, message) => ({ jsonrpc: '2.0', id: kimlik, error: { code, message } });

  if (yontem === 'initialize') {
    const istenen = (ileti.params || {}).protocolVersion || PROTOKOL;
    return cevap({
      protocolVersion: istenen,
      capabilities: { tools: {} },
      serverInfo: { name: 'santiyepro', version: SURUM },
      instructions: TALIMAT,
    });
  }
  if (yontem === 'ping') return cevap({});
  if (yontem === 'tools/list') {
    return cevap({ tools: ARACLAR.map(({ fonksiyon, ...a }) => a) });
  }
  if (yontem === 'tools/call') {
    const p = ileti.params || {};
    try {
      const sonuc = await aracCagir(env, p.name, p.arguments);
      if (sonuc === null) return hata(-32602, `Bilinmeyen araç: ${p.name}`);
      return cevap({ content: [{ type: 'text', text: JSON.stringify(sonuc) }] });
    } catch (e) {
      const mesaj = e instanceof KullaniciHatasi ? e.message : `Veri okunamadı: ${e.message || e}`;
      return cevap({ content: [{ type: 'text', text: mesaj }], isError: true });
    }
  }
  return hata(-32601, `Desteklenmeyen yöntem: ${yontem}`);
}

const mcpIsleyici = {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return new Response('Yalnızca POST', { status: 405, headers: { Allow: 'POST' } });
    }
    let govde;
    try {
      govde = await request.json();
    } catch {
      return Response.json({ jsonrpc: '2.0', id: null, error: { code: -32700, message: 'JSON okunamadı' } }, { status: 400 });
    }
    if (Array.isArray(govde)) {
      const yanitlar = (await Promise.all(govde.map((i) => isle(i, env)))).filter(Boolean);
      return yanitlar.length ? Response.json(yanitlar) : new Response(null, { status: 202 });
    }
    const yanit = await isle(govde, env);
    return yanit ? Response.json(yanit) : new Response(null, { status: 202 });
  },
};

// ---------------------------------------------------------------- şifre sayfası

const kacis = (d) => String(d ?? '').replace(/[&<>"']/g, (h) => `&#${h.charCodeAt(0)};`);

function sayfa(govde, durum = 200, basliklar = new Headers()) {
  basliklar.set('Content-Type', 'text/html; charset=utf-8');
  return new Response(`<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>ŞantiyePro</title>
<style>
  body{font-family:system-ui,sans-serif;background:#F3F0E8;color:#1C2127;margin:0;padding:24px;}
  main{max-width:420px;margin:8vh auto;background:#fff;border-radius:12px;padding:28px;box-shadow:0 2px 12px #0001;}
  h1{font-size:22px;margin:0 0 12px} p{line-height:1.5;color:#4A4F57}
  input{width:100%;box-sizing:border-box;font-size:18px;padding:12px;border:1px solid #bbb;border-radius:8px;margin:8px 0 16px}
  button{font-size:17px;padding:12px 18px;border-radius:8px;border:0;cursor:pointer}
  .evet{background:#E8762C;color:#1C2127;font-weight:600} .hayir{background:#E6E0D3;color:#1C2127;margin-left:8px}
  .uyari{color:#A9490C;font-weight:600}
</style></head><body><main>${govde}</main></body></html>`, { status: durum, headers: basliklar });
}

async function sifreDogru(girilen, beklenen) {
  if (!beklenen) return false;
  const kodla = (m) => crypto.subtle.digest('SHA-256', new TextEncoder().encode(String(m)));
  const [a, b] = await Promise.all([kodla(girilen), kodla(beklenen)]);
  return crypto.subtle.timingSafeEqual(a, b);
}

async function yetkilendir(request, env) {
  const oauth = env.OAUTH_PROVIDER;
  try {
    if (request.method === 'GET') {
      const istek = await oauth.parseAuthRequest(request);
      const ayrinti = await oauth.describeConsent(istek);
      const onay = await oauth.beginConsent(istek);
      return sayfa(`
<h1>ŞantiyePro'ya bağlan</h1>
<p><b>${kacis(ayrinti.clientDomain || ayrinti.clientName)}</b> şantiye kayıtlarınızı okumak istiyor.
Erişim <b>${kacis(ayrinti.redirectHost)}</b> adresine gönderilecek.</p>
${ayrinti.redirectIsLoopback ? '<p class="uyari">Bu istek bilgisayarınızdaki bir uygulamadan geliyor. Bağlanmayı siz başlatmadıysanız Reddet\'e basın.</p>' : ''}
<form method="post">
  <input type="hidden" name="handle" value="${kacis(onay.handle)}">
  <label for="sifre">Giriş şifresi</label>
  <input id="sifre" name="sifre" type="password" autocomplete="current-password" autofocus>
  <button class="evet" name="karar" value="izin">Bağlan</button><button class="hayir" name="karar" value="red">Reddet</button>
</form>`, 200, onay.headers);
    }
    if (request.method === 'POST') {
      const form = await request.formData();
      const handle = String(form.get('handle') || '');
      if (form.get('karar') !== 'izin') {
        const red = await oauth.denyConsent(request, handle);
        return new Response(null, { status: 302, headers: red.headers });
      }
      if (!(await sifreDogru(form.get('sifre') || '', env.GIRIS_SIFRESI))) {
        await new Promise((r) => setTimeout(r, 1500)); // tahmin denemelerini yavaşlat
        return sayfa('<h1>Şifre yanlış</h1><p>Geri dönüp tekrar deneyin.</p><p><button class="hayir" onclick="history.back()">Geri</button></p>', 401);
      }
      const onay = await oauth.approveConsent(request, handle);
      const { redirectTo } = await oauth.completeAuthorization({
        request: onay.request,
        userId: 'sahip',
        metadata: {},
        scope: onay.request.scope,
        props: { kullanici: 'sahip' },
      });
      onay.headers.set('Location', redirectTo);
      return new Response(null, { status: 302, headers: onay.headers });
    }
    return new Response('Desteklenmeyen yöntem', { status: 405 });
  } catch (e) {
    if (e instanceof AuthorizationError && e.redirectTo) return Response.redirect(e.redirectTo, 302);
    if (e instanceof AuthorizationError || e instanceof CimdFetchError) {
      const mesaj = e instanceof AuthorizationError ? e.description : 'Uygulama doğrulanamadı.';
      return sayfa(`<h1>Bağlanılamadı</h1><p>${kacis(mesaj)}</p><p>Claude'da bağlantıyı yeniden başlatın.</p>`, 400);
    }
    throw e;
  }
}

const varsayilanIsleyici = {
  async fetch(request, env) {
    const yol = new URL(request.url).pathname;
    if (yol === '/authorize') return yetkilendir(request, env);
    if (yol === '/') return new Response('ŞantiyePro MCP sunucusu. Bağlantı adresi: /mcp', { headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
    return new Response('Bulunamadı', { status: 404 });
  },
};

// ---------------------------------------------------------------- Worker

let saglayici = null;

function saglayiciAl(env) {
  if (!saglayici) {
    const kaynak = env.KAYNAK_URL;
    saglayici = new OAuthProvider({
      apiRoute: '/mcp',
      apiHandler: mcpIsleyici,
      defaultHandler: varsayilanIsleyici,
      authorizeEndpoint: '/authorize',
      tokenEndpoint: '/token',
      clientRegistrationEndpoint: '/register',
      resourceMetadata: {
        resource: kaynak,
        authorization_servers: [new URL(kaynak).origin],
      },
    });
  }
  return saglayici;
}

export default {
  fetch(request, env, ctx) {
    if (!env.KAYNAK_URL) return new Response('KAYNAK_URL tanımlı değil', { status: 500 });
    return saglayiciAl(env).fetch(request, env, ctx);
  },
};
