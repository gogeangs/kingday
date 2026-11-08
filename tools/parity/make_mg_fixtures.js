// 미니게임 「선물 배달」 웹·앱 비교 정답 값.
// 같은 판 번호(seed)·같은 누름(몇 번째 단위에 눌렀는지)이면 웹 mgStep 과 앱 MgGame.step 이 같은 점수를 내는지 본다.
//   node tools/parity/make_mg_fixtures.js          → app/test/fixtures/mg_parity.json 갱신
//   node tools/parity/make_mg_fixtures.js --check  → 최신인지만 확인(다르면 실패)
'use strict';
const fs = require('fs');
const path = require('path');
const { loadWeb, mulberry32 } = require('./load_web.js');

const w = loadWeb();
const MGC = w.run('MGC');
const mgV = w.run('mgV'), mgStep = w.run('mgStep'), mgRng = w.run('mgRng');

/* 누르는 방법 4가지 (같은 번호로 만든 누름 표 — 앱 시험은 이 표를 그대로 씀)
   every: k 단위마다 · rand: 무작위 · bot: 굴뚝이 오기 전에 정확히 · mash: 마구 */
function plan(kind, seed, g0) {
  const r = mulberry32(seed ^ 0x9e3779b9);
  const taps = [];
  const total = Math.ceil((MGC.T + 1.6) / MGC.dt);
  if (kind === 'every') for (let n = 30; n < total; n += 22 + (seed % 9)) taps.push(n);
  else if (kind === 'rand') for (let n = 0; n < total; n++) { if (r() < 0.05) taps.push(n); }
  else if (kind === 'mash') for (let n = 0; n < total; n++) { if (r() < 0.25) taps.push(n); }
  return taps;
}

/* 완벽한 봇: 웹 tools/sim/minigame_check.js 처럼 굴뚝이 떨어지는 지점에 오기 직전에 누름 (판을 돌리며 정함) */
function botRun(seed) {
  const g = w.run(`mgNew(${seed >>> 0})`);
  const taps = [];
  let guard = 0;
  while (!g.over && guard++ < 5000) {
    const v = mgV(g.t);
    const tgt = g.hs.find(h => !h.done && h.ty !== 'smoke' && h.cx - g.x > MGC.sledX + 4);
    if (tgt && g.cdT <= 0) {
      const fallT = Math.sqrt((2 * (tgt.cy - MGC.dropY)) / MGC.G);
      const need = tgt.cx - g.x - (MGC.sledX + 4) - v * fallT;
      if (need <= v * MGC.dt && need > -v * MGC.dt) {
        g.tapQ = 1;
        taps.push(g.n);
      }
    }
    mgStep(g);
  }
  return taps;
}

function run(seed, taps) {
  const g = w.run(`mgNew(${seed >>> 0})`);
  const set = new Set(taps);
  let guard = 0;
  while (!g.over && guard++ < 5000) {
    if (set.has(g.n)) g.tapQ = 1;
    mgStep(g);
  }
  return { score: g.score, hits: g.hits, perf: g.perf, maxC: g.maxC, miss: g.miss, drops: g.drops, n: g.n, hs: g.hs.length, x: g.x };
}

const out = { maxScore: MGC.maxScore, cases: [] };
const seeds = [1, 7, 42, 20261221, 3141592653, 4294967295, 123456789, 99, 2024, 777777];
for (const seed of seeds) {
  for (const kind of ['every', 'rand', 'mash', 'bot']) {
    const taps = kind === 'bot' ? botRun(seed) : plan(kind, seed);
    out.cases.push({ seed: seed >>> 0, kind, taps, ...run(seed, taps) });
  }
}
// 웹 mgRng 첫 값 몇 개 (앱 Mulberry32 와 같은지)
out.rng = seeds.map(s => {
  const r = mgRng(s);
  return [r(), r(), r()];
});

const txt = JSON.stringify(out, null, 1) + '\n';
const file = path.join(__dirname, '..', '..', 'app', 'test', 'fixtures', 'mg_parity.json');
if (process.argv.includes('--check')) {
  const cur = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  if (cur !== txt) {
    console.error('mg_parity.json 이 index.html 과 맞지 않아요. node tools/parity/make_mg_fixtures.js 를 실행해 갱신하세요.');
    process.exit(1);
  }
  console.log('mg_parity.json 최신 상태');
} else {
  fs.writeFileSync(file, txt);
  const best = Math.max(...out.cases.map(c => c.score));
  console.log('저장:', path.relative(process.cwd(), file), out.cases.length + '판 · 최고', best, '점');
}
