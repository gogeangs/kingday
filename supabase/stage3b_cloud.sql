-- 왕이 되는 그날까지 · 클라우드 저장 + 계정 연결 보상 (SQL Editor에 통째로 붙여 넣고 Run)
-- 여러 번 실행해도 안전해요.

create table if not exists public.saves (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null,
  stage int not null default 1,
  power bigint not null default 0,
  gem bigint not null default 0,
  sus boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.saves enable row level security;   -- 정책 없음: 아래 함수로만 읽고 써요

-- 저장 올리기 (크기 제한 300KB, 황금 이삭이 비정상적으로 급등하면 표시만 해 둬요)
create or replace function public.kd_save_put(p_data jsonb, p_stage int, p_power bigint, p_gem bigint)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); old public.saves; s boolean := false;
begin
  if uid is null then return 'login'; end if;
  if octet_length(p_data::text) > 300000 then return 'size'; end if;
  if p_stage < 1 or p_stage > 61 then return 'range'; end if;
  select * into old from public.saves where user_id = uid;
  if found then
    s := old.sus or (p_gem > old.gem + 20000 and now() - old.updated_at < interval '1 hour');
  end if;
  insert into public.saves (user_id, data, stage, power, gem, sus, updated_at)
    values (uid, p_data, p_stage, p_power, p_gem, s, now())
  on conflict (user_id) do update set data = excluded.data, stage = excluded.stage, power = excluded.power,
    gem = excluded.gem, sus = excluded.sus, updated_at = now();
  return 'ok';
end $$;

-- 저장 받기 (없으면 null)
create or replace function public.kd_save_get()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('data', data, 'stage', stage, 'power', power, 'gem', gem, 'updated_at', updated_at)
  from public.saves where user_id = auth.uid()
$$;

-- 계정 연결 보상: 구글 등으로 연결된 계정이면 한 번만 황금 이삭 50
create or replace function public.kd_link_reward()
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); anon boolean;
begin
  if uid is null then return 'login'; end if;
  select coalesce(is_anonymous, false) into anon from auth.users where id = uid;
  if anon then return 'anon'; end if;
  if not exists (select 1 from public.profiles where id = uid) then return 'nick'; end if;
  insert into public.mails (user_id, kind, title, body, reward, tag)
  values (uid, 'notice', '계정 연결 선물', '이제 휴대폰을 바꿔도 영지를 잃지 않아요. 연결해 주셔서 고마워요!', '{"gem":50}'::jsonb, 'link')
  on conflict (user_id, tag) where tag is not null do nothing;
  return 'ok';
end $$;

grant execute on function public.kd_save_put(jsonb,int,bigint,bigint), public.kd_save_get(), public.kd_link_reward() to anon, authenticated;
