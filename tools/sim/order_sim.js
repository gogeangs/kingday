(async()=>{/* 시장 주문 납품 횟수 — 루시안 합류 조건(누적 납품 N회) 정하기 (docs/PLAN_MONETIZATION_REMOVAL.md 2번)
   village_sim.js ① 과 같은 방식(게임 함수 ordTick·ordCan·ordSkip 그대로, 재료는 건물 생산량대로 쌓임)인데 접속을 하루 CHECKS 시각으로.
   시장·건물 레벨 단계별로 하루 몇 건 납품하는지 → 처음부터 누적 납품이 N회에 닿는 날 */
 window.toast=()=>{};window.queue=()=>{};window.renderAll=()=>{};window.haptic=()=>{};
 const FX=(await (await fetch('app/test/fixtures/web_parity.json')).json()).saves;
 const PLAY=1;const CHECKS=CHECKS_ARR;/* 하루 접속 시각(시) */
 const T0=Date.now();let NOW=T0;const realNow=Date.now;Date.now=()=>NOW;const td=window.today;window.today=()=>{const t=new Date(NOW);return t.getFullYear()+'-'+(t.getMonth()+1)+'-'+t.getDate()};
 const setS=(base,mod)=>{const d=JSON.parse(JSON.stringify(base));d.capClears=0;S=hydrate(d);Object.assign(S.bld,mod.bld||{});if(mod.best)S.best=S.stage=mod.best;S.work={};S.orders=[];S.ordDay={d:'',gem:0,skip:{}};for(const id in P)delete P[id];syncParty()};
 function orderWeek(){S.orders=[];S.items=Object.fromEntries(Object.keys(S.items).map(k=>[k,0]));let n=0;
  const rate={};for(const g of GOODS)if(S.bld[g.b])rate[g.k]=S.bld[g.b]*prodMul(g.b)*60/g.m;
  const dps=members().reduce((a,id)=>{const t=stats(id);return a+t.atk*t.aps*critE(t)},0),kph=3600/(monHp(fightSt(),false)/Math.max(1,dps)+1.2);let left=1;
  if(S.bld.farm)for(const c of[...CROPS].reverse()){const p=left*c.drop;left-=p;rate[c.k]=Math.min(plotCount()*2.3*3600/cropT(c)/3,kph*p*2.3*PLAY/24)}
  const H=24*7;for(let m=0;m<H*60;m++){NOW=T0+m*60000;for(const k in rate)S.items[k]=(S.items[k]||0)+rate[k]/60;
   const hr=Math.floor(m/60)%24;if(m%60===0&&CHECKS.includes(hr)){ordTick();S.orders.forEach((o,i)=>{if(!o||!o.need)return;
     if(ordCan(o)){for(const[k,v]of Object.entries(o.need))S.items[k]-=v;S.orders[i]={at:NOW+ORD_WAIT};n++}
     else{const need=Math.max(...Object.entries(o.need).map(([k,v])=>(v-(S.items[k]||0))/(rate[k]||1e-9)));if(need>6&&!ordDay().skip[i])ordSkip(i)}})}}
  return +(n/7).toFixed(1)}
 const SC=[['mid 영지25 · 시장1',FX.mid,{bld:{market:1}}],['mid 영지25 · 시장3',FX.mid,{bld:{market:3,dock:4,apiary:4,mine:4}}],['mid 영지25 · 시장5',FX.mid,{bld:{market:5,dock:6,apiary:6,mine:6}}],['late 영지46 · 시장5',FX.late,{bld:{market:5,ranch:5}}],['late 영지46 · 시장10',FX.late,{bld:{market:10,ranch:10}}]];
 const res={checks:CHECKS};for(const[nm,fx,mod]of SC){setS(fx,mod);res[nm]=orderWeek()}
 Date.now=realNow;window.today=td;return res})()
