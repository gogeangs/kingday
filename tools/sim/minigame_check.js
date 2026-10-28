// 미니게임 「선물 배달」 점검 (docs/content/EVENT_SNOW.md 3-9·3-10·8장) — node tools/sim/minigame_check.js [판 수]
// ① 같은 번호(seed)·같은 누름 → 같은 점수 (화면을 몇 번 그리든 1/60초 단위로만 움직이는지: 30·60·120·144fps 로 같은 누름을 넣어 비교)
// ② 완벽하게 누르는 봇의 점수 분포 → 서버 최대 점수(kd_minigames.max_score)·웹 MGC.maxScore 가 그보다 큰지
// ③ 마구 누르기(0.35초마다)·적당히 잘하는 사람(가끔 늦거나 이름) 점수
'use strict';
const { loadWeb, mulberry32 } = require('../parity/load_web.js');
const N = +(process.argv[2] || 300);
const W = loadWeb();
const { mgNew, mgStep, MGC, mgV } = W.run('({ mgNew, mgStep, MGC, mgV })');

/* 다음 단위에 누르면 선물이 각 집 굴뚝 높이를 지날 때 가운데와 얼마나 떨어지는지 (mgStep 과 같은 계산) */
function predict(g) {
  const out = [];
  const dt = MGC.dt;
  let y = MGC.dropY,
    vy = 0,
    x = g.x,
    n = g.n;
  const hs = g.hs.filter(h => !h.done);
  const left = new Set(hs);
  for (let j = 0; j < 90 && left.size; j++) {
    n++;
    const dx = mgV(n * dt) * dt;
    x += dx;
    const y0 = y;
    vy += MGC.G * dt;
    y += vy * dt;
    for (const h of [...left]) {
      if (y0 < h.cy && y >= h.cy) {
        const f = (h.cy - y0) / (y - y0),
          sx = h.cx - x + dx * (1 - f);
        out.push({ h, d: Math.abs(MGC.sledX + 4 - sx), s: MGC.sledX + 4 - sx });
        left.delete(h);
      }
    }
  }
  return out;
}
/* 봇: skill 0~1 (1 = 완벽, 굴뚝 가운데가 가장 가까워지는 순간에 누름) · 연기 굴뚝은 피함 */
function play(seed, bot) {
  const g = mgNew(seed),
    r = mulberry32(seed ^ 0x9e3779b9),
    taps = [];
  let prev = null;
  while (!g.over) {
    if (bot === 'spam') {
      if (g.cdT <= 0 && g.t < MGC.T) {
        g.tapQ = 1;
        taps.push(g.n);
      }
    } else if (g.cdT <= 0 && g.t < MGC.T) {
      const p = predict(g).filter(o => o.h.ty !== 'smoke');
      const best = p.length ? p.reduce((a, b) => (b.d < a.d ? b : a)) : null;
      if (best) {
        const err = bot.err ? (r() - 0.5) * 2 * bot.err : 0; /* 사람: 이만큼 일찍·늦게 누름(논리 단위) */
        if (prev && prev.h === best.h && best.s - err >= 0 && prev.s - err < 0 && best.s - err < 6) {
          /* 지난 단위와 이번 단위 사이에 가운데를 지남 → 더 가까운 쪽 */
          g.tapQ = 1;
          taps.push(g.n);
        } else if (best.d <= 0.5 && !bot.err) {
          g.tapQ = 1;
          taps.push(g.n);
        }
      }
      prev = best;
    }
    mgStep(g);
  }
  return { score: g.score, hits: g.hits, perf: g.perf, maxC: g.maxC, miss: g.miss, taps, n: g.n };
}
/* 같은 누름을 다른 화면 빠르기로 넣기: 누른 순간(실제 시각)을 프레임마다 모아 다음 단위에 반영 — 웹 mgLoop 와 같은 방식 */
function replayFps(seed, taps, fps) {
  const g = mgNew(seed),
    tapT = taps.map(n => n * MGC.dt);
  let acc = 0,
    t = 0,
    i = 0;
  while (!g.over) {
    const real = 1 / fps;
    t += real;
    /* 이 프레임 동안 누른 것: 누른 시각이 지금 시각 이전 */
    while (i < tapT.length && tapT[i] <= g.n * MGC.dt + 1e-9) {
      g.tapQ = 1;
      i++;
    }
    acc += Math.min(0.1, real);
    while (acc >= MGC.dt - 1e-12 && !g.over) {
      acc -= MGC.dt;
      while (i < tapT.length && tapT[i] <= g.n * MGC.dt + 1e-9) {
        g.tapQ = 1;
        i++;
      }
      mgStep(g);
    }
  }
  return g.score;
}
const st = a => {
  a = [...a].sort((x, y) => x - y);
  const q = p => a[Math.min(a.length - 1, Math.floor(p * a.length))];
  return { min: a[0], p10: q(0.1), p50: q(0.5), p90: q(0.9), max: a[a.length - 1], avg: Math.round(a.reduce((x, y) => x + y, 0) / a.length) };
};
const perfect = [],
  good = [],
  okay = [],
  spam = [];
let same = 0,
  fpsOk = 0;
for (let k = 0; k < N; k++) {
  const seed = (k * 2654435761) >>> 0;
  const a = play(seed, {});
  perfect.push(a.score);
  if (k < 40) {
    const b = play(seed, {});
    if (b.score === a.score) same++;
    const fs = [30, 60, 120, 144].map(f => replayFps(seed, a.taps, f));
    if (fs.every(x => x === a.score)) fpsOk++;
    else console.log('fps 차이', seed, a.score, fs);
  }
  good.push(play(seed, { err: 6 }).score);
  okay.push(play(seed, { err: 14 }).score);
  spam.push(play(seed, 'spam').score);
}
console.log('판', N, '· 같은 번호·같은 누름 → 같은 점수', same + '/40', '· 30/60/120/144fps 같은 점수', fpsOk + '/40');
console.log('완벽한 봇', st(perfect));
console.log('잘하는 사람(±6)', st(good));
console.log('보통(±14)', st(okay));
console.log('마구 누르기', st(spam));
console.log('MGC.maxScore', MGC.maxScore, Math.max(...perfect) < MGC.maxScore ? '> 완벽한 봇 최대 OK' : '!! 너무 작음');
