# 왕이 되는 그날까지 — 네이티브 앱 (Flutter + Flame)

웹 버전(저장소 맨 위 `index.html`)을 안드로이드·iOS 앱으로 새로 만드는 폴더입니다.
그림(`../assets/`), 서버(Supabase), 저장 데이터 구조(`S`)는 웹과 똑같이 씁니다.
진행 순서는 `docs/HANDOFF_NATIVE.md` 5-C를 따릅니다.

| 항목 | 값 |
|---|---|
| 패키지명 | `kr.co.project30s.kingday` (안드로이드·iOS 공통, 스토어 등록 후 변경 불가) |
| 상태 | 4단계 — 장비(성유물 상자·대장간)·단련·원정대(편성·동료·카드) |

## APK 받는 법 (설치 없이)

1. `app/` 이나 `assets/` 를 바꿔 GitHub에 올리면 **GitHub Actions 「app-build」** 가 자동으로 APK를 만듭니다(약 10분).
2. 저장소 → Actions → app-build → 최근 실행 → 맨 아래 **Artifacts 「kingday-apk」** 내려받기 → 압축 풀기.
3. 폰으로 `app-release.apk` 를 옮겨 설치(처음엔 「출처를 알 수 없는 앱 설치 허용」 필요).

> 지금 APK는 시험용 서명입니다. 스토어에 올릴 정식 서명 키는 출시 단계에서 따로 만듭니다.

## 내 PC에서 빌드하기 (Windows 기준)

1. **Flutter SDK**: https://docs.flutter.dev/get-started/install/windows 에서 안내대로 설치(압축 풀고 `flutter\bin` 을 PATH에 추가).
2. **Android Studio** 설치 → 처음 실행 시 Android SDK 자동 설치 → SDK Manager에서 「Android SDK Command-line Tools」 체크.
3. 명령 프롬프트에서 `flutter doctor --android-licenses` (모두 y), `flutter doctor` 로 확인.
4. 저장소 폴더에서:
   ```
   python tools/sync_app_assets.py
   cd app
   flutter pub get
   flutter run            (폰을 USB로 연결하고 개발자 옵션 → USB 디버깅 켜기)
   flutter build apk      (APK 파일만 만들기)
   ```
5. iOS 빌드는 맥(Xcode)이 필요합니다. 맥이 없으면 출시 단계에서 Codemagic 클라우드 빌드를 씁니다.

## 폴더

```
app/
  lib/               앱 코드 (Dart)
    main.dart        시작점
    core/            데이터·공식·저장 구조 (화면과 무관, 웹과 같은 값)
    battle/          전투 계산(sim.dart, 웹 step 그대로)과 Flame 그리기(battle_game.dart)
    game/            진행 담당(controller.dart): 저장·전투·탭·알림·창 대기열
    ui/              공통 부품: 색·글꼴(theme), 상자·버튼·대사·금테 창(widgets), 그림 효과(fx)
    screens/         화면: 전체 틀(shell), 전투 위 표시(stage_overlay), 탭 화면(pages)
  tool/              아이콘·시작 화면용 보조 그림
  assets/game/       ← 그림 복사본 (git 제외, tools/sync_app_assets.py 로 생성)
  android/ ios/      플랫폼 뼈대 (첫 빌드 때 GitHub Actions 가 자동 생성·커밋)
```

## 웹과 같은 공식 지키기 (1단계부터)

- `lib/core/web_data.g.dart` — 웹 `index.html` 의 데이터 표(지역·동료·건물·스킬·대사)를 **자동으로 옮긴 파일**. 직접 고치지 않고 `node tools/parity/gen_dart_data.js` 로 다시 만듭니다.
- `lib/core/calc.dart` — 웹 공식(능력치·밸런스·비용·방치 보상·상자·카드·은퇴)을 옮긴 것. 웹 함수 이름이 주석에 붙어 있습니다.
- `lib/core/state.dart` — 저장 데이터. 웹 `S` 와 **같은 JSON** (웹 기록을 그대로 불러옴).
- `test/parity_test.dart` — 웹 코드를 Node 로 그대로 돌려 뽑은 정답 값(`test/fixtures/web_parity.json`)과 앱 공식 결과를 비교. 새 게임·중반·후반·옛 저장 4가지 기록으로 확인합니다.
- `test/actions_parity_test.dart` — 상자 열기·10연속·단련·레벨업·별 올리기·편성·대장간을 웹과 같은 난수로 실행해 매 조작 뒤 저장 데이터 전체를 비교 (`node tools/parity/make_action_fixtures.js`).
- `test/shell_layout_test.dart` — 화면 틀을 폰 폭 4종(320·360·390·430)에서 새 게임·후반 기록으로 그려 넘침이 없는지 확인.
- `test/battle_parity_test.dart` — 웹 전투(step)를 같은 난수로 돌린 결과(`test/fixtures/battle_parity.json`)와 앱 전투를 1초마다 비교 (보스·군단장·황금 고블린·스킬 10종·전멸 포함, `node tools/parity/make_battle_fixtures.js`).
- 웹 공식이나 데이터를 바꾸면: `node tools/parity/gen_dart_data.js` → `node tools/parity/make_fixtures.js` → 앱 공식도 맞게 고치기. 안 하면 GitHub Actions 가 알려 줍니다.

## 규칙

- 그림 원본은 맨 위 `assets/` 하나뿐. 앱 쪽에 그림을 따로 넣지 않습니다.
- 앱에서 쓰는 그림 폴더가 늘어나면 `pubspec.yaml` 의 `assets:` 에 추가합니다.
- 밸런스 공식·숫자는 웹과 같게 유지합니다(1단계부터 `index.html` 에서 이식).
