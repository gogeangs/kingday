"""스토어 스크린샷 만들기 (2026-11-16 완전 무료판 — 상점·결제·광고 화면 없음)

웹 게임(index.html)을 Playwright 로 휴대폰 크기(360×640, 3배)로 찍고,
흐린 타이틀 그림 배경 + 위쪽 문구를 얹어 스토어 크기로 저장한다.
  - store/playstore_free/phone_1..8.png   1080×1920 (Google Play 휴대전화)
  - store/appstore_free/iphone69_1..8.png 1320×2868 (App Store 6.9인치)

쓰는 법: 저장소 맨 위에서 `python3 -m http.server 8765` 를 켜 둔 채
        `python3 tools/store_shots.py`
저장 데이터는 비교 시험용 저장(app/test/fixtures/web_parity.json 의 late)에 마을·동료를 더해 씀.
"""
import asyncio
import base64
import json
import os
import sys

from PIL import Image
from playwright.async_api import async_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
URL = 'http://localhost:8765/index.html'
OUT = {
    'play': (os.path.join(ROOT, 'store/playstore_free'), 1080, 1920, 'phone_{}.png'),
    'apple': (os.path.join(ROOT, 'store/appstore_free'), 1320, 2868, 'iphone69_{}.png'),
}

# (문구 큰 줄, 작은 줄, 화면 만들기 JS)
SCENES = [
    ('켜 두기만 해도 원정대가 싸워요', '마왕군에게 빼앗긴 영지를 하나씩 되찾아요', "setTab(null)"),
    ('개성 있는 동료들과 함께', '동료마다 전용 스킬 · 별을 올려 더 강하게', "setTab(null);ptTab='team';partySig='';setTab('pt')"),
    ('카드를 모아 동료를 키워요', '희귀 · 영웅 · 전설 · 유니크 동료', "setTab(null);S.pgFull=1;S.helpSeen=Object.assign(S.helpSeen||{},{cardgr:1});helpOpen.cardgr=false;ptTab='card';partySig='';setTab('pt');renderAll()"),
    ('폐허가 된 마을을 다시 세워요', '밭 · 식당 · 시장 · 피트의 가게', "setTab(null);S.pgFull=0;setTab('vl')"),
    ('대륙 지도의 어둠을 걷어 내요', '성주와 군단장을 쓰러뜨리고 영지 탈환', "setTab(null);setTab('mp')"),
    ('시련의 탑과 요일 던전', '층마다 보스 · 10층마다 황금 이삭', "setTab(null);chSheet()"),
    ('매일 출석하면 선물이 가득', '7일 판 · 한달 판 · 전설 만능 카드', "setTab(null);attSheet('m')"),
    ('결제도 광고도 없는 완전 무료', '이삭 · 동료 카드 · 장비 모두 플레이로 모아요', "setTab(null);setTab('eq')"),
]


def save_data():
    d = json.load(open(os.path.join(ROOT, 'app/test/fixtures/web_parity.json'), encoding='utf-8'))
    s = d['saves']['late']
    s.update({
        'started': True, 'pfSeen': 1, 'nick': '에르단영주', 'gem': 2480, 'retires': 6, 'memory': 40,
        'bld': {'inn': 10, 'farm': 6, 'diner': 10, 'dock': 10, 'apiary': 9, 'mine': 10, 'forge': 6, 'market': 7, 'ranch': 5, 'chapel': 6},
        'chOpen': 1, 'tower': {'top': 27, 'day': '', 'pk': 0},
        'last': 0, 'speed': 2,
    })
    return s


async def shoot(pg, js):
    await pg.evaluate("for(let i=0;i<10;i++){if(!$('modal').hidden)closeModal()}")
    await pg.evaluate(js)
    await pg.wait_for_timeout(1400)
    return await pg.screenshot()


def frame_html(png, big, small, w, h):
    b64 = base64.b64encode(png).decode()
    bg = 'file://' + os.path.join(ROOT, 'assets/illust/illust_title.jpg')
    font = 'file://' + os.path.join(ROOT, 'assets/fonts/hahmlet-700.woff2')
    font2 = 'file://' + os.path.join(ROOT, 'assets/fonts/plexkr-600.woff2')
    # 360 기준 CSS 크기로 짜고 deviceScaleFactor 로 키움 (w/360 배)
    cw, ch = 360, h * 360 / w
    shot_w = 290
    shot_h = shot_w * 640 / 360
    top = ch - shot_h - 14
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{{font-family:H;src:url({font})}}@font-face{{font-family:P;src:url({font2})}}
html,body{{margin:0;width:{cw}px;height:{ch}px;overflow:hidden;background:#0d1220}}
.bg{{position:absolute;inset:-20px;background:url({bg}) center/cover;filter:blur(8px) brightness(.55)}}
.t{{position:absolute;left:0;right:0;top:{max(26, (top - 70) / 2)}px;text-align:center;color:#ffd34a;font:700 27px/1.25 H;text-shadow:0 2px 6px #000}}
.s{{display:block;margin-top:8px;color:#fff;font:600 14px/1.4 P}}
.f{{position:absolute;left:{(cw - shot_w) / 2}px;top:{top}px;width:{shot_w}px;height:{shot_h}px;border:3px solid #e2b24a;border-radius:18px;overflow:hidden;box-shadow:0 8px 24px #000a}}
.f img{{width:100%;height:100%;display:block}}
</style></head><body><div class="bg"></div><div class="t">{big}<span class="s">{small}</span></div>
<div class="f"><img src="data:image/png;base64,{b64}"></div></body></html>'''


async def main():
    os.chdir(ROOT)
    save = save_data()
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={'width': 360, 'height': 640}, device_scale_factor=3)
        errs = []
        pg.on('pageerror', lambda e: errs.append(str(e)))
        # 페이지가 뜨기 전에 저장을 넣음 (다시 읽기 때 게임이 지금 저장으로 덮어쓰는 것을 피함)
        await pg.add_init_script('(()=>{if(sessionStorage.getItem("shot"))return;sessionStorage.setItem("shot","1");localStorage.clear();const s=%s;s.last=Date.now();localStorage.setItem("acorn-idle-v1",JSON.stringify(s))})()' % json.dumps(save, ensure_ascii=False))
        await pg.goto(URL)
        await pg.wait_for_timeout(1200)
        if await pg.locator('#startBtn').is_visible():
            await pg.click('#startBtn')
        await pg.wait_for_timeout(1500)
        await pg.evaluate("window.queue=f=>{};for(let i=0;i<10;i++){if(!$('modal').hidden)closeModal()}")
        # 전투가 조금 진행된 화면
        await pg.wait_for_timeout(4000)
        shots = []
        for big, small, js in SCENES:
            shots.append(await shoot(pg, js))
        for k, (d, w, h, name) in OUT.items():
            os.makedirs(d, exist_ok=True)
            fp = await b.new_page(viewport={'width': 360, 'height': int(round(h * 360 / w))}, device_scale_factor=w / 360)
            for i, (png, (big, small, _)) in enumerate(zip(shots, SCENES), 1):
                await fp.set_content(frame_html(png, big, small, w, h))
                await fp.wait_for_timeout(300)
                path = os.path.join(d, name.format(i))
                await fp.screenshot(path=path, clip={'x': 0, 'y': 0, 'width': 360, 'height': h * 360 / w})
                im = Image.open(path)
                if im.size != (w, h):
                    im.convert('RGB').resize((w, h), Image.LANCZOS).save(path)
            await fp.close()
        print('오류' if errs else '오류 없음', errs[:3])
        await b.close()


if __name__ == '__main__':
    asyncio.run(main())
    sys.exit(0)
