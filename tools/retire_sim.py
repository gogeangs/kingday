"""은퇴 일기(특성·지름길) 밸런스 확인 (docs/content/RETIRE.md 3·8장).
① 은퇴 N회 유저의 한 회차(시작 영지 → 61) 걸린 시간: 특성 없음(지금) vs 특성 있음(새 규칙)
② 지름길 + 추억 보정이 「건너뛰고 바로 은퇴」 반복 이득을 막는지: 시간당 추억
로컬 서버(python3 -m http.server 8765)를 켠 뒤 저장소 루트에서:

    python3 tools/retire_sim.py 5,10,25          # 은퇴 5·10·25회 유저
    python3 tools/retire_sim.py 25 '{}' 12       # BAL 덮어쓰기, 한 판 최대 12시간
    python3 tools/retire_sim.py 10,25 '{}' 12 10  # 처음 기획안(건너뛴 구간 절반)과 비교
"""
import asyncio,sys,json,math
from playwright.async_api import async_playwright
HOURS=float(sys.argv[3]) if len(sys.argv)>3 else 12
DIV=int(sys.argv[4]) if len(sys.argv)>4 else 5  # 보정: 건너뛴 구간 추억을 뺄 때 나누는 수 (5 = 다 뺌, 10 = 절반, 처음 기획안)
NS=[int(x) for x in (sys.argv[1] if len(sys.argv)>1 else '5,10,25').split(',')];TUNE=sys.argv[2] if len(sys.argv)>2 else '{}'
CAP_MEM=3
# 웹 MEMT 와 같은 비용표 (찍는 순서: 싼 것부터, 같으면 이 순서)
T={'sharp':(1,[1,1,2,2,3,3,4,4]),'hat':(1,[1,1,2,2,3,3,4,4]),'shortcut':(1,[2,2,2,3,3,3,4,4,5,5]),'purse':(1,[1,1,2,2,3]),
   'critd':(2,[2,2,3,3,4]),'stubborn':(2,[3,4,5]),'knack':(2,[2,2,3,3,4]),'inn':(2,[2,3,3,4]),
   'climb':(3,[2,3,3,4,4]),'stretch':(3,[4,5,6]),'memoir':(3,[4,6,8]),'goblin':(3,[3,4,5]),
   'soil':(1,[1,1,2,2,3,3]),'hands':(1,[1,1,2,2,3,3,4,4]),'carpenter':(2,[1,1,2,2,3,3]),'seedbag':(2,[2,3,4]),'stew':(3,[2,3,3,4,4]),'bumper':(3,[3,4,5,6])}
BR={'sharp':'s','hat':'s','critd':'s','stubborn':'s','stretch':'s','climb':'s','soil':'f','hands':'f','carpenter':'f','seedbag':'f','stew':'f','bumper':'f','purse':'t','shortcut':'t','inn':'t','knack':'t','memoir':'t','goblin':'t'}
ROW=[0,0,10,30]
def spent(tr,b=None):return sum(sum(T[k][1][:l]) for k,l in tr.items() if b is None or BR[k]==b)
def allocate(pts):
  """전투·여행 갈래 먼저(밭 갈래는 전투 시간에 영향 없음), 싼 단계부터 찍기"""
  tr={k:0 for k in T};order=[k for k in T if BR[k]!='f']+[k for k in T if BR[k]=='f']
  while True:
    left=pts-spent(tr);best=None
    for k in order:
      r,c=T[k];l=tr[k]
      if l>=len(c) or spent(tr,BR[k])<ROW[r] or c[l]>left:continue
      if best is None or c[l]<T[best][1][tr[best]]:best=k
    if best is None:return {k:v for k,v in tr.items() if v}
    tr[best]+=1
def start_of(tr,best=61):return max(1,min(1+5*tr.get('shortcut',0),best//2))
def pts_of(stage,start,tr):
  b=max(0,(stage-10)//5-max(0,start-10)//DIV);m=tr.get('memoir',0);return math.ceil(b*(1+.1*m)) if m else b
def memory_after(n,new=True):
  """은퇴 n번(매번 61까지 + 왕도 보너스) 뒤의 추억. new=False 는 지금 규칙"""
  mem=0
  for _ in range(n):
    if new:tr=allocate(mem);s=start_of(tr);mem+=pts_of(61,s,tr)+CAP_MEM
    else:mem+=(61-10)//5+CAP_MEM
  return mem
async def run(pg,mem,ret,tr,start,hours=HOURS):
  js=open('tools/sim/retire_sim.js').read().replace('HOURS',str(hours)).replace('TUNE',TUNE).replace('MEM',str(mem)).replace('RET',str(ret)).replace('TRAIT',json.dumps(tr)).replace('START',str(start))
  r=await pg.evaluate(js);at={};tot=0
  for st,tt,w,to,nx in r['rec']:
    tot+=tt
    if nx>st and nx not in at:at[nx]=tot
  return r,at
async def main():
  async with async_playwright() as p:
    b=await p.chromium.launch();pg=await b.new_page(viewport={'width':390,'height':844})
    await pg.goto('http://localhost:8765/index.html');await pg.evaluate("localStorage.clear()");await pg.reload();await pg.wait_for_timeout(800)
    await pg.click('#startBtn');await pg.wait_for_timeout(300)
    for n in NS:
      m0=memory_after(n,False);m1=memory_after(n,True);tr=allocate(m1);s=start_of(tr)
      r0,a0=await run(pg,m0,n,{},1);r1,a1=await run(pg,m1,n,tr,s)
      h0=a0.get(61);h1=a1.get(61)
      print(f'은퇴 {n}회 | 지금: 추억 {m0} · 영지 1→61 {h0/3600 if h0 else "미도달"}{"시간" if h0 else ""} | 새 규칙: 추억 {m1} · 특성 {spent(tr)}P {tr} · 영지 {s}→61 {h1/3600 if h1 else "미도달"}{"시간" if h1 else ""}')
      print('   새 규칙 도달(시간):',' '.join(f'{k}:{v/3600:.2f}' for k,v in sorted(a1.items()) if k%10==1 or k==61),'| 막힘',r1['stage'],r1['last'])
      # ② 반복 이득: 시작 영지에서 E까지 가서 은퇴 → 시간당 추억 (왕도 보너스 제외)
      rows=[]
      for E in sorted({s+10,s+15,s+20,40,50,61}):
        if E<20 or E<s+10 or E>61 or E not in a1:continue
        pts=pts_of(E,s,tr);hh=a1[E]/3600;rows.append((E,pts,round(hh,2),round(pts/hh,1) if hh else 0))
      t1={E:a1[E] for E in a1}
      rows1=[]
      for E in [20,30,40,50,61]:
        if E in a0:pts=pts_of(E,1,tr);hh=a0[E]/3600;rows1.append((E,pts,round(hh,2),round(pts/hh,1) if hh else 0))
      print('   지름길 시작 → E에서 은퇴 (E, 추억, 시간, 시간당):',rows)
      print('   (참고) 지금 규칙 1부터 → E (E, 추억(회고록 포함), 시간, 시간당):',rows1)
    await b.close()
asyncio.run(main())
