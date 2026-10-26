// 왕이 되는 그날까지 · 인앱결제 확인 (Supabase Edge Function)
//
// 앱이 결제를 마치면 이 함수에 영수증을 보냄 → 구글/애플 서버에 진짜 결제인지 물어봄 → 맞으면 kd_iap_grant 로 기록 + 보상 우편.
// 게임 안에서 바로 지급하지 않으므로 가짜 영수증·같은 영수증 두 번 쓰기가 막힘.
//
// 배포(대표님): Supabase 대시보드 → Edge Functions → kd-iap 만들기 → 이 파일 붙여 넣기 (또는 supabase functions deploy kd-iap)
// 비밀값(Edge Function Secrets 에만 넣고 코드·문서에는 절대 넣지 않음):
//   GOOGLE_SERVICE_ACCOUNT_JSON  Play Console 에서 권한을 준 서비스 계정 키(JSON 전체)
//   APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY  App Store Connect → 사용자 및 액세스 → 키(인앱 구매)
// SUPABASE_URL · SUPABASE_SERVICE_ROLE_KEY 는 Supabase 가 자동으로 넣어 줌.

const PKG = 'kr.co.project30s.kingday';

// 상품 → 보상 (앱 lib/game/store.dart 의 상품 ID 와 같아야 함)
const PRODUCTS: Record<string, { title: string; reward: Record<string, unknown>; sub?: boolean }> = {
  kd_gem_60: { title: '황금 이삭 60', reward: { gem: 60, pack: 'p1' } },
  kd_gem_330: { title: '황금 이삭 330', reward: { gem: 330, pack: 'p2' } },
  kd_gem_680: { title: '황금 이삭 680', reward: { gem: 680, pack: 'p3' } },
  kd_gem_1280: { title: '황금 이삭 1,280', reward: { gem: 1280, pack: 'p4' } },
  kd_gem_3280: { title: '황금 이삭 3,280', reward: { gem: 3280, pack: 'p5' } },
  kd_gem_6480: { title: '황금 이삭 6,480', reward: { gem: 6480, pack: 'p6' } },
  kd_starter: { title: '첫 거래 특가', reward: { starter: 1 } },
  kd_chief: { title: '카엘 촌장 맞이하기', reward: { chief: 1 } },
  kd_ttukttak: { title: '뚝딱이 맞이하기', reward: { ttuk: 1 } },
  kd_lucian: { title: '루시안 맞이하기', reward: { lucian: 1 } },
  kd_sub_monthly: { title: '피트의 정기 배송', reward: { sub_days: 30 }, sub: true },
  // 상점·패스 (docs/content/SHOP.md): 원정 일지 보상 {pass: 시즌 번호}·같은 시즌 중복은 SQL kd_iap_grant 가 처리 (supabase/stage7_pass.sql)
  kd_pass: { title: '원정 일지', reward: { pass: 1 } },
  kd_growth: { title: '영주의 첫걸음', reward: { grow: 1 } },
};

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
};
const json = (v: unknown, status = 200) => new Response(JSON.stringify(v), { status, headers: { ...cors, 'content-type': 'application/json' } });

const b64url = (b: ArrayBuffer | Uint8Array | string) => {
  const bytes = typeof b === 'string' ? new TextEncoder().encode(b) : new Uint8Array(b instanceof ArrayBuffer ? b : b.buffer);
  let s = '';
  for (const x of bytes) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};
const pem = (p: string) => Uint8Array.from(atob(p.replace(/-----[^-]+-----/g, '').replace(/\s/g, '')), (c) => c.charCodeAt(0));

// ── 구글: 서비스 계정으로 OAuth 토큰 받기 ──
async function googleToken(): Promise<string> {
  const sa = JSON.parse(Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON') ?? '{}');
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const body = b64url(JSON.stringify({
    iss: sa.client_email, scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  }));
  const key = await crypto.subtle.importKey('pkcs8', pem(sa.private_key), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${head}.${body}`));
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${head}.${body}.${b64url(sig)}` }),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error('google auth');
  return j.access_token;
}

async function verifyAndroid(productId: string, token: string, sub: boolean): Promise<{ ok: boolean; order?: string; why?: string }> {
  const at = await googleToken();
  const base = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PKG}/purchases`;
  if (sub) {
    const r = await fetch(`${base}/subscriptionsv2/tokens/${token}`, { headers: { authorization: `Bearer ${at}` } });
    const j = await r.json();
    const ok = ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'].includes(j.subscriptionState) &&
      (j.lineItems ?? []).some((l: { productId: string }) => l.productId === productId);
    return { ok, order: j.latestOrderId, why: ok ? undefined : `sub:${r.status}:${j.subscriptionState ?? JSON.stringify(j.error ?? {}).slice(0, 200)}` };
  }
  const r = await fetch(`${base}/products/${productId}/tokens/${token}`, { headers: { authorization: `Bearer ${at}` } });
  const j = await r.json();
  const ok = r.ok && j.purchaseState === 0;
  return { ok, order: j.orderId, why: ok ? undefined : `prod:${r.status}:${j.purchaseState ?? JSON.stringify(j.error ?? {}).slice(0, 200)}` };
}

// ── 애플: App Store Server API (ES256 토큰) ──
async function appleJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: 'ES256', kid: Deno.env.get('APPLE_KEY_ID'), typ: 'JWT' }));
  const body = b64url(JSON.stringify({ iss: Deno.env.get('APPLE_ISSUER_ID'), iat: now, exp: now + 1800, aud: 'appstoreconnect-v1', bid: PKG }));
  const key = await crypto.subtle.importKey('pkcs8', pem(Deno.env.get('APPLE_PRIVATE_KEY') ?? ''), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(`${head}.${body}`));
  return `${head}.${body}.${b64url(sig)}`;
}

async function verifyIos(productId: string, transactionId: string): Promise<{ ok: boolean; order?: string; why?: string }> {
  const jwt = await appleJwt();
  const why: string[] = [];
  for (const host of ['https://api.storekit.itunes.apple.com', 'https://api.storekit-sandbox.itunes.apple.com']) {
    const r = await fetch(`${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`, { headers: { authorization: `Bearer ${jwt}` } });
    const env = host.includes('sandbox') ? 'sandbox' : 'prod';
    if (!r.ok) {
      // 진단용: 애플이 돌려준 상태·오류 코드만 남김 (비밀값 없음)
      why.push(`${env}:${r.status}:${(await r.text()).slice(0, 200)}`);
      continue; // 시험 결제는 sandbox 에 있음 (prod 는 404·401 등으로 거절)
    }
    const j = await r.json();
    // 애플 서버에서 TLS 로 직접 받은 값이므로 내용만 읽음
    const b = j.signedTransactionInfo.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    const p = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(b + '='.repeat((4 - (b.length % 4)) % 4)), (c) => c.charCodeAt(0))));
    const ok = p.bundleId === PKG && p.productId === productId && !p.revocationDate;
    if (!ok) why.push(`${env}:mismatch:${p.bundleId}:${p.productId}:${p.revocationDate ?? ''}`);
    return { ok, order: p.originalTransactionId, why: why.join(' | ') };
  }
  return { ok: false, why: why.join(' | ') };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return json('ok');
  try {
    const url = Deno.env.get('SUPABASE_URL')!, service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    // 누가 샀는지: 앱이 보낸 로그인 토큰으로 확인
    const auth = req.headers.get('authorization') ?? '';
    const u = await fetch(`${url}/auth/v1/user`, { headers: { authorization: auth, apikey: service } });
    if (!u.ok) return json({ error: 'login' }, 401);
    const user = await u.json();

    const { platform, productId, token } = await req.json();
    const p = PRODUCTS[productId];
    if (!p || !token || !['android', 'ios'].includes(platform)) return json({ error: 'bad' }, 400);

    const v = platform === 'android' ? await verifyAndroid(productId, token, !!p.sub) : await verifyIos(productId, token);
    if (!v.ok) {
      console.log('verify fail', platform, productId, String(token).slice(0, 24), v.why ?? '');
      return json({ error: 'verify', why: v.why ?? '' }, 402);
    }

    const r = await fetch(`${url}/rest/v1/rpc/kd_iap_grant`, {
      method: 'POST',
      headers: { apikey: service, authorization: `Bearer ${service}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        p_user: user.id, p_platform: platform, p_product: productId, p_token: token, p_order: v.order ?? null,
        p_title: `구매 완료 · ${p.title}`, p_body: '피트가 보낸 물건이 도착했어요. 감사합니다!', p_reward: p.reward,
      }),
    });
    const res = await r.json();
    return json({ result: res }); // 'ok' 또는 'dup'
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
