// Bir MCP aracını claude.ai gibi bağlanıp çağırır (deneme için).
//   ADRES=http://localhost:8787 SIFRE=... node test/arac.mjs <araç> '<json argümanlar>'

import { createHash, randomBytes } from 'node:crypto';

const ADRES = process.env.ADRES || 'http://localhost:8787';
const DONUS = 'https://claude.ai/api/mcp/auth_callback';
const b64 = (b) => b.toString('base64url');

export async function baglan(adres = ADRES, sifre = process.env.SIFRE) {
  const kaynak = await (await fetch(`${adres}/.well-known/oauth-protected-resource/mcp`)).json();
  const meta = await (await fetch(`${kaynak.authorization_servers[0]}/.well-known/oauth-authorization-server`)).json();
  const istemci = await (await fetch(meta.registration_endpoint, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ client_name: 'Deneme', redirect_uris: [DONUS], token_endpoint_auth_method: 'none', grant_types: ['authorization_code'], response_types: ['code'] }),
  })).json();
  const dog = b64(randomBytes(32));
  const url = `${meta.authorization_endpoint}?` + new URLSearchParams({
    response_type: 'code', client_id: istemci.client_id, redirect_uri: DONUS, state: 's',
    code_challenge: b64(createHash('sha256').update(dog).digest()), code_challenge_method: 'S256', resource: kaynak.resource,
  });
  const sayfa = await fetch(url);
  const handle = /name="handle" value="([^"]+)"/.exec(await sayfa.text())[1].replace(/&#(\d+);/g, (_, n) => String.fromCharCode(n));
  const izin = await fetch(url, {
    method: 'POST', redirect: 'manual',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Cookie: sayfa.headers.getSetCookie().map((c) => c.split(';')[0]).join('; ') },
    body: new URLSearchParams({ handle, sifre, karar: 'izin' }),
  });
  const kod = new URL(izin.headers.get('location')).searchParams.get('code');
  const jeton = await (await fetch(meta.token_endpoint, {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'authorization_code', code: kod, redirect_uri: DONUS, client_id: istemci.client_id, code_verifier: dog, resource: kaynak.resource }),
  })).json();
  let no = 0;
  return async function cagir(ad, args = {}) {
    const y = await fetch(`${adres}/mcp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${jeton.access_token}` },
      body: JSON.stringify({ jsonrpc: '2.0', id: ++no, method: 'tools/call', params: { name: ad, arguments: args } }),
    });
    const r = (await y.json()).result;
    const metin = r.content[0].text;
    return r.isError ? { hata: metin } : JSON.parse(metin);
  };
}

if (process.argv[2]) {
  const cagir = await baglan();
  console.log(JSON.stringify(await cagir(process.argv[2], JSON.parse(process.argv[3] || '{}')), null, 2));
}
