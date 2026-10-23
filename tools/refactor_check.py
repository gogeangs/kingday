"""코드 정리 전후 비교: 화면 모양(계산된 스타일)·글자·게임 숫자가 정리 전과 똑같은지 기계로 확인한다.
로컬 서버(python3 -m http.server 8765)를 켠 뒤 저장소 루트에서 실행.

    python3 tools/refactor_check.py snap index.html  /tmp/after.json     # 지금 파일로 찍기
    git show main:index.html > _before.html
    python3 tools/refactor_check.py snap _before.html /tmp/before.json   # 정리 전 파일로 찍기
    python3 tools/refactor_check.py diff /tmp/before.json /tmp/after.json

찍는 방법: 시간·난수를 고정하고 게임 루프(requestAnimationFrame)를 멈춘 채, 시험용 저장(app/test/fixtures/web_parity.json의 saves)마다
전투 화면 → 탭 6개(반 열림·크게) → 여러 창(방치 보상·탈환 보고서·새 소식·출석부·장비 비교·확률표·은퇴 확인 등)을 차례로 열고,
문서의 모든 요소에 대해 계산된 스타일 전부와 글자를 기록한다. 애니메이션·전환 효과는 꺼서 같은 순간을 비교한다.
"""
import json, sys
from playwright.sync_api import sync_playwright

FX = json.load(open('app/test/fixtures/web_parity.json'))
NOW, SAVES = FX['now'], FX['saves']

INIT = """(()=>{const NOW=%d;let t=NOW;Date.now=()=>t;const P=performance.now.bind(performance);performance.now=()=>1000;
 let s=12345;Math.random=()=>{s|=0;s=s+0x6D2B79F5|0;let x=Math.imul(s^s>>>15,1|s);x=x+Math.imul(x^x>>>7,61|x)^x;return((x^x>>>14)>>>0)/4294967296};
 window.requestAnimationFrame=()=>0;window.__tick=ms=>{t+=ms};
 const st=document.createElement('style');st.textContent='*,*::before,*::after{animation:none!important;transition:none!important;caret-color:transparent!important}';
 document.addEventListener('DOMContentLoaded',()=>document.head.appendChild(st));})()""" % NOW

DUMP = r"""() => {
 const out={};const props=window.__props||(window.__props=[...getComputedStyle(document.body)].sort());
 const path=e=>{const a=[];for(let x=e;x&&x.nodeType===1&&x!==document.documentElement;x=x.parentElement){let i=0;for(let y=x;(y=y.previousElementSibling);)i++;a.unshift(x.tagName.toLowerCase()+(x.id?'#'+x.id:'')+':'+i)}return a.join('>')};
 for(const e of document.querySelectorAll('body *')){if(e.closest('script,style')||!e.getClientRects().length||(e.parentElement===document.body&&e.tagName==='I')||e.id==='toast'||e.closest('#acctBox'))continue;const cs=getComputedStyle(e);
  const nv=(p,x)=>p.startsWith('--')?x.replace(/\s+/g,'').replace(/'/g,'"'):x;let v=props.map(p=>nv(p,cs.getPropertyValue(p))).join('\u0001');
  for(const pe of ['::before','::after']){const c=getComputedStyle(e,pe);if(c.content&&c.content!=='none'&&c.content!=='normal')v+='\u0002'+pe+props.map(p=>nv(p,c.getPropertyValue(p))).join('\u0001')}
  out[path(e)]=v+'\u0003'+(e.children.length?'':(e.textContent||'').trim().slice(0,200))}
 return out}"""

STEPS = [
    ('main', "()=>{}"),
    *[(f'tab_{t}_{m}', f"()=>{{S.pgFull={'true' if m=='full' else 'false'};setTab(null);setTab('{t}');try{{pgMode()}}catch(e){{}};renderAll()}}")
      for t in ['eq', 'pt', 'up', 'vl', 'mp', 'sh'] for m in ['half', 'full']],
    ('tab_close', "()=>{setTab(null);S.pgFull=false;try{pgMode()}catch(e){};renderAll()}"),
    ('vl_farm', "()=>{vlSelect('farm');renderAll()}"),
    ('vl_inn', "()=>{vlSelect('inn');renderAll()}"),
    ('vl_close', "()=>{setTab(null);renderAll()}"),
    ('m_offline', "()=>{S.last=Date.now()-3*3600e3;offline();pump()}"),
    ('m_report', "()=>{sceneQ.length=0;closeModal();rpAdd({face:'assets/portraits/portrait_morbas_idle.png',eb:'제1군단 · 점령지',t:'에르단 평원',p:['sys:시험'],btn:'진격한다'});rpAdd({face:'assets/portraits/portrait_margo_idle.png',eb:'동료 합류',t:'요리사 마고',p:['m:마고|시험','k:시험','q:시험'],btn:'함께 간다'});rpFlush();pump()}"),
    ('m_report_open', "()=>{const b=document.querySelector('.rpb');if(b)b.click()}"),
    ('m_scene', "()=>{sceneQ.length=0;closeModal();scene('시험','이야기 창',['k@smile:카엘 대사','q@angry:루미나르 대사','m:피트|피트 대사','sys:설명','지문'],'계속',{label:'나중에',go:()=>{}})}"),
    ('m_item', "()=>{sceneQ.length=0;closeModal();const it=rollItem();pending=it;showItem(it,S.eq[it.slot])}"),
    ('m_odds', "()=>{sceneQ.length=0;closeModal();pending=null;oddsSheet()}"),
    ('m_att', "()=>{sceneQ.length=0;closeModal();if(attEligible())attSheet()}"),
    ('pt_list', "()=>{sceneQ.length=0;closeModal();setTab(null);setTab('pt');ptTab='list';partySig='';renderAll()}"),
    ('pt_card', "()=>{ptTab='card';partySig='';renderAll()}"),
    ('pt_form', "()=>{ptTab='form';partySig='';renderAll();setTab(null)}"),
    ('s_0_profileSheet', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{profileSheet()}catch(e){}}'),
    ('s_1_compSheet', "()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{compSheet('margo')}catch(e){}}"),
    ('s_2_seatSheet', "()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{seatSheet('miner')}catch(e){}}"),
    ('s_3_kaelSeatSheet', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{kaelSeatSheet()}catch(e){}}'),
    ('s_4_chiefSheet', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{chiefSheet()}catch(e){}}'),
    ('s_5_diarySheet', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{diarySheet()}catch(e){}}'),
    ('s_6_slotSheet', "()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{slotSheet('weapon')}catch(e){}}"),
    ('s_7_forgeSheet', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{forgeSheet()}catch(e){}}'),
    ('s_8_cardOddsSheet', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{cardOddsSheet()}catch(e){}}'),
    ('s_9_gemSheet', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{gemSheet()}catch(e){}}'),
    ('s_10_chSheet', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{chSheet()}catch(e){}}'),
    ('s_11_wkSheet', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{wkSheet()}catch(e){}}'),
    ('s_12_vlSheet', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{vlSheet()}catch(e){}}'),
    ('s_13_settingsSheet', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{settingsSheet()}catch(e){}}'),
    ('s_14_part1Sheet', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{part1Sheet()}catch(e){}}'),
    ('s_15_open10', '()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{open10()}catch(e){}}'),
    ('s_16_cardReveal', "()=>{sceneQ.length=0;closeModal();pending=null;S.gem=Math.max(S.gem||0,500);try{cardReveal([['margo',3],['haral',5]],'카드',100)}catch(e){}}"),
    ('m_end', "()=>{sceneQ.length=0;closeModal();renderAll()}"),
]

SNAP_SAVES = [('fresh', 360), ('mid', 360), ('chief', 360), ('chief', 320)]


def snap(page_file, out):
    res = {}
    with sync_playwright() as p:
        b = p.chromium.launch()
        for name, w in SNAP_SAVES:
            if True:
                pg = b.new_page(viewport={'width': w, 'height': 760})
                errs = []
                pg.on('pageerror', lambda e: errs.append(str(e)))
                pg.add_init_script(INIT)
                pg.goto(f'http://localhost:8765/{page_file}?rc')
                pg.evaluate("s=>{localStorage.setItem('acorn-idle-v1',JSON.stringify(s))}", dict(SAVES[name], started=True))
                pg.reload()
                pg.wait_for_timeout(1200)
                pg.evaluate("()=>{noSave=true;document.getElementById('startBtn').click();sceneQ.length=0;closeModal()}")
                pg.wait_for_timeout(300)
                for step, js in STEPS:
                    try:
                        pg.evaluate(js)
                    except Exception as e:
                        errs.append(f'{step}: {str(e)[:120]}')
                    pg.wait_for_timeout(150)
                    res[f'{name}@{w}/{step}'] = pg.evaluate(DUMP)
                res[f'{name}@{w}/__errors'] = errs
                res['__props'] = pg.evaluate('()=>window.__props||[]')
                pg.close()
        b.close()
    json.dump(res, open(out, 'w'), ensure_ascii=False)
    print('찍음', len(res), '장면')


PROPS = []


def diff(a, b):
    A, B = json.load(open(a)), json.load(open(b))
    PROPS[:] = A.get('__props', [])
    bad = 0
    for k in A:
        if k == '__props':
            continue
        if k.endswith('__errors'):
            if A[k] != B.get(k):
                print('오류 다름', k, A[k], B.get(k))
                bad += 1
            continue
        x, y = A[k], B.get(k, {})
        if set(x) != set(y):
            print('요소 다름', k, 'only before', list(set(x) - set(y))[:3], 'only after', list(set(y) - set(x))[:3])
            bad += 1
        for el in set(x) & set(y):
            if x[el] == y[el]:
                continue
            bad += 1
            if bad <= 40:
                xa, ya = x[el].replace('\u0002', '\u0001').replace('\u0003', '\u0001').split('\u0001'), y[el].replace('\u0002', '\u0001').replace('\u0003', '\u0001').split('\u0001')
                d = [(PROPS[i % len(PROPS)] if PROPS else i, a, b2) for i, (a, b2) in enumerate(zip(xa, ya)) if a != b2][:4]
                print('스타일 다름', k, el[-90:], d)
    print('다른 곳', bad, '/ 장면', len(A))
    return bad


if __name__ == '__main__':
    if sys.argv[1] == 'snap':
        snap(sys.argv[2], sys.argv[3])
    else:
        sys.exit(1 if diff(sys.argv[2], sys.argv[3]) else 0)
