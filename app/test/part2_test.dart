// 2부 「흩어진 동맹」 흐름 확인 (docs/content/PART2.md): 저장 옮기기 · 동맹 보너스 · 장수 처치(해방) · 은퇴.
// 공식 값 자체는 parity_test 가 웹(p2Install 을 붙인 상태)에서 뽑은 정답과 비교한다. 여기서는 흐름을 본다.
import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/battle/sim.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/data.dart';
import 'package:kingday/core/js.dart';
import 'package:kingday/core/profile_data.dart';
import 'package:kingday/core/rng.dart';
import 'package:kingday/core/state.dart';

void main() {
  const now = 1792465200000;
  GameCalc calcFor(Map<String, dynamic> save) => GameCalc(GameState.hydrate(save, now, GameCalc.rankIdxOf), clock: () => now);

  // 보스를 바로 불러 체력을 0으로 → 처치 처리 (웹 step 의 m.boss 처치 구간)
  void killBoss(BattleSim b) {
    b.spawn();
    expect(b.mons.where((m) => m.boss).length, 1);
    for (final m in b.mons) {
      if (m.boss) m.hp = 0;
    }
    for (var i = 0; i < 3; i++) {
      b.step(.05);
    }
  }

  test('표: 영지 90까지 · 사냥터 91 연합군 진영 · 나라 3개', () {
    expect(maxLand, 60);
    expect(land, 90);
    expect(p2On, isTrue);
    expect(regions.length, 9);
    expect([for (final r in regions.skip(6)) r.p2], ['elf', 'desert', 'north']);
    expect(allies.map((a) => a.boss), [70, 80, 90]);
    expect(huntName(), '연합군 진영');
    expect(GameCalc.terrName(91), '연합군 진영');
    expect(story2.keys, containsAll(['solen', 'saffron', 'einar']));
    expect(GameCalc.cardIds(), containsAll(['solen', 'saffron', 'einar']));
    expect(GameCalc.allyAt(70)?.k, 'elf');
    expect(GameCalc.allyAt(60), isNull);
    expect(GameCalc.isCap(70), isFalse, reason: '왕도 판정은 51~60 그대로');
  });

  test('체력: 1부는 그대로, 2부는 hpG2 로 이어서 · 시련의 탑은 1부 공식', () {
    expect(GameCalc.monHp(60, false), GameCalc.monHp(60, false, true));
    final r = GameCalc.monHp(62, false) / GameCalc.monHp(61, false);
    expect(r, closeTo(Balance.hpG2!, 1e-9));
    expect(GameCalc.monHp(70, false, true), greaterThan(GameCalc.monHp(70, false)));
  });

  test('예전 저장: 61 왕궁 뜰 → 61 웨이브 0 (최고 기록 그대로) · 2부 저장은 91까지', () {
    final old = calcFor({'gold': 60, 'stage': 61, 'wave': 7, 'best': 61, 'capClears': 1, 'ending1': 1});
    expect(old.s.stage, 61);
    expect(old.s.wave, 0);
    expect(old.s.best, 61);
    expect(old.s.raw['p2Intro'], 0, reason: '시작 장면은 게임을 열 때');
    final p2 = calcFor({'gold': 60, 'stage': 120, 'best': 95, 'capClears': 1, 'p2Intro': 1, 'p2v': 3});
    expect(p2.s.stage, 91);
    final mig = calcFor({'gold': 60, 'stage': 71, 'wave': 5, 'best': 71, 'capClears': 1, 'p2Intro': 1});
    expect(mig.s.wave, 0);
    expect(GameState.p2Mig, 71, reason: '웹 1차 저장 71 바다 안개 → 사막 첫 영지');
    GameState.p2Mig = 0;
  });

  test('동맹 보너스: 엘프 게이지 · 사막 골드 · 북방 체력 · 셋 다 맹주 공격', () {
    final base = calcFor({'gold': 60, 'stage': 75, 'best': 75, 'capClears': 1});
    expect(base.p2Open(), isTrue);
    expect(base.allySk(), 1);
    final all = calcFor({'gold': 60, 'stage': 75, 'best': 75, 'capClears': 1, 'ally': {'elf': 1, 'desert': 1, 'north': 1}});
    expect(all.allySk(), 1.1);
    expect(all.allyGold(), 1.2);
    expect(all.allyHp(), 1.15);
    expect(all.allyAll(), isTrue);
    expect(all.kStats().atk / base.kStats().atk, closeTo(1.1, 1e-9));
    expect(all.kStats().hp / base.kStats().hp, closeTo(1.15, 1e-9));
    expect(all.goldRate() / base.goldRate(), closeTo(1.2 * 1.1, .2), reason: '골드 +20% (공격이 늘어 처치도 빨라짐)');
    expect(pframes.any((f) => f.k == 'alliance' && f.ok(all)), isTrue);
    expect(badges.any((b) => b.k == 'part2' && b.ok(all)), isTrue);
    expect(pframes.any((f) => f.k == 'alliance' && f.ok(base)), isFalse);
  });

  test('장수 처치: 처음 해방(이삭 300·동맹) → 은퇴 뒤 다시 처치하면 회차 1번 추억 +2', () {
    final c = calcFor({'gold': 1e30, 'stage': 70, 'wave': 10, 'best': 70, 'capClears': 1, 'p2Intro': 1, 'p2v': 3});
    final sim = BattleSim(c, rng: Mulberry32(1), gobT: 1e9)..syncParty();
    final gem0 = c.s.gem;
    killBoss(sim);
    expect(c.allyOn('elf'), isTrue);
    // 해방 이삭 300 (영지 70에 닿아 칭호가 오르면 칭호 이삭도 함께)
    expect(c.s.gem - gem0, anyOf(p2Gem, p2Gem + rankGem));
    expect(truthy(asMap(c.s.raw['gemLord'])!['70']), isTrue);
    expect(c.s.stage, 71);
    expect(sim.events.whereType<P2WinEvent>().single.first, isTrue);
    expect(truthy(asMap(c.s.raw['p2Clr'])!['elf']), isTrue);
    // 은퇴하면 이번 회차 처치 기록만 지움 (동맹은 영구)
    c.retire(0);
    expect(truthy(asMap(c.s.raw['p2Clr'])!['elf']), isFalse);
    expect(c.allyOn('elf'), isTrue);
    final mem0 = c.s.memory;
    c.s.stage = 70;
    c.s.wave = 10;
    sim.events.clear();
    killBoss(sim);
    expect(c.s.memory - mem0, p2Mem);
    final e = sim.events.whereType<P2WinEvent>().single;
    expect(e.first, isFalse);
    expect(e.bonus, p2Mem);
    sim.events.clear();
    c.s.stage = 70;
    c.s.wave = 10;
    killBoss(sim);
    expect(sim.events.whereType<P2WinEvent>().single.bonus, 0, reason: '같은 회차 두 번째는 없음');
  });

  test('새 게임 저장 칸', () {
    final c = calcFor({'gold': 60});
    expect(asMap(c.s.raw['ally']), {'elf': 0, 'desert': 0, 'north': 0});
    expect(c.s.raw['p2v'], 3);
    expect(c.p2Open(), isFalse);
  });
}
