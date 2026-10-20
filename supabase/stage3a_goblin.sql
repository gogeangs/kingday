-- 왕이 되는 그날까지 · 황금 고블린 주간 랭킹 (SQL Editor에 통째로 붙여 넣고 Run)
-- stage2_mail.sql 다음에 실행하세요. 여러 번 실행해도 안전해요.

-- ── 주차: 2026-10-19(월) 00:00 KST부터 1주 단위, 1주차부터 ──
create or replace function public.kd_week(t timestamptz default now())
returns int language sql immutable as $$
  select (floor(extract(epoch from (t - timestamptz '2026-10-19 00:00:00+09')) / 604800))::int + 1
$$;
create or replace function public.kd_week_end(w int)
returns timestamptz language sql immutable as $$
  select timestamptz '2026-10-19 00:00:00+09' + make_interval(days => 7 * w)
$$;

create table if not exists public.goblin_weeks (
  user_id uuid references public.profiles(id) on delete cascade,
  week int not null,
  kills int not null default 0,
  hidden boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, week)
);
create index if not exists goblin_rank_idx on public.goblin_weeks (week, kills desc, updated_at asc) where not hidden;
alter table public.goblin_weeks enable row level security;

create table if not exists public.goblin_settlements (
  week int primary key,
  players int,
  done_at timestamptz default now()
);
alter table public.goblin_settlements enable row level security;

-- ── 이번 주 고블린 처치 수 보내기 ──
-- 속도 검사: 고블린은 빨라도 3분에 한 마리 → 이번 주 지난 시간보다 많이 잡았으면 숨김
create or replace function public.kd_gob_submit(p_week int, p_kills int)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); mins numeric; sus boolean;
begin
  if uid is null then return 'login'; end if;
  if not exists (select 1 from public.profiles where id = uid) then return 'nick'; end if;
  if p_week <> public.kd_week() then return 'week'; end if;
  if p_kills < 1 or p_kills > 5000 then return 'range'; end if;
  mins := extract(epoch from (now() - (public.kd_week_end(p_week) - interval '7 days'))) / 60;
  sus := p_kills > floor(mins / 3) + 3;
  insert into public.goblin_weeks (user_id, week, kills, hidden) values (uid, p_week, p_kills, sus)
    on conflict (user_id, week) do update set kills = excluded.kills, updated_at = now(),
      hidden = public.goblin_weeks.hidden or excluded.hidden
    where excluded.kills > public.goblin_weeks.kills;
  return 'ok';
end $$;

-- ── 이번 주 고블린 랭킹: 상위 100명 + 나 ──
create or replace function public.kd_gob_ranking()
returns table (rank bigint, nick text, kills int, frame text, badge text, title text, me boolean, total bigint, week int, week_end timestamptz)
language sql stable security definer set search_path = public as $$
  with w as (select public.kd_week() as v),
  r as (
    select g.user_id, g.kills, p.nick, p.frame, p.badge, p.title,
           row_number() over (order by g.kills desc, g.updated_at asc) as rk,
           count(*) over () as tot
    from public.goblin_weeks g join public.profiles p on p.id = g.user_id, w
    where g.week = w.v and not g.hidden and g.kills > 0
  )
  select rk, nick, kills, frame, badge, title, user_id = auth.uid(), tot, (select v from w), public.kd_week_end((select v from w))
  from r where rk <= 100 or user_id = auth.uid()
  order by rk
$$;

-- ── 끝난 주 정산: 1위 이삭 100 + 고블린 사냥꾼 배지, 2~10위 50, 상위 30% 20 ──
create or replace function public.kd_gob_settle_due()
returns void language plpgsql security definer set search_path = public as $$
declare w int; cur int := public.kd_week(); n int;
begin
  if cur <= 1 then return; end if;
  for w in 1 .. cur - 1 loop
    continue when exists (select 1 from public.goblin_settlements where week = w);
    perform pg_advisory_xact_lock(434343);
    continue when exists (select 1 from public.goblin_settlements where week = w);
    with r as (
      select user_id, kills,
             row_number() over (order by kills desc, updated_at asc) as rk,
             count(*) over () as tot
      from public.goblin_weeks where week = w and not hidden and kills > 0
    )
    insert into public.mails (user_id, kind, title, body, reward, tag)
    select user_id, 'season',
      w || '주차 황금 고블린 랭킹 · ' || rk || '위',
      '이번 주 황금 고블린을 ' || kills || '마리 잡아 ' || rk || '위에 올랐어요. (참여 ' || tot || '명)',
      case when rk = 1 then '{"gem":100,"badge":"goblin"}'::jsonb
           when rk <= 10 then '{"gem":50}'::jsonb
           else '{"gem":20}'::jsonb end,
      'gob:' || w
    from r where rk <= 10 or rk <= ceil(tot * 0.3)
    on conflict (user_id, tag) where tag is not null do nothing;
    get diagnostics n = row_count;
    insert into public.goblin_settlements (week, players) values (w, n);
  end loop;
end $$;

-- 우편함을 열 때 시즌 정산과 함께 고블린 주간 정산도 해요
create or replace function public.kd_mail_list()
returns table (id bigint, kind text, title text, body text, reward jsonb, created_at timestamptz, expires_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  perform public.kd_settle_due();
  perform public.kd_gob_settle_due();
  return query
    select m.id, m.kind, m.title, m.body, m.reward, m.created_at, m.expires_at
    from public.mails m
    where m.user_id = auth.uid() and m.claimed_at is null and m.expires_at > now()
    order by m.created_at desc
    limit 100;
end $$;

revoke all on function public.kd_gob_settle_due() from public, anon, authenticated;
grant execute on function public.kd_gob_submit(int,int), public.kd_gob_ranking(), public.kd_mail_list() to anon, authenticated;
