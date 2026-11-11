// 유니크 동료(뚝딱이·루시안·골디) 마을 일꾼 (2026-11-12 대표님 — 전설과 같은 +30%).
// 전에는 일꾼 효과 표에 유니크가 없어 효과가 숫자가 아니게 되고(웹 NaN·앱 오류), 여관이면 방치 골드가 깨졌음.
import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/actions.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/rng.dart';
import 'package:kingday/core/state.dart';

void main() {
  final now = DateTime.utc(2026, 11, 12).millisecondsSinceEpoch;
  GameCalc calcFor(Map<String, dynamic> save) => GameCalc(GameState.hydrate(save, now, GameCalc.rankIdxOf), clock: () => now);
  Map<String, dynamic> base() => {
        'gold': 1e9,
        'stage': 30,
        'best': 30,
        'started': true,
        'joined': {'bron': true, 'haral': true, 'riel': true, 'margo': true},
        'rec': {'ttukttak': 1},
        'bld': {'inn': 5, 'mine': 5, 'farm': 3, 'dock': 3},
      };

  test('유니크 일꾼 효과 = 전설과 같음 (숫자)', () {
    final c = calcFor(base());
    expect(c.owned('ttukttak'), isTrue);
    final v = c.wkOne('inn', 'ttukttak');
    expect(v.isFinite, isTrue);
    expect(v, closeTo(.3 + .02 * c.recStar('ttukttak'), 1e-9));
  });

  test('여관 일꾼이 유니크여도 방치 골드·여관 효과가 정상', () {
    final c = calcFor({
      ...base(),
      'work': {
        'inn': ['ttukttak']
      }
    });
    expect(c.workBonus('inn').isFinite, isTrue);
    expect(c.workBonus('inn'), greaterThan(0));
    expect(c.vIdle().isFinite, isTrue);
    final g = c.idleGold(3600);
    expect(g.isFinite && g > 0, isTrue);
  });

  test('쉬는 동료가 유니크뿐이어도 추천 일꾼이 멈추지 않음', () {
    final c = calcFor(base());
    final a = GameActions(c, rng: Mulberry32(1));
    expect(c.idleIds(), contains('ttukttak'));
    final n = a.wkAuto(false);
    expect(n, 1);
    expect(c.working().containsKey('ttukttak'), isTrue);
  });
}
