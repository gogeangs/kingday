-- 13단계: 2부 전체(사막·북방·연합군 진영) 랭킹 최고 영지 상한 71 → 91 (2026-10-28)
-- stage12_part2_rank.sql 에서 만든 상한 함수 kd_stage_max() 값만 바꿔요.
-- 앱이 쓰는 kd_submit(상한 61)·kd_save_put·표는 그대로 — 앱이 보내는 61 이하 기록은 지금처럼 통과.
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전. (stage12_part2_rank.sql 다음)

create or replace function public.kd_stage_max()
returns int language sql immutable as $$ select 91 $$;

grant execute on function public.kd_stage_max() to anon, authenticated;
