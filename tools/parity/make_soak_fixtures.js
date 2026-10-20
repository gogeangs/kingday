// 긴 플레이 비교 (QA): 웹 코드를 Node 에서 수십 분 동안 "자동으로 플레이"시켜, 앱과 비교할 정답 값을 만든다.
//   node tools/parity/make_soak_fixtures.js          → app/test/fixtures/soak_parity.json 갱신
//   node tools/parity/make_soak_fixtures.js --check  → 최신인지만 확인
//
// 같은 씨앗의 난수·같은 시계·같은 "플레이 규칙"으로 웹과 앱을 똑같이 진행시키고, 3분마다 저장 데이터 전체(S)를 비교한다.
// 플레이 규칙(앱 test/soak_parity_test.dart 도 똑같이):
//   매 프레임 전투 1/30초 · 0.4초마다 생산 · 0.9초마다 자동 상자 · 5초마다 추천 단련(최대)
//   30초마다 동료 레벨업·별 올리기·자동 편성 · 60초마다 밭 수확·심기·건물 공사 주문
'use strict';
const fs = require('fs');
const path = require('path');
const { loadWeb } = require('./load_web.js');

const NOW = Date.UTC(2026, 9, 20, 3, 0, 0);
const W = 390, HT = 330, DT = 1 / 30, SNAP = 30 * 180;
const w = loadWeb({ now: NOW });
const J = (x) => JSON.parse(JSON.stringify(x));
const F = (n) => w.run(n);

F('loadFx')();
w.ctx.renderAll = () => {};
w.ctx.setTimeout = (fn) => { if (typeof fn === 'function' && String(fn).includes('gainGem')) fn(); return 0; };

const base = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'app', 'test', 'fixtures', 'web_parity.json'), 'utf8')).saves;
const withTut = (s, extra = {}) => Object.assign(J(s), { done: Object.assign({}, s.done || {}, { tutSkill: true }) }, extra);

// [이름, 저장, 진행 분]
const CASES = [
  ['fresh', withTut(base.fresh, { done: { tutSkill: true, pete: true } }), 60],
  ['mid', withTut(base.mid), 30],
  ['late', withTut(base.late), 30],
];

const BLDS = F('BLD').map((b) => b.k);

function bot(f) {
  if (f % 12 === 0) F('produce')();
  if (f % 27 === 0) F('openBox')(true);
  if (f % 150 === 0) {
    w.run(`(()=>{S.upMul='max';const p0=power();let best=null,bv=0;for(const u of UPG){const l=S.up[u.k];if(l>=u.max||S.gold<u.cost(l))continue;S.up[u.k]++;const g=(power()-p0)/u.cost(l);S.up[u.k]--;if(g>bv){bv=g;best=u.k}}if(best)upFire(best)})()`);
  }
  if (f % 900 === 0) {
    w.run(`(()=>{for(const id of members()){if(id==='kael')continue;const cc=compCost(S.lv[id]||1);if(S.gold<cc)continue;const h0=stats(id).hp;S.gold-=cc;S.lv[id]=(S.lv[id]||1)+1;if(P[id])P[id].hp+=stats(id).hp-h0}})()`);
    // 별 올리기: 카드가 다 모인 동료만 (화면에서 버튼이 켜지는 경우와 같게)
    w.run('(()=>{for(const id of CARDIDS()){const need=starNeed(id);if(cardOpen(id)&&need!=null&&((S.cards&&S.cards[id])||0)>=need&&recStar(id)<starMax(id))recruitUp(id)}})()');
    F('autoForm')();
  }
  if (f % 1800 === 0) {
    F('ensurePlots')();
    w.run('(()=>{S.plots.forEach((p,i)=>harvest(i))})()');
    w.run("(()=>{S.plots.forEach((p,i)=>{if(p)return;const t=plotTag(i);if(t){if(S.seeds[t]>0)plant(i,t);return}const c=[...CROPS].reverse().find(c=>S.seeds[c.k]>0);if(c)plant(i,c.k)})})()");
    for (const k of BLDS) F('orderBuild')(F('bldK')(k));
  }
}

const out = { now: NOW, w: W, ht: HT, dt: DT, snap: SNAP, blds: BLDS, cases: {} };
for (const [name, save, mins] of CASES) {
  w.setNow(NOW);
  w.setS(F('hydrate')(J(save)));
  w.run(`W=${W};Ht=${HT};P={};mons=[];spawnT=.5;bgX=0;T=0;floats=[];proj=[];fxs=[];bossT=0;engaged=false;quip=null;quipT=6;flash=0;cut=null;warn=null;shakeT=0;banner=null;gobT=200;pending=null;
    for(const k in SKX)SKX[k]=0;SKX.mountK=1;`);
  w.setSeed(777001);
  const snaps = [];
  const frames = Math.round((mins * 60) / DT);
  const t0 = Date.now();
  for (let f = 1; f <= frames; f++) {
    w.setNow(NOW + Math.floor((f * 1000) / 30));
    F('step')(DT);
    bot(f);
    if (f % SNAP === 0) snaps.push({ f, S: J(w.run('S')) });
  }
  const l = snaps[snaps.length - 1].S;
  console.log(name, `${mins}분`, `${((Date.now() - t0) / 1000).toFixed(1)}s`, '영지', l.stage, '최고', l.best, '골드', Math.round(l.gold), '이삭', l.gem, '상자Lv', l.boxLv, '단련', JSON.stringify(l.up), '건물', JSON.stringify(l.bld));
  out.cases[name] = { save: J(save), frames, snaps };
}

const file = path.join(__dirname, '..', '..', 'app', 'test', 'fixtures', 'soak_parity.json');
const text = JSON.stringify(out) + '\n';
if (process.argv.includes('--check')) {
  const cur = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  if (cur !== text) {
    console.error('soak_parity.json 이 index.html 과 맞지 않아요. node tools/parity/make_soak_fixtures.js 를 실행해 갱신하세요.');
    process.exit(1);
  }
  console.log('soak_parity.json 최신 상태');
} else {
  fs.writeFileSync(file, text);
  console.log('저장:', path.relative(process.cwd(), file), (text.length / 1024).toFixed(0) + 'KB');
}
