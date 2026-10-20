# 왕이 되는 그날까지 — 네이티브 앱 (Flutter + Flame)

웹 버전(저장소 맨 위 `index.html`)을 안드로이드·iOS 앱으로 새로 만드는 폴더입니다.
그림(`../assets/`), 서버(Supabase), 저장 데이터 구조(`S`)는 웹과 똑같이 씁니다.
진행 순서는 `docs/HANDOFF_NATIVE.md` 5-C를 따릅니다.

| 항목 | 값 |
|---|---|
| 패키지명 | `kr.co.project30s.kingday` (안드로이드·iOS 공통, 스토어 등록 후 변경 불가) |
| 상태 | 0단계 — 빈 앱 + 아이콘·시작 화면 + Flame 시험 화면 |

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
    stage0/          0단계 시험 화면 (1단계 이후 정식 화면으로 교체)
  tool/              아이콘·시작 화면용 보조 그림
  assets/game/       ← 그림 복사본 (git 제외, tools/sync_app_assets.py 로 생성)
  android/ ios/      플랫폼 뼈대 (첫 빌드 때 GitHub Actions 가 자동 생성·커밋)
```

## 규칙

- 그림 원본은 맨 위 `assets/` 하나뿐. 앱 쪽에 그림을 따로 넣지 않습니다.
- 앱에서 쓰는 그림 폴더가 늘어나면 `pubspec.yaml` 의 `assets:` 에 추가합니다.
- 밸런스 공식·숫자는 웹과 같게 유지합니다(1단계부터 `index.html` 에서 이식).
