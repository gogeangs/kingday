"""index.html 안 <style> 의 「죽은 선언」을 지운다 (코드 정리 1단계).

죽은 선언 = 뒤에 같은 선택자(글자 그대로 같음)가 같은 속성을 다시 정해서, 화면에 절대 쓰이지 않는 앞쪽 선언.
  - 뒤쪽 규칙이 맨 바깥(미디어 쿼리 밖)이거나 앞쪽과 같은 @media 안일 때만 (조건부로 덮는 경우는 남김)
  - 앞쪽이 !important 인데 뒤쪽이 아니면 남김
  - 같은 규칙 안에서 같은 속성을 두 번 쓴 것(옛 브라우저용 대비)은 건드리지 않음
  - 줄임 속성(padding)·풀어 쓴 속성(padding-left)이 섞인 경우도 건드리지 않음
선언이 다 지워진 규칙은 통째로 지운다. 나머지 글자는 그대로 둔다.

    python3 tools/css_dedupe.py            # 바꿀 것만 보여 줌
    python3 tools/css_dedupe.py --write    # index.html 고침
    python3 tools/css_dedupe.py --merge --write   # 같은 선택자 규칙 합치기 (refactor_check.py 로 확인 필수)
"""
import re, sys

SRC = 'index.html'


def strip_comments(t):
    return re.sub(r'/\*.*?\*/', lambda m: ' ' * len(m.group(0)), t, flags=re.S)


def parse(css, base):
    """(ctx, selector, block_start, block_end, decls[(prop, important, start, end)]) 목록. 위치는 base 기준."""
    clean = strip_comments(css)
    rules = []

    def walk(lo, hi, ctx):
        i = lo
        while i < hi:
            j = clean.find('{', i, hi)
            if j < 0:
                break
            pre = clean[i:j].strip()
            # 짝 맞는 } 찾기
            d, k = 1, j + 1
            while k < hi and d:
                c = clean[k]
                if c in '"\'':
                    q = c
                    k += 1
                    while k < hi and clean[k] != q:
                        k += 2 if clean[k] == '\\' else 1
                elif c == '{':
                    d += 1
                elif c == '}':
                    d -= 1
                k += 1
            end = k - 1  # '}' 위치
            if pre.startswith('@'):
                if re.match(r'@(media|supports|container|layer)\b', pre):
                    walk(j + 1, end, ctx + (re.sub(r'\s+', ' ', pre),))
                # @keyframes·@font-face 등은 그대로
            else:
                sel = re.sub(r'\s+', ' ', pre)
                decls, p = [], j + 1
                body = clean[j + 1:end]
                off = j + 1
                # 선언 나누기 (괄호·따옴표 안의 ; 무시)
                depth, s0, q = 0, 0, None
                for n, ch in enumerate(body + ';'):
                    if q:
                        if ch == q:
                            q = None
                        continue
                    if ch in '"\'':
                        q = ch
                    elif ch == '(':
                        depth += 1
                    elif ch == ')':
                        depth -= 1
                    elif ch == ';' and depth == 0:
                        seg = body[s0:n]
                        if ':' in seg and seg.strip():
                            prop = seg.split(':', 1)[0].strip().lower()
                            imp = bool(re.search(r'!\s*important\s*$', seg.strip()))
                            decls.append((prop, imp, off + s0, off + min(n + 1, len(body))))
                        s0 = n + 1
                rules.append((ctx, sel, base + j + 1, base + end, [(a, b, base + c, base + e) for a, b, c, e in decls], base + i, base + end + 1))
            i = end + 1

    walk(0, len(clean), ())
    return rules


def main(write):
    html = open(SRC, encoding='utf-8').read()
    blocks = [(m.start(1), m.group(1)) for m in re.finditer(r'<style>(.*?)</style>', html, flags=re.S)]
    rules = []
    for base, css in blocks:
        rules += parse(css, base)
    dead = []  # (start,end) 지울 글자 구간
    for a, (ctx, sel, bs, be, decls, rs, re_) in enumerate(rules):
        for prop, imp, s, e in decls:
            for ctx2, sel2, _, _, decls2, _, _ in rules[a + 1:]:
                if sel2 != sel or not (ctx2 == () or ctx2 == ctx):
                    continue
                hit = [d for d in decls2 if d[0] == prop]
                if hit and (not imp or any(d[1] for d in hit)):
                    dead.append((s, e, sel, prop, ctx))
                    break
    # 규칙별로 살아남는 선언이 없으면 규칙 통째로
    cut = []
    by_rule = {}
    for s, e, sel, prop, ctx in dead:
        by_rule.setdefault(next(n for n, r in enumerate(rules) if r[2] <= s < r[3]), []).append((s, e))
    rule_cut = 0
    for n, spans in by_rule.items():
        r = rules[n]
        if len(spans) == len(r[4]):
            cut.append((r[5], r[6]))
            rule_cut += 1
        else:
            cut += spans
    print(f'죽은 선언 {len(dead)}개 · 통째로 지울 규칙 {rule_cut}개')
    for s, e, sel, prop, ctx in dead[:60]:
        print(' ', ('@' + ' '.join(ctx) + ' ' if ctx else '') + sel[:70], '→', prop, '|', html[s:e].strip()[:60])
    if write:
        for s, e in sorted(cut, reverse=True):
            html = html[:s] + html[e:]
        # 규칙 안에서 마지막 ; 를 지워 생긴 「;}」·「{;」 정리는 하지 않아도 됨(문법상 문제 없음)
        open(SRC, 'w', encoding='utf-8').write(html)
        print('index.html 고침')


if __name__ == '__main__' and '--merge' not in sys.argv:
    main('--write' in sys.argv)


# 합치면 모양이 바뀌는 것(refactor_check.py 로 찾음): 중간 규칙과 순서가 얽힘
SKIP_MERGE = (':root', '.crc', '.cpk', '.crow', '.crev', '.buy')


def merge(write):
    """같은 선택자 규칙(같은 @media 안)을 뒤쪽 규칙 하나로 합친다: 앞쪽 선언을 뒤쪽 규칙 맨 앞에 붙이고 앞쪽 규칙은 지움.
    (중간에 다른 규칙이 같은 속성을 정하면 순서가 바뀌어 모양이 달라질 수 있으므로 refactor_check.py 로 꼭 확인)"""
    html = open(SRC, encoding='utf-8').read()
    blocks = [(m.start(1), m.group(1)) for m in re.finditer(r'<style>(.*?)</style>', html, flags=re.S)]
    rules = []
    for base, css in blocks:
        rules += parse(css, base)
    edits = []  # (pos, delete_len, insert_text)
    used = set()
    n = 0
    for a, r in enumerate(rules):
        if a in used or r[1].startswith(SKIP_MERGE):
            continue
        for b in range(a + 1, len(rules)):
            r2 = rules[b]
            if r2[0] == r[0] and r2[1] == r[1]:
                if any(d[1] for d in r[4] + r2[4]):
                    break  # !important 이 섞이면 순서가 중요해서 합치지 않음
                body = html[r[2]:r[3]].strip().rstrip(';')
                if body:
                    edits.append((r2[2], 0, body + ';'))
                edits.append((r[5], r[6] - r[5], ''))
                used.add(a)
                n += 1
                break
    print('합칠 규칙', n)
    if write:
        for pos, dl, ins in sorted(edits, key=lambda e: e[0], reverse=True):
            html = html[:pos] + ins + html[pos + dl:]
        open(SRC, 'w', encoding='utf-8').write(html)
        print('index.html 고침')


if __name__ == '__main__' and '--merge' in sys.argv:
    merge('--write' in sys.argv)
