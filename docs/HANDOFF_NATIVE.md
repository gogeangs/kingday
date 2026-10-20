# 「왕이 되는 그날까지」 네이티브 앱 전환 인수인계서

작성일: 2026-10-20 · 대상: 새 작업 세션
이 문서 하나로 지금까지의 상태를 파악하고 네이티브 앱 전환을 시작할 수 있게 정리했다.

---

## 1. 지금 상태 한눈에

| 항목 | 값 |
|---|---|
| 저장소 | `gogeangs/kingday` (main 브랜치, PR #129까지 병합) |
| 웹 버전 | https://gogeangs.github.io/kingday/ (GitHub Pages, main 푸시 시 자동 배포) |
| 형태 | 단일 파일 웹 게임 `index.html` (약 290KB, HTML+CSS+JS 한 파일) + `assets/` 그림 364개(30.6MB) |
| 렌더링 | Canvas 2D(전투·마을·지도) + DOM(메뉴·창) |
| 저장 | `localStorage` 키 `acorn-idle-v1` (게임 전체 상태 객체 `S`), `kd-sb`(로그인 토큰), `kd-oauth`(구글 로그인 복귀 표시) |
| 서버 | Supabase 무료 플랜, 프로젝트 `kingday`, 서울 리전 |
| 오프라인 | 서비스 워커 `sw.js` (`tools/build_sw.py`로 생성) |
| 사업자 | 주식회사 프로젝트서티즈 · 문의 biz@project30s.co.kr |

---

## 2. 저장소 구조

```
index.html            게임 전체 (코드·스타일·화면)
privacy.html          개인정보처리방침 (구글 OAuth 브랜딩에 등록됨)
terms.html            이용약관
manifest.webmanifest  웹앱 설치 정보
sw.js                 오프라인용 서비스 워커 (직접 고치지 말고 tools/build_sw.py로 생성)
assets/
  characters/  동료 스프라이트 {id}_{idle|walk|attack|hit}.png (가로 프레임 시트)
  monsters/    몬스터·보스·황금 고블린 스프라이트
  portraits/   대화용 초상화 portrait_{id}_{표정}.png
  bg/          지역 배경 4겹 {지역}_{sky|far|mid|ground}.png
  fx/ skills/  스킬 효과·아이콘
  village/ crops/ map/ relic/ gem/ profile/ ui/ illust/ icon/ fonts/
supabase/       서버 SQL (아래 5장 순서대로 이미 실행 완료)
tools/          그림 잘라내기·압축·서비스워커 생성 도구 (Python)
docs/           GAME_DESIGN.md, RANKING.md, BACKLOG.md, DESIGN_BRIEF.md, ART_ASSET_HANDOFF.md
```

---

## 3. 게임 내용 요약 (자세한 건 docs/GAME_DESIGN.md)

- 장르: 자동사냥 방치형 RPG (버섯커 키우기 스타일), 정통 판타지
- 주인공: 은퇴를 꿈꾸는 농부 카엘 + 성검 루미나르
- 진행: 5지역 × 10영지 = 50영지 → 왕도. 성주·군단장 보스
- 탭: 장비(성유물 상자) · 원정대(편성/동료/카드) · 단련(강화) · 마을(밭·광산·부두·양봉장·식당·여관) · 지도. 상점(피트)
- 동료: 직업 4종 자리(광부·어부·양봉가·요리사) 고정. 이야기 동료(일반, ★3) + 모집 동료(희귀★4·영웅★5·전설★5)
  - 현재 동료: 브론·하랄·리엘·마고(이야기), 고든(일반), 데이지(희귀), 루카·넬라(영웅), 브리다(전설, 마을 스킬)
- 은퇴(환생) 시스템, 칭호(농부→왕), 오늘의 할 일, 황금 고블린(희귀 전리품)
- 재화: 골드, 황금 이삭(유료 재화 성격), 광석, 작물
- 프로필 꾸미기: 테두리 11종, 배지 14종

---

## 4. 서버(Supabase) 구성

- Project URL: `https://xqrdqigdwfyoaalqalfc.supabase.co`
- Publishable key: `sb_publishable_b0VfItWh30lKMyHaOSehXQ_lWqe_xTM` (공개용 키, 게임 코드에 들어 있음)
- **secret/service_role 키, DB 비밀번호, 구글 클라이언트 보안 비밀번호는 문서·코드에 넣지 않는다.**
- 인증: 익명 로그인(게스트) + 구글 계정 연결(Manual linking 켜짐)
- 클라이언트는 SDK 없이 REST로 직접 호출: `/auth/v1/signup`, `/auth/v1/token?grant_type=refresh_token`, `/rest/v1/rpc/{함수}`

### RPC 함수 (게임에서 부르는 것)
| 함수 | 용도 |
|---|---|
| `kd_ensure_profile` | 시작 시 계정 준비, 임시 닉네임 「영주12345」 발급, 환영 우편 |
| `kd_set_nick` | 닉네임 정하기(2~10자, 시즌 1회, 임시는 1회 자유) |
| `kd_submit` | 시즌·명예의 전당 기록 제출(속도 검사, 50곳 탈환 시 정복자 테두리 우편) |
| `kd_ranking(p_season)` | 랭킹 상위 100 + 나 (0=명예의 전당) |
| `kd_gob_submit` / `kd_gob_ranking` | 황금 고블린 주간 랭킹 |
| `kd_mail_list` / `kd_mail_claim` | 우편함(열 때 시즌·주간 자동 정산) |
| `kd_save_put` / `kd_save_get` | 클라우드 저장(300KB 제한) |
| `kd_link_reward` | 구글 연결 선물(이삭 50, 1회) |
| `kd_admin_mail` | 운영 우편(SQL Editor 전용, 게임에서 호출 불가) |

### SQL 실행 순서 (모두 실행 완료)
`schema.sql` → `fix_2026-10-20_speedcheck.sql` → `stage2_mail.sql` → `stage2b_welcome.sql` → `stage3a_goblin.sql` → `stage3b_cloud.sql`

### 일정
- 시즌: 2026-10-19(월) 0시 KST부터 2주 단위. 1시즌 종료 **11월 2일 0시**
- 고블린 주간: 1주 단위. 1주차 종료 **10월 26일 자정**
- GitHub Actions `supabase-keepalive`가 매일 서버를 깨움(무료 플랜 7일 정지 방지)

### 구글 로그인 설정 (완료)
- Google Cloud 프로젝트 `kingday-512207`, OAuth 동의 화면 외부·프로덕션, 클라이언트 `kingday web`
- 승인된 원본 `https://gogeangs.github.io`, 리디렉션 `https://xqrdqigdwfyoaalqalfc.supabase.co/auth/v1/callback`
- Supabase Site URL `https://gogeangs.github.io/kingday/`, Redirect URLs `https://gogeangs.github.io/kingday/**`

---

## 5. 네이티브 전환 시 결정할 것

### 방식 비교
| 방식 | 내용 | 장점 | 단점 |
|---|---|---|---|
| **A. 웹뷰로 감싸기 (Capacitor) — 추천** | 지금 `index.html`과 `assets`를 그대로 앱 안에 넣고 네이티브 기능만 플러그인으로 연결 | 코드 재사용 100%, 1~2주, 웹 버전과 동시 운영 | 아주 무거운 그래픽에선 성능 한계(현재 게임 규모는 충분) |
| B. 게임 엔진 재작성 (Unity / Godot / Flutter Flame) | 로직·화면 전부 새로 작성 | 성능·도구 최상 | 수개월, 지금까지 코드 재사용 불가 |

→ 1차 출시는 **A(Capacitor)**로 하고, 반응을 보고 B를 검토하는 것을 권장.

### A 방식으로 바꿔야 할 것
1. **서비스 워커 끄기**: 앱 안에 파일이 다 들어가므로 `sw.js` 등록을 앱에서는 건너뛴다(웹은 유지).
2. **저장 안정성**: `localStorage`는 iOS에서 지워질 수 있음 → `@capacitor/preferences`로 저장(웹은 그대로 localStorage).
3. **구글 로그인**: 웹뷰 안에서는 구글이 로그인을 막음 → 시스템 브라우저(`@capacitor/browser`) + 앱 딥링크(예: `kingday://auth`)로 복귀.
   - Supabase Redirect URLs에 딥링크 추가, iOS/Android용 OAuth 클라이언트 추가 생성 필요.
   - 애플 정책: 구글 로그인을 넣으면 **Sign in with Apple도 필수**.
4. **결제**: 지금은 `TEST_PAY=true`(누르면 바로 지급). 앱은 **인앱결제 필수**(Google Play Billing / Apple IAP). RevenueCat 등 사용 권장. 영수증 검증 후 서버에서 지급하도록 Supabase 함수 추가.
5. **광고**: 지금은 가짜 광고(`watchAd`, 3초 대기). AdMob 보상형 광고로 교체.
6. **뒤로 가기(안드로이드)**: `@capacitor/app`의 backButton → 창 닫기 → 메뉴 닫기 → 종료 확인.
7. **진동**: `navigator.vibrate` 대신 `@capacitor/haptics`(iOS도 지원).
8. **화면**: 노치·홈바 safe-area는 이미 CSS에서 처리. 세로 고정, 상태바 색 `#0d1220`.
9. **아이콘·스플래시**: `assets/icon/app_icon_1024.png`(원본) 사용, `@capacitor/assets`로 생성.
10. **스토어 준비**: 개인정보처리방침 URL(이미 있음), 데이터 안전 섹션(이메일·게임 기록·기기 식별자), 연령 등급, 스크린샷.

### 계정이 필요한 것 (대표님 직접)
- Apple Developer Program (연 $99), Google Play Console (1회 $25)
- 맥(Xcode)이 있어야 iOS 빌드 가능 — 없으면 클라우드 빌드(Ionic Appflow, Codemagic 등)

---

## 6. 작업 규칙 (지금까지 지켜온 방식)

- 대표님과의 대화는 **한국어**, 쉬운 말로. 결과를 먼저 말하고 확인한 내용을 덧붙인다.
- 모든 변경은 브랜치 → PR → main 병합. 커밋 끝에 Co-Authored-By 표기.
- `index.html` 또는 그림을 바꾸면 **커밋 전 `python3 tools/build_sw.py` 실행**.
- 그림은 ChatGPT로 생성(대표님이 붙여넣음). 프롬프트에는 항상 [공통 규칙] 포함:
  밝고 선명한 정통 판타지 게임 UI 화풍 / 완전 투명 배경 PNG / 글자·숫자·로고·워터마크 없음 / 오브젝트 1개 가운데 / 크기 명시.
- 받은 그림은 여백 자르기 → 크기 맞추기 → `imagequant` 압축 → 게임 화면에서 확인 후 반영.
- 검증: Playwright로 휴대폰 화면 4종(320·360·390·430 폭) 렌더, 장시간 진행 시뮬레이션, 오프라인 실행 확인. 서버 SQL은 로컬 Postgres에서 먼저 실행해 본다.
- 보안: 비밀 키·비밀번호를 받거나 코드에 넣지 않는다. 계정 생성·로그인은 대표님이 직접.

---

## 7. 남은 업무 (docs/BACKLOG.md 기준)

1. **동료 추가 7명**: 희귀(어부·요리사), 영웅(광부·양봉가), 전설(어부·양봉가·요리사, 각자 마을 스킬 1개)
2. 보류: 효과음·배경음, 뒤로 가기 처리(네이티브에서 해결), 홈 화면 추가 안내(네이티브에선 불필요)
3. 출시 준비: 실제 결제·광고, 출시 방식(→ 네이티브), 약관 법무 검토
4. 대표님: GitHub 병합된 브랜치 정리 + 「Automatically delete head branches」 켜기

---

## 8. 새 세션 시작 문장 (복사용)

> `gogeangs/kingday` 저장소의 `docs/HANDOFF_NATIVE.md`를 먼저 읽고, 「왕이 되는 그날까지」를 Capacitor로 안드로이드·iOS 네이티브 앱으로 전환하는 작업을 시작해줘. 웹 버전(GitHub Pages)은 계속 유지해야 해. 한국어로 답해줘.
