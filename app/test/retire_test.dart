// 은퇴 일기(특성·지름길·추억 보정·은퇴 횟수 보상) 규칙 + 전투 효과 확인 (docs/content/RETIRE.md).
// 공식 값 자체는 parity_test(「tr」 저장)가 웹에서 뽑은 정답과 비교한다. 여기서는 흐름을 본다.
import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/battle/sim.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/data.dart';
import 'package:kingday/core/js.dart';
import 'package:kingday/core/profile_data.dart';
import 'package:kingday/core/retire.dart';
import 'package:kingday/core/rng.dart';
import 'package:kingday/core/state.dart';

void main() {
  const now = 1792465200000;
  GameCalc calcFor(Map<String, dynamic> save) => GameCalc(GameState.hydrate(save, now, GameCalc.rankIdxOf), clock: () => now);

  test('기본값: 기존 저장은 받은 추억이 그대로 포인트', () {
    final c = calcFor({'gold': 60, 'stage': 30, 'best': 30, 'memory': 14, 'retires': 2});
    expect(c.s.raw['trait'], isA<Map>());
    expect(c.s.raw['runStart'], 1);
    expect(c.s.raw['trReset'], 0);
    expect(c.memPts(), 14);
    expect(c.trCanAny(), isTrue);
    expect(memTotal, 282);
  });

  test('찍기 · 줄 잠김(10·30포인트) · 포인트 부족', () {
    final c = calcFor({'gold': 60, 'memory': 14});
    for (var i = 0; i < 5; i++) {
      expect(c.trBuy('sharp'), i + 1);
    }
    expect(c.trSpent('sword'), 9);
    expect(c.trBuy('critd'), isNull, reason: '9포인트면 2줄 잠김');
    expect(c.trBuy('sharp'), 6);
    expect(c.trSpent('sword'), 12);
    expect(c.trOpen(memT('critd')!), isTrue);
    expect(c.trBuy('critd'), 1);
    expect(c.memPts(), 0);
    expect(c.trBuy('hat'), isNull, reason: '포인트 없음');
    expect(c.trOpen(memT('stretch')!), isFalse, reason: '3줄은 30포인트');
    expect(c.crX(), closeTo(2.1, 1e-12));
  });

  test('효과 배수: 공격·체력·보스 시간·작물·공사·단련·방치', () {
    final base = calcFor({'gold': 60, 'stage': 20, 'best': 20});
    final c = calcFor({
      'gold': 60, 'stage': 20, 'best': 20,
      'trait': {'sharp': 8, 'hat': 8, 'stubborn': 3, 'soil': 6, 'carpenter': 6, 'knack': 5, 'inn': 4, 'stew': 5, 'hands': 8},
    });
    expect(c.kStats().atk / base.kStats().atk, closeTo(1.32, 1e-9));
    expect(c.kStats().hp / base.kStats().hp, closeTo(1.32, 1e-9));
    expect(c.bossLimT(5), 36);
    expect(c.bossLimT(10), 46);
    expect(c.bossLimT(60), 66);
    expect(c.cropT(crops.first), closeTo(42, 1e-9));
    expect(c.upgradeCost('atk', 10) / base.upgradeCost('atk', 10), closeTo(.8, 1e-12));
    expect(c.offCapH(), 10);
    expect(c.trCook(), closeTo(.5, 1e-12));
    expect(c.trProd(), closeTo(1.48, 1e-12));
  });

  test('지름길·추억 보정·비상금·씨앗 주머니 · 특성은 은퇴해도 유지', () {
    final c = calcFor({
      'gold': 60, 'stage': 61, 'best': 61, 'capClears': 1, 'memory': 40, 'retires': 4,
      'trait': {'shortcut': 10, 'purse': 5, 'seedbag': 3, 'memoir': 3}, 'retRw': {'1': 1, '3': 1},
    });
    expect(c.retStart(false), 30, reason: 'min(51, 61/2)');
    expect(c.retStart(true), 1);
    expect(c.retireBase(), 10);
    expect(c.retirePts(), 13, reason: '회고록 +30% 올림');
    final p = c.retirePts(), purse = c.retPurse(30);
    c.retire(p);
    expect([c.s.stage, c.s.raw['runStart'], c.s.memory, c.s.retires], [30, 30, 53, 5]);
    expect(c.s.gold, 60 + purse);
    expect(purse, jsFloor(GameCalc.reward(30, true) * 100));
    expect([c.s.seeds['wheat'], c.s.seeds['carrot'], c.s.seeds['pumpkin']], [30, 15, 6]);
    expect(asMap(c.s.raw['trait'])!['shortcut'], 10, reason: '특성 유지');
    expect(c.landCount(), 29);
    // 이번 회차 조건: 영지 10곳
    expect(c.retCan(), isFalse);
    c.s.stage = 39;
    expect(c.retCan(), isFalse);
    c.s.stage = 40;
    expect(c.retCan(), isTrue);
    // 건너뛴 구간(30 앞)의 추억은 뺌: 61에서 10 − 4 = 6, 회고록 → 8
    c.s.stage = 61;
    expect(c.retireBase(), 6);
    expect(c.retirePts(), 8);
    // 영지 1부터 고르면 보정 없음
    c.retire(c.retirePts(), true);
    expect([c.s.stage, c.s.raw['runStart']], [1, 1]);
  });

  test('은퇴 횟수 보상: 소급·1번만·배지·테두리', () {
    final c = calcFor({'gold': 60, 'retires': 10, 'gem': 0});
    final rw = c.retRwCheck();
    expect(rw!.g, 50 + 50 + 100 + 200);
    expect(retRwText(rw), contains('은퇴 1·3·5·10회 보상'));
    expect(c.s.gem, 400);
    expect(c.retRwCheck(), isNull, reason: '두 번 주지 않음');
    c.pfCheck();
    expect(c.bdHas('retire5'), isTrue);
    expect(c.pfHas('retire'), isTrue);
    expect(c.bdHas('retire20'), isFalse);
  });

  test('전투: 끈질긴 농부·아침 체조·탑 오르기', () {
    final c = calcFor({'gold': 1000, 'stage': 33, 'best': 33, 'chOpen': 1, 'trait': {'stubborn': 3, 'stretch': 3, 'climb': 5}});
    final b = BattleSim(c, rng: Mulberry32(3), gobT: 1e9);
    b.syncParty();
    b.towerStart(5);
    expect(b.ch!.lim, 36);
    for (final e in b.party.entries) {
      final n = skills[e.key]?.need;
      if (n != null) expect(e.value.sg, closeTo(n * .3, 1e-9), reason: '${e.key} 게이지 30%');
    }
    final m = Mon(x: 100, lane: .5, hp: 1000, max: 1000, atk: 0, cd: 1);
    b.hitMon(m, 100, false, 1);
    expect(m.hp, closeTo(850, 1e-9), reason: '탑에서 주는 피해 +50%');
    b.chExit();
    final m2 = Mon(x: 100, lane: .5, hp: 1000, max: 1000, atk: 0, cd: 1);
    b.hitMon(m2, 100, false, 1);
    expect(m2.hp, closeTo(900, 1e-9), reason: '영지 전투는 그대로');
    c.s.wave = 10;
    b.mons = [];
    for (final p in b.party.values) {
      p.sg = 0;
    }
    b.spawn();
    expect(b.bossT, 36);
  });
}
