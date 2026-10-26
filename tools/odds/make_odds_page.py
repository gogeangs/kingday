"""확률 안내 페이지(odds.html) 만들기 — 게임(index.html)의 확률 공식을 그대로 불러 표로 씀.
확률(BASE_ODDS·boxF·primalP·CARD_FIX·CARD_W·동료 등급)을 바꾸면 다시 실행해서 odds.html 을 같이 커밋.

  python3 -m http.server 8765 &   (저장소 맨 위에서)
  python3 tools/odds/make_odds_page.py
"""
import asyncio, html, os
from playwright.async_api import async_playwright

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
LV = list(range(1, 31)) + [31, 32, 33, 35, 40, 45, 50, 60, 75, 100]

JS = """(LV)=>({grades:GRADES.map(g=>[g.n,g.c]), box:LV.map(L=>[L,odds(L,true)]), end:odds(99999,true),
  fix:CARD_FIX, w:CARD_W, gn:Object.fromEntries(Object.entries(GR).map(([k,v])=>[k,[v.n,v.c]])),
  comps:CARDIDS().map(id=>[COMP[id].n, GRADE[id]])})"""


def pct(v):
    if v <= 0:
        return '—'
    return f'{v:.3f}'.rstrip('0').rstrip('.') + '%'


async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page()
        await pg.goto('http://localhost:8765/index.html')
        await pg.wait_for_timeout(1500)
        d = await pg.evaluate(JS, LV)
        await b.close()
    G = d['grades']
    head = ''.join(f'<th style="color:{c}">{html.escape(n)}</th>' for n, c in G)
    rows = ''.join(f'<tr><td>{L}</td>' + ''.join(f'<td>{pct(v)}</td>' for v in o) + '</tr>' for L, o in d['box'])
    rows += '<tr class="end"><td>끝</td>' + ''.join(f'<td>{pct(v)}</td>' for v in d['end']) + '</tr>'
    fx, w, gn = d['fix'], d['w'], d['gn']
    rest_shop = 1 - fx['shop']['legend'] - fx['shop']['epic']
    rest_bat = 1 - fx['battle']['legend'] - fx['battle']['epic']
    by = {}
    for n, g in d['comps']:
        by.setdefault(g, []).append(n)
    comp_rows = ''.join(
        f'<tr><td style="color:{gn[g][1]}">{gn[g][0]}</td><td>{html.escape(", ".join(by.get(g, [])))}</td></tr>'
        for g in ['legend', 'epic', 'rare', 'common'])
    page = f'''<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>확률 안내 · 왕이 되는 그날까지</title>
<style>
:root{{--bg:#0d1220;--panel:#171e36;--text:#e8ecf6;--muted:#9aa6c1;--gold:#ffc94a;--line:rgba(255,201,74,.25)}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--text);font:15px/1.7 -apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo","Noto Sans KR","Malgun Gothic",sans-serif}}
main{{max-width:820px;margin:0 auto;padding:32px 16px 64px}}h1{{font-size:24px;margin:0 0 4px;color:var(--gold)}}h2{{font-size:17px;margin:28px 0 8px;color:var(--gold)}}
.muted{{color:var(--muted);font-size:13px}}a{{color:var(--gold)}}ul{{padding-left:20px}}
.tw{{overflow-x:auto;border:1px solid var(--line);border-radius:12px;background:var(--panel)}}
table{{border-collapse:collapse;width:100%;font-size:13px;font-variant-numeric:tabular-nums}}th,td{{padding:6px 8px;text-align:right;white-space:nowrap;border-bottom:1px solid rgba(255,255,255,.06)}}
th:first-child,td:first-child{{text-align:left}}th{{position:sticky;top:0;background:#1d2645}}tr.end td{{font-weight:700;color:var(--gold)}}
.names td:last-child{{white-space:normal;text-align:left;color:var(--muted)}}
</style></head><body><main>
<h1>확률 안내</h1>
<p class="muted">「왕이 되는 그날까지」 · 「게임산업진흥에 관한 법률」에 따른 확률형 아이템 정보 공개 · 게임 안 「확률 보기」와 같은 공식으로 만든 표입니다.</p>

<h2>1. 동료 카드</h2>
<p>동료 카드는 피트의 상점(황금 이삭)·광고·우편과 전투(보스·몬스터·황금 고블린)에서 얻습니다. 카드 한 묶음마다 어느 동료에게 갈지 아래 확률로 정합니다.</p>
<div class="tw"><table><tr><th>등급</th><th>상점·광고·우편</th><th>전투</th></tr>
<tr><td style="color:{gn['legend'][1]}">{gn['legend'][0]}</td><td>{pct(fx['shop']['legend']*100)}</td><td>{pct(fx['battle']['legend']*100)}</td></tr>
<tr><td style="color:{gn['epic'][1]}">{gn['epic'][0]}</td><td>{pct(fx['shop']['epic']*100)}</td><td>{pct(fx['battle']['epic']*100)}</td></tr>
<tr><td>{gn['rare'][0]}·{gn['common'][0]}</td><td>{pct(rest_shop*100)}</td><td>{pct(rest_bat*100)}</td></tr></table></div>
<ul class="muted">
<li>전설·영웅이 뽑히면 그 등급에서 <b>지금 모을 수 있는 동료</b> 가운데 한 명이 같은 확률로 나옵니다.</li>
<li>희귀·일반 몫({pct(rest_shop*100)} / 전투 {pct(rest_bat*100)})은 지금 열린 희귀·일반 동료에게 나뉘며, 희귀 동료 한 명은 {w['rare']}, 일반 동료 한 명은 {w['common']}의 비율(가중치)로 나눕니다. 예: 희귀 2명·일반 4명이 열려 있으면 희귀 한 명 = {pct(rest_shop*100)} × {w['rare']} ÷ ({w['rare']}×2 + {w['common']}×4).</li>
<li>희망 동료를 정하면 뽑을 때마다 절반 확률로 그 동료가 나옵니다(영웅·전설 희망 동료는 그 등급이 뽑혔을 때만).</li>
<li>별을 모두 채운 동료의 몫이나, 모을 동료가 없는 등급의 몫은 골드로 바뀝니다.</li>
<li>동료는 게임을 진행하면서 차례로 열리므로 동료 한 명당 확률은 이용자마다 다릅니다. 지금 내 확률은 게임 안 「피트의 상점 → 동료 카드 → 확률 보기」에서 동료별로 볼 수 있습니다.</li>
<li>유니크 동료(카엘 촌장·뚝딱이·루시안)는 카드 뽑기에 나오지 않고, 상점에서 확정으로 맞이합니다.</li></ul>
<div class="tw"><table class="names"><tr><th>등급</th><th>동료</th></tr>{comp_rows}</table></div>

<h2>2. 성유물 상자</h2>
<p>성유물 상자에서 나오는 성유물의 등급 확률입니다. 상자 레벨이 오를수록 좋은 등급이 잘 나오며, 레벨에는 끝이 없지만 「끝」 줄의 확률을 넘지 않습니다. 단위 %.</p>
<div class="tw"><table><tr><th>상자 Lv</th>{head}</tr>{rows}</table></div>
<ul class="muted">
<li>「{html.escape(G[-1][0])}」 등급은 첫 은퇴를 한 뒤 상자 Lv.31부터 나옵니다. 그 전에는 「{html.escape(G[-1][0])}」 칸의 몫이 다른 등급에 같은 비율로 나뉩니다.</li>
<li>성유물의 부위(무기·갑옷 등)는 같은 확률로 정해집니다. 지금 내 상자 레벨의 확률은 게임 안 「장비 탭 → 성유물 상자 → 레벨별 확률표」에서 볼 수 있습니다.</li></ul>

<h2>문의</h2>
<p>확률에 대한 문의는 게임 안 「⚙ 설정 → 문의하기」 또는 <a href="mailto:biz@project30s.co.kr">biz@project30s.co.kr</a> 로 보내 주세요. 확률이 바뀌면 바뀌기 전에 게임 안과 이 페이지로 알립니다.</p>
<p class="muted"><a href="./">게임으로 돌아가기</a> · <a href="terms.html">이용약관</a> · <a href="support.html">고객 지원</a></p>
</main></body></html>
'''
    open(os.path.join(ROOT, 'odds.html'), 'w').write(page)
    print('odds.html', len(page))

asyncio.run(main())
