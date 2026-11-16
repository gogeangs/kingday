/* 성장 체감 피드백 — 기존 전투·저장·재화 로직은 변경하지 않음. */
(() => {
  'use strict';
  let prev = null, pending = null, until = 0, timer = 0;
  const css = document.createElement('style');
  css.textContent = `
    .growth-impact {position:absolute;top:calc(90px + env(safe-area-inset-top,0px));left:50%;transform:translate(-50%,-12px) scale(.97);z-index:20;pointer-events:none;opacity:0;transition:opacity .2s,transform .25s;min-width:230px;max-width:calc(100% - 28px);padding:11px 15px;border:1px solid #e8bb5b;border-radius:14px;background:rgba(18,26,45,.95);box-shadow:0 6px 25px #0008;text-align:center;color:#eef1f8;font-family:inherit}
    .growth-impact.on {opacity:1;transform:translate(-50%,0) scale(1)}
    .growth-impact strong {display:block;color:#ffc94a;font-size:16px}
    .growth-impact span {display:block;font-size:12px;margin-top:4px;color:#d5def1}
    @media(prefers-reduced-motion:reduce){.growth-impact{transition:none}}
  `;
  document.head.appendChild(css);
  function snapshot() {
    if (typeof S === 'undefined' || !S || !S.started || typeof members !== 'function' || typeof stats !== 'function') return null;
    const ids = members();
    if (!ids.length) return null;
    let dps = 0;
    for (const id of ids) {
      const s = stats(id);
      if (!s || !Number.isFinite(s.atk) || !Number.isFinite(s.aps)) return null;
      const crit = typeof critE === 'function' ? critE(s) : 1;
      dps += s.atk * s.aps * (Number.isFinite(crit) ? crit : 1);
    }
    if (!(dps > 0) || !Number.isFinite(dps)) return null;
    const stage = typeof fightSt === 'function' ? fightSt() : S.stage;
    const bossHp = typeof monHp === 'function' ? monHp(stage, true) : null;
    return { dps, stage, bossHp, retires: S.retires || 0 };
  }
  function show(old, now) {
    const ratio = now.dps / old.dps;
    const percent = Math.round((ratio - 1) * 100);
    if (percent < 3 || !Number.isFinite(percent)) return;
    let el = document.querySelector('.growth-impact');
    if (!el) {
      el = document.createElement('div');
      el.className = 'growth-impact';
      el.setAttribute('role', 'status');
      el.setAttribute('aria-live', 'polite');
      (document.querySelector('.app') || document.body).appendChild(el);
    }
    const oldSec = now.bossHp / old.dps, newSec = now.bossHp / now.dps;
    const meaningful = Number.isFinite(oldSec) && oldSec >= 2 && oldSec < 3600;
    const secs = meaningful ? ' · 보스 예상 ' + Math.ceil(oldSec) + '초 → ' + Math.ceil(newSec) + '초' : '';
    el.replaceChildren();
    const head = document.createElement('strong');
    head.textContent = now.retires > old.retires ? '은퇴의 추억, 다시 강해졌어요!' : '성장 효과! 예상 화력 +' + percent + '%';
    const detail = document.createElement('span');
    detail.textContent = now.retires > old.retires ? '새 회차가 시작됐습니다' : '현재 원정대 기준' + secs;
    el.append(head, detail);
    el.classList.add('on');
    clearTimeout(timer);
    timer = setTimeout(() => el.classList.remove('on'), 2900);
  }
  setInterval(() => {
    try {
      const now = snapshot();
      if (!now) return;
      if (!prev) { prev = now; return; }
      if (now.retires !== prev.retires || now.stage !== prev.stage) {
        prev = now; pending = null; return;
      }
      const ratio = now.dps / prev.dps;
      if (ratio >= 1.03) {
        if (!pending) pending = { old: prev, now, at: Date.now() };
        else pending.now = now;
        if (Date.now() - pending.at >= 500 && Date.now() > until) {
          show(pending.old, pending.now);
          until = Date.now() + 3200;
          prev = pending.now;
          pending = null;
        }
      } else if (ratio < 0.98) { prev = now; pending = null; }
    } catch (_) { /* 피드백 오류가 게임을 중단하지 않도록 격리 */ }
  }, 350);
})();
