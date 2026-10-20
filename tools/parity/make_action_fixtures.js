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
    case 'equip': return w.run('(()=>{const it=pending;const c=S.eq[it.slot];if(c)S.gold+=c.price;S.eq[it.slot]=it;closeModal()})()');
    case 'sell': return w.run('(()=>{S.gold+=pending.price;closeModal()})()');
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
    default: throw new Error('모르는 조작 ' + o);
  }
}

const rep = (o, n) => Array(n).fill(o);
const CASES = {
  fresh: [base.fresh, ['gold:5000', 'box:auto', ...rep('box:auto', 45), 'box', 'equip', 'box', 'sell', 'mul:10', 'up:atk', 'up:hp', 'mul:max', 'up:spd', 'up:crit', 'mul:1', 'up:atk', 'gold:3', 'up:atk']],
  mid: [base.mid, ['box', 'equip', 'box', 'sell', 'box', 'equip', 'autosell:on', ...rep('box', 6), 'autosell:off', 'open10', 'gem:300', 'open10', 'open10', 'lv:haral', 'lv:haral', 'lv:haral', 'lv:daisy',
    'rec:daisy', 'card:daisy:45', 'rec:daisy', 'rec:gordon', 'card:gordon:31', 'rec:gordon', 'set:miner:gordon', 'auto', 'set:keeper:riel', 'en:weapon', 'en:weapon', 'en:weapon', 'en:ring', 'cw:haral', 'cw:haral', 'cw:riel',
    'wish:gordon', 'wish:gordon', 'wish:luka', 'mul:max', 'up:atk', 'up:spd']],
  late: [base.late, ['open10', 'open10', 'open10', 'auto', 'set:fisher:haral', 'auto', 'mul:max', 'up:atk', 'up:hp', 'up:spd', 'up:crit', 'rec:brida', 'card:brida:200', 'rec:brida', 'rec:nella', 'rec:luka',
    'card:luka:500', 'rec:luka', 'rec:luka', 'rec:luka', 'en:weapon', 'en:boots', 'cw:haral', 'cw:margo', 'lv:brida', 'lv:luka', ...rep('box:auto', 20), 'box', 'sell']],
};

const out = { now: NOW, cases: {} };
for (const [name, [save, ops]] of Object.entries(CASES)) {
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
