(async()=>{Object.assign(BAL,TUNE.bal||{});if(TUNE.star)DUN_STAR.splice(0,3,...TUNE.star);Object.assign(DUNB,TUNE.dun||{});
 window.toast=()=>{};window.queue=()=>{};window.say=()=>{};window.scene=()=>{};const ra=renderAll;window.renderAll=()=>{};
 const fresh0=fresh();Object.keys(S).forEach(k=>delete S[k]);Object.assign(S,fresh0,{started:true,done:{pete:true,capRoad:true,cap56:true,cap57:true},speed:1,memory:0,retires:0,chOpen:1});for(const id in P)delete P[id];mons=[];syncParty();
 const dt=0.05,out={runs:[]};
 const opts=()=>{const o=[];for(const id of members())if(id!=='kael')o.push([compCost(S.lv[id]),()=>{S.gold-=compCost(S.lv[id]);S.lv[id]++}]);
  for(const u of UPG){const l=S.up[u.k];if(l<u.max)o.push([u.cost(l),()=>{S.gold-=u.cost(l);S.up[u.k]++}])}
  o.push([boxCost()*1.0,()=>openBox(true)]);return o};
 /* 한 회차: 막힐 때까지(같은 영지 STUCK초) 또는 STOP 영지 도달 또는 HOURS */
 function grind(stop){let t=0,acc=0,lastSt=S.stage,stT=0;
  while(t<HOURS*3600&&S.stage<=MAXLAND&&S.stage<stop){step(dt);t+=dt;acc+=dt;
   if(acc>=1){acc=0;for(let k=0;k<30;k++){const o=opts().sort((a,b)=>a[0]-b[0])[0];if(!o||S.gold<o[0])break;o[1]()}}
   if(S.stage!==lastSt){lastSt=S.stage;stT=t}else if(t-stT>STUCK)break}
  return Math.round(t/60)}
 function fightUntil(cond,max){let t=0;while(t<max&&!cond()){step(dt);t+=dt}return t}
 function tower(){const keep=[S.stage,S.wave];let f=1,tries=0;
  while(f<400){towerStart(f);fightUntil(()=>CH.st!=='fight',70);const st=CH.st;chExit(true);
   if(st==='win'){f++;tries=0}else if(++tries>=2)break}
  S.stage=keep[0];S.wave=keep[1];S.tower.top=0;return f-1}
 function dun(n){const keep=[S.stage,S.wave],ks=[];for(let i=0;i<n;i++){S.dun.d=today();S.dun.used=0;dunEnter('mine');fightUntil(()=>!CH,200);ks.push(window.__lastKills)}S.stage=keep[0];S.wave=keep[1];return ks}
 const de=dunEnd;window.dunEnd=()=>{if(CH)window.__lastKills=CH.kills;return de()};S.dun.seen={mine:1,field:1,vault:1};
 for(let r=0;r<=RET;r++){const mins=grind(r===RET?FINAL:999);const st=S.stage,best=S.best,top=tower(),ks=dun(DUNN),L=dunL();
  const c3=ks.filter(k=>k>=DUN_STAR[2]).length/ks.length,vars=[];
  for(const v of (TUNE.dvar||[])){const k0=Object.assign({},DUNB);Object.assign(DUNB,v);const kv=dun(DUNN);Object.assign(DUNB,k0);vars.push([JSON.stringify(v),kv.sort((a,b)=>a-b)])}
  out.runs.push({ret:S.retires,mem:S.memory,mins,stage:st,best,tower:top,dunL:L,ms:dunMs(),kills:ks.sort((a,b)=>a-b),star3:Math.round(c3*100),vars});
  if(r<RET){const p=retirePts();retire(p)}}
 window.renderAll=ra;return out})()
