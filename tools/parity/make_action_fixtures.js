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
  const [k, a, b, c] = o.split(':');
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
    case 'en': return w.run(`(()=>{const k=${q(a)},l=enLv(k),c=enCost(l);if(!S.bld.forge||l>=enMax()||(S.items.ore||0)<c)return;S.items.ore-=c;if(!S.slotEn)S.slotEn={};S.slotEn[k]=l+1})()`);
    case 'cw': return w.run(`(()=>{const id=${q(a)},l=cwLv(id),o=cwOre(l),g=cwGold(l);if(!S.bld.forge||!S.joined[id]||l>=enMax()||(S.items.ore||0)<o||S.gold<g)return;S.items.ore-=o;S.gold-=g;if(!S.cwEn)S.cwEn={};S.cwEn[id]=l+1})()`);
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
    case 'cook': return w.run(`(()=>{const r=RECIPES.find(x=>x.k===${q(a)});if(!Object.entries(r.need).every(([k,n])=>S.items[k]>=n))return;for(const[k,n]of Object.entries(r.need))S.items[k]-=n;S.buffs[r.buff]=Math.max(Date.now(),S.buffs[r.buff]||0)+cookMs();stat('cook',1)})()`);
    case 'sellall': return w.run('(()=>{const keys=Object.keys(S.items),kp=ordKeep();let v=0;keys.forEach(k=>{const n=Math.max(0,(S.items[k]||0)-(kp[k]||0));v+=n*itemPrice(k);S.items[k]-=n});S.gold+=v})()');
    case 'build': return F('orderBuild')(F('bldK')(a));
    case 'cancel': return F('cancelQueued')(a);
    case 'bgem': return w.run(`(()=>{const b=bldK(${q(a)}),l=S.bld[b.k];if(l>=b.max||inBuild(b.k))return;if(!oreOk(b,l))return;if(!spendGem(bldGem(bldCost(b,l))+timeGem(bldTime(b,l))))return;S.items.ore-=bldOre(b,l);S.bld[b.k]=l+1;if(!l)S.prod[b.k]=Date.now()})()`);
    case 'bfin': return w.run('(()=>{if(!building()||!spendGem(timeGem(buildLeft())))return;finishBuild()})()');
    case 'time': { clock += +a; w.setNow(clock); return F('produce')(); }
    case 'seeds': return w.run(`S.seeds[${q(a)}]=${b}`);
    case 'items': return w.run(`S.items[${q(a)}]=${b}`);
    // ── 마을 확장 (docs/content/VILLAGE.md) ──
    case 'bld': return w.run(`S.bld[${q(a)}]=${+b}`);
    case 'otick': return F('ordTick')();
    case 'odeliver': return F('ordDeliver')(+a);
    case 'oskip': return F('ordSkip')(+a);
    case 'keep': return w.run(`S.keepOrder=${+a}`);
    case 'blessfirst': return w.run('(()=>{const o=blessOpts();if(o.length)blessPick(o[0])})()');
    case 'blessad': return w.run('(()=>{blessDay().ad=1;S.bless.opts=[]})()');
    case 'wkput': return F('wkPut')(a, +b, c);
    case 'wkout': return w.run(`S.work[${q(a)}]=wkIds(${q(a)}).filter(x=>x!==${q(b)})`);
    case 'wkauto': return F('wkAuto')(a === '1');
    case 'wkclear': return w.run('S.work={}');
    case 'vlclaim': return F('vlClaim')();
    case 'harvre': return F('harvestAll')();
    // ── 피트의 상점 ──
    case 'daily': return w.run(`daily()[${q(a)}]=${b}`);
    case 'mis': return w.run(`(()=>{const k=${q(a)},m=MISSIONS.find(x=>x.k===k);if(!misCan(m||null))return;daily().claim[k]=true;passAdd(k==='all'?'misall':'mis');if(k==='all'){gainCard(5,'shop')}gainGem(m?m.r:MIS_ALL,m?m.n:'오늘의 할 일 완료')})()`);
    case 'gx': return F('buyGoldX')(a);
    case 'cp': return w.run(`(()=>{const c=CARDPK[${+a}];if(!CARDIDS().some(x=>cardOpen(x)&&recStar(x)<starMax(x)))return;if(!spendGem(c.gem))return;gainCards(c.n,'shop',c.n>=30?5:1)})()`);
    case 'pack': return F('buyPack')(F('PACKS').find((p) => p.k === a));
    case 'starter': return F('buyStarter')();
    case 'sub': return F('buySub')();
    case 'subclaim': return F('claimSub')();
    // ── 카엘 촌장 ──
    case 'chief': return F('buyChief')();
    case 'chiefchk': return F('chiefCheck')();
    case 'chiefup': return F('chiefUp')();
    case 'kseat': return F('setKaelSeat')(a);
    case 'ucard': return w.run(`S.ucard=${+a}`);
    case 'retires': return w.run(`S.retires=${+a}`);
    case 'adbox': return w.run('(()=>{S.gold+=boxCost();openBox(false)})()');
    case 'adgem': return w.run('(()=>{S.gem=(S.gem||0)+5})()');
    case 'adcard': return w.run("(()=>{gainCards(3,'shop',1)})()");
    case 'att': return F('attDo')(a);
    case 'attad': return F('attAdDo')(a);
    case 'attm': return w.run(`(()=>{const x=attA();x.ym=${q(a)};x.m=${+b}})()`);
    case 'tk': return w.run(`S.tickets[${q(a)}]=${+b}`);
    // ── 상점·패스 (docs/content/SHOP.md): 원정 일지 · 영주의 첫걸음 ──
    case 'started': return w.run('S.started=true');
    case 'padd': return F('passAdd')(a);
    case 'pkill': return w.run(`for(let i=0;i<${+a};i++)passKill()`);
    case 'ppt': return w.run(`passS().pt=${+a}`);
    case 'pclaim': return a ? F('passClaim')(a, +b) : F('passClaim')();
    case 'pbuy': return F('buyPass')();
    case 'popen': return F('passOpen')(+a);
    case 'pmail': return F('passMailClaim')(a || null);
    case 'pwarn': return F('passWarn')();
    case 'best': return w.run(`S.best=${+a}`);
    case 'grow': return F('buyGrow')();
    case 'growgive': return F('growGive')();
    case 'growchk': return F('growCheck')();
    // ── 유니크 뚝딱이 ──
    case 'tbuy': return F('buyTtuk')();
    case 'uqup': return F('uqUp')(a);
    // ── 유니크 루시안 ──
    case 'lbuy': return F('buyLucian')();
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
  // 마을 확장: 주문(납품·덤·이삭 한도·다른 주문·1시간 갱신)·창고 판매 주문 재료 남기기·축복(광고 1번 더)·일꾼(추천·편성으로 빠짐)·마을 레벨 보상·새 요리·대장간
  village2: [base.vill, ['otick', 'odeliver:0', 'odeliver:2', 'odeliver:3', 'items:fish:500', 'items:egg:50', 'items:milk:60', 'otick', 'odeliver:0', 'odeliver:1', 'odeliver:2', 'oskip:1', 'oskip:1',
    'time:' + 61 * M, 'otick', 'oskip:1', 'items:ore:999', 'items:honey:999', 'items:wheat:999', 'items:pumpkin:999', 'otick', 'odeliver:0', 'odeliver:1', 'odeliver:2', 'odeliver:3', 'odeliver:4',
    'keep:1', 'sellall', 'otick', 'keep:0', 'sellall', 'blessfirst', 'blessfirst', 'blessad', 'blessfirst', 'blessad',
    'wkauto:0', 'wkput:inn:0:haral', 'set:fisher:haral', 'wkout:mine:gordon', 'wkauto:1', 'wkclear', 'wkauto:0', 'bld:market:9', 'otick', 'vlclaim', 'bld:chapel:10', 'vlclaim', 'vlclaim',
    'items:milk:10', 'items:carrot:10', 'items:wheat:10', 'cook:soup', 'items:egg:9', 'items:pumpkin:9', 'cook:pancake', 'time:' + 30 * M,
    'en:weapon', 'en:weapon', 'en:weapon', 'cw:haral', 'bld:forge:0', 'en:helm', 'gem:0', 'ensure', 'seeds:wheat:9', 'plantall', 'time:' + 3 * M, 'harvre', 'time:' + 2 * H]],
  // 첫 공사: 이삭 10개 선물 → 바로 완료
  firstBuild: [Object.assign({}, base.fresh, { stage: 3, best: 3, done: { marta: true }, bld: { farm: 1 } }), ['gold:100000', 'ensure', 'build:inn', 'bfin', 'build:farm', 'build:inn', 'time:' + 2 * H, 'gem:3', 'build:farm', 'bfin', 'time:' + 24 * H]],
  // 희귀 동료 3명(토비·카라·베릴) 맞이하기·별·편성 + 카드 묶음 나눠 받기
  rares: [base.mid, ['card:toby:30', 'rec:toby', 'card:kara:30', 'rec:kara', 'card:beryl:45', 'rec:beryl', 'rec:beryl', 'set:fisher:toby', 'set:cook:kara', 'set:miner:beryl', 'gem:2000', 'cp:1', 'cp:1', 'wish:kara', 'cp:1', 'cp:0', 'adcard', 'en:weapon', 'cw:haral']],
  commons: [base.mid, ['card:mora:30', 'rec:mora', 'card:melo:30', 'rec:melo', 'card:pori:50', 'rec:pori', 'rec:pori', 'set:fisher:mora', 'set:keeper:melo', 'set:cook:pori', 'cp:1', 'wish:pori', 'cp:1']],
  commons2: [base.mid, ['card:rollo:30', 'rec:rollo', 'card:crab:30', 'rec:crab', 'card:birch:30', 'rec:birch', 'card:gram:50', 'rec:gram', 'rec:gram', 'set:miner:rollo', 'set:fisher:crab', 'set:keeper:birch', 'set:cook:gram', 'cp:1', 'wish:gram', 'cp:1']],
  // 피트의 상점: 할 일 보상·무료 선물·골드 바꾸기·카드 묶음·꾸러미·첫 거래·정기 배송 (결제는 시험용 바로 지급)
  shop: [base.mid, ['mis:kill', 'daily:kill:150', 'mis:kill', 'mis:kill', 'daily:box:10', 'daily:harv:12', 'mis:all', 'mis:box', 'mis:harv', 'mis:all', 'mis:all',
    'gem:20', 'gx:g1', 'gx:g2', 'gem:5000', 'gx:g1', 'gx:g2', 'gx:g3', 'cp:0', 'cp:1', 'cp:1', 'cp:0',
    'pack:p1', 'pack:p1', 'pack:p6', 'starter', 'starter', 'sub', 'subclaim', 'time:' + 24 * H, 'subclaim', 'subclaim', 'sub',
    'adgem', 'adcard', 'adbox', 'sell', 'gold:0', 'adbox', 'equip']],
  // 유니크 카엘 촌장: 은퇴 전엔 못 삼 → 첫 은퇴 뒤 500원 → 카엘 자리 → 유니크 카드로 별(덤·정기 배송) → 카엘로 되돌림 / 은퇴 10번 무료
  chief: [base.mid, ['retires:0', 'chief', 'retires:1', 'chief', 'chief', 'kseat:kael_chief', 'chiefup', 'pack:p2', 'pack:p3', 'pack:p4', 'chiefup', 'sub', 'subclaim', 'time:' + 24 * H, 'subclaim', 'ucard:100', 'chiefup', 'chiefup', 'chiefup', 'chiefup', 'up:hp', 'kseat:kael', 'kseat:kael', 'kseat:kael_chief']],
  chief10: [base.late, ['chiefchk', 'retires:9', 'chiefchk', 'retires:10', 'chiefchk', 'chiefchk', 'kseat:kael_chief', 'chiefup']],
  // 전설 어부 막례: 카드 모아 맞이하기 → 별 올리기 → 편성 → 낚시터 생선 생산 「물질 대장」
  makrye: [base.mid, ['ensure', 'card:makrye:29', 'rec:makrye', 'card:makrye:30', 'rec:makrye', 'set:fisher:makrye', 'time:' + 10 * M, 'card:makrye:40', 'rec:makrye', 'time:' + 30 * M, 'auto', 'card:makrye:999', 'rec:makrye', 'rec:makrye', 'rec:makrye', 'rec:makrye', 'time:' + 2 * H, 'lv:makrye', 'cw:makrye']],
  // 말봉(꿀 생산)·덕배(요리 시간)·페피·안단테: 맞이하기·별·편성·생산·요리
  legends: [base.mid, ['ensure', 'gold:1e12', 'card:malbong:30', 'rec:malbong', 'card:deokbae:30', 'rec:deokbae', 'card:peppy:30', 'rec:peppy', 'card:andante:30', 'rec:andante',
    'set:keeper:malbong', 'set:cook:deokbae', 'set:miner:peppy', 'time:' + 20 * M, 'items:wheat:30', 'items:fish:30', 'cook:bread', 'cook:stew',
    'card:malbong:9999', 'rec:malbong', 'rec:malbong', 'rec:malbong', 'rec:malbong', 'card:deokbae:9999', 'rec:deokbae', 'rec:deokbae', 'time:' + 30 * M, 'cook:bread',
    'set:keeper:andante', 'auto', 'card:andante:200', 'rec:andante', 'rec:andante', 'lv:peppy', 'cw:malbong', 'time:' + 2 * H]],
  // 새 동료 6명(살로·베티·나이아·베르나르·엘름·하그린): 맞이하기·별·편성 + 마을 스킬(강화 광석·작물 시간·방치 시간)
  newcomp: [base.mid, ['ensure', 'gold:1e12', 'items:ore:9999', 'en:weapon', 'card:salo:30', 'rec:salo', 'card:betty:50', 'rec:betty', 'rec:betty',
    'card:naia:30', 'rec:naia', 'card:bernard:30', 'rec:bernard', 'card:elm:30', 'rec:elm', 'card:hagrin:30', 'rec:hagrin',
    'set:fisher:naia', 'set:cook:bernard', 'set:keeper:elm', 'set:miner:hagrin', 'en:weapon', 'en:helm', 'cw:hagrin', 'seeds:wheat:9', 'plantall', 'time:' + 3 * M, 'harvre',
    'card:hagrin:9999', 'rec:hagrin', 'rec:hagrin', 'rec:hagrin', 'rec:hagrin', 'en:weapon', 'card:elm:9999', 'rec:elm', 'rec:elm', 'plantall', 'time:' + 2 * M, 'harvre',
    'card:naia:9999', 'rec:naia', 'rec:naia', 'set:fisher:salo', 'set:miner:betty', 'auto', 'time:' + 10 * H]],
  // 영웅 소피·오스카: 맞이하기·별(★5까지)·편성
  epic2: [base.mid, ['ensure', 'gold:1e12', 'card:sophie:30', 'rec:sophie', 'card:oscar:30', 'rec:oscar', 'set:cook:sophie', 'set:keeper:oscar',
    'card:sophie:9999', 'rec:sophie', 'rec:sophie', 'rec:sophie', 'rec:sophie', 'lv:sophie', 'lv:oscar', 'auto', 'time:' + 2 * H]],
  // 유니크 뚝딱이: 상점 구매(합류 ★1) → 두 번 사기 막힘 → 바로 출전 → 유니크 카드로 ★ 올리기(카엘 촌장과 같은 카드) → 방치 골드 마을 스킬
  ttuk: [base.mid, ['ensure', 'gold:1e12', 'tbuy', 'tbuy', 'set:miner:ttukttak', 'ucard:150', 'uqup:ttukttak', 'uqup:ttukttak', 'uqup:ttukttak', 'uqup:ttukttak',
    'lv:ttukttak', 'lv:ttukttak', 'auto', 'time:' + 3 * H]],
  // 유니크 루시안: 상점 구매(합류 ★1) → 두 번 사기 막힘 → 바로 출전(요리사) → 유니크 카드로 ★ 올리기
  lucian: [base.mid, ['ensure', 'gold:1e12', 'lbuy', 'lbuy', 'set:cook:lucian', 'ucard:60', 'uqup:lucian', 'uqup:lucian',
    'lv:lucian', 'lv:lucian', 'auto', 'time:' + 3 * H]],
  // 루시안 마을 스킬 「왕실 납품」: 시장 주문 골드 +50%
  lucord: [base.vill, ['lbuy', 'items:ore:999', 'items:honey:999', 'items:wheat:999', 'items:pumpkin:999', 'items:fish:500', 'items:egg:50', 'items:milk:60',
    'otick', 'odeliver:0', 'odeliver:1', 'odeliver:2', 'ucard:20', 'uqup:lucian', 'odeliver:3', 'odeliver:4']],
  // 출석체크: 7일 판 반복·한달 판 초기화·건너뛰기·같은 날·날짜 되돌리기·광고 2배·큰 보상(7·14·21·28)·배지·무료권 사용
  attend: [base.mid, ['att:2026-10-21', 'att:2026-10-22', 'att:2026-10-23', 'att:2026-10-24', 'att:2026-10-25', 'att:2026-10-26', 'att:2026-10-27',
    'attad:2026-10-27', 'attad:2026-10-27', 'att:2026-10-27', 'att:2026-10-29', 'att:2026-10-28', 'att:2026-11-1', 'att:2026-11-2',
    'attm:2026-11:6', 'att:2026-11-3', 'attad:2026-11-3', 'attm:2026-11:13', 'att:2026-11-4', 'attm:2026-11:20', 'att:2026-11-5', 'attad:2026-11-5',
    'attm:2026-11:27', 'att:2026-11-6', 'attad:2026-11-6', 'att:2026-11-7', 'att:2026-11-30', 'att:2026-12-1', 'att:2026-1-5',
    'tk:box:2', 'box', 'sell', 'box', 'sell', 'box', 'sell', 'tk:box10:1', 'gem:0', 'open10', 'open10']],
  // 출석체크: 카드 받을 동료가 없을 때 이삭으로 대체 (7일 판 6칸, 한달 판 7회)
  attendFresh: [base.fresh, ['att:2026-10-21', 'att:2026-10-22', 'att:2026-10-23', 'att:2026-10-24', 'att:2026-10-25', 'att:2026-10-26', 'att:2026-10-27', 'attad:2026-10-27']],
  // 카드 동료가 아직 없을 때 카드 묶음
  shopEarly: [base.fresh, ['gem:999', 'cp:0', 'cp:1', 'adcard', 'mis:all']],
  // 원정 일지: 하루 한도(출석·할 일·영지·마물 1,000·탑·던전·주문) → 다음 날 → 무료 칸 받기 → 중간 구매(지난 유료 한꺼번에)·중복 구매 막기
  //   → 20단계·시즌 테두리 → 시즌 바뀜(남은 보상 우편)·우편 받기 → 마감 3일 전 알림 → 지난 시즌 결제(이삭 200)
  pass: [base.mid, ['padd:att', 'started', 'padd:att', 'padd:att', ...rep('padd:boss', 12), 'pkill:2500', ...rep('padd:mis', 4), 'padd:misall', 'padd:misall',
    ...rep('padd:tower', 4), ...rep('padd:dun', 4), ...rep('padd:ord', 4), 'time:' + 24 * H, 'padd:att', 'padd:boss', 'ppt:750', 'pclaim:f:0', 'pclaim:p:1', 'pclaim:f:9',
    'pbuy', 'pbuy', 'popen:1', 'pclaim', 'ppt:2000', 'pclaim', 'pclaim', 'time:' + 9 * 24 * H, 'pwarn', 'pwarn', 'time:' + 24 * H, 'padd:att',
    'time:' + 14 * 24 * H, 'padd:boss', 'popen:2', 'ppt:640', 'pclaim:f:0', 'pclaim:p:3', 'time:' + 14 * 24 * H, 'padd:att', 'pmail', 'pmail', 'popen:2', 'pbuy', 'pbuy']],
  // 카드 받을 동료가 없을 때: 유료 줄 카드 → 이삭 (1장당 3)
  passFresh: [base.fresh, ['started', 'ppt:300', 'pbuy', 'pclaim']],
  // 영주의 첫걸음: 영지 3까지는 안 보임 → 영지 35에서 사면 300+10·20·30 즉시 → 40·50 나중에 → 다 받으면 사라짐 · 두 번 못 삼
  grow: [base.mid, ['started', 'best:3', 'grow', 'best:35', 'growchk', 'grow', 'grow', 'best:41', 'growchk', 'growchk', 'best:52', 'growchk', 'best:12', 'growchk', 'growgive']],
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
