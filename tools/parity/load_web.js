// 웹 버전 index.html 의 게임 코드를 Node 에서 화면 없이 불러오는 도구.
// 앱(Flutter) 공식이 웹과 같은 값을 내는지 비교할 "정답 값"을 만들 때 씀.
// 화면(DOM)·캔버스는 아무 일도 하지 않는 가짜 객체로 바꾸고, 시간과 난수는 고정한다.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

// 무엇을 불러도 자기 자신을 돌려주는 가짜 객체 (document.getElementById(...).onclick= 같은 코드가 그냥 지나가게)
function stub() {
  const f = function () { return p; };
  const p = new Proxy(f, {
    get(t, k) {
      if (k === Symbol.toPrimitive) return () => 0;
      if (k === Symbol.iterator) return function* () {};
      if (k === 'then') return undefined;
      if (k === 'length') return 0;
      return p;
    },
    set() { return true; },
    apply() { return p; },
    construct() { return p; },
    has() { return true; },
  });
  return p;
}

/** mulberry32: 앱(Dart) 쪽에도 같은 것을 두어 같은 난수 순서를 쓴다 */
function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function loadWeb(opts = {}) {
  const html = fs.readFileSync(path.join(__dirname, '..', '..', 'index.html'), 'utf8');
  const m = html.match(/<script>([\s\S]*?)<\/script>\s*<\/body>/) || html.match(/<script>([\s\S]*)<\/script>/);
  let code = m[1];
  // 맨 끝의 자동 시작 호출은 빼고, 함수·상수 정의만 남긴다
  code = code.replace(/window\.claude\?\.hot\?\.ready\?[^\n]*\n?/, '');
  // let/const 로 선언된 S 를 밖에서 바꿀 수 있게 손잡이를 단다
  code += '\n;globalThis.__setS=v=>{S=v};globalThis.__getS=()=>S;';

  const s = stub();
  let now = opts.now ?? Date.UTC(2026, 9, 20, 3, 0, 0); // 2026-10-20 12:00 KST
  const RealDate = Date;
  class FixedDate extends RealDate {
    constructor(...a) { if (a.length === 0) super(now); else super(...a); }
    static now() { return now; }
  }
  const ctx = {
    console, Math: Object.create(Math), JSON, Object, Array, String, Number, Boolean, Symbol,
    Map, Set, WeakMap, Promise, RegExp, Error, TypeError, isFinite, isNaN, parseInt, parseFloat,
    Intl, Proxy, Reflect, encodeURIComponent, decodeURIComponent,
    Date: FixedDate,
    document: s, navigator: s, location: { search: '', hostname: 'test', href: 'http://test/' },
    localStorage: { getItem: () => null, setItem() {}, removeItem() {} },
    sessionStorage: { getItem: () => null, setItem() {}, removeItem() {} },
    addEventListener() {}, removeEventListener() {}, matchMedia: () => ({ matches: false, addEventListener() {} }),
    requestAnimationFrame() {}, cancelAnimationFrame() {},
    setTimeout: () => 0, clearTimeout() {}, setInterval: () => 0, clearInterval() {},
    Image: function () { return s; }, Audio: function () { return s; },
    fetch: () => new Promise(() => {}), URLSearchParams,
    devicePixelRatio: 1, innerWidth: 390, innerHeight: 844, screen: s, history: s,
    CSS: { supports: () => false },
  };
  for (const k of ['MutationObserver', 'ResizeObserver', 'IntersectionObserver', 'Event', 'CustomEvent',
    'HTMLElement', 'AudioContext', 'webkitAudioContext', 'FontFace', 'OffscreenCanvas', 'Blob', 'FileReader', 'XMLHttpRequest'])
    ctx[k] = function () { return s; };
  ctx.window = ctx; ctx.self = ctx; ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(code, ctx, { filename: 'index.html' });

  const api = {
    ctx,
    run: (src) => vm.runInContext(src, ctx),
    setNow: (t) => { now = t; },
    setSeed: (seed) => { ctx.Math.random = mulberry32(seed); },
    setS: (st) => ctx.__setS(st),
    getS: () => ctx.__getS(),
  };
  api.setSeed(1);
  return api;
}

module.exports = { loadWeb, mulberry32 };
