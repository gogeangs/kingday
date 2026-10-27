// 2부 엘프 왕국(61~70) 시간 재기 — tools/balance_sim.py p2 가 브라우저에서 실행 (docs/content/PART2.md 8장)
// ① 1부 엔딩까지: CAPITAL.md 10장의 「처음 60을 깨는 유저」(추억 MEM·은퇴 RET, 욕심쟁이 소비)로 쉬지 않고 사냥해 60 알현실을 깸
// ② 1부 엔딩 직후부터 「출퇴근 방치러」(docs/PLAYER_PLANNING.md 3장): 하루 3번(간격 9·10·5시간) 들어와
//    방치 보상(여관 최대 시간까지)을 받아 다 쓰고 5분 사냥. 이번 회차가 최고 영지 앞(벽)까지 와서 하루 동안 못 나가면 그날 마지막에 은퇴(1부와 같은 성장 방법)
//    → 영지 61~71 에 처음 닿은 날(며칠째)을 잰다.
// 넣지 않은 것(실제보다 느림): 은퇴 일기 특성(지름길 등)·카드·모집 동료·할 일·출석 이삭·(VIL=0이면) 마을 건물. 여관 Lv.8(방치 최대 14시간)
(()=>{Object.assign(BAL,TUNE);window.toast=()=>{};window.queue=()=>{};window.renderAll=()=>{};window.say=()=>{};window.rpAdd=()=>{};window.rpFlush=()=>{};
 const rf=resetFight;let wipes=0,timeouts=0;window.resetFight=m=>{if(m.includes('가호'))wipes++;else timeouts++;return rf(m)};
 const fresh0=fresh();Object.keys(S).forEach(k=>delete S[k]);Object.assign(S,fresh0,{started:true,done:{pete:true,capRoad:true,cap56:true,cap57:true},speed:1,memory:MEM,retires:RET,ending1:1,p2Intro:1});
 S.bld.inn=8;
 /* VIL=1: 1부 끝 무렵 흔한 마을(웹·앱 비교 시험 late 저장과 같은 건물 레벨) — 식당 체력·양봉장 동료 공격·광산 장비 배수 */
 if(VIL)Object.assign(S.bld,{inn:10,farm:6,diner:10,dock:10,apiary:9,mine:10});
 for(const id in P)delete P[id];mons=[];syncParty();
 const opts=()=>{const o=[];for(const id of members())if(id!=='kael')o.push([compCost(S.lv[id]||1),()=>{S.gold-=compCost(S.lv[id]||1);S.lv[id]=(S.lv[id]||1)+1}]);
  for(const u of UPG){const l=S.up[u.k];if(l<u.max)o.push([u.cost(l),()=>{S.gold-=u.cost(l);S.up[u.k]++}])}
  o.push([boxCost()*1.0,()=>openBox(true)]);return o};
 const spend=()=>{for(let k=0;k<400;k++){const o=opts().sort((a,b)=>a[0]-b[0])[0];if(!o||S.gold<o[0])break;o[1]()}};
 let t=0,acc=0;
 while(t<HOURS*3600&&S.stage<=MAXLAND){step(0.05);t+=0.05;acc+=0.05;if(acc>=1){acc=0;spend()}}
 const tA=Math.round(t/360)/10,okA=S.stage>MAXLAND,mem0=S.memory;wipes=0;timeouts=0;
 const gaps=[9,10,5],ses=300,day={},rets=[];let k=0,bestDay=S.best;
 while(okA&&k<DAYS*3&&S.best<=LAND){
  S.gold+=idleGold(Math.min(gaps[k%3],offCapH())*3600);spend();
  for(let s=0;s<ses;s+=0.05){step(0.05);acc+=0.05;if(acc>=1){acc=0;spend()}}
  k++;
  for(let st=MAXLAND+1;st<=Math.min(S.best,LAND+1);st++)if(day[st]==null)day[st]=Math.round(k/3*10)/10;
  /* 은퇴: 이번 회차가 최고 영지 앞까지 다시 와서(벽) 하루 동안 더 못 나갔을 때만 */
  if(k%3===0){if(S.best<=bestDay&&S.stage>=S.best-1&&retCan()){const p=retirePts();rets.push([Math.round(k/3),S.stage,p]);retire(p,false);syncParty()}bestDay=S.best}
 }
 return{hoursToEnding:tA,ending:okA,stage:S.stage,best:S.best,days:day,sessions:k,retires:rets,memory:[mem0,S.memory],fails:[wipes,timeouts],mon:[Math.round(monHp(61,false)),Math.round(monHp(70,true))]}})()
