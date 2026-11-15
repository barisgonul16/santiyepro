// Firestore'dan yalnızca okur. Uygulama her koleksiyonu users/{uid}/data/{ad}
// belgesinde, "json" alanında metin olarak tutar ("updatedAt" son yazma zamanı).
// Kimlik: kullanıcının Firebase yenileme anahtarı (Worker secret'ı), bir saatlik
// kimlik jetonuna çevrilir.

const FIREBASE_PROJE = 'santiyepro-49515';
const FIREBASE_ANAHTAR = 'AIzaSyCnWJIUcsiBrsZSdHndBeVHSIPCj4HlduE'; // uygulamanın Windows/web anahtarı (gizli değil)
const ONBELLEK_MS = 60_000;

export class BulutHatasi extends Error {}

async function istek(url, secenekler) {
  let yanit;
  try {
    yanit = await fetch(url, { ...secenekler, signal: AbortSignal.timeout(20_000) });
  } catch (e) {
    throw new BulutHatasi(`bağlantı kurulamadı (${e.message || e})`);
  }
  const govde = await yanit.text();
  let veri = null;
  try {
    veri = govde ? JSON.parse(govde) : null;
  } catch {
    veri = null;
  }
  if (!yanit.ok) {
    let ayrinti = veri && (veri.error ?? veri);
    if (ayrinti && typeof ayrinti === 'object') ayrinti = ayrinti.message || JSON.stringify(ayrinti);
    const hata = new BulutHatasi(`HTTP ${yanit.status} ${ayrinti || ''}`.trim());
    hata.durum = yanit.status;
    throw hata;
  }
  return veri;
}

// Aynı Worker örneği içinde yeniden kullanılır (istekler arası).
const jeton = { deger: null, bitis: 0 };
const onbellek = new Map(); // ad -> { zaman, veri, ms }

async function kimlikJetonu(env) {
  if (jeton.deger && Date.now() < jeton.bitis) return jeton.deger;
  let y;
  try {
    y = await istek(`https://securetoken.googleapis.com/v1/token?key=${FIREBASE_ANAHTAR}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'refresh_token', refresh_token: env.FIREBASE_YENILEME }),
    });
  } catch (e) {
    if (/TOKEN_EXPIRED|INVALID_REFRESH_TOKEN|USER_/.test(e.message)) {
      throw new BulutHatasi('bulut oturumu geçersiz; bilgisayarda "python araclar/santiyepro_mcp.py giris" ile yeniden giriş yapıp FIREBASE_YENILEME secretını güncelleyin');
    }
    throw e;
  }
  jeton.deger = y.id_token;
  jeton.bitis = Date.now() + (Number(y.expires_in) || 3600) * 1000 - 120_000;
  return jeton.deger;
}

function zamanMs(rfc3339) {
  if (!rfc3339) return 0;
  const ms = Date.parse(rfc3339);
  return Number.isFinite(ms) ? ms : 0;
}

/** { veri, ms } ya da belge yoksa { veri: null, ms: 0 }. */
export async function bulutOku(env, ad) {
  const k = onbellek.get(ad);
  if (k && Date.now() - k.zaman < ONBELLEK_MS) return k;
  if (!env.FIREBASE_UID || !env.FIREBASE_YENILEME) {
    throw new BulutHatasi('FIREBASE_UID / FIREBASE_YENILEME secretları tanımlı değil');
  }
  const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJE}/databases/(default)/documents/users/${encodeURIComponent(env.FIREBASE_UID)}/data/${encodeURIComponent(ad)}`;
  let sonuc = { veri: null, ms: 0 };
  try {
    const belge = await istek(url, { headers: { Authorization: `Bearer ${await kimlikJetonu(env)}` } });
    const alanlar = belge.fields || {};
    const metin = (alanlar.json || {}).stringValue || '';
    if (metin.trim()) {
      sonuc = {
        veri: JSON.parse(metin),
        ms: zamanMs((alanlar.updatedAt || {}).timestampValue) || zamanMs(belge.updateTime),
      };
    }
  } catch (e) {
    if (e.durum !== 404) throw e;
  }
  sonuc = { ...sonuc, zaman: Date.now() };
  onbellek.set(ad, sonuc);
  return sonuc;
}

// ---------------------------------------------------------------- Claude gelen kutusu
//
// Claude'un önerdiği kayıtlar users/{uid}/data/claude_gelen/oneriler/{id}
// belgelerine yazılır. Uygulamanın kendi verisine (data/project_logs vb.)
// ASLA yazılmaz: kayıtları uygulama, kullanıcı onaylayınca kendisi ekler ve
// belgeyi siler. Böylece açık bir uygulamanın eski listesi Claude'un yazdığını
// ezemez.

function gelenKutusuUrl(env, id = '') {
  return `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJE}/databases/(default)/documents/users/${encodeURIComponent(env.FIREBASE_UID)}/data/claude_gelen/oneriler${id ? '/' + encodeURIComponent(id) : ''}`;
}

async function yetki(env) {
  if (!env.FIREBASE_UID || !env.FIREBASE_YENILEME) {
    throw new BulutHatasi('FIREBASE_UID / FIREBASE_YENILEME secretları tanımlı değil');
  }
  return { Authorization: `Bearer ${await kimlikJetonu(env)}` };
}

function belgedenOneri(belge) {
  const f = belge.fields || {};
  let icerik = null;
  try {
    icerik = JSON.parse((f.json || {}).stringValue || 'null');
  } catch {
    icerik = null;
  }
  return {
    id: belge.name.split('/').pop(),
    aciklama: (f.aciklama || {}).stringValue || '',
    olusturma: zamanMs((f.olusturma || {}).timestampValue) || zamanMs(belge.createTime),
    icerik,
  };
}

/** Öneriyi gelen kutusuna yazar; belge kimliğini döndürür. */
export async function oneriYaz(env, icerik, aciklama) {
  const belge = await istek(gelenKutusuUrl(env), {
    method: 'POST',
    headers: { ...(await yetki(env)), 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        json: { stringValue: JSON.stringify(icerik) },
        aciklama: { stringValue: aciklama || '' },
        olusturma: { timestampValue: new Date().toISOString() },
        kaynak: { stringValue: 'claude' },
      },
    }),
  });
  return belge.name.split('/').pop();
}

/** Uygulamada henüz onaylanmamış öneriler, eskiden yeniye. */
export async function oneriler(env) {
  const hepsi = [];
  let sayfa = '';
  do {
    const url = gelenKutusuUrl(env) + '?pageSize=100' + (sayfa ? '&pageToken=' + encodeURIComponent(sayfa) : '');
    let y;
    try {
      y = await istek(url, { headers: await yetki(env) });
    } catch (e) {
      if (e.durum === 404) break;
      throw e;
    }
    for (const b of (y && y.documents) || []) hepsi.push(belgedenOneri(b));
    sayfa = (y && y.nextPageToken) || '';
  } while (sayfa);
  return hepsi.sort((a, b) => a.olusturma - b.olusturma);
}

/** Öneriyi siler; yoksa false. */
export async function oneriSil(env, id) {
  try {
    await istek(gelenKutusuUrl(env, id) + '?currentDocument.exists=true', { method: 'DELETE', headers: await yetki(env) });
    return true;
  } catch (e) {
    if (e.durum === 404 || /NOT_FOUND|FAILED_PRECONDITION/.test(e.message)) return false;
    throw e;
  }
}

/** ms → "YYYY-MM-DD HH:MM" (Türkiye saati). */
export function turkiyeSaati(ms) {
  if (!ms) return null;
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Europe/Istanbul', year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
    }).formatToParts(new Date(ms)).map((x) => [x.type, x.value]),
  );
  return `${p.year}-${p.month}-${p.day} ${p.hour}:${p.minute}`;
}
