# 문의하기 (2026-10-26)

게임 안 문의 창 → 서버에 저장 → 대표님 관리 페이지에서 보고 답 → 답은 게임 우편함으로.

## 이용자 쪽 (웹 `index.html` · 앱 `app/lib/screens/inquiry_sheet.dart`)
- 프로필 → ⚙ 설정(카엘의 수첩) → 「문의」 칸: **문의하기** · **내 문의**
- 문의 창: 종류(결제·버그·계정·기타) · 내용(5~1000자) · 사진 1장(선택, 긴 쪽 1280px로 줄여 올림)
- 함께 보내는 것: 닉네임 · 계정 번호(로그인 토큰) · 게임 버전(웹 `web-배포시각`, 앱 `app_info.dart appVersion`) · 기기·브라우저 · 플랫폼
- 하루 3번까지(서버가 셈), 사진은 하루 5장까지 올릴 수 있음
- 내 문의: 최근 30개, 상태(답변 기다리는 중 · 답변 완료 · 처리 완료)와 답변
- 우편함: 답변 우편은 💬, 보상이 없으면 버튼이 「확인」

## 서버 (`supabase/stage8_inquiry.sql`)
- 표 `inquiries`(정책 없음, 함수로만) · 관리자 표 `kd_admins`(이메일) · 비공개 사진 저장소 `inquiry`(「계정번호/파일」, 본인만 올리기·읽기, 관리자만 읽기·지우기)
- 함수: `kd_inq_send` · `kd_inq_mine` · `kd_is_admin` · `kd_adm_inq_list` · `kd_adm_inq_answer`(우편 kind `reply`) · `kd_adm_inq_status`
- 관리자 확인: 로그인한 계정의 **구글·애플** 로그인 이메일이 `kd_admins` 에 있어야 함 (게스트·이메일 가입은 안 됨)
- 보관: 사진은 「처리 완료」 때 지움 · 내용은 답변·처리 후 1년 뒤 자동 삭제 · 계정 삭제 시 함께 삭제 (`privacy.html` 반영)

## 새 문의 메일 알림 (2026-10-26 추가)
- 문의가 저장되면 게임(웹·앱)이 Edge Function `kd-inq-notify` 를 부름 → `kd_inq_take_notify`(`supabase/stage10_inquiry_notify.sql`, 서버만 부를 수 있음)로 그 사람의 방금 문의를 하나 꺼내 「알림 보냄」 표시 → Resend 로 대표님께 메일(종류·닉네임·내용·관리 페이지 링크). 같은 문의는 두 번 알리지 않음
- 비밀값(Edge Function Secrets): `RESEND_API_KEY`, `NOTIFY_TO`(받을 메일), `NOTIFY_FROM`(선택, 없으면 Resend 시험 주소 — Resend 가입 메일로만 보낼 수 있음). 없으면 조용히 아무것도 안 보냄
- 앱 문의 창에는 「자주 묻는 질문」·「개인정보처리방침」 버튼(휴대폰 브라우저로 열기, `url_launcher`)

## 대표님 관리 페이지 (`admin.html`)
- 주소: https://gogeangs.github.io/kingday/admin.html (검색에 안 나오게 해 둠)
- 구글로 로그인 → 서버가 관리자인지 확인 → 목록(처리 전·답변함·처리 완료·전체, 종류별)
- 문의를 누르면: 내용·사진·닉네임·계정 번호·이메일·게임 버전·기기·진행(클라우드 저장 기준 영지·이삭)·최근 결제 10건
- 답 쓰기(자주 쓰는 답 5개) + 함께 보낼 황금 이삭(0이면 답만) → 「답 보내기(우편)」 → 「처리 완료」(사진 지움) · 「다시 열기」
- 페이지에는 공개용 키만 있음. 비밀 키·비밀번호 없음.

## 처음 한 번 설정 (대표님)
1. Supabase SQL Editor 에서 `supabase/stage8_inquiry.sql` 실행
2. 같은 곳에서 관리자 등록: `insert into public.kd_admins (email) values ('대표님 구글 이메일') on conflict do nothing;`
3. (이미 됨) Redirect URLs 의 `https://gogeangs.github.io/kingday/**` 가 admin.html 도 포함
4. 메일 알림: `supabase/stage10_inquiry_notify.sql` 실행 → resend.com 가입(알림 받을 메일로) → API 키 만들기 → Supabase Edge Function Secrets 에 `RESEND_API_KEY`·`NOTIFY_TO` → Edge Functions 에 `kd-inq-notify` 만들기(`supabase/functions/kd-inq-notify/index.ts` 붙여 넣기)
