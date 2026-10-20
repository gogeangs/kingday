// 긴 플레이 비교 (QA): 웹과 앱을 같은 규칙으로 수십 분 "자동 플레이"시켜 3분마다 저장 데이터 전체를 비교.
// 정답 값: node tools/parity/make_soak_fixtures.js  (플레이 규칙은 그 파일 맨 위 설명과 같음)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/battle/sim.dart';
import 'package:kingday/core/actions.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/data.dart';
import 'package:kingday/core/js.dart';
import 'package:kingday/core/rng.dart';
import 'package:kingday/core/state.dart';

/// 처음 다른 곳 하나만 알려 줌 (긴 비교라 실패 메시지가 너무 길어지지 않게)
String? diff(Object? a, Object? e, String where) {
  if (e is num && a is num) {
    if (a == e) return null;
    final tol = 1e-9 * (e.abs() > 1 ? e.abs() : 1);
    return (a - e).abs() <= tol ? null : '$where: 앱 $a ≠ 웹 $e';
  }
  if (e is Map) {
    if (a is! Map) return '$where: 앱은 Map 이 아님 ($a)';
    for (final k in {...e.keys, ...a.keys}) {
      if (!e.containsKey(k)) return '$where.$k: 앱에만 있음 (${a[k]})';
      if (!a.containsKey(k)) return '$where.$k: 웹에만 있음 (${e[k]})';
      final d = diff(a[k], e[k], '$where.$k');
      if (d != null) return d;
    }
    return null;
  }
  if (e is List) {
    if (a is! List) return '$where: 앱은 List 가 아님 ($a)';
    if (a.length != e.length) return '$where: 길이 앱 ${a.length} ≠ 웹 ${e.length}';
    for (var i = 0; i < e.length; i++) {
      final d = diff(a[i], e[i], '$where[$i]');
      if (d != null) return d;
    }
    return null;
  }
  return a == e ? null : '$where: 앱 $a ≠ 웹 $e';
}

dynamic j(Object? v) => jsonDecode(jsonEncode(v));

void main() {
  final fx = jsonDecode(File('test/fixtures/soak_parity.json').readAsStringSync()) as Map<String, dynamic>;
  final now = fx['now'] as int, dt = (fx['dt'] as num).toDouble(), snapEvery = fx['snap'] as int;
  final blds = (fx['blds'] as List).cast<String>();

  for (final e in (fx['cases'] as Map<String, dynamic>).entries) {
    test('긴 플레이 「${e.key}」 — 웹과 같은 결과', () {
      final cs = e.value as Map<String, dynamic>;
      final s = GameState.hydrate(cs['save'] as Map<String, dynamic>, now, GameCalc.rankIdxOf);
      var clock = now;
      final c = GameCalc(s, clock: () => clock);
      final rng = Mulberry32(777001);
      final b = BattleSim(c, rng: rng, gobT: 200)
        ..w = fx['w'] as num
        ..ht = fx['ht'] as num;
      final a = GameActions(c, rng: rng)
        ..bossFight = (() => b.mons.any((m) => m.boss && m.hp > 0 && m.dead == 0))
        ..onHpAdd = (id, h) {
          final p = b.party[id];
          if (p != null) p.hp += h;
        }
        ..onSwap = (cur, id) {
          // 진행 담당 _swap 과 같음 (웹 setMember)
          final p = b.party[cur];
          if (p == null) return;
          final r = p.down ? 0 : p.hp / c.stats(cur).hp;
          b.party.remove(cur);
          b.party[id] = Member(hp: c.stats(id).hp * (r < 0 ? 0 : r), cd: .5)..down = r <= 0;
        };
      final snaps = (cs['snaps'] as List).cast<Map<String, dynamic>>();
      var k = 0;
      final frames = cs['frames'] as int;
      for (var f = 1; f <= frames; f++) {
        clock = now + (f * 1000 / 30).floor();
        b.step(dt);
        b.events.clear();
        if (f % 12 == 0) c.produce();
        if (f % 27 == 0) a.openBox(true);
        if (f % 150 == 0) {
          s.raw['upMul'] = 'max';
          final best = a.bestUpgrade();
          if (best != null) a.upFire(best);
        }
        if (f % 900 == 0) {
          for (final id in c.members()) {
            if (id == 'kael') continue;
            final cc = GameCalc.compCost(asNum(s.lv[id], 1));
            if (s.gold < cc) continue;
            a.levelUp(id);
          }
          for (final id in GameCalc.cardIds()) {
            final need = c.starNeed(id);
            if (c.cardOpen(id) && need != null && orNum(s.cardsW[id], 0) >= need && c.recStar(id) < c.starMax(id)) a.recruitUp(id);
          }
          a.autoForm();
        }
        if (f % 1800 == 0) {
          a.ensurePlots();
          for (var i = 0; i < s.plots.length; i++) {
            a.harvest(i);
          }
          a.plantAll();
          for (final bk in blds) {
            a.orderBuild(bk);
          }
        }
        if (f % snapEvery == 0) {
          final d = diff(j(s.raw), snaps[k]['S'], '${e.key} ${(f * dt / 60).toStringAsFixed(0)}분 S');
          if (d != null) fail(d);
          k++;
        }
      }
      expect(k, snaps.length);
      expect(maxLand, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
