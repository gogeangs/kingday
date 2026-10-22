(()=>{Object.assign(BAL,TUNE);const out=[];window.toast=()=>{};window.queue=()=>{};window.renderAll=()=>{};window.say=()=>{};
 const rf=resetFight;let wipes=0,timeouts=0;window.resetFight=m=>{if(m.includes('가호'))wipes++;else timeouts++;return rf(m)};
 const fresh0=fresh();Object.keys(S).forEach(k=>delete S[k]);Object.assign(S,fresh0,{started:true,done:{pete:true,capRoad:true,cap56:true,cap57:true},speed:1,memory:MEM,retires:RET});for(const id in P)delete P[id];mons=[];syncParty();
 let t=0,lastSt=1,stT=0,dt=0.05,acc=0;const rec=[];
 const opts=()=>{const o=[];for(const id of members())if(id!=='kael')o.push([compCost(S.lv[id]),()=>{S.gold-=compCost(S.lv[id]);S.lv[id]++}]);
  for(const u of UPG){const l=S.up[u.k];if(l<u.max)o.push([u.cost(l),()=>{S.gold-=u.cost(l);S.up[u.k]++}])}
  o.push([boxCost()*1.0,()=>openBox(true)]);return o};
 while(t<HOURS*3600&&S.stage<=MAXLAND){step(dt);t+=dt;acc+=dt;
  if(acc>=1){acc=0;for(let k=0;k<30;k++){const o=opts().sort((a,b)=>a[0]-b[0])[0];if(!o||S.gold<o[0])break;o[1]()}}
  if(S.stage!==lastSt){rec.push([lastSt,Math.round(t-stT),wipes,timeouts]);wipes=0;timeouts=0;stT=t;lastSt=S.stage}}
 const kael=stats('kael');return{t:Math.round(t),stage:S.stage,rec,last:[Math.round(t-stT),wipes,timeouts],lv:S.lv,up:S.up,gearG:Object.values(S.eq).map(i=>i.g),kael:[Math.round(kael.atk),Math.round(kael.hp)],bron:S.joined.bron?[Math.round(stats('bron').atk),Math.round(stats('bron').hp)]:null,mon:[Math.round(monHp(S.stage,false)),Math.round(monAtk(S.stage,false))]}})()
