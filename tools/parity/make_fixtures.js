// 웹 버전 공식의 "정답 값"을 뽑아 app/test/fixtures/web_parity.json 으로 저장한다.
// 앱 테스트(app/test/parity_test.dart)가 이 값과 Dart 공식 결과를 비교한다.
//   node tools/parity/make_fixtures.js          → 파일 갱신
//   node tools/parity/make_fixtures.js --check  → 파일이 최신인지만 확인(다르면 실패)
'use strict';
const fs = require('fs');
const path = require('path');
const { loadWeb } = require('./load_web.js');

const NOW = Date.UTC(2026, 9, 20, 3, 0, 0); // 2026-10-20 12:00 KST (UTC 와 날짜가 같은 시각)
const MIN = 60000, HOUR = 3600000;
const w = loadWeb({ now: NOW });
const J = (x) => JSON.parse(JSON.stringify(x));
const run = (src) => J(w.run(src));
const F = (name) => w.run(name); // 웹의 함수·상수 꺼내기 (const 로 선언된 것도)

// ── 시험용 저장 데이터 (웹 저장 구조 S 그대로) ──
const item = (slot, g, lv, atk, hp, price) => ({ slot, g, lv, atk, hp, price });
const SAVES = {
  fresh: { gold: 60 },
  mid: {
    gold: 123456.7, stage: 23, wave: 4, best: 25, boxLv: 4, boxXp: 7, started: true, last: NOW - 30 * MIN,
    up: { atk: 40, hp: 30, spd: 10, crit: 12 },
    eq: {
      weapon: item('weapon', 3, 22, 1031, 0, 300), helm: item('helm', 2, 20, 0, 1010, 200),
      armor: item('armor', 2, 23, 0, 1850, 210), gloves: item('gloves', 1, 21, 120, 210, 90),
      boots: item('boots', 4, 24, 140, 1900, 900),
    },
    slotEn: { weapon: 5, armor: 3, boots: 1 }, cwEn: { haral: 4, bron: 2, margo: 1 },
    bld: { inn: 4, farm: 3, diner: 5, dock: 2, apiary: 3, mine: 2 },
    joined: { margo: true, haral: true, riel: true, bron: true },
    done: { marta: true, margo: true, haral: true, riel: true, bron: true, pete: true, tutBuild: true },
    lv: { bron: 5, haral: 7, riel: 4, margo: 6, daisy: 2 },
    memory: 3, retires: 1, rec: { daisy: 2 }, cards: { daisy: 11, gordon: 7, luka: 3, haral: 9 },
    party: { keeper: 'daisy' }, wish: 'gordon',
    buffs: { atk: NOW + 5 * MIN, crit: NOW - 1000, gold: NOW + 2 * MIN },
    items: { wheat: 12, carrot: 3, pumpkin: 1, fish: 40, honey: 22, ore: 31 },
    seeds: { wheat: 4, carrot: 2, pumpkin: 0 },
    plots: [{ k: 'wheat', at: NOW - 2 * MIN }, { k: 'carrot', at: NOW - 1 * MIN }, null, null, { k: 'pumpkin', at: NOW - 30 * MIN }],
    prod: { dock: NOW - 9 * MIN, apiary: NOW - 3 * MIN, mine: NOW - 61 * MIN },
    sub: { until: NOW + 10 * 24 * HOUR, last: '2026-10-19' }, gem: 77, gemPlots: 1,
    daily: { d: '2026-10-20', kill: 55, box: 10, harv: 4, claim: { box: true }, ad: { box: 2 } },
    build: { k: 'diner', end: NOW - 5 * MIN, dur: 3600 }, bq: ['dock'],
    pf: 'wood', pfUnl: { wood: 1 }, v: 3,
  },
  late: {
    gold: 9.87e14, stage: 45, wave: 9, best: 46, boxLv: 10, boxXp: 0, started: true, last: NOW - 20 * HOUR,
    up: { atk: 900, hp: 850, spd: 40, crit: 55 },
    eq: {
      weapon: item('weapon', 5, 46, 22000, 0, 9e9), helm: item('helm', 4, 45, 0, 99000, 5e9),
      armor: item('armor', 5, 44, 0, 260000, 8e9), gloves: item('gloves', 5, 46, 14000, 30000, 8e9),
      boots: item('boots', 4, 47, 6000, 60000, 6e9), ring: item('ring', 5, 45, 11000, 40000, 8e9),
    },
    slotEn: { weapon: 20, helm: 18, armor: 20, gloves: 15, boots: 12, ring: 19 },
    cwEn: { haral: 20, bron: 17, margo: 12, riel: 15 },
    bld: { inn: 10, farm: 6, diner: 10, dock: 10, apiary: 9, mine: 10 },
    joined: { margo: true, haral: true, riel: true, bron: true },
    done: { marta: true, margo: true, haral: true, riel: true, bron: true },
    lv: { bron: 60, haral: 61, riel: 58, margo: 55, brida: 40, nella: 33, luka: 20, daisy: 12, gordon: 9 },
    memory: 12, retires: 4,
    rec: { brida: 3, luka: 1, nella: 5, gordon: 2, daisy: 4 },
    cards: { brida: 70, luka: 29, nella: 0, gordon: 15, daisy: 79, bron: 3 },
    party: { miner: 'brida', fisher: 'nella', keeper: 'riel', cook: 'luka' },
    buffs: { spd: NOW + 9 * MIN, atk: NOW + 1 * MIN, crit: NOW + 3 * MIN },
    items: { wheat: 400, carrot: 120, pumpkin: 55, fish: 2000, honey: 1500, ore: 980 },
    prod: { dock: NOW - 50 * MIN, apiary: NOW - 50 * MIN, mine: NOW - 50 * MIN },
    gem: 5000, v: 3,
  },
  // 안내(다음 할 일) 단계 확인용
  g1: { gold: 100, stage: 4, best: 4, eq: { weapon: item('weapon', 0, 2, 6, 0, 5) } },
  g2: { gold: 100, stage: 8, best: 8, up: { atk: 3, hp: 0, spd: 0, crit: 0 }, eq: { weapon: item('weapon', 0, 2, 6, 0, 5) }, joined: { margo: true }, done: { marta: true } },
  g3: { gold: 100, stage: 14, best: 14, up: { atk: 3 }, bld: { inn: 1, farm: 1 }, joined: { margo: true }, lv: { margo: 2 }, done: { marta: true }, stat: { harv: 4 } },
  g4: { gold: 100, stage: 22, best: 22, up: { atk: 3 }, bld: { inn: 1, farm: 1 }, joined: { margo: true }, lv: { margo: 2 }, done: { marta: true }, stat: { harv: 4 }, daily: { d: '2026-10-20', kill: 0, box: 0, harv: 0, claim: { box: true } } },
  // 옛 저장(v 없음): crops 필드 → items 로 합치기, rankSeen 계산
  old: { gold: 500, stage: 14, best: 14, crops: { wheat: 7, carrot: 2 }, items: { wheat: 1 }, joined: { margo: true }, lv: { margo: 3 } },
};

function setSave(name) {
  w.setNow(NOW);
  const s = F('hydrate')(J(SAVES[name]));
  w.setS(s);
  return s;
}

const out = { now: NOW, saves: SAVES, scenarios: {}, stages: [], fmt: {}, misc: {} };

// ── 영지별 표 ──
for (let st = 1; st <= 60; st++) {
  out.stages.push(run(`({st:${st},hpN:monHp(${st},false),hpB:monHp(${st},true),atkN:monAtk(${st},false),atkB:monAtk(${st},true),
    gN:reward(${st},false),gB:reward(${st},true),region:REGIONS.indexOf(region(${st})),terr:terrName(${st}),lord:isLord(${st}),boss:bossName(${st})})`));
}

// ── 숫자 표시 ──
const NUMS = [0, 1, 9.99, 12.5, 999, 1234, 9999, 10000, 12345, 99999, 123456, 999999, 1e6, 1234567, 2.5e9, 7.77e12, 1e15, 3.3e16, 1e18, 4.56e21, 1e30, 9.9e40, 1e80, Infinity];
out.fmt.fmt = NUMS.map((n) => [n === Infinity ? 'Infinity' : n, F('fmt')(n)]);
out.fmt.fmtT = [0, 1, 59, 60, 61, 125, 599, 600, 3599, 3600, 3660, 7200, 43200, 50000].map((s) => [s, F('fmtT')(s)]);
out.fmt.mmss = [0, 1, 59, 60, 125, 3599, 3600].map((s) => [s, F('mmss')(s)]);

// ── 상태별 공식 ──
const IDS = run('CARDIDS()');
const COMPS = run('Object.keys(COMP)');
for (const name of Object.keys(SAVES)) {
  setSave(name);
  const sc = {};
  sc.hydrated = run('S');
  sc.basic = run(`({rankIdx:rankIdx(),memMul:memMul(),allMul:allMul(),boxCost:boxCost(),xpNeed:xpNeed(),odds:odds(),
    retireTarget:retireTarget(),retirePts:retirePts(),plotCount:plotCount(),landCount:landCount(),vpMine:vpMine(),
    members:members(),power:power(),gemGold:gemGold(),goldRate:goldRate(),goldX:GOLDX.map(goldX),
    buffs:Object.keys(BUFFN).map(k=>buff(k)),subOn:subOn(),gearSum:gearSum(),kStats:kStats(),
    guide:(S.retires>0||S.best>30)?-1:GUIDE.findIndex((x,j)=>!x.ok()&&!(j<3&&S.best>12))})`);
  sc.comp = {};
  for (const id of COMPS) {
    sc.comp[id] = run(`({stats:${id === 'kael' ? 'kStats()' : `cStats('${id}')`},cPow:cPow('${id}'),owned:owned('${id}'),
      recStar:${id === 'kael' ? 0 : `recStar('${id}')`},starMul:starMul('${id}'),skPow:skPow('${id}'),
      cardOpen:${id === 'kael' ? false : `cardOpen('${id}')`},starNeed:${id === 'kael' ? null : `(starNeed('${id}')??null)`},
      starMax:${id === 'kael' ? null : `starMax('${id}')`},cwLv:cwLv('${id}'),cwMul:cwMul('${id}')})`);
  }
  sc.slots = run(`Object.fromEntries(JSLOT.map(j=>[j,{member:slotMember(j),all:j==='kael'?['kael']:jobMembers(j),better:j==='kael'?false:betterBench(j)}]))`);
  sc.costs = run(`({
    en:Array.from({length:21},(_,l)=>enCost(l)),cwOre:Array.from({length:21},(_,l)=>cwOre(l)),cwGold:Array.from({length:21},(_,l)=>cwGold(l)),
    comp:Array.from({length:80},(_,i)=>compCost(i+1)),
    upg:Object.fromEntries(UPG.map(u=>[u.k,Array.from({length:61},(_,l)=>u.cost(l))])),
    bld:Object.fromEntries(BLD.map(b=>[b.k,Array.from({length:b.max+1},(_,l)=>({cost:bldCost(b,l),ore:bldOre(b,l),time:bldTime(b,l),gem:bldGem(bldCost(b,l))+timeGem(bldTime(b,l))}))])),
    bldOpen:Object.fromEntries(BLD.map(b=>[b.k,!!b.open()])),
    bldEff:Object.fromEntries(BLD.map(b=>[b.k,Array.from({length:b.max+1},(_,l)=>b.eff(l))])),
    price:Object.fromEntries([...CROPS,...GOODS].map(c=>[c.k,itemPrice(c.k)])),
    timeGem:[0,1,179,180,181,3600,43200].map(timeGem),
    adLeft:Object.fromEntries(Object.keys(ADS).map(k=>[k,adLeft(k)])),
    cardReady:cardReady(),nextGoal:nextGoal()})`);
  // 방치 보상: offline() 이 더하는 골드 (S.last 기준)
  {
    const gold0 = w.getS().gold;
    F('offline')();
    sc.offline = w.getS().gold - gold0;
  }
  // 생산(낚시터·양봉장·광산)과 공사 완료
  setSave(name);
  F('produce')();
  sc.produced = run('({items:S.items,prod:S.prod,bld:S.bld,build:S.build??null,bq:S.bq??null})');
  // 밭 상태
  setSave(name);
  sc.plots = run('S.plots.map(p=>{const s=plotState(p);return{st:s.st,k:s.c?s.c.k:null,left:s.left??null}})');
  // 난수: 성유물 상자·카드
  setSave(name);
  w.setSeed(4242);
  sc.rolls = { items: [], forced: [], cards: [] };
  for (let i = 0; i < 40; i++) sc.rolls.items.push(J(F('rollItem')()));
  for (let g = 0; g < 6; g++) sc.rolls.forced.push(J(F('rollItem')(g)));
  w.setSeed(777);
  for (let i = 0; i < 30; i++) sc.rolls.cards.push(F('gainCard')(1) ?? null);
  sc.rolls.cards.push(F('gainCard')(30, 'battle') ?? null);
  for (let i = 0; i < 20; i++) sc.rolls.cards.push(F('gainCard')(2, 'battle') ?? null);
  sc.rolls.chunks = F('gainCards')(30, 'shop', 5);
  sc.rolls.cardsAfter = run('S.cards??null');
  sc.rolls.goldAfter = run('S.gold');
  // 은퇴
  // (retire 끝의 화면 새로 그리기 renderAll 은 칭호 테두리·밭 칸 정리 같은 다른 일도 하므로 잠시 끄고 잰다)
  setSave(name);
  {
    const ra = w.ctx.renderAll;
    w.ctx.renderAll = () => {};
    F('retire')(5);
    w.ctx.renderAll = ra;
  }
  sc.retired = run('S');
  // 프로필 테두리·배지 (pfCheck)
  setSave(name);
  F('pfCheck')();
  sc.pf = run('({pfUnl:S.pfUnl,bdUnl:S.bdUnl,pfNew:S.pfNew??null})');
  // 오늘의 할 일 날짜 바뀜
  setSave(name);
  w.setNow(NOW + 24 * HOUR);
  sc.dailyNext = run('daily()');
  w.setNow(NOW);
  out.scenarios[name] = sc;
}

// 저장 코드: 웹 설정의 「코드 만들기」와 똑같이 만든 코드 (앱이 그대로 불러와야 함)
out.codes = {};
for (const name of ['mid', 'late', 'old']) {
  setSave(name);
  out.codes[name] = w.run('btoa(unescape(encodeURIComponent(JSON.stringify(S))))');
}

out.misc.cardIds = IDS;
// 랭킹: 영지 이름·시즌 끝·주차·서버에 보내는 꾸미기 정보
out.misc.stgName = [1, 2, 10, 11, 37, 50, 51, 99].map((n) => [n, F('stgName')(n)]);
out.misc.seasonEnd = F('seasonEnd')();
out.misc.curWeek = F('curWeek')();
out.misc.compIds = COMPS;

const file = path.join(__dirname, '..', '..', 'app', 'test', 'fixtures', 'web_parity.json');
const text = JSON.stringify(out, null, 1) + '\n';
if (process.argv.includes('--check')) {
  const cur = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  if (cur !== text) {
    console.error('web_parity.json 이 index.html 과 맞지 않아요. node tools/parity/make_fixtures.js 를 실행해 갱신하세요.');
    process.exit(1);
  }
  console.log('web_parity.json 최신 상태');
} else {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text);
  console.log('저장:', path.relative(process.cwd(), file), (text.length / 1024).toFixed(0) + 'KB');
}
