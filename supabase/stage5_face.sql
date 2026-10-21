-- 5단계: 프로필 얼굴 (2026-10-22)
-- 영주가 고른 얼굴(카엘 또는 합류한 동료 id)을 저장하고, 랭킹에 함께 돌려줌.
-- 휴대폰 사진은 서버에 올리지 않음 (기기에만 저장) → 여기서는 동료 id 만 다룸.
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전.

alter table public.profiles add column if not exists face text;

-- 얼굴 바꾸기: 영문 소문자 2~12자(동료 id)만 받음
create or replace function public.kd_set_face(p_face text)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return 'auth'; end if;
  if p_face is null or p_face !~ '^[a-z]{2,12}$' then return 'bad'; end if;
  update public.profiles set face = nullif(p_face, 'kael') where id = uid;
  return 'ok';
end $$;

-- 시즌 랭킹: 마지막 칸에 face 추가 (돌려주는 칸이 바뀌어 지우고 다시 만듦)
drop function if exists public.kd_ranking(int);
create function public.kd_ranking(p_season int default null)
returns table (rank bigint, nick text, stage int, power bigint, frame text, badge text, title text, me boolean, total bigint, season int, season_end timestamptz, face text)
language sql stable security definer set search_path = public as $$
  with s as (select coalesce(p_season, public.kd_season()) as v),
  r as (
    select rc.user_id, rc.stage, rc.power, p.nick, p.frame, p.badge, p.title, p.face,
           row_number() over (order by rc.stage desc, rc.reached_at asc) as rk,
           count(*) over () as tot
    from public.records rc join public.profiles p on p.id = rc.user_id, s
    where rc.season = s.v and not rc.hidden
  )
  select rk, nick, stage, power, frame, badge, title, user_id = auth.uid(), tot, (select v from s),
         case when (select v from s) = 0 then null else public.kd_season_end((select v from s)) end,
         face
  from r where rk <= 100 or user_id = auth.uid()
  order by rk
$$;

-- 황금 고블린 주간 랭킹: 마지막 칸에 face 추가
drop function if exists public.kd_gob_ranking();
create function public.kd_gob_ranking()
returns table (rank bigint, nick text, kills int, frame text, badge text, title text, me boolean, total bigint, week int, week_end timestamptz, face text)
language sql stable security definer set search_path = public as $$
  with w as (select public.kd_week() as v),
  r as (
    select g.user_id, g.kills, p.nick, p.frame, p.badge, p.title, p.face,
           row_number() over (order by g.kills desc, g.updated_at asc) as rk,
           count(*) over () as tot
    from public.goblin_weeks g join public.profiles p on p.id = g.user_id, w
    where g.week = w.v and not g.hidden and g.kills > 0
  )
  select rk, nick, kills, frame, badge, title, user_id = auth.uid(), tot, (select v from w), public.kd_week_end((select v from w)), face
  from r where rk <= 100 or user_id = auth.uid()
  order by rk
$$;

grant execute on function public.kd_set_face(text), public.kd_ranking(int), public.kd_gob_ranking() to anon, authenticated;
