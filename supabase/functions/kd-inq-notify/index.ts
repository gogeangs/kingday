// 왕이 되는 그날까지 · 새 문의 메일 알림 (Supabase Edge Function)
//
// 게임(웹·앱)이 문의를 보낸 직후 로그인 토큰과 함께 이 함수를 부름 → 그 사람의 방금 문의(아직 알리지 않은 것)를 하나 꺼내
// 대표님 메일로 「새 문의」를 보냄. 같은 문의는 두 번 알리지 않음(supabase/stage10_inquiry_notify.sql 의 kd_inq_take_notify).
//
// 배포(대표님): Supabase 대시보드 → Edge Functions → 「kd-inq-notify」 만들기 → 이 파일 붙여 넣기 (또는 supabase functions deploy kd-inq-notify)
// 비밀값(Edge Function Secrets 에만 넣고 코드·문서에는 넣지 않음):
//   RESEND_API_KEY  메일 보내기 서비스 Resend(resend.com) 의 API 키
//   NOTIFY_TO       알림 받을 메일 주소
//   NOTIFY_FROM     (선택) 보내는 주소. 없으면 Resend 시험 주소 onboarding@resend.dev (Resend 가입 메일로만 보낼 수 있음)
// RESEND_API_KEY 나 NOTIFY_TO 가 없으면 아무것도 보내지 않고 조용히 끝남(게임은 그대로).
// SUPABASE_URL · SUPABASE_SERVICE_ROLE_KEY 는 Supabase 가 자동으로 넣어 줌.

const ADMIN = 'https://gogeangs.github.io/kingday/admin.html';
const KN: Record<string, string> = { pay: '결제', bug: '버그', account: '계정', etc: '기타' };

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
};
const json = (v: unknown, status = 200) => new Response(JSON.stringify(v), { status, headers: { ...cors, 'content-type': 'application/json' } });
const esc = (s: unknown) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return json('ok');
  try {
    const key = Deno.env.get('RESEND_API_KEY'), to = Deno.env.get('NOTIFY_TO');
    if (!key || !to) return json({ result: 'off' });
    const url = Deno.env.get('SUPABASE_URL')!, service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // 누가 보냈는지: 게임이 보낸 로그인 토큰으로 확인
    const u = await fetch(`${url}/auth/v1/user`, { headers: { authorization: req.headers.get('authorization') ?? '', apikey: service } });
    if (!u.ok) return json({ error: 'login' }, 401);
    const user = await u.json();

    const r = await fetch(`${url}/rest/v1/rpc/kd_inq_take_notify`, {
      method: 'POST',
      headers: { apikey: service, authorization: `Bearer ${service}`, 'content-type': 'application/json' },
      body: JSON.stringify({ p_user: user.id }),
    });
    const rows = await r.json();
    const q = Array.isArray(rows) ? rows[0] : null;
    if (!q) return json({ result: 'none' });

    const kind = KN[q.kind] ?? q.kind;
    const subject = `[왕이 되는 그날까지] 새 문의 · ${kind} · ${q.nick ?? '닉네임 없음'}`;
    const html = `<div style="font-family:-apple-system,'Apple SD Gothic Neo','Malgun Gothic',sans-serif;line-height:1.6">
<p><b>새 문의가 왔어요</b> (#${q.id} · ${esc(kind)})</p>
<p>보낸 사람: ${esc(q.nick ?? '-')} · ${esc(q.platform ?? '-')} ${esc(q.app_ver ?? '')}${q.has_photo ? ' · 📷 사진 1장' : ''}</p>
<div style="white-space:pre-wrap;background:#f5f5f7;border-radius:8px;padding:12px">${esc(q.body)}</div>
<p>처리 전 문의: ${q.open_count}개</p>
<p><a href="${ADMIN}">관리 페이지에서 보기 →</a></p></div>`;
    const m = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { authorization: `Bearer ${key}`, 'content-type': 'application/json' },
      body: JSON.stringify({ from: Deno.env.get('NOTIFY_FROM') ?? '왕이 되는 그날까지 <onboarding@resend.dev>', to: [to], subject, html }),
    });
    if (!m.ok) {
      console.log('mail fail', m.status, (await m.text()).slice(0, 200));
      return json({ error: 'mail' }, 502);
    }
    return json({ result: 'sent' });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
