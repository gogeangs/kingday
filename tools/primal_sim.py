"""첫 「태초」까지 걸리는 시간을 안(案)마다 잰다 (docs/content/FIRST_DAY.md 3-4).
로컬 서버(python3 -m http.server 8765)를 켠 뒤 저장소 루트에서 실행.

    python3 tools/primal_sim.py 4 3        # 플레이 4시간까지, 안마다 3번
    python3 tools/primal_sim.py 4 3 1안    # 한 안만

안마다 index.html 의 primalP 줄만 바꾼 사본(_primal_<안>.html)을 잠깐 만들어 띄우고 끝나면 지움.
"""
import asyncio, json, os, re, sys
from playwright.async_api import async_playwright

H = sys.argv[1] if len(sys.argv) > 1 else '6'
N = int(sys.argv[2]) if len(sys.argv) > 2 else 3
ORIG = 'const primalP=L=>L<=10?0:5*(1-Math.pow(.93,L-10));'
GATE = '(S.best>50||(S.retires||0)>0)'
B50 = 'S.best>50'
RET = '(S.retires||0)>0'
PLANS = {k: v for k, v in {
    '지금': ORIG,
    '1안 상자 Lv.21부터': 'const primalP=L=>L<=20?0:5*(1-Math.pow(.93,L-20));',
    '2안 영지 50 탈환 뒤': f'const primalP=L=>L<=10||!({B50})?0:5*(1-Math.pow(.93,L-10));',
    '3안 섞기 (상자 Lv.31부터 + 첫 은퇴 뒤)': f'const primalP=L=>L<=30||!{RET}?0:5*(1-Math.pow(.93,L-30));',
}.items() if len(sys.argv) < 4 or k.startswith(sys.argv[3])}


async def main():
    src = open('index.html', encoding='utf-8').read()
    assert src.count(ORIG) == 1
    js = open('tools/sim/primal_sim.js', encoding='utf-8').read().replace('HOURS', H)
    res = {}
    async with async_playwright() as p:
        b = await p.chromium.launch()
        for i, (name, line) in enumerate(PLANS.items()):
            fn = f'_primal_{i}.html'
            open(fn, 'w', encoding='utf-8').write(src.replace(ORIG, line))
            try:
                runs = []
                for _ in range(N):
                    pg = await b.new_page(viewport={'width': 390, 'height': 844})
                    await pg.goto(f'http://localhost:8765/{fn}')
                    await pg.evaluate('localStorage.clear()')
                    await pg.reload()
                    await pg.wait_for_timeout(800)
                    await pg.click('#startBtn')
                    await pg.wait_for_timeout(300)
                    runs.append(await pg.evaluate(js))
                    await pg.close()
                res[name] = runs
                print(name, json.dumps(runs, ensure_ascii=False), flush=True)
            finally:
                os.remove(fn)
        await b.close()


asyncio.run(main())
