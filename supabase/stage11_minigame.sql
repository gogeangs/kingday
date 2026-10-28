-- 11단계(이벤트): 정기 이벤트 날짜 표 + 미니게임 랭킹 (2026-10-29, docs/content/EVENT_SNOW.md 3-1·3-10)
-- 새로 더하기만 함: 기존 표·함수(우편 kd_mail_list·kd_mail_claim, 랭킹, 탑 등)는 그대로. 앱이 그대로 돌아감.
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전. (schema.sql·stage2_mail.sql 다음이면 언제든)
--
-- ① kd_events      : 이벤트마다 시작·끝·상점 끝 (읽기만 공개). 날짜를 바꿀 때는 이 표 한 줄만 고치면 됨 (앱 재심사 필요 없음)
-- ② kd_minigames   : 미니게임 랭킹 설정 (기록 받는 기간·정산 시각·한 판 최대 점수·하루 판 수·보상)
-- ③ kd_mg_plays    : 판 번호 (판을 시작할 때 서버가 줌 → 이 번호로만 기록 제출)
-- ④ kd_minigame_scores : 계정마다 한 판 최고 점수 (같은 점수면 먼저 낸 사람이 위, hidden = 랭킹에서 빠짐 — 탑 랭킹과 같은 방식)
-- 함수: kd_event_list(로그인 없이 읽기) · kd_mg_start · kd_mg_submit · kd_mg_ranking · kd_mg_settle_due(정산, 직접 부를 수 없음)
-- 미니게임 id 를 받으므로 다음 이벤트 미니게임도 kd_minigames 에 한 줄 더하면 그대로 씀.

-- ── ① 이벤트 날짜 ──
create table if not exists public.kd_events (
  id text primary key,                      -- 'snow2026', 다음: 'newyear2027', 'seol2027' …
  name text not null,
  start_at timestamptz not null,
  end_at timestamptz not null,              -- 이벤트 끝 (이 시각부터 상점만)
  shop_end_at timestamptz not null,         -- 상점 끝 (이 시각부터 이벤트 저장·재화 지움)
  extra jsonb not null default '{}'::jsonb, -- 이벤트마다 더 필요한 날짜 (눈꽃제: {"xmas":[크리스마스 주간 시작, 끝]})
  updated_at timestamptz not null default now()
);
alter table public.kd_events enable row level security;
drop policy if exists kd_events_read on public.kd_events;
create policy kd_events_read on public.kd_events for select to anon, authenticated using (true);  -- 읽기만 공개 (쓰기 정책 없음)
grant select on public.kd_events to anon, authenticated;

insert into public.kd_events (id, name, start_at, end_at, shop_end_at, extra) values
  ('snow2026', '눈꽃제', '2026-12-11 00:00+09', '2027-01-01 00:00+09', '2027-01-08 00:00+09',
   '{"xmas":["2026-12-21T00:00:00+09:00","2026-12-26T00:00:00+09:00"]}')
on conflict (id) do nothing;

-- 이벤트 목록 + 서버 시각 (웹이 시계 되돌림을 막는 데 씀). 로그인 없이 부를 수 있음
create or replace function public.kd_event_list()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'now', now(),
    'events', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'name', e.name, 'start_at', e.start_at, 'end_at', e.end_at,
                                                          'shop_end_at', e.shop_end_at, 'extra', e.extra) order by e.start_at)
                        from public.kd_events e where e.shop_end_at > now() - interval '1 day'), '[]'::jsonb))
$$;

-- ── ② 미니게임 설정 ──
create table if not exists public.kd_minigames (
  id text primary key,                      -- 'gift2026'
  event_id text references public.kd_events(id),
  name text not null,
  play_from timestamptz not null,           -- 이때부터 보상 판(기록) 시작 가능
  play_to timestamptz not null,             -- 이때까지 시작한 판만 기록
  settle_at timestamptz not null,           -- 정산 시각 (이 뒤 첫 조회 때 순위 확정 → 우편)
  max_score int not null,                   -- 한 판 최대 가능 점수 (넘으면 거절)
  daily_max int not null default 4,         -- 하루(한국 날짜) 보상 판 수 (3판 + 광고 1)
  min_sec int not null default 28,          -- 판 시작 뒤 이 초보다 빨리 낸 기록은 거절 (한 판 30초)
  max_sec int not null default 600,         -- 판 시작 뒤 이 초가 지나면 거절
  rewards jsonb not null                    -- 순위 보상 (아래 정산 함수가 읽음)
);
alter table public.kd_minigames enable row level security;   -- 정책 없음: 함수로만

-- 「선물 배달」(눈꽃제 크리스마스 주간): 최대 점수 2,600 — 웹 tools/sim/minigame_check.js 완벽한 봇 3,000판 최대 2,075 + 여유
-- 보상: 1위 이삭 500 + 배지 「선물 배달왕」 · 1~10위 외형 「산타 카엘」 · 2~10위 이삭 200 · 11~100위 이삭 100 · 상위 30% 이삭 30 · 참가 눈송이 100
insert into public.kd_minigames (id, event_id, name, play_from, play_to, settle_at, max_score, daily_max, min_sec, max_sec, rewards) values
  ('gift2026', 'snow2026', '선물 배달', '2026-12-21 00:00+09', '2026-12-26 00:00+09', '2026-12-26 00:00+09', 2600, 4, 28, 600,
   '{"tiers":[{"to":1,"reward":{"gem":500,"badge":"delivery","skin":"santa","skin_year":2026}},
              {"to":10,"reward":{"gem":200,"skin":"santa","skin_year":2026}},
              {"to":100,"reward":{"gem":100}}],
     "pct":{"p":0.3,"reward":{"gem":30}},
     "join":{"evc":{"snow2026":100}}}')
on conflict (id) do nothing;

-- ── ③ 판 번호 ──
create table if not exists public.kd_mg_plays (
  id bigserial primary key,
  game text not null references public.kd_minigames(id),
  user_id uuid not null references public.profiles(id) on delete cascade,
  day date not null,                        -- 한국 날짜
  seed bigint not null,                     -- 집 배치 번호 (웹 mgNew)
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  score int,
  result text                               -- ok · range · early · late · closed
);
create index if not exists kd_mg_plays_day_idx on public.kd_mg_plays (game, user_id, day);
alter table public.kd_mg_plays enable row level security;

-- ── ④ 최고 점수 ──
create table if not exists public.kd_minigame_scores (
  game text not null references public.kd_minigames(id),
  user_id uuid not null references public.profiles(id) on delete cascade,
  best int not null default 0,
  reached_at timestamptz not null default now(),
  plays int not null default 0,
  hidden boolean not null default false,
  primary key (game, user_id)
);
create index if not exists kd_mg_rank_idx on public.kd_minigame_scores (game, best desc, reached_at asc) where not hidden;
alter table public.kd_minigame_scores enable row level security;

create table if not exists public.kd_mg_settlements (
  game text primary key,
  players int,
  done_at timestamptz default now()
);
alter table public.kd_mg_settlements enable row level security;

-- ── 판 시작 → {"id":판 번호,"seed":배치 번호,"left":오늘 남은 판} 또는 {"err":"login"|"nick"|"game"|"closed"|"limit"} ──
create or replace function public.kd_mg_start(p_game text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); g public.kd_minigames; d date := (now() at time zone 'Asia/Seoul')::date; n int; pid bigint; sd bigint;
begin
  if uid is null then return '{"err":"login"}'; end if;
  if not exists (select 1 from public.profiles where id = uid) then return '{"err":"nick"}'; end if;
  select * into g from public.kd_minigames where id = p_game;
  if not found then return '{"err":"game"}'; end if;
  if now() < g.play_from or now() >= g.play_to then return '{"err":"closed"}'; end if;
  perform pg_advisory_xact_lock(hashtext('kd_mg:' || uid::text));
  select count(*) into n from public.kd_mg_plays where game = p_game and user_id = uid and day = d;
  if n >= g.daily_max then return '{"err":"limit"}'; end if;
  sd := floor(random() * 4294967296)::bigint;
  insert into public.kd_mg_plays (game, user_id, day, seed) values (p_game, uid, d, sd) returning id into pid;
  return jsonb_build_object('id', pid, 'seed', sd, 'left', g.daily_max - n - 1);
end $$;

-- ── 기록 제출 (서버에서 받은 판 번호로만, 한 번만) → 'ok' · 'login' · 'none' · 'used' · 'range' · 'early' · 'late' · 'closed' ──
create or replace function public.kd_mg_submit(p_id bigint, p_score int)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); pl public.kd_mg_plays; g public.kd_minigames; age numeric; res text := 'ok';
begin
  if uid is null then return 'login'; end if;
  select * into pl from public.kd_mg_plays where id = p_id and user_id = uid for update;
  if not found then return 'none'; end if;
  if pl.submitted_at is not null then return 'used'; end if;
  select * into g from public.kd_minigames where id = pl.game;
  age := extract(epoch from (now() - pl.started_at));
  if p_score is null or p_score < 0 or p_score > g.max_score then res := 'range';
  elsif age < g.min_sec then res := 'early';
  elsif age > g.max_sec then res := 'late';
  elsif pl.started_at >= g.play_to or now() >= g.settle_at then res := 'closed';
  end if;
  update public.kd_mg_plays set submitted_at = now(), score = p_score, result = res where id = p_id;
  if res <> 'ok' then return res; end if;
  insert into public.kd_minigame_scores (game, user_id, best, plays) values (pl.game, uid, p_score, 1)
    on conflict (game, user_id) do update set
      plays = public.kd_minigame_scores.plays + 1,
      best = greatest(public.kd_minigame_scores.best, excluded.best),
      reached_at = case when excluded.best > public.kd_minigame_scores.best then now() else public.kd_minigame_scores.reached_at end;
  return 'ok';
end $$;

-- ── 정산: settle_at 이 지난 미니게임마다 한 번 → 참가자(보상 판 1번 이상, 숨김 제외) 순위대로 우편 ──
-- 우편 함수는 그대로 두고 보상 내용(reward)에 새 종류만: skin·skin_year(외형) · evc(이벤트 재화). 배지는 기존 badge 종류.
create or replace function public.kd_mg_settle_due(p_game text default null)
returns void language plpgsql security definer set search_path = public as $$
declare g public.kd_minigames; n int;
begin
  for g in select * from public.kd_minigames m
           where m.settle_at <= now() and (p_game is null or m.id = p_game)
             and not exists (select 1 from public.kd_mg_settlements s where s.game = m.id) loop
    perform pg_advisory_xact_lock(hashtext('kd_mg_settle:' || g.id));
    continue when exists (select 1 from public.kd_mg_settlements where game = g.id);
    with r as (
      select user_id, best,
             row_number() over (order by best desc, reached_at asc) as rk,
             count(*) over () as tot
      from public.kd_minigame_scores where game = g.id and not hidden and plays > 0
    ), w as (
      select r.*,
        coalesce((select t.v -> 'reward' from jsonb_array_elements(g.rewards -> 'tiers') as t(v)
                  where r.rk <= (t.v ->> 'to')::int order by (t.v ->> 'to')::int limit 1),
                 case when r.rk <= ceil(r.tot * coalesce((g.rewards -> 'pct' ->> 'p')::numeric, 0)) then g.rewards -> 'pct' -> 'reward' end,
                 '{}'::jsonb) || coalesce(g.rewards -> 'join', '{}'::jsonb) as reward
      from r
    )
    insert into public.mails (user_id, kind, title, body, reward, tag)
    select user_id, 'event',
      g.name || ' 랭킹 · ' || rk || '위',
      g.name || ' ' || best || '점으로 ' || rk || '위에 올랐어요. (참여 ' || tot || '명)',
      reward, 'mg:' || g.id
    from w
    on conflict (user_id, tag) where tag is not null do nothing;
    get diagnostics n = row_count;
    insert into public.kd_mg_settlements (game, players) values (g.id, n);
  end loop;
end $$;

-- ── 랭킹: 위 100명 + 나 (정산 시각이 지났으면 먼저 정산) ──
create or replace function public.kd_mg_ranking(p_game text)
returns table (rank bigint, nick text, score int, frame text, badge text, title text, me boolean, total bigint, face text, settled boolean, settle_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare g public.kd_minigames;
begin
  select * into g from public.kd_minigames where id = p_game;
  if not found then return; end if;
  if g.settle_at <= now() then perform public.kd_mg_settle_due(p_game); end if;
  return query
    with r as (
      select s.user_id, s.best, p.nick, p.frame, p.badge, p.title, p.face,
             row_number() over (order by s.best desc, s.reached_at asc) as rk,
             count(*) over () as tot
      from public.kd_minigame_scores s join public.profiles p on p.id = s.user_id
      where s.game = p_game and not s.hidden and s.best > 0
    )
    select r.rk, r.nick, r.best, r.frame, r.badge, r.title, r.user_id = auth.uid(), r.tot, r.face,
           exists (select 1 from public.kd_mg_settlements x where x.game = p_game), g.settle_at
    from r where r.rk <= 100 or r.user_id = auth.uid()
    order by r.rk;
end $$;

-- ── 관리자: 미니게임 기록 숨김 켜고 끄기 (stage8_inquiry.sql 의 kd_is_admin) → 'ok' · 'none' ──
create or replace function public.kd_adm_mg_hidden_set(p_game text, p_user uuid, p_hidden boolean)
returns text language plpgsql security definer set search_path = public as $$
declare n int := 0;
begin
  if not public.kd_is_admin() then raise exception 'not admin' using errcode = '42501'; end if;
  update public.kd_minigame_scores set hidden = p_hidden where game = p_game and user_id = p_user;
  get diagnostics n = row_count;
  return case when n > 0 then 'ok' else 'none' end;
end $$;

revoke all on function public.kd_mg_settle_due(text) from public, anon, authenticated;
revoke all on function public.kd_adm_mg_hidden_set(text, uuid, boolean) from public, anon;
grant execute on function public.kd_adm_mg_hidden_set(text, uuid, boolean) to authenticated;
grant execute on function public.kd_event_list() to anon, authenticated;
grant execute on function public.kd_mg_start(text), public.kd_mg_submit(bigint, int), public.kd_mg_ranking(text) to anon, authenticated;
