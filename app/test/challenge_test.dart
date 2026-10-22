// 도전(시련의 탑·요일 던전) 규칙이 웹과 같은지 + 전투 흐름 확인.
//
// 정답 값(test/fixtures/challenge.json)은 웹 index.html 의 towerInfo·dunReward·dunL 등을 브라우저에서 돌려 뽑은 것이다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/battle/sim.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/challenge.dart';
import 'package:kingday/core/js.dart';
import 'package:kingday/core/profile_data.dart';
import 'package:kingday/core/rng.dart';
import 'package:kingday/core/state.dart';

void close(num a, num e, String where) {
  final tol = 1e-9 * (e.abs() > 1 ? e.abs() : 1);
  expect((a - e).abs() <= tol, isTrue, reason: '$where: 앱 $a ≠ 웹 $e');
}

void main() {
  final fx = jsonDecode(File('test/fixtures/challenge.json').readAsStringSync()) as Map<String, dynamic>;
  const now = 1792465200000; // 2026-10-20 (화)

  GameCalc calcFor(Map<String, dynamic> save) {
    final st = GameState.hydrate(save, now, GameCalc.rankIdxOf);
    return GameCalc(st, clock: () => now);
  }

  test('탑 층 수치·규칙·이름·보상이 웹과 같음', () {
    for (final t in fx['tower'] as List) {
      final f = t['f'] as int, i = towerInfo(f);
      expect(i.s, t['s'], reason: '$f s');
      expect(i.gate, t['gate'], reason: '$f gate');
      expect(i.rule, t['rule'], reason: '$f rule');
      expect(i.name, t['name'], reason: '$f name');
      expect(i.face, t['face'], reason: '$f face');
      expect(i.lim, t['lim'], reason: '$f lim');
      expect(i.art.ri, t['ri'], reason: '$f ri');
      expect(i.art.lord, t['lord'], reason: '$f lord');
      expect(i.art.balt, t['balt'], reason: '$f balt');
      expect(i.art.guard, t['guard'], reason: '$f guard');
      expect(i.art.ghost, t['ghost'], reason: '$f ghost');
      close(i.hp, t['hp'] as num, '$f hp');
      close(i.atk, t['atk'] as num, '$f atk');
      expect(jsFloor(towerGold(f)), t['gold'], reason: '$f gold');
      expect(towerOre(f), t['ore'], reason: '$f ore');
    }
  });

  test('던전 보상·단계·요일·별 기준이 웹과 같음', () {
    final c = calcFor({'gold': 60});
    for (final d in fx['dun'] as List) {
      final r = c.dunReward(d['k'] as String, d['l'] as int, d['r'] as num, false);
      final e = (d['rw'] as Map).cast<String, num>();
      expect(r.keys.toSet(), e.keys.toSet(), reason: '${d['k']} ${d['l']} ${d['r']}');
      for (final k in e.keys) {
        expect(r[k], e[k], reason: '${d['k']} L${d['l']} ×${d['r']} $k');
      }
    }
    for (final v in fx['lv'] as List) {
      final cc = calcFor({'gold': 60, 'best': v['best'], 'stage': 1, 'capClears': 0});
      expect(cc.dunL(), v['L'], reason: 'best ${v['best']} L');
      expect(cc.dunMs(), v['ms'], reason: 'best ${v['best']} ms');
      expect(cc.chCan(), v['can'], reason: 'best ${v['best']} can');
    }
    final open = fx['open'] as List;
    for (var w = 0; w < 7; w++) {
      expect(c.dunOpenK(w), (open[w] as List).cast<String>(), reason: '요일 $w');
    }
    expect(dunStars, (fx['stars'] as List).cast<int>());
    final b = fx['dunb'] as Map;
    expect([dunLive, dunSp, dunHpM, dunAtkM], [b['live'], b['sp'], b['hp'], b['atk']]);
  });

  test('저장 필드 기본값·은퇴해도 유지', () {
    final c = calcFor({'gold': 60, 'stage': 30, 'best': 30, 'chOpen': 1, 'tower': {'top': 12}, 'dun': {'star': {'mine': {'6': 3}}}});
    expect(asMap(asMap(c.s.raw['dun'])!['star'])!.keys.toSet(), {'mine', 'field', 'vault'});
    expect(asMap(c.s.raw['dun'])!['seen'], isA<Map>());
    c.retire(4);
    expect(c.chOpen, isTrue);
    expect(c.towerTop(), 12);
    expect(c.dunStar('mine', 6), 3);
    final f = calcFor({'gold': 60});
    expect(f.s.raw['chOpen'], 0);
    expect(f.towerTop(), 0);
  });

  test('탑 전투: 들어가도 영지 그대로 · 이기면 보상·기록 · 지면 실패 · 나가면 복귀', () {
    final c = calcFor({'gold': 1000, 'stage': 33, 'best': 33, 'wave': 4, 'chOpen': 1});
    final b = BattleSim(c, rng: Mulberry32(7), gobT: 1e9);
    b.syncParty();
    b.towerStart(15);
    expect(b.ch!.info!.rule, 1);
    for (var i = 0; i < 40; i++) {
      b.step(.05);
    }
    expect(b.mons.where((m) => m.boss).length, 2, reason: '쌍둥이');
    expect(b.bossLimit, 30);
    final g0 = c.s.gold, o0 = orNum(c.s.items['ore'], 0);
    for (final m in b.mons) {
      m.hp = 0;
    }
    b.step(.05);
    expect(b.ch!.st, 'win');
    expect(c.towerTop(), 15);
    expect(c.s.gold - g0, jsFloor(towerGold(15)));
    expect(orNum(c.s.items['ore'], 0) - o0, towerOre(15));
    expect(b.events.whereType<TowerWinEvent>().length, 1, reason: '쌍둥이를 한 번에 잡아도 돌파는 한 번');
    expect([c.s.stage, c.s.wave], [33, 4]);
    // 다음 층에서 시간 초과 → 실패, 기록 그대로
    b.towerStart(16);
    for (var i = 0; i < 120 && !b.engaged; i++) {
      b.step(.05);
    }
    b.bossT = .01;
    for (var i = 0; i < 5 && b.ch!.st == 'fight'; i++) {
      b.step(.05);
    }
    expect(b.ch!.st, 'lose');
    expect(c.towerTop(), 15);
    b.chExit();
    expect(b.ch, isNull);
    expect([c.s.stage, c.s.wave], [33, 4]);
    // 25층 배지 · 50층 테두리
    c.towerS['top'] = 49;
    b.towerStart(50);
    for (var i = 0; i < 20; i++) {
      b.step(.05);
    }
    for (final m in b.mons) {
      m.hp = 0;
    }
    b.step(.05);
    expect(c.pfHas('tower'), isTrue);
    expect(c.bdHas('tower25'), isTrue);
  });

  test('시련 규칙: 회복 금지 · 단단한 껍질', () {
    final c = calcFor({'gold': 1000, 'stage': 33, 'best': 33});
    final b = BattleSim(c, rng: Mulberry32(3), gobT: 1e9)..syncParty();
    b.towerStart(5);
    expect(b.healOk(), isFalse);
    b.chExit();
    expect(b.healOk(), isTrue);
    b.towerStart(35);
    for (var i = 0; i < 20; i++) {
      b.step(.05);
    }
    final m = b.mons.first;
    expect(m.shell, isTrue);
    final h0 = m.hp;
    b.hitMon(m, 100, false, 1);
    expect(h0 - m.hp, 50);
  });

  test('던전: 입장권·별·환불·소탕', () {
    final c = calcFor({'gold': 1000, 'stage': 33, 'best': 33, 'chOpen': 1});
    final b = BattleSim(c, rng: Mulberry32(11), gobT: 1e9)..syncParty();
    expect(c.dunLeft(), 2);
    // ★0 → 환불
    c.dunDay()['used'] = 1;
    b.dunStart('mine');
    b.dunEnd();
    expect(b.ch, isNull);
    expect(c.dunLeft(), 2);
    final ev = b.events.whereType<DunEndEvent>().last;
    expect(ev.star, 0);
    // ★3
    c.dunDay()['used'] = 1;
    b.dunStart('mine');
    final l = b.ch!.l, o0 = orNum(c.s.items['ore'], 0);
    b.ch!.kills = dunStars[2];
    b.ch!.t = .01;
    b.step(.05);
    expect(b.ch, isNull);
    expect(orNum(c.s.items['ore'], 0) - o0, 20 + l * 5);
    expect(c.dunStar('mine', l), 3);
    expect(c.sweepOk('mine'), isTrue);
    expect(c.sweepOk('field'), isFalse);
    // 마물이 끊기지 않음 (약한 단계로)
    final c2 = calcFor({'gold': 1000, 'stage': 5, 'best': 5});
    final b2 = BattleSim(c2, rng: Mulberry32(5), gobT: 1e9)..syncParty();
    b2.dunStart('field');
    for (var i = 0; i < 200; i++) {
      b2.step(.05);
    }
    expect(b2.ch, isNotNull);
    expect(b2.mons.isNotEmpty, isTrue);
    expect(b2.mons.every((m) => m.ri == 0 && m.alt), isTrue);
    expect(b2.ch!.kills, greaterThan(0));
    b2.dunEnd();
  });

  test('탑 보급: 하루 1번', () {
    final c = calcFor({'gold': 1000, 'stage': 33, 'best': 33, 'chOpen': 1, 'tower': {'top': 100, 'day': ''}});
    expect(c.supplyMin(), 120);
    expect(c.supplyOre(), 45);
    final r = c.claimSupply();
    expect(r, isNotNull);
    expect(r!.$2, 45);
    expect(c.claimSupply(), isNull);
  });
}
