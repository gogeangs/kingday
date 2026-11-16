-- 16단계: 결제 정리 (2026-11-16, docs/PLAN_MONETIZATION_REMOVAL.md 1번)
-- ⚠ 아이폰 0.0.5 심사가 끝난 뒤, 그리고 결제를 뺀 앱 버전이 스토어에 나간 뒤 실행.
--   (그 전에 지우면 심사 중 결제 시험이나 옛 버전의 결제가 실패함)
-- 실제 결제자는 없음(테스트 계정뿐) → 환불·보상 없이 기록째 지움. 지우기 전 코드는 태그 iap-last.
-- 그대로 두는 것: 랭킹 시즌 유니크 카드 보상(stage6_unique.sql), 원정 일지 시즌 번호 함수 kd_season(), 우편함.
-- 같이 할 일: Edge Function 「kd-iap」 삭제, Secrets 의 GOOGLE_SERVICE_ACCOUNT_JSON·APPLE_* 삭제(대표님).
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전.

drop function if exists public.kd_iap_grant(uuid, text, text, text, text, text, text, jsonb);
drop table if exists public.purchases;

-- 받지 않은 결제 보상 우편(테스트 결제분)은 지움 — 새 게임은 이 칸을 읽지 않음
delete from public.mails where kind = 'shop' and tag like 'iap:%';
