-- 12단계: 2부 「흩어진 동맹」 랭킹 최고 영지 상한 늘리기 (2026-10-28)
-- 웹만 2부(영지 61~70 엘프 왕국, 71 바다 안개)가 열렸어요. 앱은 심사 중이라 그대로라서
-- 앱이 쓰는 kd_submit(상한 61)·표·규칙은 하나도 바꾸지 않고, 새 함수만 더해요.
--   · kd_stage_max()  : 랭킹 최고 영지 상한. 지금 71 (사막이 열리면 81, 북방까지 열리면 91로 이 함수만 고치면 돼요)
--   · kd_submit2(...) : kd_submit과 똑같이 동작하고 상한만 kd_stage_max(). 웹이 영지 62 이상일 때 이걸 불러요
-- 웹은 이 SQL을 실행하기 전이면 자동으로 kd_submit에 61까지로 보내요(실행 순서 상관없음).
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전. (stage2_mail.sql 다음)

create or replace function public.kd_stage_max()
returns int language sql immutable as $$ select 71 $$;

create or replace function public.kd_submit2(p_stage int, p_power bigint default 0, p_frame text default null, p_badge text default null, p_title text default null)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); s int := public.kd_season(); age_min numeric; b int; sus boolean;
begin
  if uid is null then return 'login'; end if;
  if not exists (select 1 from public.profiles where id = uid) then return 'nick'; end if;
  if p_stage < 1 or p_stage > public.kd_stage_max() then return 'range'; end if;
  -- 속도 검사: kd_submit과 같음 (첫 기록을 기준점으로, 오른 영지에 비해 너무 빠르면 숨김)
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
  if p_stage > 50 and not sus then
    insert into public.mails (user_id, kind, title, body, reward, tag, expires_at)
    values (uid, 'hall', '정복자의 테두리', '영지 50곳을 모두 되찾았어요. 명예의 전당이 당신을 기억할 거예요.', '{"frame":"conquer"}'::jsonb, 'hall:conquer', now() + interval '365 days')
    on conflict (user_id, tag) where tag is not null do nothing;
  end if;
  return 'ok';
end $$;

grant execute on function public.kd_stage_max(), public.kd_submit2(int,bigint,text,text,text) to anon, authenticated;
