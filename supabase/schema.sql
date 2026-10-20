-- 왕이 되는 그날까지 · 랭킹 1단계 (Supabase SQL Editor에 통째로 붙여 넣고 Run)
-- 여러 번 실행해도 안전하게 만들었어요.

-- ── 시즌 계산: 2026-10-19(월) 00:00 KST부터 2주 단위, 1시즌부터 ──
create or replace function public.kd_season(t timestamptz default now())
returns int language sql immutable as $$
  select (floor(extract(epoch from (t - timestamptz '2026-10-19 00:00:00+09')) / 1209600))::int + 1
$$;
create or replace function public.kd_season_end(s int)
returns timestamptz language sql immutable as $$
  select timestamptz '2026-10-19 00:00:00+09' + make_interval(days => 14 * s)
$$;

-- ── 프로필: 닉네임·꾸미기 ──
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nick text not null,
  frame text default 'wood',
  badge text,
  title text,
  nick_season int default 0,
  created_at timestamptz default now()
);
-- 첫 기록을 보낸 시점의 스테이지·시각 (속도 검사 기준점)
alter table public.profiles add column if not exists base_stage int;
alter table public.profiles add column if not exists base_at timestamptz;
create unique index if not exists profiles_nick_key on public.profiles (lower(nick));

-- ── 기록: season=0 은 명예의 전당(역대 최고) ──
create table if not exists public.records (
  user_id uuid references public.profiles(id) on delete cascade,
  season int not null,
  stage int not null,
  power bigint default 0,
  reached_at timestamptz default now(),
  hidden boolean default false,
  primary key (user_id, season)
);
create index if not exists records_rank_idx on public.records (season, stage desc, reached_at asc) where not hidden;

alter table public.profiles enable row level security;
alter table public.records  enable row level security;
drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles for select using (true);
drop policy if exists "records read" on public.records;
create policy "records read" on public.records for select using (not hidden);
-- 쓰기는 아래 함수로만 (직접 insert/update 금지)

-- ── 닉네임 정하기/바꾸기 (시즌마다 1번 변경) ──
create or replace function public.kd_set_nick(p_nick text, p_frame text default null, p_badge text default null, p_title text default null)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); n text := btrim(p_nick); cur public.profiles;
begin
  if uid is null then return 'login'; end if;
  if char_length(n) < 2 or char_length(n) > 10 then return 'length'; end if;
  if n !~ '^[가-힣A-Za-z0-9_]+$' then return 'chars'; end if;
  if n ~* '(시발|씨발|ㅅㅂ|병신|ㅂㅅ|개새|좆|존나|fuck|shit|admin|운영자|관리자)' then return 'bad'; end if;
  select * into cur from public.profiles where id = uid;
  if found and lower(cur.nick) <> lower(n) and cur.nick_season = public.kd_season() then return 'once'; end if;
  if exists (select 1 from public.profiles where lower(nick) = lower(n) and id <> uid) then return 'taken'; end if;
  insert into public.profiles (id, nick, frame, badge, title, nick_season)
    values (uid, n, coalesce(p_frame,'wood'), p_badge, p_title, public.kd_season())
  on conflict (id) do update set
    nick = excluded.nick,
    nick_season = case when lower(public.profiles.nick) <> lower(excluded.nick) then public.kd_season() else public.profiles.nick_season end,
    frame = coalesce(p_frame, public.profiles.frame), badge = case when p_badge is null then public.profiles.badge else nullif(p_badge,'') end, title = coalesce(p_title, public.profiles.title);
  return 'ok';
end $$;

-- ── 기록 보내기: 시즌 기록과 역대 기록을 함께 갱신 ──
create or replace function public.kd_submit(p_stage int, p_power bigint default 0, p_frame text default null, p_badge text default null, p_title text default null)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); s int := public.kd_season(); age_min numeric; b int; sus boolean;
begin
  if uid is null then return 'login'; end if;
  if not exists (select 1 from public.profiles where id = uid) then return 'nick'; end if;
  if p_stage < 1 or p_stage > 61 then return 'range'; end if;
  -- 속도 검사: 랭킹에 처음 기록을 보낸 뒤 오른 스테이지가 걸린 시간에 비해 너무 빠르면 숨김(관리자 확인)
  -- (이미 진행한 유저가 늦게 랭킹에 들어와도 걸리지 않도록 첫 기록을 기준점으로 삼아요)
  update public.profiles set base_stage = p_stage, base_at = now() where id = uid and base_stage is null;
  select extract(epoch from (now() - base_at)) / 60, base_stage into age_min, b from public.profiles where id = uid;
  sus := p_stage - b > 5 and age_min < (p_stage - b) * 1.5;
  update public.profiles set frame = coalesce(p_frame, frame), badge = case when p_badge is null then badge else nullif(p_badge,'') end, title = coalesce(p_title, title) where id = uid;
  insert into public.records (user_id, season, stage, power, hidden) values (uid, s, p_stage, p_power, sus)
    on conflict (user_id, season) do update set stage = excluded.stage, power = excluded.power, reached_at = now(), hidden = public.records.hidden or excluded.hidden
    where excluded.stage > public.records.stage;
  insert into public.records (user_id, season, stage, power, hidden) values (uid, 0, p_stage, p_power, sus)
    on conflict (user_id, season) do update set stage = excluded.stage, power = excluded.power, reached_at = now(), hidden = public.records.hidden or excluded.hidden
    where excluded.stage > public.records.stage;
  return 'ok';
end $$;

-- ── 랭킹 받기: 상위 100명 + 내 순위 (p_season: 0=명예의 전당, null=지금 시즌) ──
create or replace function public.kd_ranking(p_season int default null)
returns table (rank bigint, nick text, stage int, power bigint, frame text, badge text, title text, me boolean, total bigint, season int, season_end timestamptz)
language sql stable security definer set search_path = public as $$
  with s as (select coalesce(p_season, public.kd_season()) as v),
  r as (
    select rc.user_id, rc.stage, rc.power, p.nick, p.frame, p.badge, p.title,
           row_number() over (order by rc.stage desc, rc.reached_at asc) as rk,
           count(*) over () as tot
    from public.records rc join public.profiles p on p.id = rc.user_id, s
    where rc.season = s.v and not rc.hidden
  )
  select rk, nick, stage, power, frame, badge, title, user_id = auth.uid(), tot, (select v from s),
         case when (select v from s) = 0 then null else public.kd_season_end((select v from s)) end
  from r where rk <= 100 or user_id = auth.uid()
  order by rk
$$;

grant execute on function public.kd_set_nick(text,text,text,text), public.kd_submit(int,bigint,text,text,text), public.kd_ranking(int), public.kd_season(timestamptz) to anon, authenticated;
