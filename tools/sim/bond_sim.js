/* 원정대의 정(호감도) 시뮬레이션 — docs/content/BOND.md 8장
   하루 10시간이 쌓이는 유저: 접속 3번(20분씩 전투 = 1시간) + 접속 사이 방치 3번(3시간씩 = 9시간, 여관 최대 시간 안).
   점수는 게임 코드 그대로(affTick: 전투 step·방치 offline 이 부르는 함수, affTalk: 마을 길 위 대화 하루 1번).
   A: 출전 동료 + 매일 말 걸기 · B: 출전 동료, 말 걸기 안 함 · C: 같은 직업 짝(브리다 출전 + 브론 광산 일꾼), 둘 다 매일 말 걸기 */
(() => {
  Object.assign(window, { toast: () => {}, queue: () => {}, renderAll: () => {}, say: () => {}, scene: () => {}, rpAdd: () => {}, save: () => {} });
  const DAYS = 60;
  const plan = [['b', 20 * 60], ['i', 3 * 3600], ['b', 20 * 60], ['i', 3 * 3600], ['b', 20 * 60], ['i', 3 * 3600]];
  const run = (ids, talk) => {
    S.aff = {};
    S.affTalk = { d: '', ids: {} };
    S.bond = { seen: {}, intro: 1, five: {} };
    const reach = {};
    for (let d = 1; d <= DAYS; d++) {
      S.affTalk = { d: '', ids: {} }; /* 하루가 바뀜 */
      if (talk) for (const id of ids) affTalk(id);
      for (const [k, sec] of plan) {
        if (k === 'b') for (let t = 0; t < sec; t += 1) affTick(1); /* 전투: 1초씩 (step 처럼 잘게) */
        else affTick(sec); /* 방치: 돌아왔을 때 한 번에 */
      }
      for (const id of ids)
        for (const l of [3, 5]) {
          const key = id + '♥' + l;
          if (!reach[key] && affLv(id) >= l) reach[key] = d;
        }
    }
    return { reach, perDay: ids.map(id => Math.round(affPt(id) / DAYS)) };
  };
  S.joined = Object.assign(S.joined || {}, { bron: true, margo: true, haral: true, riel: true });
  S.rec = Object.assign(S.rec || {}, { brida: 1 });
  S.party = { miner: 'brida', fisher: 'haral', keeper: 'riel', cook: 'margo' };
  S.bld = Object.assign(S.bld || {}, { mine: 5 });
  S.work = { mine: ['bron'] };
  wkClean();
  return {
    need: AFF_NEED,
    A_talk: run(['brida'], true),
    B_noTalk: run(['brida'], false),
    C_pair: run(['brida', 'bron'], true),
    check: { members: members(), working: working() }
  };
})();
