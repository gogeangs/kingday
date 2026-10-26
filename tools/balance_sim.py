"""밸런스 시뮬레이션: 처음부터 자동 전투 + 욕심쟁이 소비(가장 싼 것부터 레벨업·단련·상자)로
영지마다 걸린 시간을 잰다. 로컬 서버(python3 -m http.server 8765)를 켠 뒤 저장소 루트에서 실행.

    python3 tools/balance_sim.py 3 '{"hpG":1.2}'   # 3시간, BAL 값 덮어쓰기
    python3 tools/balance_sim.py village            # 마을 확장 밸런스 ①~④ (docs/content/VILLAGE.md 8장)
    python3 tools/balance_sim.py pass               # 원정 일지 점수: 하루 2~3번 접속 유저 · 출석만 하는 유저 (docs/content/SHOP.md 8장)
"""
import asyncio,sys,json
from playwright.async_api import async_playwright
SP='tools/sim';H=sys.argv[1] if len(sys.argv)>1 else '3';TUNE=sys.argv[2] if len(sys.argv)>2 else '{}'
async def main():
  async with async_playwright() as p:
    b=await p.chromium.launch();pg=await b.new_page(viewport={'width':390,'height':844})
    await pg.goto('http://localhost:8765/index.html');await pg.evaluate("localStorage.clear()");await pg.reload();await pg.wait_for_timeout(800)
    await pg.click('#startBtn');await pg.wait_for_timeout(300)
    if H=='village':
      r=await pg.evaluate(open(SP+'/village_sim.js').read())
      print(json.dumps(r,ensure_ascii=False,indent=1));await b.close();return
    if H=='pass':
      r=await pg.evaluate(open(SP+'/pass_sim.js').read())
      for who,v in r.items():
        print(who,'| 20단계 끝낸 날',v['done20'],'| 14일째',v['lv14'],'단계',v['pt14'],'점')
        for d in v['days']: print('  ',d)
      await b.close();return
    js=open(SP+'/balance_sim.js').read().replace('HOURS',H).replace('TUNE',TUNE)
    r=await pg.evaluate(js)
    rec=r.pop('rec');tot=0;line=[]
    for st,tt,w,to in rec:
      tot+=tt
      if st%5==0: line.append(f'{st}:{tot//60}m')
    print('stages',[(a,b,c,d) for a,b,c,d in rec if 14<=a<=31]);print('slow',sorted(rec,key=lambda x:-x[1])[:8]);print(TUNE,'|',' '.join(line),'| end',r['stage'],'stuck',r['last'],'gear',r['gearG'],'lv',list(r['lv'].values()))
    await b.close()
asyncio.run(main())
