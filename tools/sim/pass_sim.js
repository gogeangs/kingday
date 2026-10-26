/* 원정 일지(시즌 패스) 점수 시뮬레이션 — docs/content/SHOP.md 8장
   2주(14일) 동안 하루 일정대로 실제 전투(step)를 돌리고, 점수는 게임 코드(passAdd·passKill)가 그대로 매김.
   전투로 생기는 점수(영지 탈환·마물 1,000마리)는 실제로 재고, 화면에서 하는 일(할 일 받기·탑·던전·주문)은 아래 PLAN 가정대로 누름.
   PLAN: [하루 접속 수, 한 번에 전투 분, 탑 층/일, 던전/일, 주문/일, 할 일 받기] */
(() => {
  const PLAN = {
    att: { n: 1, min: 3, tower: 0, dun: 0, ord: 0, mis: false },
    normal: { n: 3, min: 20, tower: 2, dun: 2, ord: 2, mis: true }
  };
  Object.assign(window, { toast: () => {}, queue: () => {}, renderAll: () => {}, say: () => {}, scene: () => {}, rpAdd: () => {}, save: () => {}, cardReveal: () => {} });
  const greedy = () => {
    const o = [];
    for (const id of members()) if (id !== 'kael') o.push([compCost(S.lv[id]), () => { S.gold -= compCost(S.lv[id]); S.lv[id]++; }]);
    for (const u of UPG) { const l = S.up[u.k]; if (l < u.max) o.push([u.cost(l), () => { S.gold -= u.cost(l); S.up[u.k]++; }]); }
    o.push([boxCost(), () => { openBox(true); dailyAdd('box', 1); }]);
    for (let k = 0; k < 30; k++) { const x = o.sort((a, b) => a[0] - b[0])[0]; if (!x || S.gold < x[0]) break; x[1](); }
  };
  const res = {};
  for (const who of Object.keys(PLAN)) {
    const pl = PLAN[who];
    const f0 = fresh();
    Object.keys(S).forEach(k => delete S[k]);
    Object.assign(S, f0, { started: true, done: { pete: true }, speed: 1 });
    for (const id in P) delete P[id];
    mons = [];
    syncParty();
    let day = 0;
    window.today = () => 'D' + day;
    const p = passS();
    const log = [];
    let doneDay = 0;
    for (day = 1; day <= 14; day++) {
      const pt0 = p.pt;
      passAdd('att');
      for (let s = 0; s < pl.n; s++) {
        const T = pl.min * 60, dt = 0.1;
        for (let t = 0, acc = 0; t < T && S.stage <= 50; t += dt) {
          step(dt);
          if ((acc += dt) >= 1) { acc = 0; greedy(); }
        }
        if (pl.mis) {
          const d = daily();
          d.harv = Math.max(d.harv || 0, S.bld.farm ? 10 : 0);
          for (const m of MISSIONS) if (misCan(m)) { d.claim[m.k] = true; passAdd('mis'); }
          if (misCan(null)) { d.claim.all = true; passAdd('misall'); }
        }
        /* 접속 사이 방치(8시간을 접속 수로 나눔): 골드만 */
        S.gold += idleGold((16 / pl.n) * 3600);
      }
      if (S.chOpen || S.best > 20) {
        for (let i = 0; i < pl.tower; i++) passAdd('tower');
        for (let i = 0; i < pl.dun; i++) passAdd('dun');
      }
      if (S.bld.market || S.best > 15) for (let i = 0; i < pl.ord; i++) passAdd('ord');
      log.push([day, p.pt - pt0, passLv(), Math.min(S.best - 1, 50), JSON.stringify(p.day.src)]);
      if (!doneDay && passLv() >= 20) doneDay = day;
    }
    res[who] = { done20: doneDay || null, lv14: passLv(), pt14: p.pt, days: log };
  }
  return res;
})()
