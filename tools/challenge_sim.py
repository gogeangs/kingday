"""도전(시련의 탑·요일 던전) 밸런스 확인. 로컬 서버(python3 -m http.server 8765)를 켠 뒤 저장소 루트에서:

    python3 tools/challenge_sim.py 6 5            # 회차당 최대 6시간, 은퇴 5번까지(0~5회 결과를 모두 보여 줌)
    python3 tools/challenge_sim.py 6 0 51         # 은퇴 없이 51(왕도)까지
    python3 tools/challenge_sim.py 6 2 99 '{"star":[40,80,120],"bal":{}}'

방법: 처음부터 자동 전투 + 욕심쟁이 소비(동료 레벨·단련·상자)로 한 회차를 같은 영지에서 20분 막힐 때까지 돌리고,
그 상태로 ① 탑을 1층부터(층마다 2번까지 도전) ② 그 단계 던전(폐광)을 여러 번 돌려 처치 수·★3 비율을 잰다.
막히면 은퇴(추억 +floor((영지-10)/5))하고 다음 회차. 마을·카드·모집 동료는 빠져서 실제 유저보다 조금 약하다.
"""
import asyncio,sys,json
from playwright.async_api import async_playwright
H=sys.argv[1] if len(sys.argv)>1 else '6';RET=sys.argv[2] if len(sys.argv)>2 else '0';FINAL=sys.argv[3] if len(sys.argv)>3 else '999';TUNE=sys.argv[4] if len(sys.argv)>4 else '{}'
STUCK=sys.argv[5] if len(sys.argv)>5 else '1200';DUNN=sys.argv[6] if len(sys.argv)>6 else '10'
async def main():
  async with async_playwright() as p:
    b=await p.chromium.launch();pg=await b.new_page(viewport={'width':390,'height':844})
    await pg.goto('http://localhost:8765/index.html');await pg.evaluate("localStorage.clear()");await pg.reload();await pg.wait_for_timeout(800)
    await pg.click('#startBtn');await pg.wait_for_timeout(300)
    js=open('tools/sim/challenge_sim.js').read().replace('HOURS',H).replace('TUNE',TUNE).replace('RET',RET).replace('FINAL',FINAL).replace('STUCK',STUCK).replace('DUNN',DUNN)
    r=await pg.evaluate(js)
    print('TUNE',TUNE)
    for x in r['runs']:
      for v,k in x.get('vars',[]):print('   변형',v,'처치',k)
      print(f"은퇴 {x['ret']}회 · 추억 {x['mem']} · {x['mins']}분 → 영지 {x['stage']} (최고 {x['best']}) | 탑 {x['tower']}층 | 던전 단계 {x['dunL']}(몬스터 {x['ms']}단계) 처치 {x['kills']} ★3 {x['star3']}%")
    await b.close()
asyncio.run(main())
