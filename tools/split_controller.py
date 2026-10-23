"""앱 game/controller.dart 나누기 (코드 정리 3단계).

GameController 클래스 안의 「// ── 제목 ──」 구역 중 정한 구역의 메서드·게터를 같은 라이브러리의 part 파일로 옮겨
`extension 이름 on GameController { ... }` 로 둔다. 필드(상태)·생성자·@override·static·notifyListeners 를 쓰는 것은 클래스에 남긴다.
같은 라이브러리(part)라서 밑줄(_) 이름도 그대로 쓸 수 있고, 다른 파일에서 g.chCheck() 처럼 부르던 것도 그대로 된다.

    python3 tools/split_controller.py          # 무엇이 옮겨지는지만
    python3 tools/split_controller.py --write
"""
import re, sys

P = 'app/lib/game/controller.dart'

# 구역 제목 앞부분 → (part 파일, extension 이름)
PLAN = [
    ('대륙 지도', 'controller_map.dart', 'GameMapX', '대륙 지도 (docs/content/WORLDMAP.md)'),
    ('출석체크', 'controller_return.dart', 'GameReturnX', '출석·방치 보상 (다시 들어왔을 때)'),
    ('방치 보상', 'controller_return.dart', 'GameReturnX', None),
    ('새 소식', 'controller_story.dart', 'GameStoryX', '이야기 창 묶기: 새 소식 · 탈환 보고서 · 첫 은퇴 권하기'),
    ('탈환 보고서', 'controller_story.dart', 'GameStoryX', None),
    ('첫 은퇴 권하기', 'controller_story.dart', 'GameStoryX', None),
    ('마을', 'controller_village.dart', 'GameVillageX', '마을'),
    ('광고 보상', 'controller_ads.dart', 'GameAdsX', '광고 보상 · 장비 창 · 전투가 보낸 일 처리'),
    ('도전', 'controller_challenge.dart', 'GameChallengeX', '도전: 시련의 탑 · 요일 던전 (docs/content/CHALLENGE.md)'),
    ('다음 할 일 안내', 'controller_retire.dart', 'GameRetireX', '할 일 길잡이 · 은퇴 · 은퇴 일기'),
    ('은퇴', 'controller_retire.dart', 'GameRetireX', None),
    ('왕도 아스테리온', 'controller_capital.dart', 'GameCapitalX', '왕도 아스테리온 · 1부 엔딩 (docs/content/CAPITAL.md)'),
    ('빨간 점', 'controller_dots.dart', 'GameDotsX', '빨간 점 · 탭 점'),
]


def scan_depth(line, st):
    """Dart 한 줄을 읽어 괄호 깊이를 갱신. st = {'stack': [...], 'depth': int} — 문자열·주석·${} 안 처리"""
    i, n = 0, len(line)
    stack = st['stack']
    while i < n:
        mode = stack[-1] if stack else 'code'
        c = line[i]
        if mode == 'code' or mode == 'interp':
            if line.startswith('//', i):
                break
            if line.startswith('/*', i):
                stack.append('block')
                i += 2
                continue
            m = re.match(r"r?('''|\"\"\"|'|\")", line[i:])
            if m:
                raw = m.group(0).startswith('r')
                stack.append(('str', m.group(1), raw))
                i += len(m.group(0))
                continue
            if c in '({[':
                st['depth'] += 1
                if mode == 'interp':
                    stack.append('nest')
            elif c in ')}]':
                if mode == 'interp' and c == '}':
                    stack.pop()
                    i += 1
                    continue
                st['depth'] -= 1
            i += 1
        elif mode == 'nest':
            # interp 안의 중괄호
            if c in '({[':
                st['depth'] += 1
                stack.append('nest')
            elif c in ')}]':
                st['depth'] -= 1
                stack.pop()
            elif c in '\'"':
                stack.append(('str', c, False))
            i += 1
        elif mode == 'block':
            if line.startswith('*/', i):
                stack.pop()
                i += 2
            else:
                i += 1
        else:
            _, q, raw = mode
            if not raw and c == '\\':
                i += 2
                continue
            if line.startswith(q, i):
                stack.pop()
                i += len(q)
                continue
            if not raw and line.startswith('${', i):
                stack.append('interp')
                i += 2
                continue
            i += 1
    # 한 줄짜리 따옴표 문자열은 줄 끝에서 닫힌 것으로 (Dart 는 줄을 넘지 못함)
    while stack and isinstance(stack[-1], tuple) and len(stack[-1][1]) == 1:
        stack.pop()


def members(lines, start, end):
    """클래스 본문 [start, end) 에서 멤버 목록: (첫 줄, 끝 줄(포함), 앞 주석 시작 줄, 구역 제목)"""
    out, i, section, pre = [], start, '', None
    while i < end:
        L = lines[i]
        s = L.strip()
        if L.startswith('  // ──'):
            section = L.strip()[5:].strip(' ─')
            pre = None
            i += 1
            continue
        if not s:
            pre = None
            i += 1
            continue
        if L.startswith('  //') or L.startswith('  @'):
            if pre is None:
                pre = i
            i += 1
            continue
        if not L.startswith('  ') or L.startswith('   '):
            i += 1
            continue
        st = {'stack': [], 'depth': 0}
        j = i
        while True:
            scan_depth(lines[j], st)
            code = re.sub(r'//.*$', '', lines[j]).rstrip()
            if st['depth'] == 0 and (code.endswith(';') or code.endswith('}')) and not st['stack']:
                break
            j += 1
        out.append((i, j, pre if pre is not None else i, section))
        pre = None
        i = j + 1
    return out


def kind(lines, a, b, c0):
    head = lines[a].strip()
    body = '\n'.join(lines[a:b + 1])
    annot = '\n'.join(lines[c0:a])
    if '@override' in annot or head.startswith(('static ', 'GameController(', 'factory ')):
        return 'keep'
    if 'notifyListeners' in body or 'hasListeners' in body:
        return 'keep'
    # 맨 바깥(괄호 밖)에서 처음 나오는 = / => / { 로 판단
    d, k = 0, 0
    while k < len(body):
        c = body[k]
        if c in '(<[':
            d += 1
        elif c in ')>]':
            d -= 1 if not (c == '>' and k and body[k - 1] == '=') else 0
        elif d == 0:
            if body.startswith('=>', k):
                return 'method'
            if c == '=' and not body.startswith('==', k):
                return 'field'
            if c == '{':
                return 'method'
            if c == ';':
                return 'field'
        k += 1
    return 'field'


def statics(lines, cs, ce):
    return set(re.findall(r'^  static (?:const |final )?(?:[\w<>?,\s()]+?\s)?(\w+)\s*=', '\n'.join(lines[cs:ce]), re.M))


def main(write):
    lines = open(P, encoding='utf-8').read().split('\n')
    cs = next(i for i, l in enumerate(lines) if l.startswith('class GameController'))
    ce = next(i for i in range(cs + 1, len(lines)) if lines[i] == '}')
    ms = members(lines, cs + 1, ce)
    moves = {}
    for a, b, c0, sec in ms:
        plan = next((p for p in PLAN if sec.startswith(p[0])), None)
        if not plan:
            continue
        k = kind(lines, a, b, c0)
        if k == 'method':
            moves.setdefault((plan[1], plan[2]), []).append((c0, b, sec))
    total = 0
    for (f, x), lst in moves.items():
        total += sum(b - c + 1 for c, b, _ in lst)
        print(f'{f} ({x}): 멤버 {len(lst)}개 · {sum(b - c + 1 for c, b, _ in lst)}줄')
    print('옮길 줄', total, '/ 지금', len(lines))
    if not write:
        return
    drop = set()
    st = statics(lines, cs, ce)
    for (f, x), lst in moves.items():
        title = next(p[3] for p in PLAN if p[1] == f and p[3])
        body = []
        for c, b, sec in lst:
            txt0 = '\n'.join(lines[c:b + 1])
            for name in st:  # 클래스의 static 은 extension 안에서 「GameController.이름」으로
                txt0 = re.sub(r'(?<![\w.])' + re.escape(name) + r'\b', 'GameController.' + name, txt0)
            body.append(txt0)
            drop.update(range(c, b + 1))
        txt = f"// {title}\n// (game/controller.dart 의 GameController 에서 옮겨 옴 — 상태(필드)는 클래스에 그대로)\npart of 'controller.dart';\n\nextension {x} on GameController {{\n" + '\n\n'.join(body) + '\n}\n'
        open('app/lib/game/' + f, 'w', encoding='utf-8').write(txt)
    new = [l for i, l in enumerate(lines) if i not in drop]
    # 빈 줄 3개 이상 → 1개
    out = re.sub(r'\n{3,}', '\n\n', '\n'.join(new))
    parts = ''.join(f"part '{f}';\n" for f in sorted({f for f, _ in moves}))
    last_imp = max(i for i, l in enumerate(out.split('\n')) if l.startswith('import '))
    ol = out.split('\n')
    ol.insert(last_imp + 1, '\n' + parts.rstrip('\n'))
    open(P, 'w', encoding='utf-8').write('\n'.join(ol))
    print('고침')


if __name__ == '__main__':
    main('--write' in sys.argv)
