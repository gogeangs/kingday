"""왕도(51~60) 난이도 확인: 처음부터 자동 전투 + 욕심쟁이 소비로 60 알현실까지 걸린 시간을 잰다.
은퇴의 추억(MEM)·은퇴 횟수(RET)를 넣어 「은퇴 2~3회 유저」를 흉내 낸다. 로컬 서버(python3 -m http.server 8765)를 켠 뒤 저장소 루트에서:

    python3 tools/capital_sim.py 40 20 3 '{"demHp":24}'   # 최대 40시간, 추억 20개, 은퇴 3번, BAL 덮어쓰기
"""
import asyncio,sys,json
from playwright.async_api import async_playwright
H=sys.argv[1] if len(sys.argv)>1 else '40';MEM=sys.argv[2] if len(sys.argv)>2 else '20';RET=sys.argv[3] if len(sys.argv)>3 else '3';TUNE=sys.argv[4] if len(sys.argv)>4 else '{}'
async def main():
  async with async_playwright() as p:
    b=await p.chromium.launch();pg=await b.new_page(viewport={'width':390,'height':844})
    await pg.goto('http://localhost:8765/index.html');await pg.evaluate("localStorage.clear()");await pg.reload();await pg.wait_for_timeout(800)
    await pg.click('#startBtn');await pg.wait_for_timeout(300)
    js=open('tools/sim/capital_sim.js').read().replace('HOURS',H).replace('TUNE',TUNE).replace('MEM',MEM).replace('RET',RET)
    r=await pg.evaluate(js)
    rec=r.pop('rec');tot=0;at={}
    for st,tt,w,to in rec:
      tot+=tt;at[st]=tot
    t50=at.get(49,0)+[x for x in rec if x[0]==50][0][1] if any(x[0]==50 for x in rec) else None
    print('MEM',MEM,'RET',RET,TUNE)
    print('도달 시간(시간):',' '.join(f'{s}:{at[s]/3600:.1f}' for s in sorted(at) if s%5==0 or s>=50))
    cap=[(a,round(b/60),c,d) for a,b,c,d in rec if a>50]
    print('왕도 영지별(분, 전멸, 시간초과):',cap[:12],'…' if len(cap)>12 else '')
    print('끝',r['stage'],'막힘',r['last'])
    await b.close()
asyncio.run(main())
