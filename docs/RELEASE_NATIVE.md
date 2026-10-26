# 앱 출시 준비 안내 (대표님 할 일 + 값 넣는 곳)

앱 코드는 로그인·결제·광고까지 미리 만들어 두었어요. 아래 값만 생기면 제가 바로 연결할 수 있어요.

- **공개해도 되는 값**: 클라이언트 ID, 광고 ID, 상품 ID, SHA-1. 채팅으로 주셔도 돼요.
- **절대 채팅·코드에 넣지 않는 값**: 비밀번호, 키 파일, 서비스 계정 JSON. GitHub Secrets나 Supabase Secrets에 **대표님이 직접** 넣어 주세요.

---

## 0. 순서 한눈에

1. 정식 서명 키 만들기 → GitHub Secrets 4개 (§1)
2. Google Play Console 가입 → 앱 만들기 → 내부 테스트에 AAB 올리기 (§2)
3. Google Cloud에 안드로이드 OAuth 클라이언트 추가 → Supabase에 클라이언트 ID 추가 (§3)
4. AdMob 앱·광고 단위 만들기 (§4)
5. Play Console에 상품 9개 등록 → 서비스 계정 연결 → Supabase에 SQL 실행·Edge Function 배포 (§5)
6. (iOS) Apple Developer 가입 → 앱·상품·애플 로그인 → Codemagic (§6)
7. 스토어 등록정보·개인정보처리방침·콘텐츠 등급 (§7, `docs/STORE_LISTING.md`, `docs/PRIVACY_POLICY.md`)

---

## 1. 정식 서명 키 (안드로이드)

지금 APK는 빌드할 때마다 바뀌는 시험용 키로 서명돼요. 스토어에 올리고 구글 로그인을 붙이려면 **바뀌지 않는 키**가 필요해요.

1. PC에 Android Studio(또는 Java)가 설치돼 있으면 명령 프롬프트에서 실행해 주세요.
   ```
   keytool -genkey -v -keystore kingday-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   비밀번호는 대표님만 아는 것으로 정하고 따로 보관해 주세요. 이 파일과 비밀번호를 잃어버리면 앱을 업데이트할 수 없어요.
2. 키 파일을 글자로 바꿔 주세요.
   - Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("kingday-upload.jks")) | Set-Clipboard`
3. GitHub 저장소 → Settings → Secrets and variables → Actions → **New repository secret**에 4개를 넣어 주세요.

| 이름 | 값 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | 2번에서 복사한 글자 |
| `ANDROID_KEYSTORE_PASSWORD` | 키 저장소 비밀번호 |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | 키 비밀번호 (보통 위와 같음) |

4. 다음 빌드부터 다음 두 가지가 생겨요.
   - **업로드 키 SHA-1**: 빌드 화면 알림(`upload-key-sha1`)에 떠요. §3에서 써요.
   - **스토어용 파일**: Artifacts에 `kingday-aab`가 생겨요.

## 2. Google Play Console

1. https://play.google.com/console 에 가입해 주세요(25달러, 1회). 개발자 계정은 **조직(주식회사 프로젝트서티즈)** 으로 만들기를 권해요.
2. 앱을 만들어 주세요. 이름은 「왕이 되는 그날까지」, 기본 언어는 한국어, 게임, 무료로 해 주세요.
3. 테스트 및 출시 → 내부 테스트 → 새 버전 → `kingday-aab`의 `app-release.aab`를 올려 주세요.
   - 처음 올릴 때 **Play 앱 서명**을 켜 주세요(권장 기본값).
4. 설정 → 앱 무결성 → 앱 서명 화면에서 **앱 서명 키 SHA-1**을 복사해 주세요. §3에서 업로드 키 SHA-1과 함께 써요.

## 3. 구글 로그인 (Google Cloud + Supabase)

웹 로그인용 프로젝트 `kingday-512207`를 그대로 써요.

> **안드로이드 완료 (2026-10-25)**: 안드로이드 클라이언트 2개 `kingday android upload`(업로드 키 `17:E1:74:80:DE:71:8D:FD:B8:53:8D:4F:71:C2:89:97:79:9A:92:59`)·`kingday android play`(앱 서명 키 `B3:83:E4:0B:A0:65:65:8D:03:DB:2A:9F:AF:2C:16:3D:6A:33:9B:86`) 만듦. 웹 클라이언트 ID를 `app/lib/game/login.dart`에 넣어 안드로이드 구글 로그인 켬. 남은 것: iOS 클라이언트(아이폰 낼 때).

1. Google Cloud → API 및 서비스 → 사용자 인증 정보 → **OAuth 클라이언트 ID 만들기 → Android**를 2개 만들어 주세요.
   - 패키지 이름: `kr.co.project30s.kingday`
   - SHA-1: 하나는 **업로드 키 SHA-1**, 다른 하나는 **앱 서명 키 SHA-1**
2. (iOS를 낼 때) **OAuth 클라이언트 ID → iOS**도 하나 만들어 주세요. 번들 ID는 `kr.co.project30s.kingday`예요.
3. Supabase → Authentication → Providers → Google → **Client IDs** 칸에 쉼표로 이어서 넣어 주세요.
   - 기존 웹 클라이언트 ID
   - iOS 클라이언트 ID
   - 안드로이드 앱은 웹 클라이언트 ID로 토큰을 받기 때문에 안드로이드 클라이언트 ID는 넣지 않아도 돼요.
4. 저에게 아래 두 값을 알려 주세요(공개해도 되는 값). 그러면 제가 `app/lib/game/login.dart`에 넣고 로그인 버튼을 켤게요.
   - 웹 클라이언트 ID
   - iOS 클라이언트 ID

## 4. AdMob (보상형 광고)

지금은 구글 공식 **시험용 광고**가 나와요. 진짜 수익을 내려면 실제 ID가 필요해요.

1. https://admob.google.com 에서 앱을 추가해 주세요(안드로이드, 아이폰 각각).
2. 각 앱에 **보상형 광고 단위**를 하나씩 만들어 주세요. 이름 예: `보상형-공통`
3. 저에게 아래 4개 값을 알려 주세요.

| 값 | 넣을 곳 (제가 넣어요) |
|---|---|
| 안드로이드 앱 ID `ca-app-pub-…~…` | `app/android/app/src/main/AndroidManifest.xml` |
| 아이폰 앱 ID | `app/ios/Runner/Info.plist` |
| 안드로이드 보상형 광고 단위 ID `ca-app-pub-…/…` | `app/lib/game/ads.dart` `realAndroid` |
| 아이폰 보상형 광고 단위 ID | `app/lib/game/ads.dart` `realIos` |

> 개발 중에 실제 광고를 직접 누르면 AdMob 계정이 정지될 수 있어요. 출시 전까지는 시험용 광고로 확인해 주세요.

## 5. 인앱결제 (상품·결제 확인 서버)

### 5-1. 상품 등록 (Play Console → 수익 창출 → 상품)

> **안드로이드 완료 (2026-10-25)**: 아래 9개 모두 Play Console에 등록·활성(일회성 제품은 구매 옵션 ID `buy`, 정기 결제는 기본 요금제 `monthly` 매월 자동 갱신). 서비스 계정 `kingday-iap@kingday-512207.iam.gserviceaccount.com`(재무 데이터 보기·주문 및 구독 관리), Android Developer API 사용, `stage4_iap.sql` 실행, `kd-iap` 배포, Secret `GOOGLE_SERVICE_ACCOUNT_JSON`(대표님 입력), 라이선스 테스트 목록 「kingday 결제 시험」(ceo@itso.co.kr). 앱 `IapStore.enabled` 는 안드로이드에서 켬. 남은 것: 아이폰.

**인앱 상품(관리형)**:

| 상품 ID | 이름 | 가격 |
|---|---|---|
| `kd_gem_60` | 황금 이삭 60 | ₩1,200 |
| `kd_gem_330` | 황금 이삭 330 | ₩5,500 |
| `kd_gem_680` | 황금 이삭 680 | ₩11,000 |
| `kd_gem_1280` | 황금 이삭 1,280 | ₩22,000 |
| `kd_gem_3280` | 황금 이삭 3,280 | ₩55,000 |
| `kd_gem_6480` | 황금 이삭 6,480 | ₩99,000 |
| `kd_starter` | 첫 거래 특가 | ₩1,200 |
| `kd_chief` | 카엘 촌장 맞이하기 (유니크 동료, 첫 은퇴 뒤 상점에 열림) | ₩500 (스토어에서 안 되면 그 스토어의 가장 낮은 가격) |
| `kd_pass` | 원정 일지 (시즌 패스 유료 줄 · **소모성** — 2주 시즌마다 다시 삼) | ₩3,300 |
| `kd_growth` | 영주의 첫걸음 (성장 패키지 · **비소모성** — 계정당 1번) | ₩11,000 |
| `kd_ttukttak` | 뚝딱이 맞이하기 (유니크 동료, 처음부터 상점에 보임 · 소모성 — 합류하면 상점에서 사라짐) | ₩5,500 |
| `kd_lucian` | 루시안 맞이하기 (유니크 동료, 처음부터 상점에 보임 · 소모성 — 합류하면 상점에서 사라짐) | ₩5,500 |

> **2026-10-26 추가(유니크 동료 루시안)**: `kd_lucian` ₩5,500(소모성) → 대표님이 Play Console·App Store Connect에 등록 + `kd-iap` 다시 배포. 보상 우편 `{lucian: 1}`.

> **2026-10-26 추가(유니크 동료 뚝딱이)**: `kd_ttukttak` ₩5,500(소모성) → 대표님이 Play Console·App Store Connect에 등록 + `kd-iap` 다시 배포. 보상 우편 `{ttuk: 1}`.

> **2026-10-26 추가(상점·패스, `docs/content/SHOP.md`)**: `kd_pass`·`kd_growth` 2개는 아직 스토어에 없음 → 대표님이 Play Console·App Store Connect에 등록. 서버는 `supabase/stage7_pass.sql` 실행 + `kd-iap` 다시 배포(상품 2개 추가된 파일). 원정 일지는 서버가 시즌 번호와 함께 기록하고, 같은 시즌 두 번째 결제는 황금 이삭 200으로 돌려줌. App Store는 비소모성 상품이 있으면 「구매 복원」이 필요 → 앱 상점 「영주의 첫걸음」 칸에 넣음.

**정기 결제(구독)**: `kd_sub_monthly` 피트의 정기 배송, ₩5,500, 1개월 기본 요금제(자동 갱신).

> 첫 구매 2배·첫 거래 특가 1회 제한은 게임이 기록으로 처리해요. 스토어에는 위 금액만 등록하면 돼요.

### 5-2. 결제 확인용 서비스 계정
1. Google Cloud → IAM → 서비스 계정을 만들고 → 키 → JSON 키를 내려받아 주세요.
2. Play Console → 사용자 및 권한 → 그 서비스 계정 이메일을 초대하고 **재무 데이터 보기·주문 관리** 권한을 주세요.
3. Google Cloud에서 **Google Play Android Developer API**를 사용 설정해 주세요.

### 5-3. Supabase 서버
1. SQL Editor → `supabase/stage4_iap.sql`을 통째로 붙여 넣고 Run 해 주세요.
2. Edge Functions → 새 함수 `kd-iap` → `supabase/functions/kd-iap/index.ts` 내용을 붙여 넣고 Deploy 해 주세요.
3. Edge Functions → Secrets에 넣어 주세요. **값은 대표님만 넣어요.**
   - `GOOGLE_SERVICE_ACCOUNT_JSON`: 5-2의 JSON 파일 내용 전체
   - (iOS) `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`: App Store Connect → 사용자 및 액세스 → 통합 → 인앱 구매 키
4. 다 됐다고 알려 주시면 제가 `app/lib/game/store.dart`의 `enabled`를 켜고 시험용 바로 지급을 꺼요.
5. Play Console → 설정 → 라이선스 테스트에 대표님 구글 계정을 넣으면 실제 돈 없이 결제 시험을 할 수 있어요.

## 6. 아이폰 (나중에)
1. Apple Developer Program에 가입해 주세요(연 99달러, 조직은 D-U-N-S 번호 필요).
2. App Store Connect에서 앱을 만들어 주세요. 번들 ID는 `kr.co.project30s.kingday`예요.
3. 상품 9개를 §5-1과 같은 ID로 등록해 주세요.
4. **Sign in with Apple**을 켜고, Supabase → Providers → Apple을 켜 주세요. App Store 규정상 구글 로그인이 있으면 애플 로그인도 있어야 해요.
5. 맥이 없으면 Codemagic(https://codemagic.io) 가입 → 저장소 연결 → 제가 빌드 설정 파일을 만들어 드릴게요.

## 7. 스토어 등록정보·정책
- 설명 문구 초안: `docs/STORE_LISTING.md`
- 개인정보처리방침 초안: `docs/PRIVACY_POLICY.md`
  - 회사 정보와 문의 이메일을 채워서 공개 주소(예: GitHub Pages)에 올려 주세요.
- **콘텐츠 등급(IARC 설문)**: 판타지 전투(만화풍, 피 표현 없음), 인앱 구매 있음, 광고 있음, 사용자 간 소통 없음(닉네임·랭킹만), 도박 요소 없음으로 답하면 돼요.
  - 단, 성유물 상자는 **유료 확률형 아이템**이에요. 한국은 확률 공개가 의무예요. 게임 안 장비 탭에 확률이 이미 표시돼 있어요.
- **데이터 보안(Data safety)**: `docs/PRIVACY_POLICY.md` 끝의 표대로 답해 주세요.

---

## 제가 이미 넣어 둔 것 (참고)

| 기능 | 파일 | 지금 상태 |
|---|---|---|
| 효과음·진동 | `app/lib/game/feel.dart`, `app/assets/audio/` | 켜짐(설정에서 끄기 가능) |
| 보상형 광고 | `app/lib/game/ads.dart` | 시험용 광고 ID |
| 인앱결제 | `app/lib/game/store.dart`, `supabase/functions/kd-iap`, `supabase/stage4_iap.sql` | 꺼짐(시험용 바로 지급) |
| 구글·애플 로그인 | `app/lib/game/login.dart` | 꺼짐(클라이언트 ID 대기) |
| 정식 서명 | `.github/workflows/app-build.yml`, `app/android/app/build.gradle.kts` | GitHub 비밀값을 넣으면 자동 사용 |
