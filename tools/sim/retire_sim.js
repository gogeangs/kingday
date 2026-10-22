(()=>{Object.assign(BAL,TUNE);window.toast=()=>{};window.queue=()=>{};window.renderAll=()=>{};window.say=()=>{};
 /* 은퇴한 유저의 한 회차: 추억 MEM·특성 TRAIT·시작 영지 START 에서 61(왕궁 뜰)까지 자동 전투 + 욕심쟁이 소비 */
 const rf=resetFight;let wipes=0,timeouts=0;window.resetFight=m=>{if(m.includes('가호'))wipes++;else timeouts++;return rf(m)};
 const fresh0=fresh();Object.keys(S).forEach(k=>delete S[k]);
 const ids=EVENTS.map(e=>e.id),done={pete:true,capRoad:true,cap56:true,cap57:true};ids.forEach(i=>done[i]=true);
 Object.assign(S,fresh0,{started:true,done,joined:{margo:true,haral:true,riel:true,bron:true},speed:1,memory:MEM,retires:RET,trait:TRAIT,best:61,capClears:1});
 const st=START;S.stage=st;S.runStart=st;S.gold=60+retPurse(st);for(const id in P)delete P[id];mons=[];syncParty();
 let t=0,lastSt=st,stT=0,dt=0.05,acc=0;const rec=[];
 const opts=()=>{const o=[];for(const id of members())if(id!=='kael')o.push([compCost(S.lv[id]),()=>{S.gold-=compCost(S.lv[id]);S.lv[id]++}]);
  for(const u of UPG){const l=S.up[u.k];if(l<u.max)o.push([u.cost(l),()=>{S.gold-=u.cost(l);S.up[u.k]++}])}
  o.push([boxCost()*1.0,()=>openBox(true)]);return o};
 while(t<HOURS*3600&&S.stage<=MAXLAND){step(dt);t+=dt;acc+=dt;
  if(acc>=1){acc=0;for(let k=0;k<30;k++){const o=opts().sort((a,b)=>a[0]-b[0])[0];if(!o||S.gold<o[0])break;o[1]()}}
  if(S.stage!==lastSt){rec.push([lastSt,Math.round(t-stT),wipes,timeouts,S.stage]);wipes=0;timeouts=0;stT=t;lastSt=S.stage}}
 return{t:Math.round(t),stage:S.stage,rec,last:[Math.round(t-stT),wipes,timeouts]}})()
