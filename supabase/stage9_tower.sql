-- 9단계: 시련의 탑 랭킹 (2026-10-26, 대표님 결정: 역대 최고 층 순위 + 주간 보상)
-- 순위는 역대 최고 층(은퇴해도 남음), 같은 층이면 먼저 오른 사람이 위.
-- 주마다(고블린과 같은 주차) 그 주에 게임한 영주끼리 최고 층으로 정산 → 우편 보상.
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전. (stage3a_goblin.sql 다음)

-- ── 역대 최고 층 ──
create table if not exists public.tower_records (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  top int not null default 0,
  reached_at timestamptz not null default now(),
  hidden boolean not null default false
);
create index if not exists tower_rank_idx on public.tower_records (top desc, reached_at asc) where not hidden;
alter table public.tower_records enable row level security;   -- 정책 없음: 함수로만

-- ── 주마다 참여 기록 (그 주에 보낸 최고 층) ──
create table if not exists public.tower_weeks (
  user_id uuid references public.profiles(id) on delete cascade,
  week int not null,
  top int not null default 0,
  reached_at timestamptz not null default now(),
  hidden boolean not null default false,
  primary key (user_id, week)
);
create index if not exists tower_weeks_idx on public.tower_weeks (week, top desc, reached_at asc) where not hidden;
alter table public.tower_weeks enable row level security;

create table if not exists public.tower_settlements (
  week int primary key,
  players int,
  done_at timestamptz default now()
);
alter table public.tower_settlements enable row level security;

-- ── 최고 층 보내기 → 'ok' · 'login' · 'nick' · 'range' ──
-- 속도 검사: 탑 층 ≈ 막힌 영지 − 5 (기획서 10장). 최고 영지가 50 아래인데 최고 영지 + 40층을 넘으면 숨김.
create or replace function public.kd_tower_submit(p_top int)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); w int := public.kd_week(); hall int; sus boolean;
begin
  if uid is null then return 'login'; end if;
  if not exists (select 1 from public.profiles where id = uid) then return 'nick'; end if;
  if p_top is null or p_top < 1 or p_top > 5000 then return 'range'; end if;
  select stage into hall from public.records where user_id = uid and season = 0;
  sus := coalesce(hall, 0) < 50 and p_top > coalesce(hall, 0) + 40;
  insert into public.tower_records (user_id, top, hidden) values (uid, p_top, sus)
    on conflict (user_id) do update set top = excluded.top, reached_at = now(),
      hidden = public.tower_records.hidden or excluded.hidden
    where excluded.top > public.tower_records.top;
  insert into public.tower_weeks (user_id, week, top, hidden)
    select uid, w, t.top, t.hidden from public.tower_records t where t.user_id = uid
    on conflict (user_id, week) do update set top = excluded.top, reached_at = now(),
      hidden = public.tower_weeks.hidden or excluded.hidden
    where excluded.top > public.tower_weeks.top or excluded.hidden <> public.tower_weeks.hidden;
  return 'ok';
end $$;

-- ── 탑 랭킹: 역대 최고 층 상위 100명 + 나 (이번 주 번호·끝나는 때도 같이) ──
create or replace function public.kd_tower_ranking()
returns table (rank bigint, nick text, top int, frame text, badge text, title text, me boolean, total bigint, week int, week_end timestamptz, face text)
language sql stable security definer set search_path = public as $$
  with w as (select public.kd_week() as v),
  r as (
    select t.user_id, t.top, p.nick, p.frame, p.badge, p.title, p.face,
           row_number() over (order by t.top desc, t.reached_at asc) as rk,
           count(*) over () as tot
    from public.tower_records t join public.profiles p on p.id = t.user_id
    where not t.hidden and t.top > 0
  )
  select rk, nick, top, frame, badge, title, user_id = auth.uid(), tot, (select v from w), public.kd_week_end((select v from w)), face
  from r where rk <= 100 or user_id = auth.uid()
  order by rk
$$;

-- ── 끝난 주 정산: 그 주에 게임한 영주끼리 최고 층 순 · 1위 이삭 100, 2~10위 50, 상위 30% 20 ──
create or replace function public.kd_tower_settle_due()
returns void language plpgsql security definer set search_path = public as $$
declare w int; cur int := public.kd_week(); n int;
begin
  if cur <= 1 then return; end if;
  for w in 1 .. cur - 1 loop
    continue when exists (select 1 from public.tower_settlements where week = w);
    perform pg_advisory_xact_lock(454545);
    continue when exists (select 1 from public.tower_settlements where week = w);
    with r as (
      select user_id, top,
             row_number() over (order by top desc, reached_at asc) as rk,
             count(*) over () as tot
      from public.tower_weeks where week = w and not hidden and top > 0
    )
    insert into public.mails (user_id, kind, title, body, reward, tag)
    select user_id, 'season',
      w || '주차 시련의 탑 랭킹 · ' || rk || '위',
      '시련의 탑 ' || top || '층으로 이번 주 ' || rk || '위에 올랐어요. (참여 ' || tot || '명)',
      case when rk = 1 then '{"gem":100}'::jsonb
           when rk <= 10 then '{"gem":50}'::jsonb
           else '{"gem":20}'::jsonb end,
      'tower:' || w
    from r where rk <= 10 or rk <= ceil(tot * 0.3)
    on conflict (user_id, tag) where tag is not null do nothing;
    get diagnostics n = row_count;
    insert into public.tower_settlements (week, players) values (w, n);
  end loop;
end $$;

-- 우편함을 열 때 시즌·고블린 정산과 함께 탑 주간 정산도 (stage3a_goblin.sql 의 kd_mail_list 에 한 줄 추가)
create or replace function public.kd_mail_list()
returns table (id bigint, kind text, title text, body text, reward jsonb, created_at timestamptz, expires_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  perform public.kd_settle_due();
  perform public.kd_gob_settle_due();
  perform public.kd_tower_settle_due();
  return query
    select m.id, m.kind, m.title, m.body, m.reward, m.created_at, m.expires_at
    from public.mails m
    where m.user_id = auth.uid() and m.claimed_at is null and m.expires_at > now()
    order by m.created_at desc
    limit 100;
end $$;

revoke all on function public.kd_tower_settle_due() from public, anon, authenticated;
grant execute on function public.kd_tower_submit(int), public.kd_tower_ranking(), public.kd_mail_list() to anon, authenticated;
