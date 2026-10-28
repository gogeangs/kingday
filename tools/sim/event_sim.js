/* 눈꽃제 21일 — tools/balance_sim.py snow 가 브라우저에서 실행 (docs/content/EVENT_SNOW.md 8장)
   ① 1부를 하는 중인 유저를 만듦: 처음부터 HOURS 시간 쉬지 않고 사냥(추억 MEM·은퇴 RET, 욕심쟁이 소비)
   ② 그 상태로 이벤트 21일: 하루 일정대로 실제 전투(step)·방치(offline 과 같은 계산)·눈사람 대장(실제 30초 전투)을 돌리고
      눈송이는 게임 코드(evKill·evIdle·evBossWin·evAttClaim)가 그대로 매김. 크리스마스 주간 몫(산타 피트·트리·선물 배달·랭킹 참가)은 따로 더함.
   유저: daily = 매일 3번(간격 9·10·5시간) 들어와 5분 사냥 + 눈사람 대장 3번(접속마다 1번)
         once  = 하루 1번(24시간 만에) 들어와 방치 받고 3분 사냥 + 눈사람 대장 1번 */
(() => {
  Object.assign(BAL, TUNE);
  const EV = EVT.snow2026;
  Object.assign(EV.bat, EVBAT);
  Object.assign(EV.boss, EVBOSS);
  Object.assign(window, { toast: () => {}, queue: () => {}, renderAll: () => {}, say: () => {}, scene: () => {}, rpAdd: () => {}, rpFlush: () => {}, save: () => {}, cardReveal: () => {}, evSheet: () => {}, haptic: () => {}, nwAdd: () => {} });
  const opts = () => {
    const o = [];
    for (const id of members()) if (id !== 'kael') o.push([compCost(S.lv[id] || 1), () => { S.gold -= compCost(S.lv[id] || 1); S.lv[id] = (S.lv[id] || 1) + 1; }]);
    for (const u of UPG) { const l = S.up[u.k]; if (l < u.max) o.push([u.cost(l), () => { S.gold -= u.cost(l); S.up[u.k]++; }]); }
    o.push([boxCost(), () => openBox(true)]);
    return o;
  };
  const spend = () => { for (let k = 0; k < 400; k++) { const o = opts().sort((a, b) => a[0] - b[0])[0]; if (!o || S.gold < o[0]) break; o[1](); } };
  const out = {};
  let base = null;
  for (const who of ['daily', 'once']) {
    /* ① 같은 출발점 (두 유저 모두) */
    if (!base) {
      const f0 = fresh();
      Object.keys(S).forEach(k => delete S[k]);
      Object.assign(S, f0, { started: true, done: { pete: true, capRoad: true, cap56: true, cap57: true }, speed: 1, memory: MEM, retires: RET });
      S.bld.inn = 8;
      for (const id in P) delete P[id];
      mons = [];
      syncParty();
      let acc = 0;
      for (let t = 0; t < HOURS * 3600; t += 0.05) { step(0.05); acc += 0.05; if (acc >= 1) { acc = 0; spend(); } }
      base = JSON.stringify(S);
    }
    const st0 = JSON.parse(base);
    Object.keys(S).forEach(k => delete S[k]);
    Object.assign(S, st0);
    for (const id in P) delete P[id];
    mons = [];
    CH = null;
    syncParty();
    evDemoOn = 'snow'; /* 날짜와 상관없이 이벤트 켬(크리스마스 주간은 아래에서 따로 셈) */
    delete S.evs;
    const e = () => evS(EV.id);
    const plan = who === 'daily' ? { gaps: [9, 10, 5], min: 5, fights: [1, 1, 1] } : { gaps: [24], min: 3, fights: [1] };
    const days = [];
    let acc = 0;
    const startBest = S.best;
    let dayBest = S.best;
    for (let d = 0; d < 21; d++) {
      const day = { d: d + 1, bat: 0, idle: 0, boss: 0, att: 0, win: 0, lose: 0, st: 0 };
      let hOff = 0;
      for (let j = 0; j < plan.gaps.length; j++) {
        hOff += plan.gaps[j];
        evSkew = (d * 24 + hOff - plan.gaps[0]) * 3600e3; /* 이벤트 날짜만 움직임 (하루 = 접속 묶음) */
        if (plan.gaps.length === 1) evSkew = d * 864e5;
        const sec = Math.min(plan.gaps[j], offCapH()) * 3600;
        const sf0 = e().sf;
        S.gold += idleGold(sec);
        evIdle(sec);
        day.idle += e().sf - sf0;
        spend();
        if (j === 0) {
          const a0 = e().sf;
          if (evAttCan(EV)) evAttClaim(EV.id);
          day.att += e().sf - a0;
        }
        for (let k = 0; k < plan.fights[j]; k++) {
          if (evTriesLeft(EV) <= 0) break;
          const b0 = e().sf,
            st = e().boss.st;
          evBossStart(EV.id);
          let hpL = 1,
            alive = 1;
          for (let t = 0; CH && CH.mode === 'ev' && CH.st === 'fight' && t < 45; t += 0.05) {
            step(0.05);
            const bm = mons.find(m => m.snow);
            if (bm && CH && CH.st === 'fight') {
              hpL = Math.max(0, bm.hp / bm.max);
              alive = members().filter(i => P[i] && !P[i].down).length;
            }
          }
          if (CH && CH.mode === 'ev') chExit(true);
          if (e().boss.st > st) day.win++;
          else {
            day.lose++;
            day.why = (day.why || '') + (alive ? '시간' : '전멸') + Math.round(hpL * 100) + '% ';
          }
          day.boss += e().sf - b0;
        }
        const k0 = e().sf;
        for (let t = 0; t < plan.min * 60; t += 0.05) { step(0.05); acc += 0.05; if (acc >= 1) { acc = 0; spend(); } }
        day.bat += e().sf - k0;
      }
      /* 은퇴: 이번 회차가 최고 영지 앞(벽)까지 와서 하루 동안 더 못 나갔을 때만 (part2_sim 과 같은 규칙) */
      if (S.best <= dayBest && S.stage >= S.best - 1 && retCan()) {
        retire(retirePts(), false);
        syncParty();
        day.ret = 1;
      }
      dayBest = S.best;
      day.st = e().boss.st;
      day.best = S.best;
      days.push(day);
    }
    const sum = k => days.reduce((a, x) => a + x[k], 0);
    /* 크리스마스 주간 몫 (5일): 산타 피트 선물 50×4 + 큰 선물 300 · 트리 1/3 확률 30 · 선물 배달 3판(daily, 판마다 점수÷10) / once 는 1판 · 랭킹 참가 100 */
    const mgSf = MGSC / 10;
    const xm = { pete: 50 * 4 + 300, tree: Math.round((30 / 3) * 5), mg: Math.round(Math.min(100, mgSf) * (who === 'daily' ? 3 : 1) * 5), rank: 100 };
    out[who] = {
      total: sum('bat') + sum('idle') + sum('boss') + sum('att'),
      bat: sum('bat'),
      idle: sum('idle'),
      boss: sum('boss'),
      att: sum('att'),
      attCnt: e().att.cnt,
      xmas: xm,
      xmTotal: xm.pete + xm.tree + xm.mg + xm.rank,
      best: [startBest, S.best],
      mem: S.memory,
      bossBest: e().boss.best,
      days: days.map(x => `${x.d}일 W${x.win}/L${x.lose}→${x.st}단계 전투${x.bat}·방치${x.idle}·보스${x.boss}·출석${x.att} 영지${x.best}${x.ret ? ' 은퇴' : ''}${x.why ? ' (진 이유·남은 체력 ' + x.why.trim() + ')' : ''}`)
    };
  }
  evDemoOn = null;
  evSkew = 0;
  return out;
})();
