(async()=>{/* 마을 확장 밸런스 (docs/content/VILLAGE.md 8장 ①~④). 게임 함수를 그대로 써서 계산 */
 window.toast=()=>{};window.queue=()=>{};window.renderAll=()=>{};window.haptic=()=>{};
 const FX=(await (await fetch('app/test/fixtures/web_parity.json')).json()).saves;
 const PLAY=4;/* 하루에 게임을 켜 두는 시간(씨앗·사냥 골드) */const T0=Date.now();let NOW=T0;const realNow=Date.now;Date.now=()=>NOW;const td=window.today;window.today=()=>{const t=new Date(NOW);return t.getFullYear()+'-'+(t.getMonth()+1)+'-'+t.getDate()};
 const setS=(base,mod)=>{const d=JSON.parse(JSON.stringify(base));d.capClears=0;S=hydrate(d);Object.assign(S.bld,mod.bld||{});if(mod.best)S.best=S.stage=mod.best;S.work={};S.bless={d:'',used:0,ad:0,k:'',until:0,opts:[]};S.orders=[];S.ordDay={d:'',gem:0,skip:{}};for(const id in P)delete P[id];syncParty()};
 /* 일꾼을 꽉 채운 상태: 모든 동료 합류·별 최대, 출전은 이야기 동료 4명(일반) → 나머지 20명을 추천 일꾼으로 */
 const maxAll=()=>{S.rec=S.rec||{};for(const id of CARDIDS()){if(isRec(id))S.rec[id]=gr(id).max;else{S.joined[id]=true;S.rec[id]=gr(id).max}}S.party={miner:'bron',fisher:'haral',keeper:'riel',cook:'margo'};syncParty()};
 const res={};
 /* ① 주문 골드: 7일 동안 2시간마다 접속(하루 16시간 깨어 있음 → 8번), 재료는 계속 생산. 작물은 밭 칸을 세 작물이 나눠 계속 심는다고 봄 */
 function orderWeek(){S.orders=[];S.items=Object.fromEntries(Object.keys(S.items).map(k=>[k,0]));let gold=0,n=0,gem=0,skips=0;
  const rate={};for(const g of GOODS)if(S.bld[g.b])rate[g.k]=S.bld[g.b]*prodMul(g.b)*60/g.m;/* 시간당 */
  /* 작물은 씨앗이 있어야 함: 하루 PLAY시간 사냥하며 씨앗을 줍는다고 보고, 밭이 감당하는 양과 비교해 작은 쪽 */
  const dps=members().reduce((a,id)=>{const t=stats(id);return a+t.atk*t.aps*critE(t)},0),kph=3600/(monHp(fightSt(),false)/Math.max(1,dps)+1.2);let left=1;
  if(S.bld.farm)for(const c of[...CROPS].reverse()){const p=left*c.drop;left-=p;rate[c.k]=Math.min(plotCount()*2.3*3600/cropT(c)/3,kph*p*2.3*PLAY/24)}
  const H=24*7;for(let m=0;m<H*60;m++){NOW=T0+m*60000;for(const k in rate)S.items[k]=(S.items[k]||0)+rate[k]/60;
   const hr=Math.floor(m/60)%24;if(m%120===0&&hr>=8){ordTick();S.orders.forEach((o,i)=>{if(!o||!o.need)return;
     if(ordCan(o)){gold+=ordGold(o);const e=o.extra||{};if(e.k==='gem'){const d=ordDay(),gv=Math.min(Math.max(0,ORD_GEM-d.gem),e.n);d.gem+=gv;gem+=gv}for(const[k,v]of Object.entries(o.need))S.items[k]-=v;S.orders[i]={at:NOW+ORD_WAIT};n++}
     else{const need=Math.max(...Object.entries(o.need).map(([k,v])=>(v-(S.items[k]||0))/(rate[k]||1e-9)));if(need>6&&!ordDay().skip[i]){ordSkip(i);skips++}}})}}
  const hunt=goldRate()*3600,sell=Object.entries(rate).reduce((a,[k,r])=>a+r*itemPrice(k),0);
  const huntDay=hunt*PLAY+idleGold(Math.min(offCapH(),24-PLAY)*3600);
  return{ordersPerDay:+(n/7).toFixed(1),orderGoldH:Math.round(gold/H),huntGoldH:Math.round(hunt),ratio:+(gold/H/hunt).toFixed(3),dayRatio:+(gold/7/huntDay).toFixed(3),sellAllGoldH:Math.round(sell),gemPerDay:+(gem/7).toFixed(1),skips}}
 const SC=[['mid(영지25·시장1)',FX.mid,{bld:{market:1}}],['mid(영지25·시장5)',FX.mid,{bld:{market:5,dock:6,apiary:6,mine:6}}],['late(영지46·시장5)',FX.late,{bld:{market:5,ranch:5}}],['late(영지46·시장10)',FX.late,{bld:{market:10,ranch:10}}],['tr(영지61·시장10)',FX.tr,{bld:{market:10,ranch:10}}]];
 res.order={};for(const[nm,fx,mod]of SC){setS(fx,mod);const a=orderWeek();setS(fx,mod);wkAuto(false);const b=orderWeek();res.order[nm]={noWork:a,autoWork:b}}
 /* ② 마을 Lv.10(건물 레벨 합 80)까지: 공사는 한 번에 하나(대기 2) → 공사 시간 합이 바닥. 골드는 그때 사냥 골드 몇 시간치인지 */
 function toLv10(trB){const lv={},plan=[];for(const b of BLD)lv[b.k]=0;let sum=0,secs=0,gold=0,ore=0;
  while(sum<80){let best=null,bc=1e300;for(const b of BLD){const l=lv[b.k];if(l>=b.max)continue;const c=bldCost(b,l);if(c<bc){bc=c;best=b}}
   const l=lv[best.k];secs+=Math.min(12*3600,Math.round(60*Math.sqrt(best.base/120)*Math.pow(2,l)*(trB||1)));gold+=bldCost(best,l);ore+=l>=5&&best.k!=='mine'&&best.k!=='forge'?Math.ceil(15*Math.pow(1.5,l-5)):0;lv[best.k]++;sum++}
  return{days:+(secs/86400).toFixed(1),gold,ore}}
 setS(FX.late,{});res.lv10={noRetire:toLv10(1),carpenter6:toLv10(.7),huntGoldH_late:Math.round(goldRate()*3600),lateBldSum:bldSum(),lateVLv:vLv()};
 /* ③ 이삭: 하루 받는 이삭(할 일 50 + 광고 15 + 출석 평균) 대비 주문 이삭 */
 res.gem={missions:MISSIONS.reduce((a,m)=>a+m.r,0)+MIS_ALL,adGem:ADS.gem.n*5,orderCap:ORD_GEM,orderAvg:res.order['late(영지46·시장10)'].autoWork.gemPerDay,goldBag:'이삭 30 = 사냥 2시간'};
 /* ④ 일꾼 꽉 채움: 같은 상태에서 일꾼 없음 vs 추천 일꾼으로 20명 배치 */
 setS(FX.late,{bld:{market:10,ranch:10,chapel:10,forge:10,apiary:10}});maxAll();S.work={};const base={prod:{},idle:idleGold(3600),cut:forgeCut()};for(const b of['dock','apiary','mine','ranch'])base.prod[b]=prodMul(b);const ow=orderWeek();
 S.work={};wkAuto(false);const full={prod:{},idle:idleGold(3600),cut:forgeCut()};for(const b of['dock','apiary','mine','ranch'])full.prod[b]=prodMul(b);const ow3=orderWeek();
 res.workMax={work:JSON.stringify(S.work),prodX:Object.fromEntries(Object.keys(base.prod).map(b=>[b,+(full.prod[b]/base.prod[b]).toFixed(2)])),idleX:+(full.idle/base.idle).toFixed(3),forgeCut:[+base.cut.toFixed(2),+full.cut.toFixed(2)],orderRatio:[ow.ratio,ow3.ratio],orderGoldH:[ow.orderGoldH,ow3.orderGoldH],sellAllGoldH:[ow.sellAllGoldH,ow3.sellAllGoldH],huntGoldH:ow3.huntGoldH,
  bonus:Object.fromEntries(BLD.map(b=>[b.k,+wkReal(b.k,workBonus(b.k)).toFixed(2)]))};
 Date.now=realNow;window.today=td;return res})()
