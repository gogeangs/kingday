-- 17단계: 행동 기록 정리 (2026-11-16, docs/PLAN_MONETIZATION_REMOVAL.md 2단계 3번)
-- 광고를 모두 없애며 행동 기록(play_log)도 그만 모음. 0.0.10 앱·웹은 kd_log_day 를 부르지 않음.
-- 언제: 0.0.10 이 스토어에 올라가 예전 앱(0.0.9 이하)이 거의 안 남았을 때. 그 전에 실행해도
--       예전 앱은 기록 올리기만 조용히 실패하고 게임은 그대로 됨 (오류 창 없음).
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전.
-- 되돌리기: supabase/stage15_play_log.sql 을 다시 실행 (지운 기록은 돌아오지 않음).

begin;

-- 1) 기록 올리는 함수 (권한도 같이 사라짐)
drop function if exists public.kd_log_day(jsonb);
drop function if exists public.kd_log_clean(jsonb);

-- 2) 쌓인 기록과 표 (계정 id 와 날짜별 숫자뿐 — 개인을 알아볼 정보는 처음부터 없음)
drop table if exists public.play_log;

commit;

-- 확인: 아래 세 줄이 모두 false 면 끝
select
  to_regclass('public.play_log') is not null                       as play_log_남음,
  to_regprocedure('public.kd_log_day(jsonb)') is not null          as kd_log_day_남음,
  to_regprocedure('public.kd_log_clean(jsonb)') is not null        as kd_log_clean_남음;
