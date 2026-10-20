// 웹의 「누르면 일어나는 일」(상자 열기·10연속·단련·동료 레벨업·별 올리기·편성·대장간)을 Node 에서 그대로 실행해
// 앱(GameActions)과 비교할 정답 값을 만든다.
//   node tools/parity/make_action_fixtures.js          → app/test/fixtures/action_parity.json 갱신
//   node tools/parity/make_action_fixtures.js --check  → 최신인지만 확인
'use strict';
const fs = require('fs');
const path = require('path');
const { loadWeb } = require('./load_web.js');

const NOW = Date.UTC(2026, 9, 20, 3, 0, 0);
const w = loadWeb({ now: NOW });
const J = (x) => JSON.parse(JSON.stringify(x));
const F = (n) => w.run(n);
w.ctx.renderAll = () => {};

const base = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'app', 'test', 'fixtures', 'web_parity.json'), 'utf8')).saves;
const q = (x) => JSON.stringify(x);

// 조작 하나를 웹 코드로 실행. 앱 테스트도 같은 이름의 조작을 한다.
function op(o) {
  const [k, a, b] = o.split(':');
  switch (k) {
    case 'box': return F('openBox')(a === 'auto');
    case 'equip': return w.run('(()=>{if(!pending)return;const it=pending;const c=S.eq[it.slot];if(c)S.gold+=c.price;S.eq[it.slot]=it;closeModal()})()');
    case 'sell': return w.run('(()=>{if(!pending)return;S.gold+=pending.price;closeModal()})()');
    case 'open10': return F('open10')();
    case 'mul': return w.run(`S.upMul=${a === 'max' ? "'max'" : a}`);
    case 'up': return F('upFire')(a);
    case 'lv': return w.run(`(()=>{const id=${q(a)};const cc=compCost(S.lv[id]||1);if(S.gold<cc)return;S.gold-=cc;S.lv[id]=(S.lv[id]||1)+1})()`);
    case 'rec': return F('recruitUp')(a);
    case 'set': return F('setMember')(a, b);
    case 'auto': return F('autoForm')();
    case 'en': return w.run(`(()=>{const k=${q(a)},l=enLv(k),c=enCost(l);if(l>=EN_MAX||(S.items.ore||0)<c)return;S.items.ore-=c;if(!S.slotEn)S.slotEn={};S.slotEn[k]=l+1})()`);
    case 'cw': return w.run(`(()=>{const id=${q(a)},l=cwLv(id),o=cwOre(l),g=cwGold(l);if(!S.joined[id]||l>=CW_MAX||(S.items.ore||0)<o||S.gold<g)return;S.items.ore-=o;S.gold-=g;if(!S.cwEn)S.cwEn={};S.cwEn[id]=l+1})()`);
    case 'wish': return w.run(`S.wish=S.wish===${q(a)}?null:${q(a)}`);
    case 'autosell': return w.run(`S.autoSell=${a === 'on'}`);
    case 'gold': return w.run(`S.gold=${a}`);
    case 'gem': return w.run(`S.gem=${a}`);
    case 'card': return w.run(`S.cards=S.cards||{};S.cards[${q(a)}]=${b}`);
    // ── 마을 (5단계) ──
    case 'ensure': return F('ensurePlots')();
    case 'plant': return F('plant')(+a, b);
    case 'plantc': return w.run(`(()=>{const i=${+a},k=${q(b)};if(!S.plotTag)S.plotTag=[];S.plotTag[i]=k;plant(i,k)})()`);
    case 'choose': return F('chooseSeed')(+a);
    case 'harv': return F('harvest')(+a);
    case 'tap': return w.run(`(()=>{const i=${+a};const ps=plotState(S.plots[i]);if(ps.st==='ready'){harvest(i)}})()`);
    case 'harvall': return w.run('(()=>{let t=0;S.plots.forEach((p,i)=>t+=harvest(i))})()');
    case 'plantall': return w.run("(()=>{S.plots.forEach((p,i)=>{if(p)return;const t=plotTag(i);if(t){if(S.seeds[t]>0)plant(i,t);return}const c=[...CROPS].reverse().find(c=>S.seeds[c.k]>0);if(c)plant(i,c.k)})})()");
    case 'tag': return F('cycleTag')(+a);
    case 'gemplot': return w.run('(()=>{const n=S.gemPlots||0,c=GEM_PLOTS[n];if(c==null)return;if(!spendGem(c))return;S.gemPlots=n+1;ensurePlots()})()');
    case 'grownow': return F('growNow')();
    case 'cook': return w.run(`(()=>{const r=RECIPES.find(x=>x.k===${q(a)});if(!Object.entries(r.need).every(([k,n])=>S.items[k]>=n))return;for(const[k,n]of Object.entries(r.need))S.items[k]-=n;S.buffs[r.buff]=Math.max(Date.now(),S.buffs[r.buff]||0)+600000;stat('cook',1)})()`);
    case 'sellall': return w.run('(()=>{const keys=Object.keys(S.items),val=keys.reduce((a,k)=>a+S.items[k]*itemPrice(k),0);S.gold+=val;keys.forEach(k=>S.items[k]=0)})()');
    case 'build': return F('orderBuild')(F('bldK')(a));
    case 'cancel': return F('cancelQueued')(a);
    case 'bgem': return w.run(`(()=>{const b=bldK(${q(a)}),l=S.bld[b.k];if(l>=b.max||inBuild(b.k))return;if(!oreOk(b,l))return;if(!spendGem(bldGem(bldCost(b,l))+timeGem(bldTime(b,l))))return;S.items.ore-=bldOre(b,l);S.bld[b.k]=l+1;if(!l)S.prod[b.k]=Date.now()})()`);
    case 'bfin': return w.run('(()=>{if(!building()||!spendGem(timeGem(buildLeft())))return;finishBuild()})()');
    case 'time': { clock += +a; w.setNow(clock); return F('produce')(); }
    case 'seeds': return w.run(`S.seeds[${q(a)}]=${b}`);
    case 'items': return w.run(`S.items[${q(a)}]=${b}`);
    // ── 피트의 상점 ──
    case 'daily': return w.run(`daily()[${q(a)}]=${b}`);
    case 'mis': return w.run(`(()=>{const k=${q(a)},m=MISSIONS.find(x=>x.k===k);if(!misCan(m||null))return;daily().claim[k]=true;if(k==='all'){gainCard(5)}gainGem(m?m.r:MIS_ALL,m?m.n:'오늘의 할 일 완료')})()`);
    case 'gx': return F('buyGoldX')(a);
    case 'cp': return w.run(`(()=>{const c=CARDPK[${+a}];if(!CARDIDS().some(x=>cardOpen(x)&&recStar(x)<starMax(x)))return;if(!spendGem(c.gem))return;if(c.n>=30){const av=g=>CARDIDS().some(x=>cardOpen(x)&&gr(x).w<=GR[g].w&&recStar(x)<starMax(x));gainCard(c.n,av('epic')?'epic':av('rare')?'rare':null)}else for(let i=0;i<c.n;i++)gainCard(1)})()`);
    case 'pack': return F('buyPack')(F('PACKS').find((p) => p.k === a));
    case 'starter': return F('buyStarter')();
    case 'sub': return F('buySub')();
    case 'subclaim': return F('claimSub')();
    case 'adbox': return w.run('(()=>{S.gold+=boxCost();openBox(false)})()');
    case 'adgem': return w.run('(()=>{S.gem=(S.gem||0)+5})()');
    case 'adcard': return w.run('(()=>{for(let i=0;i<3;i++)gainCard(1)})()');
    default: throw new Error('모르는 조작 ' + o);
  }
}

const rep = (o, n) => Array(n).fill(o);
let clock = NOW;
const H = 3600000, M = 60000;
const CASES = {
  fresh: [base.fresh, ['gold:5000', 'box:auto', ...rep('box:auto', 45), 'box', 'equip', 'box', 'sell', 'mul:10', 'up:atk', 'up:hp', 'mul:max', 'up:spd', 'up:crit', 'mul:1', 'up:atk', 'gold:3', 'up:atk']],
  mid: [base.mid, ['box', 'equip', 'box', 'sell', 'box', 'equip', 'autosell:on', ...rep('box', 6), 'autosell:off', 'open10', 'gem:300', 'open10', 'open10', 'lv:haral', 'lv:haral', 'lv:haral', 'lv:daisy',
    'rec:daisy', 'card:daisy:45', 'rec:daisy', 'rec:gordon', 'card:gordon:31', 'rec:gordon', 'set:miner:gordon', 'auto', 'set:keeper:riel', 'en:weapon', 'en:weapon', 'en:weapon', 'en:ring', 'cw:haral', 'cw:haral', 'cw:riel',
    'wish:gordon', 'wish:gordon', 'wish:luka', 'mul:max', 'up:atk', 'up:spd']],
  late: [base.late, ['open10', 'open10', 'open10', 'auto', 'set:fisher:haral', 'auto', 'mul:max', 'up:atk', 'up:hp', 'up:spd', 'up:crit', 'rec:brida', 'card:brida:200', 'rec:brida', 'rec:nella', 'rec:luka',
    'card:luka:500', 'rec:luka', 'rec:luka', 'rec:luka', 'en:weapon', 'en:boots', 'cw:haral', 'cw:margo', 'lv:brida', 'lv:luka', ...rep('box:auto', 20), 'box', 'sell']],
  // 마을: 밭·전용 밭·황금 밭·바로 키우기·요리·판매·공사(예약·취소·바로 짓기·바로 완료)·시간 흐름
  village: [base.mid, ['ensure', 'seeds:wheat:9', 'seeds:carrot:4', 'seeds:pumpkin:2', 'plant:2:wheat', 'plantc:3:carrot', 'tag:5', 'tag:5', 'choose:5', 'choose:3', 'plantall',
    'time:' + 2 * M, 'tap:0', 'harv:2', 'time:' + 6 * M, 'harvall', 'plantall', 'gem:500', 'grownow', 'harvall', 'gemplot', 'gemplot', 'ensure', 'plantall', 'time:' + 25 * M, 'harvall',
    'items:wheat:30', 'items:fish:9', 'cook:bread', 'cook:bread', 'cook:stew', 'cook:pie', 'cook:grill', 'time:' + 5 * M, 'cook:bread',
    'gold:1e12', 'build:farm', 'build:diner', 'build:dock', 'build:inn', 'cancel:diner', 'build:apiary', 'time:' + 30 * M, 'bfin', 'bgem:inn', 'bgem:mine', 'time:' + 3 * H, 'time:' + 13 * H,
    'items:ore:3', 'build:diner', 'bgem:diner', 'items:ore:9999', 'build:diner', 'sellall', 'tag:0', 'tag:0', 'tag:0', 'tag:0', 'tag:9']],
  // 첫 공사: 이삭 10개 선물 → 바로 완료
  firstBuild: [Object.assign({}, base.fresh, { stage: 3, best: 3, done: { marta: true }, bld: { farm: 1 } }), ['gold:100000', 'ensure', 'build:inn', 'bfin', 'build:farm', 'build:inn', 'time:' + 2 * H, 'gem:3', 'build:farm', 'bfin', 'time:' + 24 * H]],
  // 피트의 상점: 할 일 보상·무료 선물·골드 바꾸기·카드 묶음·꾸러미·첫 거래·정기 배송 (결제는 시험용 바로 지급)
  shop: [base.mid, ['mis:kill', 'daily:kill:150', 'mis:kill', 'mis:kill', 'daily:box:10', 'daily:harv:12', 'mis:all', 'mis:box', 'mis:harv', 'mis:all', 'mis:all',
    'gem:20', 'gx:g1', 'gx:g2', 'gem:5000', 'gx:g1', 'gx:g2', 'gx:g3', 'cp:0', 'cp:1', 'cp:1', 'cp:0',
    'pack:p1', 'pack:p1', 'pack:p6', 'starter', 'starter', 'sub', 'subclaim', 'time:' + 24 * H, 'subclaim', 'subclaim', 'sub',
    'adgem', 'adcard', 'adbox', 'sell', 'gold:0', 'adbox', 'equip']],
  // 전설 어부 막례: 카드 모아 맞이하기 → 별 올리기 → 편성 → 낚시터 생선 생산 「물질 대장」
  makrye: [base.mid, ['ensure', 'card:makrye:29', 'rec:makrye', 'card:makrye:30', 'rec:makrye', 'set:fisher:makrye', 'time:' + 10 * M, 'card:makrye:40', 'rec:makrye', 'time:' + 30 * M, 'auto', 'card:makrye:999', 'rec:makrye', 'rec:makrye', 'rec:makrye', 'rec:makrye', 'time:' + 2 * H, 'lv:makrye', 'cw:makrye']],
  // 카드 동료가 아직 없을 때 카드 묶음
  shopEarly: [base.fresh, ['gem:999', 'cp:0', 'cp:1', 'adcard', 'mis:all']],
};

const out = { now: NOW, cases: {} };
for (const [name, [save, ops]] of Object.entries(CASES)) {
  clock = NOW;
  w.setNow(NOW);
  w.setS(F('hydrate')(J(save)));
  w.run('pending=null;P={};mons=[];');
  w.setSeed(9090);
  const steps = [];
  for (const o of ops) {
    op(o);
    steps.push({ op: o, S: J(w.run('S')), pending: J(w.run('pending')),
      plan: J(w.run('UPG.map(u=>upPlan(u))')) });
  }
  out.cases[name] = { save: J(save), steps };
}

const file = path.join(__dirname, '..', '..', 'app', 'test', 'fixtures', 'action_parity.json');
const text = JSON.stringify(out) + '\n';
if (process.argv.includes('--check')) {
  const cur = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  if (cur !== text) {
    console.error('action_parity.json 이 index.html 과 맞지 않아요. node tools/parity/make_action_fixtures.js 를 실행해 갱신하세요.');
    process.exit(1);
  }
  console.log('action_parity.json 최신 상태');
} else {
  fs.writeFileSync(file, text);
  console.log('저장:', path.relative(process.cwd(), file), (text.length / 1024).toFixed(0) + 'KB');
  for (const [n, c] of Object.entries(out.cases)) {
    const l = c.steps[c.steps.length - 1].S;
    console.log(n, '골드', Math.round(l.gold), '이삭', l.gem, '상자Lv', l.boxLv, '단련', JSON.stringify(l.up), 'rec', JSON.stringify(l.rec || {}), 'party', JSON.stringify(l.party || {}));
  }
}
