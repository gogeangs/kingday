-- 7단계: 상점·패스 (2026-10-26, docs/content/SHOP.md 7장)
-- ① 결제 기록에 시즌 번호 칸(season)을 더함 — 「원정 일지」(kd_pass)는 랭킹 시즌 번호와 함께 기록
-- ② kd_iap_grant: 원정 일지는 우편 보상을 {pass: 지금 시즌}으로 보내고, 같은 계정·같은 시즌 두 번째 결제는
--    보상 대신 황금 이삭 200(유료 줄 값)으로 돌려줌. 「영주의 첫걸음」(kd_growth)은 계정당 1번만 지급
--    (아이폰 「구매 복원」으로 같은 상품 영수증이 다시 와도 두 번 받지 않음)
-- 함수 이름·받는 값은 그대로라 Edge Function(kd-iap)은 상품 2개만 추가하면 됨.
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전.

alter table public.purchases add column if not exists season int;
create index if not exists purchases_user_product on public.purchases (user_id, product_id, season);

create or replace function public.kd_iap_grant(p_user uuid, p_platform text, p_product text, p_token text, p_order text,
                                               p_title text, p_body text, p_reward jsonb)
returns text language plpgsql security definer set search_path = public as $$
declare
  s int := null;
  r jsonb := p_reward;
  t text := p_title;
  b text := p_body;
  again boolean := false;
begin
  if p_product = 'kd_pass' then
    s := public.kd_season();
    again := exists (select 1 from public.purchases where user_id = p_user and product_id = 'kd_pass' and season = s);
  elsif p_product = 'kd_growth' then
    again := exists (select 1 from public.purchases where user_id = p_user and product_id = 'kd_growth');
  end if;

  insert into public.purchases (user_id, platform, product_id, token, order_id, season)
  values (p_user, p_platform, p_product, p_token, p_order, s)
  on conflict (platform, token) do nothing;
  if not found then return 'dup'; end if;

  if p_product = 'kd_growth' and again then return 'dup'; end if;
  if p_product = 'kd_pass' then
    if again then
      r := '{"gem":200}'::jsonb;
      t := '원정 일지 · 이미 열린 시즌';
      b := '이번 시즌 원정 일지는 이미 열려 있어서 황금 이삭 200으로 돌려 드려요.';
    else
      r := jsonb_build_object('pass', s);
    end if;
  end if;

  -- (게임은 결제 전에 kd_ensure_profile 로 프로필을 꼭 만들어 둠 → 우편을 받을 수 있음)
  insert into public.mails (user_id, kind, title, body, reward, tag, expires_at)
  values (p_user, 'shop', t, b, r, 'iap:' || p_platform || ':' || md5(p_token), now() + interval '365 days')
  on conflict do nothing;
  return 'ok';
end $$;

-- 게임(anon·로그인 사용자)에서는 부를 수 없고, Edge Function(service_role)만 부름
revoke all on function public.kd_iap_grant(uuid, text, text, text, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.kd_iap_grant(uuid, text, text, text, text, text, text, jsonb) to service_role;
