-- 랭킹 속도 검사 수정 (2026-10-20)
-- 이미 많이 진행한 유저가 처음 랭킹에 들어오면 기록이 숨겨지던 문제를 고쳐요.
alter table public.profiles add column if not exists base_stage int;
alter table public.profiles add column if not exists base_at timestamptz;

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

-- 잘못 숨겨진 기록을 다시 보이게 하고, 기준점을 지금 기록으로 맞춰요
update public.records set hidden = false where hidden;
update public.profiles p set base_stage = r.stage, base_at = now()
  from public.records r where r.user_id = p.id and r.season = 0 and p.base_stage is null;
