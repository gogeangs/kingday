"""게임 미리보기(claude.ai Artifact)용 index 사본 만들기.

Artifact 한 개에는 파일을 512개까지만 올릴 수 있어서, 미리보기 사본에서만
- 글꼴 4개와 고정 경로로만 쓰는 작은 UI 아이콘을 HTML 안(data URI)에 넣고
- 설치용 아이콘·manifest 링크를 뺀다. (실제 게임 index.html 은 그대로)

    python3 tools/build_preview.py <출력.html>

올릴 때는 출력 파일을 페이지로, INLINE·DROP 의 파일은 Artifact 에서 빼고(null), 나머지 assets 는 그대로 둔다.
INLINE 에는 'assets/ui/'+이름 처럼 코드로 경로를 만들어 부르는 그림을 넣으면 안 된다(그 경로는 바뀌지 않음).
"""
import base64, os, re, sys

INLINE = ['assets/fonts/hahmlet-500.woff2', 'assets/fonts/hahmlet-700.woff2', 'assets/fonts/plexkr-400.woff2', 'assets/fonts/plexkr-600.woff2'] + \
    ['assets/ui/%s.png' % n for n in 'btn_auto btn_close icon_goblin icon_lock icon_mail icon_rank relic_chest tab_party village_skill'.split()]
DROP = ['assets/icon/apple-touch-icon.png', 'assets/icon/favicon-16.png', 'assets/icon/favicon-32.png', 'assets/icon/icon-192.png', 'assets/icon/icon-512.png', 'favicon.ico', 'manifest.webmanifest']
MIME = {'.png': 'image/png', '.woff2': 'font/woff2'}

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
s = open(os.path.join(root, 'index.html'), encoding='utf-8').read()
for p in INLINE:
    assert p in s, p
    data = base64.b64encode(open(os.path.join(root, p), 'rb').read()).decode()
    s = s.replace(p, 'data:%s;base64,%s' % (MIME[os.path.splitext(p)[1]], data))
s = re.sub(r'<link[^>]+(?:manifest|apple-touch-icon|rel="icon")[^>]*>', '', s)
open(sys.argv[1], 'w', encoding='utf-8').write(s)
print(sys.argv[1], round(len(s) / 1e6, 2), 'MB · 빼는 파일', len(INLINE) + len(DROP))
