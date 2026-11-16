/* 황금 이삭 재기 — docs/PLAN_MONETIZATION_REMOVAL.md 4번
   보통 유저(하루 3번 × 20분 전투)가 결제 없이 DAYS일 동안 얻는 황금 이삭을 출처별로 잰다.
   - 전투로 생기는 이삭(황금 고블린·군단장·칭호·탑 10층마다)은 실제 게임 코드(step·towerStart)로 돈다.
   - 화면에서 누르는 일(출석·오늘의 할 일·원정 일지 무료 줄·피트의 이삭 광고·출석 광고 2배·은퇴)은 아래 가정대로 누른다.
   - 이삭은 쓰지 않고 모은다(얻는 양만 잼). 쓰고 싶은 양은 balance_sim.py 에서 가격표로 따로 계산.
   - 하루가 지나면 Date.now 를 하루씩 밀어 시즌(원정 일지)도 실제처럼 바뀐다.
   PLAN 은 HOOK 으로 바꿀 수 있음: {"n":3,"min":20,"ad":1,"ret":1} */
(() => {
  const PL = Object.assign({ n: 3, min: 20, ad: 1, ret: 1, harvDay: 2 }, PLAN_JSON);
  const DAYS = DAYS_N;
  Object.assign(window, { toast: () => {}, queue: () => {}, renderAll: () => {}, say: () => {}, scene: () => {}, rpAdd: () => {}, save: () => {}, cardReveal: () => {}, haptic: () => {}, attSheet: () => {}, pfCheck: () => {} });
  window.setTimeout = f => {
    try {
      f();
    } catch (e) {}
    return 0;
  };
  window.playAd = done => done();
  /* 시간: 다음 시즌 시작 1시간 뒤를 1일째로 */
  const rn = Date.now.bind(Date);
  let OFF = 0;
  {
    const t = rn(),
      k = Math.ceil((t - SEAS0) / 12096e5);
    OFF = SEAS0 + k * 12096e5 + 3600e3 - t;
  }
  Date.now = () => rn() + OFF;
  window.today = () => {
    const t = new Date(Date.now() + 9 * 3600e3);
    return t.getUTCFullYear() + '-' + (t.getUTCMonth() + 1) + '-' + t.getUTCDate();
  };
  const greedy = () => {
    const o = [];
    for (const id of members()) if (id !== 'kael') o.push([compCost(S.lv[id]), () => { S.gold -= compCost(S.lv[id]); S.lv[id]++; }]);
    for (const u of UPG) { const l = S.up[u.k]; if (l < u.max) o.push([u.cost(l), () => { S.gold -= u.cost(l); S.up[u.k]++; }]); }
    o.push([boxCost(), () => { openBox(true); dailyAdd('box', 1); }]);
    for (let k = 0; k < 30; k++) { const x = o.sort((a, b) => a[0] - b[0])[0]; if (!x || S.gold < x[0]) break; x[1](); }
  };
  const f0 = fresh();
  Object.keys(S).forEach(k => delete S[k]);
  Object.assign(S, f0, { started: true, done: { pete: true }, speed: 1 });
  for (const id in P) delete P[id];
  mons = [];
  syncParty();
  /* 이삭 출처 기록: 정해 둔 꼬리표(ctx) → 전투 중이면 부른 함수 이름으로 */
  const inc = {};
  let ctx = 'etc',
    G = S.gem || 0;
  const FN = { gobDrop: '황금 고블린', towerWin: '시련의 탑 (10층마다)', retRwCheck: '은퇴 횟수 보상', bondPlay: '원정대 일기', vlClaim: '마을 레벨' };
  const tagOf = () => {
    const st = new Error().stack || '';
    for (const k in FN) if (st.includes(k)) return FN[k];
    if (ctx !== 'battle') return ctx;
    if (st.includes('gainGem')) return '군단장·마왕 첫 처치';
    if (st.includes('p2Win')) return '2부 나라 해방';
    return '칭호·기타 전투';
  };
  Object.defineProperty(S, 'gem', {
    configurable: true,
    enumerable: true,
    get: () => G,
    set: v => {
      const d = v - G;
      if (d > 0) {
        const k = tagOf();
        inc[k] = (inc[k] || 0) + d;
        day[k] = (day[k] || 0) + d;
      }
      G = v;
    }
  });
  const gainG = window.gainGem;
  window.gainGem = (n, why) => {
    const c = ctx;
    if (c === 'battle') ctx = /군단장|마왕/.test(why || '') ? '군단장·마왕 첫 처치' : '칭호·기타 전투';
    gainG(n, why);
    ctx = c;
  };
  const fightUntil = (cond, max) => {
    let t = 0;
    while (t < max && !cond()) { step(0.05); t += 0.05; }
  };
  let day = {};
  const log = [],
    weeks = [];
  let wk = {},
    stall = 0,
    best0 = 1,
    retN = 0,
    towerTop = 0;
  for (let d = 1; d <= DAYS; d++) {
    day = {};
    if (d > 1) OFF += 864e5;
    /* 출석 (두 판) + 광고 2배 */
    ctx = '출석';
    attDo(today(), 'w');
    attDo(today(), 'm');
    passAdd('att');
    if (PL.ad) {
      ctx = '광고 · 출석 2배';
      try { attAdDo(today(), 'w'); attAdDo(today(), 'm'); } catch (e) {}
    }
    for (let s = 0; s < PL.n; s++) {
      ctx = 'battle';
      const T = PL.min * 60,
        dt = 0.1;
      for (let t = 0, acc = 0; t < T && S.stage <= 50; t += dt) {
        step(dt);
        if ((acc += dt) >= 1) { acc = 0; greedy(); }
      }
      /* 오늘의 할 일 (작물 10개 수확은 밭이 생긴 날부터 한다고 가정) */
      ctx = '오늘의 할 일';
      const dd = daily();
      if (d >= PL.harvDay) dd.harv = Math.max(dd.harv || 0, 10);
      for (const m of MISSIONS) if (misCan(m)) { dd.claim[m.k] = true; gainGem(m.r, m.n); passAdd('mis'); }
      if (misCan(null)) { dd.claim.all = true; gainGem(MIS_ALL); passAdd('misall'); }
      S.gold += idleGold((16 / PL.n) * 3600);
    }
    /* 피트의 선물: 이삭 광고 */
    if (PL.ad) {
      ctx = '광고 · 피트의 이삭 +5';
      for (let i = 0; i < 3; i++) adGem();
    }
    /* 시련의 탑: 하루 한 번, 막힐 때까지 (실제 전투) */
    if (S.chOpen || S.best > 20) {
      const keep = [S.stage, S.wave];
      let f = (S.tower.top || 0) + 1,
        tries = 0;
      ctx = 'battle';
      while (f < 400) {
        towerStart(f);
        fightUntil(() => CH.st !== 'fight', 70);
        const st = CH.st;
        chExit(true);
        if (st === 'win') { f++; tries = 0; } else if (++tries >= 2) break;
      }
      S.stage = keep[0];
      S.wave = keep[1];
      towerTop = S.tower.top || 0;
      passAdd('tower');
      passAdd('tower');
      passAdd('dun');
      passAdd('dun');
    }
    if (S.bld.market || S.best > 15) { passAdd('ord'); passAdd('ord'); }
    /* 원정 일지 무료 줄 받기 */
    ctx = '원정 일지 무료 줄';
    passClaim(null);
    /* 은퇴: 하루 종일 최고 영지가 안 오르면 (은퇴 가능할 때) */
    if (S.best > best0) { best0 = S.best; stall = 0; } else stall++;
    if (PL.ret && stall >= 1 && retCan()) {
      ctx = '은퇴 횟수 보상';
      retire(retirePts());
      retN++;
      stall = 0;
      best0 = S.best;
    }
    const tot = Object.values(day).reduce((a, b) => a + b, 0);
    log.push([d, tot, Math.min(S.best - 1, 50), S.retires || 0, towerTop, JSON.stringify(day)]);
    for (const k in day) wk[k] = (wk[k] || 0) + day[k];
    if (d % 7 === 0) { weeks.push(wk); wk = {}; }
  }
  return { inc, weeks, days: log, gem: G, best: S.best, retires: S.retires || 0, tower: towerTop, stage: S.stage };
})()
