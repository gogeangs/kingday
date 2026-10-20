"""웹 그림(assets/)을 Flutter 앱(app/assets/game/)으로 복사하는 도구.

웹과 앱은 같은 그림을 씁니다. 원본은 저장소 맨 위 assets/ 하나뿐이고,
app/assets/game/ 은 빌드 전에 이 도구로 만드는 복사본입니다(git에 올리지 않음).
    python3 tools/sync_app_assets.py
그림을 바꾸거나 추가한 뒤, 앱을 빌드하기 전에 실행하세요. 바뀐 파일만 복사합니다.
"""
import filecmp, os, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets")
DST = os.path.join(ROOT, "app", "assets", "game")
# 웹 전용(앱에서 안 쓰는) 폴더·파일
SKIP_DIRS = {"fonts", "icon"}

copied = kept = 0
want = set()
for d, dirs, fs in os.walk(SRC):
    rel = os.path.relpath(d, SRC)
    if rel.split(os.sep)[0] in SKIP_DIRS:
        dirs[:] = []
        continue
    for f in fs:
        if f.startswith("."):
            continue
        s = os.path.join(d, f)
        t = os.path.normpath(os.path.join(DST, rel, f))
        want.add(t)
        if os.path.exists(t) and filecmp.cmp(s, t, shallow=False):
            kept += 1
            continue
        os.makedirs(os.path.dirname(t), exist_ok=True)
        shutil.copy2(s, t)
        copied += 1

# 원본에서 지워진 그림은 복사본에서도 지운다
removed = 0
for d, _, fs in os.walk(DST):
    for f in fs:
        p = os.path.join(d, f)
        if p not in want:
            os.remove(p)
            removed += 1

print(f"app/assets/game: 복사 {copied} · 그대로 {kept} · 삭제 {removed}")
