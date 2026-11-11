-- 신년축제·설날 보너스 날짜 (docs/content/EVENT_NEWYEAR.md) — 더하기만 함
-- stage11_minigame.sql 의 kd_events 표에 줄 두 개를 더함. 표·함수·규칙은 바꾸지 않음 (이미 있는 줄은 그대로: on conflict do nothing)
-- 웹은 이 줄을 kd_event_list() 로 읽고, 못 읽으면 코드 기본값(같은 날짜)을 씀. 날짜를 바꿀 때는 이 표 한 줄만 고치면 됨
insert into public.kd_events (id, name, start_at, end_at, shop_end_at, extra) values
  ('newyear2027', '신년축제', '2027-01-01 00:00+09', '2027-01-22 00:00+09', '2027-01-29 00:00+09', '{}'),
  ('seol2027', '설날', '2027-02-06 00:00+09', '2027-02-09 00:00+09', '2027-02-09 00:00+09', '{}')
on conflict (id) do nothing;

-- 확인 (읽기만)
select id, name, start_at, end_at, shop_end_at from public.kd_events order by start_at;
