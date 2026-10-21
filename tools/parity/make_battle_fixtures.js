// 웹 전투(step)를 Node 에서 그대로 돌려, 앱 전투 시뮬레이션과 비교할 정답 값을 만든다.
//   node tools/parity/make_battle_fixtures.js          → app/test/fixtures/battle_parity.json 갱신
//   node tools/parity/make_battle_fixtures.js --check  → 최신인지만 확인
// 같은 씨앗의 난수·같은 화면 크기·같은 시각으로 웹과 앱을 똑같이 싸우게 한 뒤 0.5초마다 상태를 비교한다.
'use strict';
const fs = require('fs');
const path = require('path');
const { loadWeb } = require('./load_web.js');

const NOW = Date.UTC(2026, 9, 20, 3, 0, 0);
const W = 390, HT = 330, DT = 1 / 30, SNAP = 30;
const w = loadWeb({ now: NOW });
const J = (x) => JSON.parse(JSON.stringify(x));
const F = (n) => w.run(n);

// 전투 효과 그림을 "불러온 것"으로 (앱은 그림이 모두 있으므로 같은 조건)
F('loadFx')();
// 화면 새로 그리기는 전투 계산과 무관하고 저장 데이터를 건드리므로 끔
w.ctx.renderAll = () => {};
// 군단장 첫 처치 이삭(웹은 2.3초 뒤 지급)은 바로 지급 — 앱도 바로 지급
w.ctx.setTimeout = (fn) => { if (typeof fn === 'function' && String(fn).includes('gainGem')) fn(); return 0; };

const fixtures = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'app', 'test', 'fixtures', 'web_parity.json'), 'utf8'));
const base = fixtures.saves;
const withTut = (s, extra = {}) => Object.assign(J(s), { done: Object.assign({}, s.done || {}, { tutSkill: true }) }, extra);

// [이름, 저장, 초기 gobT, 진행 초]
const CASES = [
  ['fresh', withTut(base.fresh), 200, 90],
  ['mid', withTut(base.mid), 200, 120],
  ['late', withTut(base.late), 200, 120],
  ['goblin', withTut(base.mid, { wave: 2 }), 0.5, 60],
  ['lord', withTut(base.mid, { stage: 20, best: 20, wave: 10 }), 200, 60],
  ['weak', withTut(base.fresh, { stage: 30, best: 30, wave: 10 }), 200, 70],
  ['manual', withTut(base.mid, { autoSkill: false, stage: 31, best: 31, wave: 0 }), 200, 60],
  ['lateHard', withTut(base.late, { stage: 56, best: 56, wave: 0 }), 200, 120],
  ['lateAlt', withTut(base.late, { stage: 68, best: 68, wave: 0, party: { miner: 'gordon', fisher: 'haral', keeper: 'daisy', cook: 'margo' } }), 200, 120],
  ['makrye', withTut(base.late, { stage: 66, best: 68, wave: 2, rec: Object.assign({}, base.late.rec || {}, { makrye: 5 }), lv: Object.assign({}, base.late.lv || {}, { makrye: 60 }), party: Object.assign({}, base.late.party || {}, { fisher: 'makrye' }) }), 200, 240],
  ['legends', withTut(base.late, { stage: 70, best: 72, wave: 2, rec: Object.assign({}, base.late.rec || {}, { makrye: 3, malbong: 5, deokbae: 4, peppy: 3 }), lv: Object.assign({}, base.late.lv || {}, { makrye: 60, malbong: 60, deokbae: 60, peppy: 60 }), party: { fisher: 'makrye', keeper: 'malbong', cook: 'deokbae', miner: 'peppy' } }), 200, 240],
  ['andante', withTut(base.late, { stage: 64, best: 68, wave: 1, rec: Object.assign({}, base.late.rec || {}, { andante: 5 }), lv: Object.assign({}, base.late.lv || {}, { andante: 60 }), party: Object.assign({}, base.late.party || {}, { keeper: 'andante' }) }), 200, 180],
  ['honey', withTut(base.late, { stage: 68, best: 68, wave: 3, party: { miner: 'bron', fisher: 'haral', keeper: 'riel', cook: 'margo' } }), 200, 120],
  // 희귀 동료 3명: 토비(밀치기)·카라(화상)·베릴(약점)
  ['rares', withTut(base.late, { stage: 66, best: 68, wave: 2, rec: Object.assign({}, base.late.rec || {}, { toby: 3, kara: 3, beryl: 4 }), lv: Object.assign({}, base.late.lv || {}, { toby: 60, kara: 60, beryl: 60 }), party: { miner: 'beryl', fisher: 'toby', keeper: 'riel', cook: 'kara' } }), 200, 240],
  ['commons', withTut(base.late, { stage: 66, best: 68, wave: 2, rec: Object.assign({}, base.late.rec || {}, { mora: 3, melo: 3, pori: 3 }), lv: Object.assign({}, base.late.lv || {}, { mora: 60, melo: 60, pori: 60 }), party: { miner: 'bron', fisher: 'mora', keeper: 'melo', cook: 'pori' } }), 200, 240],
];

const out = { now: NOW, w: W, ht: HT, dt: DT, snap: SNAP, cases: {} };
for (const [name, save, gob, secs] of CASES) {
  w.setNow(NOW);
  w.setS(F('hydrate')(J(save)));
  w.run(`W=${W};Ht=${HT};P={};mons=[];spawnT=.5;bgX=0;T=0;floats=[];proj=[];fxs=[];bossT=0;engaged=false;quip=null;quipT=6;flash=0;cut=null;warn=null;shakeT=0;banner=null;gobT=${gob};
    for(const k in SKX)SKX[k]=0;SKX.mountK=1;`);
  w.setSeed(20261020);
  const snaps = [];
  const frames = Math.round(secs / DT);
  for (let f = 1; f <= frames; f++) {
    F('step')(DT);
    // 수동 모드: 1/3초마다 스킬이 찬 동료의 스킬을 직접 씀 (초상화 누르기)
    if (name === 'manual' && f % 10 === 0) {
      for (const id of F('members')()) if (F('skFull')(id)) { F('castSkill')(id); break; }
    }
    if (f % SNAP === 0) {
      snaps.push(J(w.run(`({f:${f},gold:S.gold,stage:S.stage,wave:S.wave,best:S.best,gem:S.gem,seeds:S.seeds,cards:S.cards??null,
        gemLord:S.gemLord,kill:daily().kill,joined:S.joined,rankSeen:S.rankSeen,gemRank:S.gemRank??0,gobW:S.gobW??null,stat:S.stat??null,
        bdUnl:S.bdUnl??null,
        P:Object.fromEntries(Object.entries(P).map(([k,p])=>[k,[p.hp,p.down,p.sg||0,p.cd,p.swing,p.hit]])),
        mons:mons.map(m=>[m.x,m.hp,m.dead,!!m.boss,!!m.gob,!!m.alt,!!m.flee,m.cd,m.bind||0,m.psn||0,m.slow||0,m.vul||0,m.brn||0,m.kb||0]),
        engaged,bgX,spawnT,gobT,bossT,shakeT,flash,
        skx:{shield:SKX.shield,honey:SKX.honey,feast:SKX.feast,bake:SKX.bake,mount:SKX.mount,mountK:SKX.mountK,wall:SKX.wall},
        nFloats:floats.length,nFx:fxs.length,nProj:proj.length,quip:quip?quip.txt:null,banner:banner?banner.txt:null,cut:cut?cut.id:null,warn:!!warn})`)));
    }
  }
  out.cases[name] = { save: J(save), gobT: gob, frames, snaps };
}

const file = path.join(__dirname, '..', '..', 'app', 'test', 'fixtures', 'battle_parity.json');
const text = JSON.stringify(out) + '\n';
if (process.argv.includes('--check')) {
  const cur = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  if (cur !== text) {
    console.error('battle_parity.json 이 index.html 과 맞지 않아요. node tools/parity/make_battle_fixtures.js 를 실행해 갱신하세요.');
    process.exit(1);
  }
  console.log('battle_parity.json 최신 상태');
} else {
  fs.writeFileSync(file, text);
  const sum = Object.entries(out.cases).map(([k, c]) => { const l = c.snaps[c.snaps.length - 1]; return `${k}: 영지 ${c.save.stage ?? 1}→${l.stage} 골드 ${Math.round(l.gold)} 마물 ${l.mons.length}`; });
  console.log('저장:', path.relative(process.cwd(), file), (text.length / 1024).toFixed(0) + 'KB\n' + sum.join('\n'));
}
