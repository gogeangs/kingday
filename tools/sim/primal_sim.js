/* 첫 「태초」까지 걸리는 시간 (docs/content/FIRST_DAY.md 3-4). tools/primal_sim.py 가 안(案)마다 primalP 를 바꾼 사본을 띄워 실행.
   처음 온 사람 흉내(리뷰 2회차와 같은 방법): 자동 전투, 골드가 상자값 3배를 넘으면 상자(1초에 2번까지 누름),
   25초마다(할 일 한 번) 가장 싼 단련·동료 레벨 5번까지, 8분 뒤 한 번 껐다 켬(다음 날: 방치 최대 시간분 + 출석 1시간분 골드),
   영지 20 넘어 10분 동안 그 회차 최고 영지가 안 오르면 은퇴. HOURS 시간(플레이 시간)까지. */
(()=>{const out={};window.toast=()=>{};window.queue=()=>{};window.renderAll=()=>{};window.say=()=>{};window.scene=()=>{};window.haptic=()=>{};
 const fresh0=fresh();Object.keys(S).forEach(k=>delete S[k]);Object.assign(S,fresh0,{started:true,done:{pete:true},speed:1});for(const id in P)delete P[id];mons=[];syncParty();
 let t=0,acc=0,uacc=0,hi=1,lastBest=1,lastBestT=0,off=false;const dt=0.05;const ev=[];
 const ri=rollItem;window.rollItem=fg=>{const it=ri(fg);if(it&&it.g===6&&out.first==null){out.first=Math.round(t);out.firstLv=S.boxLv;out.firstBest=S.best;out.firstRet=S.retires||0}if(it&&it.g===6)out.n=(out.n||0)+1;return it};
 const opts=()=>{const o=[];for(const id of members())if(id!=='kael')o.push([compCost(S.lv[id]),()=>{S.gold-=compCost(S.lv[id]);S.lv[id]++}]);
  for(const u of UPG){const l=S.up[u.k];if(l<u.max)o.push([u.cost(l),()=>{S.gold-=u.cost(l);S.up[u.k]++}])}return o};
 while(t<HOURS*3600){step(dt);t+=dt;acc+=dt;uacc+=dt;
  if(!off&&t>=480){off=true;const g=idleGold(offCapH()*3600+3600);out.offGold=Math.round(g);S.gold+=g}
  if(acc>=1){acc=0;for(let k=0;k<2&&S.gold>=boxCost()*3;k++)openBox(true)}
  if(uacc>=25){uacc=0;for(let k=0;k<5;k++){const o=opts().sort((a,b)=>a[0]-b[0])[0];if(!o||S.gold<o[0])break;o[1]()}}
  if(S.best===51&&out.t50==null)out.t50=Math.round(t);
  if(S.stage>hi){hi=S.stage;lastBestT=t}
  if(S.best>=21&&t-lastBestT>600&&retCan()){if(out.ret==null){out.ret=Math.round(t);out.retBest=S.best;out.retLv=S.boxLv}ev.push([Math.round(t),'retire',S.best]);retire(retirePts(),false);hi=S.stage;lastBestT=t}
 }
 out.end={t:Math.round(t),best:S.best,boxLv:S.boxLv,retires:S.retires||0,eqG:Object.values(S.eq).filter(Boolean).map(i=>i.g)};out.ev=ev.slice(0,6);return out})()
