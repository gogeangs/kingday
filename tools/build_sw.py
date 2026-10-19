"""오프라인 실행용 서비스 워커(sw.js)를 만드는 도구.

게임 파일(index.html, manifest, assets/**)의 내용 해시를 모아 sw.js에 적습니다.
그림이나 index.html을 바꾼 뒤에는 커밋 전에 꼭 다시 실행하세요.
    python3 tools/build_sw.py
바뀐 파일만 새로 받고, 나머지는 휴대폰에 저장된 것을 그대로 씁니다.
"""
import hashlib, json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP = {"assets/icon/app_icon_1024.png"}  # 스토어 제출용 원본, 게임에서 안 씀


def h(p):
    return hashlib.sha1(open(os.path.join(ROOT, p), "rb").read()).hexdigest()[:10]


files = ["manifest.webmanifest", "favicon.ico"]
for d, _, fs in os.walk(os.path.join(ROOT, "assets")):
    for f in fs:
        p = os.path.relpath(os.path.join(d, f), ROOT).replace(os.sep, "/")
        if p not in SKIP and not f.startswith("."):
            files.append(p)
files.sort()
mp = {p: h(p) for p in files}
ver = hashlib.sha1((h("index.html") + json.dumps(mp, sort_keys=True)).encode()).hexdigest()[:10]
tpl = open(os.path.join(ROOT, "tools", "sw_template.js"), encoding="utf-8").read()
out = tpl.replace("__VERSION__", ver).replace("__MAP__", json.dumps(mp, separators=(",", ":")))
open(os.path.join(ROOT, "sw.js"), "w", encoding="utf-8").write(out)
print("sw.js", ver, len(mp), "files", round(sum(os.path.getsize(os.path.join(ROOT, p)) for p in mp) / 1e6, 1), "MB")
