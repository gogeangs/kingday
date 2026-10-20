// 누르면 일어나는 일(상자·10연속·단련·레벨업·별·편성·대장간)이 웹과 같은지 확인.
// 정답 값: node tools/parity/make_action_fixtures.js (웹 코드를 같은 난수로 실행)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/actions.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/data.dart';
import 'package:kingday/core/rng.dart';
import 'package:kingday/core/state.dart';

void same(Object? a, Object? e, String where) {
  if (e is num && a is num) {
    if (a == e) return;
    final tol = 1e-11 * (e.abs() > 1 ? e.abs() : 1);
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
    if (a.length != e.length) fail('$where: 길이 앱 ${a.length} ≠ 웹 ${e.length}');
    for (var i = 0; i < e.length; i++) {
      same(a[i], e[i], '$where[$i]');
    }
    return;
  }
  if (a != e) fail('$where: 앱 $a ≠ 웹 $e');
}

dynamic j(Object? v) => jsonDecode(jsonEncode(v));

void main() {
  final fx = jsonDecode(File('test/fixtures/action_parity.json').readAsStringSync()) as Map<String, dynamic>;
  final now = fx['now'] as int;
  for (final e in (fx['cases'] as Map<String, dynamic>).entries) {
    test('조작 「${e.key}」 — 웹과 같은 결과', () {
      final cs = e.value as Map<String, dynamic>;
      final s = GameState.hydrate(cs['save'] as Map<String, dynamic>, now, GameCalc.rankIdxOf);
      final c = GameCalc(s, clock: () => now);
      final a = GameActions(c, rng: Mulberry32(9090));
      for (final st in (cs['steps'] as List).cast<Map<String, dynamic>>()) {
        final o = (st['op'] as String).split(':');
        switch (o[0]) {
          case 'box':
            a.openBox(o.length > 1 && o[1] == 'auto');
          case 'equip':
            a.equip(a.pending!);
          case 'sell':
            a.sell(a.pending!);
          case 'open10':
            a.open10();
          case 'mul':
            s.raw['upMul'] = o[1] == 'max' ? 'max' : int.parse(o[1]);
          case 'up':
            a.upFire(o[1]);
          case 'lv':
            a.levelUp(o[1]);
          case 'rec':
            a.recruitUp(o[1]);
          case 'set':
            a.setMember(o[1], o[2]);
          case 'auto':
            a.autoForm();
          case 'en':
            a.enhanceSlot(o[1]);
          case 'cw':
            a.enhanceWeapon(o[1]);
          case 'wish':
            a.toggleWish(o[1]);
          case 'autosell':
            s.raw['autoSell'] = o[1] == 'on';
          case 'gold':
            s.gold = num.parse(o[1]);
          case 'gem':
            s.gem = num.parse(o[1]);
          case 'card':
            s.cardsW[o[1]] = int.parse(o[2]);
          default:
            fail('모르는 조작 ${st['op']}');
        }
        final where = '${e.key} · ${st['op']}';
        same(j(s.raw), st['S'], '$where · S');
        same(j(a.pending?.toJson()), st['pending'], '$where · pending');
        same([for (final u in upgrades) () {
          final p = a.upPlan(u);
          return {'n': p.n, 'c': p.c};
        }()], st['plan'], '$where · upPlan');
      }
    });
  }
}
