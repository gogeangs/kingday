/* 신년축제 21일 — tools/balance_sim.py newyear 가 브라우저에서 실행 (docs/content/EVENT_NEWYEAR.md 8-1)
   눈꽃제 시뮬레이터(event_sim.js)와 같은 유저·같은 출발점. 등불·윷·복주머니·바퀴는 게임 코드(evKill·evIdle·yutDaily·yutGo·bokGo·evAttClaim)가 그대로 매김.
   유저: daily = 매일 3번 들어와 5분 사냥, 접속 때마다 윷을 모두 던지고 복주머니를 모두 엶 / once = 하루 1번 3분 사냥
   (아래는 눈꽃제 설명 그대로)
   ① 1부를 하는 중인 유저를 만듦: 처음부터 HOURS 시간 쉬지 않고 사냥(추억 MEM·은퇴 RET, 욕심쟁이 소비)
   ② 그 상태로 이벤트 21일: 하루 일정대로 실제 전투(step)·방치(offline 과 같은 계산)·눈사람 대장(실제 30초 전투)을 돌리고
      눈송이는 게임 코드(evKill·evIdle·evBossWin·evAttClaim)가 그대로 매김. 크리스마스 주간 몫(산타 피트·트리·선물 배달·랭킹 참가)은 따로 더함.
   유저: daily = 매일 3번(간격 9·10·5시간) 들어와 5분 사냥 + 눈사람 대장 3번(접속마다 1번)
         once  = 하루 1번(24시간 만에) 들어와 방치 받고 3분 사냥 + 눈사람 대장 1번 */
(() => {
  Object.assign(BAL, TUNE);
  const EV = EVT.newyear2027;
  Object.assign(EV.bat, EVBAT);
  Object.assign(EV.yut, EVYUT);
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
    evDemoOn = 'newyear'; /* 날짜와 상관없이 신년축제 켬 */
    delete S.evs;
    const e = () => evS(EV.id);
    const plan = who === 'daily' ? { gaps: [9, 10, 5], min: 5 } : { gaps: [24], min: 3 };
    const days = [];
    let acc = 0;
    const T0 = { gem: S.gem, mong: (S.cards && S.cards.mong) || 0, lc: S.lcard || 0 };
    const src = { bat: 0, idle: 0, att: 0, board: 0, bok: 0, first: 0 };
    const startBest = S.best;
    let dayBest = S.best;
    let throws = 0,
      boks = 0,
      evGem = 0;
    const G = f => { const g0 = S.gem; f(); evGem += S.gem - g0; };
    for (let d = 0; d < 21; d++) {
      const day = { d: d + 1, bat: 0, idle: 0, att: 0, board: 0, bok: 0, yut: 0, laps: 0 };
      let hOff = 0;
      for (let j = 0; j < plan.gaps.length; j++) {
        hOff += plan.gaps[j];
        evSkew = (d * 24 + hOff - plan.gaps[0]) * 3600e3;
        if (plan.gaps.length === 1) evSkew = d * 864e5;
        const sec = Math.min(plan.gaps[j], offCapH()) * 3600;
        let s0 = e().sf;
        S.gold += idleGold(sec);
        evIdle(sec);
        day.idle += e().sf - s0;
        spend();
        if (j === 0) {
          if (d === 0) { s0 = e().sf; G(() => evGive(EV.id, [...EV.first.r, { k: 'badge', id: 'firstday' }])); src.first += e().sf - s0; } /* 1/1 에 들어온 셈 */
          yutDaily(EV);
          s0 = e().sf;
          if (evAttCan(EV)) G(() => evAttClaim(EV.id));
          day.att += e().sf - s0;
          bokGo(EV.id, 'free');
        }
        s0 = e().sf;
        for (let t = 0; t < plan.min * 60; t += 0.05) { step(0.05); acc += 0.05; if (acc >= 1) { acc = 0; spend(); } }
        day.bat += e().sf - s0;
        /* 접속마다 윷을 모두 던지고 복주머니를 모두 엶 */
        const y0 = e().yut.n, l0 = e().yut.laps;
        s0 = e().sf;
        if (e().yut.n > 0) { throws += 1; G(() => yutGo(EV.id, true)); }
        day.board += e().sf - s0;
        day.yut += y0;
        day.laps += e().yut.laps - l0;
        s0 = e().sf;
        boks += e().bok.n;
        if (e().bok.n > 0) G(() => bokGo(EV.id, 'all'));
        day.bok += e().sf - s0;
        spend();
      }
      /* 은퇴: 눈꽃제 시뮬레이터와 같은 규칙 (벽 앞에서 하루 동안 못 나갔을 때만) */
      if (S.best <= dayBest && S.stage >= S.best - 1 && retCan()) {
        retire(retirePts(), false);
        syncParty();
        day.ret = 1;
      }
      dayBest = S.best;
      days.push(day);
      for (const k of ['bat', 'idle', 'att', 'board', 'bok']) src[k] += day[k];
    }
    const tot = Object.values(src).reduce((a, x) => a + x, 0);
    out[who] = {
      total: tot,
      src,
      laps: e().yut.laps,
      boks,
      gem: evGem,
      mong: ((S.cards && S.cards.mong) || 0) - T0.mong,
      lcard: (S.lcard || 0) - T0.lc,
      badgeYut: !!(S.bdUnl && S.bdUnl.yut),
      best: [startBest, S.best],
      days: days.map(x => `${x.d}일 윷${x.yut}(바퀴+${x.laps}) 전투${x.bat}·방치${x.idle}·출석${x.att}·윷판${x.board}·복${x.bok}${x.ret ? ' 은퇴' : ''}`)
    };
  }
  evDemoOn = null;
  evSkew = 0;
  return out;
})();
