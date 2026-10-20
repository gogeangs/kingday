-- 왕이 되는 그날까지 · 인앱결제(앱) — 결제 확인 기록 + 우편으로 지급
-- SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전해요.
-- 결제 확인은 Edge Function「kd-iap」(supabase/functions/kd-iap)이 하고, 이 함수는 그 함수만 부를 수 있어요.

create table if not exists public.purchases (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  product_id text not null,
  token text not null,                 -- 안드로이드 purchaseToken / 아이폰 transactionId
  order_id text,
  created_at timestamptz not null default now(),
  unique (platform, token)             -- 같은 영수증으로 두 번 받지 못하게
);
alter table public.purchases enable row level security;   -- 정책 없음: 아래 함수로만 기록

-- 결제 확인이 끝난 구매를 기록하고 보상 우편을 보냄. 이미 받은 영수증이면 'dup'
create or replace function public.kd_iap_grant(p_user uuid, p_platform text, p_product text, p_token text, p_order text,
                                               p_title text, p_body text, p_reward jsonb)
returns text language plpgsql security definer set search_path = public as $$
begin
  insert into public.purchases (user_id, platform, product_id, token, order_id)
  values (p_user, p_platform, p_product, p_token, p_order)
  on conflict (platform, token) do nothing;
  if not found then return 'dup'; end if;
  -- (게임은 결제 전에 kd_ensure_profile 로 프로필을 꼭 만들어 둠 → 우편을 받을 수 있음)
  insert into public.mails (user_id, kind, title, body, reward, tag, expires_at)
  values (p_user, 'shop', p_title, p_body, p_reward, 'iap:' || p_platform || ':' || md5(p_token), now() + interval '365 days')
  on conflict do nothing;
  return 'ok';
end $$;

-- 게임(anon·로그인 사용자)에서는 부를 수 없고, Edge Function(service_role)만 부름
revoke all on function public.kd_iap_grant(uuid, text, text, text, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.kd_iap_grant(uuid, text, text, text, text, text, text, jsonb) to service_role;
