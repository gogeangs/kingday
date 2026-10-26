// 전투가 웹과 똑같이 진행되는지 확인하는 테스트.
//
// 정답 값(test/fixtures/battle_parity.json)은 웹 index.html 의 step() 을 Node 에서 그대로 돌려 뽑은 것이다.
//   node tools/parity/make_battle_fixtures.js
// 같은 저장 데이터·같은 화면 크기·같은 씨앗의 난수로 앱 전투(BattleSim)를 돌려 0.5초마다 상태를 비교한다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/battle/sim.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/js.dart';
import 'package:kingday/core/rng.dart';
import 'package:kingday/core/state.dart';

void same(Object? a, Object? e, String where) {
  if (e is num && a is num) {
    if (a == e) return;
    final tol = 1e-9 * (e.abs() > 1 ? e.abs() : 1);
    if ((a - e).abs() <= tol) return;
    fail('$where: 앱 $a ≠ 웹 $e');
  }
  if (e is Map) {
    if (a is! Map) fail('$where: 앱은 Map 이 아님 ($a)');
    for (final k in {...e.keys, ...a.keys}) {
      if (!e.containsKey(k)) fail('$where.$k: 앱에만 있음 (${a[k]})');
      if (!a.containsKey(k)) fail('$where.$k: 웹에만 있음 (${e[k]})');
      same(a[k], e[k], '$where.$k');
    }
    return;
  }
  if (e is List) {
    if (a is! List) fail('$where: 앱은 List 가 아님 ($a)');
    if (a.length != e.length) fail('$where: 길이 앱 ${a.length} ≠ 웹 ${e.length}  (앱 $a / 웹 $e)');
    for (var i = 0; i < e.length; i++) {
      same(a[i], e[i], '$where[$i]');
    }
    return;
  }
  if (a != e) fail('$where: 앱 $a ≠ 웹 $e');
}

dynamic j(Object? v) => jsonDecode(jsonEncode(v));

Map<String, dynamic> snapshot(BattleSim b, int f) {
  final s = b.s, c = b.c;
  return {
    'f': f, 'gold': s.gold, 'stage': s.stage, 'wave': s.wave, 'best': s.best, 'gem': s.gem,
    'seeds': j(s.raw['seeds']), 'cards': j(s.raw['cards']), 'gemLord': j(s.raw['gemLord']),
    'kill': c.daily()['kill'], 'joined': j(s.raw['joined']), 'rankSeen': s.raw['rankSeen'],
    'gemRank': orNum(s.raw['gemRank'], 0), 'gobW': j(s.raw['gobW']), 'stat': j(s.raw['stat']), 'bdUnl': j(s.raw['bdUnl']), 'aff': j(s.raw['aff']),
    'P': {for (final e in b.party.entries) e.key: [e.value.hp, e.value.down, e.value.sg, e.value.cd, e.value.swing, e.value.hit]},
    'mons': [for (final m in b.mons) [m.x, m.hp, m.dead, m.boss, m.gob, m.alt, m.flee, m.cd, m.bind, m.psn, m.slow, m.vul, m.brn, m.kb]],
    'engaged': b.engaged, 'bgX': b.bgX, 'spawnT': b.spawnT, 'gobT': b.gobT, 'bossT': b.bossT, 'shakeT': b.shakeT,
    'flash': b.flash,
    'skx': {
      'shield': b.skx.shield, 'honey': b.skx.honey, 'feast': b.skx.feast, 'bake': b.skx.bake,
      'mount': b.skx.mount, 'mountK': b.skx.mountK, 'wall': b.skx.wall,
      'ul': b.skx.ul, 'ulA': b.skx.ulA, 'ulS': b.skx.ulS,
    },
    'nFloats': b.floats.length, 'nFx': b.fxs.length, 'nProj': b.proj.length,
    'quip': b.quip?.txt, 'banner': b.banner?.txt, 'cut': b.cut?.id, 'warn': b.warn != null,
  };
}

void main() {
  final fx = jsonDecode(File('test/fixtures/battle_parity.json').readAsStringSync()) as Map<String, dynamic>;
  final now = fx['now'] as int, dt = (fx['dt'] as num).toDouble(), snapEvery = fx['snap'] as int;
  final cases = fx['cases'] as Map<String, dynamic>;

  for (final name in cases.keys) {
    test('전투 「$name」 — 웹과 같은 진행', () {
      final cs = cases[name] as Map<String, dynamic>;
      final st = GameState.hydrate(cs['save'] as Map<String, dynamic>, now, GameCalc.rankIdxOf);
      final c = GameCalc(st, clock: () => now);
      final b = BattleSim(c, rng: Mulberry32(20261020), gobT: cs['gobT'] as num)
        ..w = fx['w'] as num
        ..ht = fx['ht'] as num;
      final snaps = (cs['snaps'] as List).cast<Map<String, dynamic>>();
      var k = 0;
      final frames = cs['frames'] as int;
      for (var f = 1; f <= frames; f++) {
        b.step(dt);
        b.events.clear();
        if (name == 'manual' && f % 10 == 0) {
          for (final id in c.members()) {
            if (b.skFull(id)) {
              b.castSkill(id);
              break;
            }
          }
        }
        if (f % snapEvery == 0) {
          same(j(snapshot(b, f)), snaps[k], '$name ${(f * dt).toStringAsFixed(1)}초');
          k++;
        }
      }
      expect(k, snaps.length);
    });
  }
}
