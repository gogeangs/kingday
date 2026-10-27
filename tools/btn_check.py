"""폭 320 화면에서 창(시트) 아래 버튼 글자가 두 줄로 넘어가는 곳 찾기 (앱 소스 정적 검사).

창 안쪽 폭 = 320 - 16×2(화면 여백) - 28×2(금테 안쪽) = 232. 버튼 n개면 한 칸 = (232 - 8(n-1)) / n, 글자 자리 = 칸 - 24.
KdActs 는 16px → 14px 로 줄여 보고 그래도 넘치면 두 줄 (app/lib/ui/widgets.dart KdActs.fit).
글자 폭은 Hahmlet 700 글꼴 실제 글자 너비로 잼. ${...} 는 「00」, fmt() 는 「12.3K」로 바꿔 어림.

    python3 tools/btn_check.py
"""
import glob
import re

from fontTools.ttLib import TTFont

F = TTFont('assets/fonts/hahmlet-700.woff2')
CMAP, HM, UPM = F.getBestCmap(), F['hmtx'], F['head'].unitsPerEm
W = 232


def width(t, size):
    return sum(HM[CMAP[ord(ch)]][0] if ord(ch) in CMAP else UPM * .6 for ch in t) * size / UPM


def sub(t):
    t = re.sub(r"\$\{[^}]*fmt\([^}]*\)\}", "12.3K", t)
    return re.sub(r"\$\w+", "00", re.sub(r"\$\{[^}]*\}", "00", t))


def inner(n):
    return (W - 8 * (n - 1)) / n - 24


# 실제로는 한 줄에 함께 놓이지 않는 버튼(서로 다른 조건) — 직접 확인함
OK = {('app/lib/screens/social_sheets.dart', '원정대 보기'),  # 닫기+원정대 보기 또는 원정대 보기+또 뽑기 (2개)
      ('app/lib/screens/social_sheets.dart', "바로 ${frame ? ")}  # 「바로 끼우기」·「바로 달기」 (따옴표 안 따옴표라 잘림)
LIT = r"(['\"])((?:\\.|(?!\1).)*)\1"
bad = []
for fn in sorted(glob.glob('app/lib/**/*.dart', recursive=True)):
    src = open(fn, encoding='utf-8').read()
    # KdActs(buttons: [...]) — 버튼 수는 줄에 실제로 함께 놓일 수 있는 최대 수로 어림 (if/else·삼항은 1개로)
    for m in re.finditer(r"KdActs\(\s*(?:key:[^,]*,\s*)?buttons:\s*\[", src):
        i, d, j = m.end(), 1, m.end()
        while d and j < len(src):
            d += {'[': 1, ']': -1}.get(src[j], 0)
            j += 1
        body = src[i:j - 1]
        n = len(re.findall(r"KdAct\(", body)) - len(re.findall(r"\?\s*KdAct\(", body)) - len(re.findall(r"\belse\b[^\[;]*?KdAct\(", body, re.S))
        for _, t in re.findall(r"KdAct\(\s*" + LIT, body):
            if (fn, t) not in OK and width(sub(t), 14) > inner(max(n, 1)):
                bad.append((fn, src[:m.start()].count('\n') + 1, n, t))
    # scene(..., '버튼', altLabel: '다른 버튼') — 버튼 2개
    for m in re.finditer(LIT + r"\s*,\s*altLabel:\s*" + LIT.replace('\\1', '\\3'), src):
        for t in (m.group(2), m.group(4)):
            if width(sub(t), 14) > inner(2):
                bad.append((fn, src[:m.start()].count('\n') + 1, 2, t))
for b in bad:
    print('%s:%d  버튼 %d개  「%s」' % b)
print('두 줄 버튼', len(bad), '곳')
