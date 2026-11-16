-- 15단계: 유저 행동 기록 (2026-11-16, docs/PLAN_MONETIZATION_REMOVAL.md 6번)
-- 게임이 하루 한 줄씩 올림: 날짜 · 최고 영지 · 지금 영지 · 은퇴 횟수 · 광고 자리별 시청 수 · 얻은 이삭 · 쓴 곳별 이삭
-- 계정 id(auth.uid())로만 묶고 이메일·닉네임 같은 개인을 알아볼 정보는 넣지 않음. 1년 지난 줄은 지움(개인정보처리방침 3번).
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전.

create table if not exists public.play_log (
  user_id uuid not null references auth.users(id) on delete cascade,   -- 계정을 지우면 같이 지워짐
  d date not null,                       -- 이 기기 기준 날짜(한국 시간)
  best int not null default 1,           -- 그날 최고 영지
  stage int not null default 1,          -- 그날 마지막 영지
  ret int not null default 0,            -- 은퇴 횟수(누적)
  ad jsonb not null default '{}'::jsonb, -- 광고 자리별 시청 수 {gem:3, retry:1, spd:2, pass:1, box:3, card:1, offline:1, att:2, ...}
  gin int not null default 0,            -- 그날 얻은 황금 이삭
  gout jsonb not null default '{}'::jsonb, -- 쓴 곳별 이삭 {box10:100, card:30, goldx:100, build:12, crop:5, plot:50, offline:20, trait:100}
  updated_at timestamptz not null default now(),
  primary key (user_id, d)
);
create index if not exists play_log_d on public.play_log (d);
alter table public.play_log enable row level security;   -- 정책 없음: 아래 함수로만 씀, 읽기는 대시보드(SQL)에서만

-- 숫자만 남긴 작은 jsonb (키 40개·키 이름 24자·값 0~1000000까지)
create or replace function public.kd_log_clean(j jsonb)
returns jsonb language sql immutable set search_path = public as $$
  select coalesce(jsonb_object_agg(left(k, 24), least(greatest(floor((v)::numeric), 0), 1000000)), '{}'::jsonb)
  from (
    select key as k, value #>> '{}' as v
    from jsonb_each(case when jsonb_typeof(j) = 'object' then j else '{}'::jsonb end)
    where jsonb_typeof(value) = 'number'
    limit 40
  ) x
$$;

-- 게임이 부름: p_rows = [{d:'2026-11-16', best, stage, ret, ad:{}, gin, out:{}}, ...] (최근 15일 안, 한 번에 20줄까지)
create or replace function public.kd_log_day(p_rows jsonb)
returns text language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  r jsonb;
  dd date;
  n int := 0;
begin
  if uid is null then return 'no-auth'; end if;
  if jsonb_typeof(p_rows) <> 'array' then return 'bad'; end if;
  for r in select value from jsonb_array_elements(p_rows) limit 20 loop
    begin   -- 줄 하나가 이상해도(숫자 칸에 글자 등) 그 줄만 건너뜀
    dd := to_date(r->>'d', 'YYYY-MM-DD');
    if dd is null or dd < current_date - 15 or dd > current_date + 1 then continue; end if;
    insert into public.play_log as p (user_id, d, best, stage, ret, ad, gin, gout, updated_at)
    values (
      uid, dd,
      least(greatest(coalesce((r->>'best')::numeric, 1), 1), 1000)::int,
      least(greatest(coalesce((r->>'stage')::numeric, 1), 1), 1000)::int,
      least(greatest(coalesce((r->>'ret')::numeric, 0), 0), 100000)::int,
      public.kd_log_clean(r->'ad'),
      least(greatest(coalesce((r->>'gin')::numeric, 0), 0), 10000000)::int,
      public.kd_log_clean(r->'out'),
      now()
    )
    on conflict (user_id, d) do update
      set best = greatest(p.best, excluded.best), stage = excluded.stage, ret = greatest(p.ret, excluded.ret),
          ad = excluded.ad, gin = excluded.gin, gout = excluded.gout, updated_at = now();
    n := n + 1;
    exception when others then
      null;
    end;
  end loop;
  -- 1년 지난 줄은 지움 (이 계정 것만, 가볍게)
  delete from public.play_log where user_id = uid and d < current_date - 365;
  return 'ok:' || n;
exception when others then
  return 'err';
end $$;

revoke all on function public.kd_log_day(jsonb) from public, anon;
grant execute on function public.kd_log_day(jsonb) to authenticated;
revoke all on function public.kd_log_clean(jsonb) from public, anon, authenticated;

-- ── 대시보드에서 보는 법 (SQL Editor, 실행만 하면 됨) ──
-- 하루 접속자:            select d, count(*) from play_log group by d order by d desc;
-- 다음날 다시 온 비율:     select a.d, count(*) n, count(b.user_id) back1 from play_log a left join play_log b on b.user_id=a.user_id and b.d=a.d+1 group by a.d order by a.d desc;
-- 광고 자리별 하루 시청:   select d, k, sum(v::int) from play_log, jsonb_each_text(ad) as e(k, v) group by d, k order by d desc, k;
-- 그만두는 지점(마지막 날): select best, count(*) from (select distinct on (user_id) user_id, best from play_log order by user_id, d desc) x group by best order by best;
-- 이삭 얻은 양·쓴 곳:      select d, avg(gin), sum(gin) from play_log group by d order by d desc;
--                          select d, k, sum(v::int) from play_log, jsonb_each_text(gout) as e(k, v) group by d, k order by d desc, k;
