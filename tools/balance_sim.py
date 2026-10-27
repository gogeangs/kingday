"""밸런스 시뮬레이션: 처음부터 자동 전투 + 욕심쟁이 소비(가장 싼 것부터 레벨업·단련·상자)로
영지마다 걸린 시간을 잰다. 로컬 서버(python3 -m http.server 8765)를 켠 뒤 저장소 루트에서 실행.

    python3 tools/balance_sim.py 3 '{"hpG":1.2}'   # 3시간, BAL 값 덮어쓰기
    python3 tools/balance_sim.py village            # 마을 확장 밸런스 ①~④ (docs/content/VILLAGE.md 8장)
    python3 tools/balance_sim.py pass               # 원정 일지 점수: 하루 2~3번 접속 유저 · 출석만 하는 유저 (docs/content/SHOP.md 8장)
    python3 tools/balance_sim.py bond               # 원정대의 정: 하루 10시간 쌓이는 유저의 ♥3·♥5 도달일 · 같은 직업 짝 (docs/content/BOND.md 8장)
    python3 tools/balance_sim.py p2 4 50 8 '{"hpG2":1.1}' 30 1   # 2부 엘프(61~70): 1부 엔딩까지(최대 4시간, 추억 50·은퇴 8 + 1부 끝 무렵 마을 = 60을 겨우 깨는 유저) → 출퇴근 방치러가 61~71에 닿는 날 (PART2.md 8장)
"""
import asyncio,sys,json
from playwright.async_api import async_playwright
SP='tools/sim';H=sys.argv[1] if len(sys.argv)>1 else '3';TUNE=sys.argv[2] if len(sys.argv)>2 else '{}'
async def main():
  async with async_playwright() as p:
    b=await p.chromium.launch();pg=await b.new_page(viewport={'width':390,'height':844})
    await pg.goto('http://localhost:8765/index.html');await pg.evaluate("localStorage.clear()");await pg.reload();await pg.wait_for_timeout(800)
    await pg.click('#startBtn');await pg.wait_for_timeout(300)
    if H=='p2':
      A=sys.argv[2:]
      hrs=A[0] if len(A)>0 else '4';mem=A[1] if len(A)>1 else '50';ret=A[2] if len(A)>2 else '8';tune=A[3] if len(A)>3 else '{}';days=A[4] if len(A)>4 else '30';vil=A[5] if len(A)>5 else '1'
      js=open(SP+'/part2_sim.js').read().replace('HOURS',hrs).replace('TUNE',tune).replace('MEM',mem).replace('RET',ret).replace('DAYS',days).replace('VIL',vil)
      r=await pg.evaluate(js)
      print('추억',mem,'은퇴',ret,'마을',vil,tune,'| 1부 엔딩까지',r['hoursToEnding'],'시간',('' if r['ending'] else '(엔딩 못 봄)'))
      print('출퇴근 방치러 (하루 3번 · 5분) 처음 닿은 날:',' '.join(f"{k}:{v}일" for k,v in sorted(r['days'].items(),key=lambda x:int(x[0]))))
      print('은퇴(며칠째, 영지, 추억):',r['retires'],'| 추억',r['memory'][0],'→',r['memory'][1],'| 끝 영지',r['stage'],'최고',r['best'],'세션',r['sessions'],'| 2부 실패(전멸, 시간 초과)',r['fails'])
      print('61 몬스터 체력',r['mon'][0],'· 70 장수 체력',r['mon'][1])
      await b.close();return
    if H=='village':
      r=await pg.evaluate(open(SP+'/village_sim.js').read())
      print(json.dumps(r,ensure_ascii=False,indent=1));await b.close();return
    if H=='bond':
      r=await pg.evaluate(open(SP+'/bond_sim.js').read())
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
