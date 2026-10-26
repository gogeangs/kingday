// 웹 index.html 의 데이터 표(지역·동료·건물·스킬 등)를 Dart 파일로 그대로 옮긴다.
// 손으로 옮기다 생기는 오타를 막기 위해, 표는 이 도구로만 만든다.
//   node tools/parity/gen_dart_data.js          → app/lib/core/web_data.g.dart 갱신
//   node tools/parity/gen_dart_data.js --check  → 최신인지만 확인(다르면 실패)
// 함수가 들어 있는 부분(비용 공식, 효과 문구 등)은 표에서 빼고 app/lib/core/ 에서 직접 옮긴다.
'use strict';
const fs = require('fs');
const path = require('path');
const { loadWeb } = require('./load_web.js');

const w = loadWeb();
const pick = (src) => JSON.parse(JSON.stringify(w.run(src)));

// [Dart 이름, 웹 식]
const TABLES = [
  ['SLOTS', 'SLOTS'], ['GRADES', 'GRADES'], ['BASE_ODDS', 'BASE_ODDS'], ['FRAMES', 'FRAMES'], ['RELIC_T', 'RELIC_T'],
  ['REGIONS', 'REGIONS'], ['MAXLAND', 'MAXLAND'], ['BOSSID', 'BOSSID'],
  ['COMP', 'COMP'], ['JOB', 'JOB'], ['JOBN', 'JOBN'], ['JSLOT', 'JSLOT'], ['STORY', 'STORY'], ['ORDER', 'ORDER'], ['HEIGHT', 'HEIGHT'],
  ['RECRUITS', 'RECRUITS'], ['STAR_NEED', 'STAR_NEED'], ['STAR_MUL', 'STAR_MUL'], ['GRADE', 'GRADE'], ['GR', 'GR'],
  ['VPAS', 'Object.fromEntries(Object.entries(VPAS).map(([k,v])=>[k,{n:v.n}]))'],
  ['SKILLS', 'SKILLS'],
  // 원정대의 정 (docs/content/BOND.md)
  ['AFF_NEED', 'AFF_NEED'], ['AFF_SEC', 'AFF_SEC'], ['BONDS', 'BONDS'], ['BOND_INTRO', 'BOND_INTRO'], ['BOND5', 'BOND5'], ['BOND5J', 'BOND5J'],
  ['BAL', 'BAL'], ['COMP_GROW', 'COMP_GROW'], ['BLESS', 'BLESS'], ['EN_MAX', 'enMaxL(0)'], ['CW', 'CW'], ['CW_MAX', 'enMaxL(0)'],
  ['UPG', 'UPG.map(u=>({k:u.k,n:u.n,max:u.max}))'],
  ['CROPS', 'CROPS'], ['GOODS', 'GOODS'], ['RECIPES', 'RECIPES'], ['BUFFN', 'BUFFN'],
  ['BLD', 'BLD.map(b=>({k:b.k,n:b.n,who:b.who,max:b.max,base:b.base,lock:b.lock}))'], ['BQ_MAX', 'BQ_MAX'], ['TUT_GEM', 'TUT_GEM'],
  ['GEM_PLOTS', 'GEM_PLOTS'], ['RANKS', 'RANKS'],
  ['EVENTS', 'EVENTS.map(e=>({at:e.at,id:e.id,eb:e.eb,t:e.t,p:e.p,btn:e.btn}))'], ['QUIPS', 'QUIPS'],
  ['MISSIONS', 'MISSIONS'], ['MIS_ALL', 'MIS_ALL'], ['RANK_GEM', 'RANK_GEM'], ['LORD_GEM', 'LORD_GEM'],
  ['ADS', 'ADS'], ['PACKS', 'PACKS'], ['SUB', 'SUB'], ['STARTER', 'STARTER'], ['CARDPK', 'CARDPK'], ['GOLDX', 'GOLDX'],
  ['GEM10', 'GEM10'], ['GEM_PLOT', 'GEM_PLOT'], ['GEM_OFFLINE', 'GEM_OFFLINE'], ['LUMQ', 'LUMQ'],
  ['SAVE_KEY', 'KEY'],
  // ── 전투 (2단계) ──
  ['SPRITES', 'SPRITES'], ['SPR_CONST', '({frame:SPR_FRAME,foot:SPR_FOOT,fig:SPR_FIG})'],
  ['MON_SPRITES', 'MON_SPRITES'], ['MON_ALT', 'MON_ALT'], ['TRAITS', 'TRAITS'], ['GOB', 'GOB'],
  ['FXDEF', 'FXDEF'], ['FORM', 'FORM'], ['GOB_RARE', 'GOB_RARE'], ['BG_IMG', 'BG_IMG'], ['BG_FULL', 'BG_FULL'],
  ['DECO', 'DECO'],
  // ── 2026-10-21 카드 확률·고블린 밭 ──
  ['CARD_FIX', 'CARD_FIX'], ['CARD_W', 'CARD_W'], ['GOB_PLOT', '({n:GOB_PLOT,gem:GOB_PLOT_GEM})'],
  // ── 2026-10-23 마을 확장 (docs/content/VILLAGE.md) ──
  ['VLV', 'VLV'], ['VLV_GEM', 'VLV_GEM'], ['WJOB', 'WJOB'], ['WBASE', 'WBASE'], ['WEFF', 'WEFF'], ['VPPL', 'VPPL'], ['LIKE', 'LIKE'],
  ['ORD', '({gem:ORD_GEM,wait:ORD_WAIT,mul:ORD_MUL,lv:ORD_LV})'], ['BLS', 'BLS'], ['VTALK', 'VTALK'], ['WLINE', 'WLINE'],
  ['VEP', 'VEP'], ['VOPEN', 'VOPEN'], ['VMOVE', 'VMOVE'], ['VNOTE', 'VNOTE'], ['VPOS', 'VPOS'], ['VBB', 'VBB'], ['WSPOT', 'WSPOT'],
  ['VTABN', 'VTABN'], ['VFN', 'VFN'],
  // ── 2026-10-23 대륙 지도 (docs/content/WORLDMAP.md) ──
  ['MAPPOS', 'MAPPOS'], ['REG_FOG', 'REG_FOG'], ['P2', 'P2'],
  // ── 2026-10-26 상점·패스 (docs/content/SHOP.md) ──
  ['SEAS0', 'SEAS0'], ['PASS', 'PASS'], ['PASS_SRC', 'PASS_SRC'], ['PASS_REW', 'PASS_REW'], ['GROW', 'GROW'],
];

function dartStr(s) {
  return "'" + s.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$').replace(/\n/g, '\\n').replace(/\r/g, '\\r') + "'";
}
function lit(v, ind) {
  const pad = '  '.repeat(ind + 1), end = '  '.repeat(ind);
  if (v === null || v === undefined) return 'null';
  if (typeof v === 'string') return dartStr(v);
  if (typeof v === 'boolean') return String(v);
  if (typeof v === 'number') {
    if (!isFinite(v)) throw new Error('유한하지 않은 숫자');
    // 정수처럼 보여도 웹에서 소수였던 값은 그대로 두고, 1.0 같은 것은 정수로 (Dart 쪽은 num 으로 읽음)
    return Number.isInteger(v) ? String(v) : String(v);
  }
  if (Array.isArray(v)) {
    if (!v.length) return 'const <Object?>[]';
    const items = v.map((x) => lit(x, ind + 1));
    const one = '[' + items.join(', ') + ']';
    if (one.length < 90 && !one.includes('\n')) return one;
    return '[\n' + items.map((x) => pad + x + ',').join('\n') + '\n' + end + ']';
  }
  const ks = Object.keys(v);
  if (!ks.length) return 'const <String, Object?>{}';
  const items = ks.map((k) => dartStr(k) + ': ' + lit(v[k], ind + 1));
  const one = '{' + items.join(', ') + '}';
  if (one.length < 90 && !one.includes('\n')) return one;
  return '{\n' + items.map((x) => pad + x + ',').join('\n') + '\n' + end + '}';
}

let out = `// 자동 생성 파일 — 직접 고치지 마세요.
// 원본: index.html (웹 버전). 다시 만들기: node tools/parity/gen_dart_data.js
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars, unnecessary_const

`;
for (const [name, expr] of TABLES) {
  out += `const ${name === name.toUpperCase() ? 'w' + name.toLowerCase().replace(/_([a-z])/g, (_, c) => c.toUpperCase()).replace(/^./, (c) => c.toUpperCase()) : name} = ${lit(pick(expr), 0)};\n\n`;
}

const file = path.join(__dirname, '..', '..', 'app', 'lib', 'core', 'web_data.g.dart');
if (process.argv.includes('--check')) {
  const cur = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  if (cur !== out) {
    console.error('web_data.g.dart 가 index.html 과 맞지 않아요. node tools/parity/gen_dart_data.js 를 실행해 갱신하세요.');
    process.exit(1);
  }
  console.log('web_data.g.dart 최신 상태');
} else {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, out);
  console.log('저장:', path.relative(process.cwd(), file), (out.length / 1024).toFixed(0) + 'KB');
}
