// 웹 버전과 같은 공식·같은 숫자인지 확인하는 테스트.
//
// 정답 값(test/fixtures/web_parity.json)은 웹 index.html 의 코드를 Node 에서 그대로 돌려 뽑은 것이다.
//   node tools/parity/make_fixtures.js
// 웹 공식을 바꾸면 위 명령으로 정답 값을 다시 뽑고, Dart 공식도 같이 고쳐 이 테스트를 통과시킨다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/data.dart';
import 'package:kingday/core/fmt.dart';
import 'package:kingday/core/rng.dart';
import 'package:kingday/core/state.dart';

late Map<String, dynamic> fx;
late int now;

/// 숫자는 아주 작은 오차(1e-11 비율)까지 같다고 본다. 나머지는 완전히 같아야 한다.
void same(Object? actual, Object? expected, String where) {
  if (expected is num && actual is num) {
    if (expected == actual) return;
    final tol = 1e-11 * (expected.abs() > 1 ? expected.abs() : 1);
    if ((actual - expected).abs() <= tol) return;
    fail('$where: 앱 $actual ≠ 웹 $expected');
  }
  if (expected is Map) {
    if (actual is! Map) fail('$where: 앱은 Map 이 아님 ($actual)');
    final ks = {...expected.keys, ...actual.keys};
    for (final k in ks) {
      if (!expected.containsKey(k)) fail('$where.$k: 앱에만 있음 (${actual[k]})');
      if (!actual.containsKey(k)) fail('$where.$k: 웹에만 있음 (${expected[k]})');
      same(actual[k], expected[k], '$where.$k');
    }
    return;
  }
  if (expected is List) {
    if (actual is! List) fail('$where: 앱은 List 가 아님 ($actual)');
    if (actual.length != expected.length) fail('$where: 길이 앱 ${actual.length} ≠ 웹 ${expected.length}');
    for (var i = 0; i < expected.length; i++) {
      same(actual[i], expected[i], '$where[$i]');
    }
    return;
  }
  if (actual != expected) fail('$where: 앱 $actual ≠ 웹 $expected');
}

GameCalc calcFor(String save, {int? at}) {
  final t = at ?? now;
  final s = GameState.hydrate((fx['saves'] as Map)[save] as Map<String, dynamic>, t, GameCalc.rankIdxOf);
  return GameCalc(s, clock: () => t);
}

dynamic relicJson(Relic r) => r.toJson();

void main() {
  setUpAll(() {
    fx = jsonDecode(File('test/fixtures/web_parity.json').readAsStringSync()) as Map<String, dynamic>;
    now = fx['now'] as int;
  });

  test('영지별 마물 체력·공격·보상·이름', () {
    for (final e in (fx['stages'] as List).cast<Map<String, dynamic>>()) {
      final st = e['st'] as int, w = 'stage $st';
      same(GameCalc.monHp(st, false), e['hpN'], '$w hpN');
      same(GameCalc.monHp(st, true), e['hpB'], '$w hpB');
      same(GameCalc.monAtk(st, false), e['atkN'], '$w atkN');
      same(GameCalc.monAtk(st, true), e['atkB'], '$w atkB');
      same(GameCalc.reward(st, false), e['gN'], '$w gN');
      same(GameCalc.reward(st, true), e['gB'], '$w gB');
      same(GameCalc.regionIndex(st), e['region'], '$w region');
      same(GameCalc.terrName(st), e['terr'], '$w terr');
      same(GameCalc.isLord(st), e['lord'], '$w lord');
      same(GameCalc.bossName(st), e['boss'], '$w boss');
    }
  });

  test('숫자·시간 표시', () {
    final f = fx['fmt'] as Map<String, dynamic>;
    for (final p in (f['fmt'] as List).cast<List>()) {
      final n = p[0] == 'Infinity' ? double.infinity : p[0] as num;
      same(fmt(n), p[1], 'fmt(${p[0]})');
    }
    for (final p in (f['fmtT'] as List).cast<List>()) {
      same(fmtT(p[0] as num), p[1], 'fmtT(${p[0]})');
    }
    for (final p in (f['mmss'] as List).cast<List>()) {
      same(mmss(p[0] as num), p[1], 'mmss(${p[0]})');
    }
  });

  test('카드 동료·전체 동료 목록 순서', () {
    same(GameCalc.cardIds(), fx['misc']['cardIds'], 'CARDIDS');
    same(comps.keys.toList(), fx['misc']['compIds'], 'COMP');
  });

  for (final name in ['fresh', 'mid', 'late', 'old']) {
    group('저장 데이터 「$name」', () {
      late Map<String, dynamic> sc;
      setUp(() => sc = (fx['scenarios'] as Map)[name] as Map<String, dynamic>);

      test('불러오기(hydrate) 결과가 웹과 같은 JSON', () {
        final c = calcFor(name);
        same(jsonDecode(jsonEncode(c.s.raw)), sc['hydrated'], 'S');
      });

      test('기본 공식', () {
        final c = calcFor(name), b = sc['basic'] as Map<String, dynamic>;
        same(c.rankIdx(), b['rankIdx'], 'rankIdx');
        same(c.memMul(), b['memMul'], 'memMul');
        same(c.allMul(), b['allMul'], 'allMul');
        same(c.boxCost(), b['boxCost'], 'boxCost');
        same(c.xpNeed(), b['xpNeed'], 'xpNeed');
        same(c.odds(), b['odds'], 'odds');
        same(c.retireTarget(), b['retireTarget'], 'retireTarget');
        same(c.retirePts(), b['retirePts'], 'retirePts');
        same(c.plotCount(), b['plotCount'], 'plotCount');
        same(c.landCount(), b['landCount'], 'landCount');
        same(c.vpMine(), b['vpMine'], 'vpMine');
        same(c.members(), b['members'], 'members');
        same(c.power(), b['power'], 'power');
        same(c.gemGold(), b['gemGold'], 'gemGold');
        same(c.goldRate(), b['goldRate'], 'goldRate');
        same([for (final x in goldExchanges) c.goldX(x)], b['goldX'], 'goldX');
        same([for (final k in buffName.keys) c.buff(k)], b['buffs'], 'buffs');
        same(c.subOn(), b['subOn'], 'subOn');
        final gs = c.gearSum();
        same({'a': gs.a, 'h': gs.h}, b['gearSum'], 'gearSum');
        same(c.kStats().toJson(), b['kStats'], 'kStats');
      });

      test('동료별 능력치·별·전투력', () {
        final c = calcFor(name);
        final cm = sc['comp'] as Map<String, dynamic>;
        for (final id in comps.keys) {
          final e = cm[id] as Map<String, dynamic>, w = id;
          same(c.stats(id).toJson(), e['stats'], '$w stats');
          same(c.cPow(id), e['cPow'], '$w cPow');
          same(c.owned(id), e['owned'], '$w owned');
          same(id == 'kael' ? 0 : c.recStar(id), e['recStar'], '$w recStar');
          same(c.starMul(id), e['starMul'], '$w starMul');
          same(c.skPow(id), e['skPow'], '$w skPow');
          same(id == 'kael' ? false : c.cardOpen(id), e['cardOpen'], '$w cardOpen');
          same(id == 'kael' ? null : c.starNeed(id), e['starNeed'], '$w starNeed');
          same(id == 'kael' ? null : c.starMax(id), e['starMax'], '$w starMax');
          same(c.cwLv(id), e['cwLv'], '$w cwLv');
          same(c.cwMul(id), e['cwMul'], '$w cwMul');
        }
      });

      test('편성 자리', () {
        final c = calcFor(name);
        final sl = sc['slots'] as Map<String, dynamic>;
        for (final j in jobSlots) {
          final e = sl[j] as Map<String, dynamic>;
          same(c.slotMember(j), e['member'], '$j member');
          same(j == 'kael' ? ['kael'] : c.jobMembers(j), e['all'], '$j all');
          same(j == 'kael' ? false : c.betterBench(j), e['better'], '$j better');
        }
      });

      test('비용·건물·가격·광고·목표', () {
        final c = calcFor(name), e = sc['costs'] as Map<String, dynamic>;
        same([for (var l = 0; l <= 20; l++) c.enCost(l)], e['en'], 'enCost');
        same([for (var l = 0; l <= 20; l++) c.cwOre(l)], e['cwOre'], 'cwOre');
        same([for (var l = 0; l <= 20; l++) c.cwGold(l)], e['cwGold'], 'cwGold');
        same([for (var l = 1; l <= 80; l++) GameCalc.compCost(l)], e['comp'], 'compCost');
        same({for (final u in upgrades) u.k: [for (var l = 0; l <= 60; l++) GameCalc.upgradeCost(u.k, l)]}, e['upg'], 'UPG');
        same({
          for (final b in buildings)
            b.k: [
              for (var l = 0; l <= b.max; l++)
                {
                  'cost': GameCalc.bldCost(b, l),
                  'ore': c.bldOre(b, l),
                  'time': c.bldTime(b, l),
                  'gem': c.bldGem(GameCalc.bldCost(b, l)) + GameCalc.timeGem(c.bldTime(b, l)),
                }
            ]
        }, e['bld'], 'BLD');
        same({for (final b in buildings) b.k: c.bldOpen(b.k)}, e['bldOpen'], 'bldOpen');
        same({for (final b in buildings) b.k: [for (var l = 0; l <= b.max; l++) c.bldEff(b.k, l)]}, e['bldEff'], 'bldEff');
        same({for (final k in itemName.keys) k: c.itemPrice(k)}, e['price'], 'itemPrice');
        same([for (final s in [0, 1, 179, 180, 181, 3600, 43200]) GameCalc.timeGem(s)], e['timeGem'], 'timeGem');
        same({for (final k in ads.keys) k: c.adLeft(k)}, e['adLeft'], 'adLeft');
        same(c.cardReady(), e['cardReady'], 'cardReady');
        same(c.nextGoal(), e['nextGoal'], 'nextGoal');
      });

      test('방치 보상', () {
        same(calcFor(name).offlineReward().gold, sc['offline'], 'offline');
      });

      test('생산·공사 완료', () {
        final c = calcFor(name)..produce();
        final r = c.s.raw;
        same(jsonDecode(jsonEncode({'items': r['items'], 'prod': r['prod'], 'bld': r['bld'], 'build': r['build'], 'bq': r['bq']})),
            sc['produced'], 'produce');
      });

      test('밭 상태', () {
        final c = calcFor(name);
        same([
          for (final p in c.s.plots)
            () {
              final ps = c.plotState(p);
              return {'st': ps.st, 'k': ps.c?.k, 'left': ps.left};
            }()
        ], sc['plots'], 'plots');
      });

      test('성유물 상자·동료 카드 (같은 난수)', () {
        final c = calcFor(name), r = sc['rolls'] as Map<String, dynamic>;
        var rng = Mulberry32(4242);
        same([for (var i = 0; i < 40; i++) relicJson(c.rollItem(rng))], r['items'], 'rollItem');
        same([for (var g = 0; g < 6; g++) relicJson(c.rollItem(rng, g))], r['forced'], 'rollItem(g)');
        rng = Mulberry32(777);
        same([for (var i = 0; i < 30; i++) c.gainCard(rng, 1), c.gainCard(rng, 30, 'epic')], r['cards'], 'gainCard');
        same(jsonDecode(jsonEncode(c.s.raw['cards'])), r['cardsAfter'], 'cards');
      });

      test('은퇴', () {
        final c = calcFor(name)..retire(5);
        same(jsonDecode(jsonEncode(c.s.raw)), sc['retired'], 'retired S');
      });

      test('날짜가 바뀌면 오늘의 할 일 새로 시작', () {
        final c = calcFor(name, at: now + 24 * 3600 * 1000);
        same(jsonDecode(jsonEncode(c.daily())), sc['dailyNext'], 'daily');
      });
    });
  }
}
