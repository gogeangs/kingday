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

## 5. 결정: Flutter + Flame으로 새로 작성 (2026-10-20 확정)

대표님 결정: 웹뷰(Capacitor) 대신 **Flutter + Flame**으로 네이티브 앱을 새로 만든다.
- 유지: 기획(docs/GAME_DESIGN.md), 그림 `assets/` 전부, Supabase 서버·RPC 전부, 저장 데이터 구조 `S`
- 새로 작성: 화면(메뉴·창)과 게임 로직·전투 렌더링
- 웹 버전(GitHub Pages)은 **새 앱이 나올 때까지 그대로 운영**. 두 버전은 같은 Supabase 계정·랭킹·우편·클라우드 저장을 공유한다.

### 5-A. 기술 구성 (권장)
| 영역 | 패키지 |
|---|---|
| 앱 뼈대·화면 | Flutter (Dart), 상태관리 `riverpod` |
| 전투 화면·스프라이트·파티클 | `flame` (전투 캔버스만 Flame `GameWidget`, 메뉴·창은 일반 Flutter 위젯) |
| 서버 | `supabase_flutter` (익명 로그인, RPC, 구글/애플 로그인 연결) |
| 로그인 | `google_sign_in` + `sign_in_with_apple` → Supabase `signInWithIdToken` / `linkIdentity` |
| 결제 | `purchases_flutter`(RevenueCat) 또는 `in_app_purchase` (+ Supabase Edge Function 영수증 검증) |
| 광고 | `google_mobile_ads` (AdMob 보상형) |
| 저장 | `shared_preferences` 또는 `hive` (로컬) + 기존 `kd_save_put/get` (클라우드) |
| 진동·소리 | `HapticFeedback`(기본 제공), `flame_audio` |
| 글꼴 | `assets/fonts/*.woff2` → 앱용 TTF/OTF 원본으로 교체 필요 (Hahmlet, IBM Plex Sans KR) |
| 빌드 | 안드로이드: 이 작업 환경에서 빌드 가능 / iOS: 맥 또는 Codemagic 클라우드 빌드 |

### 5-B. 저장소 구성
- 같은 저장소에 `app/` 폴더로 Flutter 프로젝트를 만든다(웹 코드와 그림을 함께 관리). 그림은 `assets/`를 그대로 참조하거나 빌드 시 복사.
- 저장 데이터는 **웹과 같은 JSON 구조(`S`)를 유지** → 웹에서 클라우드 저장한 기록을 앱에서 그대로 불러올 수 있게 한다. 필드 정의는 `index.html`의 `fresh()`/`hydrate()` 참고.

### 5-C. 이식 순서 (index.html 구역 → Flutter)
| 단계 | 내용 | index.html 참고 구역 |
|---|---|---|
| 0 | 개발 환경(Flutter SDK·Android SDK) 설치, 빈 앱 실행, 아이콘·스플래시 | — |
| 1 | 데이터·공식 이식: 지역/영지, 몬스터 체력·보상, 동료·등급·별, 능력치, 비용 공식, 밸런스 상수 | 「데이터」「능력치」「밸런스 손잡이」 |
| 2 | 전투 화면(Flame): 배경 4겹 스크롤, 스프라이트 애니메이션, 웨이브·보스·제한시간, 스킬·효과, 황금 고블린 | 「전투」「특수 스킬」「그리기」「이미지 에셋」 |
| 3 | 상단 바·하단 탭·반쯤 열리는 메뉴 틀, 공통 창(팝업 테두리, ✕) | 「Layout」「공통 렌더」 |
| 4 | 장비(성유물 상자), 단련(연속 강화), 원정대(편성·동료·카드) | 「장비」「원정대 · 단련 · 지도」「편성」 |
| 5 | 마을(건물·밭·부엌·광석·증축), 지도 | 「밭 · 부엌 · 마을」「마을 풍경」「영지 지도」 |
| 6 | 이야기·대화 큐, 튜토리얼 안내, 칭호, 은퇴 | 「이야기 큐」「다음 할 일 안내」 |
| 7 | 저장·오프라인 보상, 웹 기록 가져오기(저장 코드·클라우드) | 「저장 · 방치 보상」 |
| 8 | Supabase: 계정·닉네임·랭킹 3탭·우편함·고블린 주간·클라우드 저장·결과 창 | 「랭킹」「우편함」「클라우드 저장」 |
| 9 | 로그인(구글·애플), 인앱결제, AdMob, 진동·소리 | 「광고 보상 자리」, `pay()` |
| 10 | QA(웹 버전과 수치 비교 시뮬레이션), 스토어 등록(내부 테스트 → 비공개 테스트 → 출시) | `tools/balance_sim.py` |

- 각 단계마다 안드로이드 빌드(APK)를 만들어 대표님 폰에서 확인 → 다음 단계.
- 밸런스는 웹 버전과 **같은 공식·같은 숫자**를 유지(시뮬레이션으로 웹과 결과 비교).

### 5-D. 로그인 설정 변경 (앱용)
- Google Cloud에 **Android OAuth 클라이언트**(패키지명 + SHA-1)와 **iOS OAuth 클라이언트** 추가 생성
- Supabase Google 제공자의 Client IDs에 앱용 클라이언트 ID 추가(쉼표로 여러 개)
- Supabase Apple 제공자 켜기(Apple Developer에서 Service ID·키 발급)
- 패키지명(예: `kr.co.project30s.kingday`) 결정 필요

### 5-E. 계정이 필요한 것 (대표님 직접)
- Google Play Console (1회 25달러), Apple Developer Program (연 99달러)
- AdMob, RevenueCat(선택), Codemagic(맥이 없으면, 무료 구간 있음)

## 5-1. 결제(PG)와 광고 연결 계획

### 결제: 앱은 인앱결제가 기본
- 앱 안에서 파는 디지털 상품(황금 이삭, 첫 거래 특가, 정기 배송)은 **Google Play 결제 / Apple 인앱결제(IAP)** 를 쓰는 것이 기본. 일반 PG(토스페이먼츠 등)를 앱 안에 그냥 붙이면 스토어 심사에서 거절될 수 있음.
- 한국은 법(2021 인앱결제 강제 금지)으로 **외부 결제(제3자 결제)도 허용**되지만, 스토어 수수료 26% + PG 수수료가 붙어 인앱결제(30%, 소규모 개발사는 15% 프로그램)보다 유리하지 않은 경우가 많음.
- 구글은 수수료 체계 개편을 발표했고 한국은 2026-12-31 적용 예정이라는 보도가 있음 → 출시 시점에 최신 정책 확인 필요.
- 구현: `purchases_flutter`(RevenueCat) 또는 Flutter `in_app_purchase`
  1. 스토어 콘솔에 상품 등록(이삭 꾸러미 6종, 첫 거래 특가, 정기 배송=구독)
  2. 결제 성공 → 영수증을 Supabase Edge Function으로 보내 검증 → 서버가 우편/직접 지급 (게임 안에서 바로 지급하지 않기)
  3. 지금 코드의 `pay(k,won,cb)` 와 `TEST_PAY` 자리를 교체
- 웹 버전 결제(선택): 웹에서도 팔려면 토스페이먼츠 등 PG 계약(사업자·통신판매업 신고·PG 심사). 웹 게임을 직접 유료로 서비스하면 게임물관리위원회 등급분류 대상이 될 수 있음(앱은 스토어 자체등급분류). → 1차는 **웹은 무료 체험용, 결제는 앱에서만** 권장.

### 광고: AdMob 보상형 광고
- 지금 코드의 가짜 광고 `watchAd(kind, cb)` (3초 대기 후 보상) 자리를 **AdMob 보상형 광고**로 교체. Flutter 패키지 `google_mobile_ads`.
- 광고 자리(이미 게임에 있음): 피트의 무료 선물(상자·이삭·카드), 오프라인 보상 2배, 밭 등 → 하루 횟수 제한 그대로 유지
- 필요: AdMob 계정, 앱 등록(안드로이드·iOS 각각), 보상형 광고 단위 ID, iOS 추적 동의(ATT) 문구, 개인정보처리방침에 광고 식별자 항목 추가
- 보상은 광고 SDK의 "보상 지급" 콜백에서만 지급(창을 닫기만 하면 지급 안 함)
- 웹 버전 광고(선택): AdSense 게임용(H5 Games Ads)은 별도 신청 필요 → 1차는 앱만 권장

### 대표님 준비물
- Google Play Console(25달러), Apple Developer(연 99달러), AdMob 계정, RevenueCat 계정(무료 구간 있음)
- 정산 받을 사업자 계좌·세금 정보(각 콘솔에 입력)
- 상품 가격표 확정(지금 게임의 원화 가격 그대로 쓸지)

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
2. 보류: 효과음·배경음(Flutter에서 함께), 뒤로 가기(Flutter 기본 지원), 홈 화면 추가 안내(앱에선 불필요)
3. 출시 준비: Flutter 앱(5-C), 실제 결제·광고, 약관 법무 검토(앱 출시 시 광고 식별자·결제 항목 추가)
4. 대표님: GitHub 병합된 브랜치 정리 + 「Automatically delete head branches」 켜기

---

## 8. 새 세션 시작 문장 (복사용)

> `gogeangs/kingday` 저장소의 `docs/HANDOFF_NATIVE.md`를 먼저 읽고, 「왕이 되는 그날까지」를 **Flutter + Flame**으로 안드로이드·iOS 네이티브 앱으로 새로 만드는 작업을 5-C의 0단계부터 시작해줘. 그림·서버(Supabase)·저장 데이터 구조는 그대로 쓰고, 웹 버전(GitHub Pages)은 계속 유지해야 해. 한국어로 답해줘.
