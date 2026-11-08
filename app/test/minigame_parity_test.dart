// 선물 배달: 웹 mgStep 과 같은 판 번호·같은 누름이면 같은 점수 (정답 값: tools/parity/make_mg_fixtures.js)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/minigame.dart';
import 'package:kingday/core/rng.dart';

void main() {
  final fx = jsonDecode(File('test/fixtures/mg_parity.json').readAsStringSync()) as Map<String, dynamic>;

  test('판 번호 난수: 웹 mgRng 와 같은 순서', () {
    final seeds = [1, 7, 42, 20261221, 3141592653, 4294967295, 123456789, 99, 2024, 777777];
    final want = fx['rng'] as List;
    for (var i = 0; i < seeds.length; i++) {
      final r = Mulberry32(seeds[i]);
      expect([r.next(), r.next(), r.next()], (want[i] as List).cast<num>(), reason: 'seed ${seeds[i]}');
    }
  });

  test('최대 점수 = 서버 kd_minigames.max_score', () => expect(Mgc.maxScore, fx['maxScore']));

  for (final c in (fx['cases'] as List).cast<Map<String, dynamic>>()) {
    test('${c['seed']} · ${c['kind']} → 웹과 같은 점수 ${c['score']}', () {
      final g = MgGame(c['seed'] as int), taps = (c['taps'] as List).cast<int>().toSet();
      var guard = 0;
      while (!g.over && guard++ < 5000) {
        if (taps.contains(g.n)) g.tap();
        g.step();
      }
      expect(
        {'score': g.score, 'hits': g.hits, 'perf': g.perfN, 'maxC': g.maxC, 'miss': g.miss, 'drops': g.drops, 'n': g.n, 'hs': g.hs.length},
        {for (final k in const ['score', 'hits', 'perf', 'maxC', 'miss', 'drops', 'n', 'hs']) k: c[k]},
      );
      expect(g.x, closeTo(c['x'] as num, 1e-6));
      expect(g.score, lessThanOrEqualTo(Mgc.maxScore));
    });
  }
}
