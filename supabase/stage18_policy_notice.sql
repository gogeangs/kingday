-- 왕이 되는 그날까지 · 개인정보처리방침·이용약관 변경 공지 (2026-11-17 공지, 2026-11-24 시행)
-- 모든 영주에게 공지 우편을 한 통씩 보내요. 보상은 없어요. 여러 번 실행해도 한 사람에게 한 통만 가요.
insert into public.mails (user_id, kind, title, body, reward, tag, expires_at)
select id, 'notice',
  '개인정보처리방침·이용약관 변경 안내',
  '영주님, 「왕이 되는 그날까지」가 결제와 광고가 없는 완전 무료 게임이 되었어요. 이에 맞춰 개인정보처리방침과 이용약관을 바꿉니다.' || chr(10) || chr(10) ||
  '· 바뀌는 내용: 유료 상품 결제와 관련된 수집 항목(구매한 상품·주문 번호·구매 확인 값·구매 일시)과 이용 목적, 결제 처리 위탁(Google·Apple)을 뺍니다. 이용약관의 유료 상품·정기 결제·청약철회 조항은 「무료 이용과 확률 공개」, 「이전 구매의 환불」로 바꿉니다.' || chr(10) ||
  '· 새로 모으는 정보는 없습니다.' || chr(10) ||
  '· 시행일: 2026년 11월 24일' || chr(10) ||
  '· 전문: https://gogeangs.github.io/kingday/privacy.html · https://gogeangs.github.io/kingday/terms.html' || chr(10) || chr(10) ||
  '궁금한 점은 게임 안 「⚙ 설정 → 문의하기」로 알려 주세요.',
  '{}'::jsonb, 'notice:policy-20261124', now() + interval '30 days'
from public.profiles
on conflict (user_id, tag) where tag is not null do nothing;

-- 확인: 보낸 공지 수
select count(*) as 보낸_공지 from public.mails where tag = 'notice:policy-20261124';
