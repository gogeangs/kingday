// 웹 버전과 같은 공식·같은 숫자인지 확인하는 테스트.
//
// 정답 값(test/fixtures/web_parity.json)은 웹 index.html 의 코드를 Node 에서 그대로 돌려 뽑은 것이다.
//   node tools/parity/make_fixtures.js
// 웹 공식을 바꾸면 위 명령으로 정답 값을 다시 뽑고, Dart 공식도 같이 고쳐 이 테스트를 통과시킨다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/actions.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/data.dart';
import 'package:kingday/core/profile_data.dart';
import 'package:kingday/core/retire.dart';
import 'package:kingday/core/fmt.dart';
import 'package:kingday/core/js.dart';
import 'package:kingday/core/rng.dart';
import 'package:kingday/core/save_code.dart';
import 'package:kingday/core/state.dart';
import 'package:kingday/core/village.dart';
import 'package:kingday/core/worldmap.dart';
import 'package:kingday/game/online.dart';

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

  test('웹에서 만든 저장 코드를 그대로 불러오고, 앱 코드도 다시 읽힘', () {
    final codes = (fx['codes'] as Map).cast<String, String>();
    for (final e in codes.entries) {
      final d = importSaveCode(e.value);
      expect(d, isNotNull, reason: e.key);
      final st = GameState.hydrate(d!, now, GameCalc.rankIdxOf);
      same(jsonDecode(jsonEncode(st.raw)), (fx['scenarios'] as Map)[e.key]['hydrated'], '코드 ${e.key}');
      // 줄바꿈이 섞여 붙여 넣어도
      final broken = e.value.replaceAllMapped(RegExp(r'.{40}'), (m) => '${m[0]}\n ');
      expect(importSaveCode(broken), isNotNull, reason: '줄바꿈 ${e.key}');
      same(jsonDecode(jsonEncode(importSaveCode(exportSaveCode(st)))), jsonDecode(jsonEncode(st.raw)), '앱 코드 ${e.key}');
    }
    expect(importSaveCode('엉터리'), isNull);
    expect(importSaveCode(base64Encode(utf8.encode('{"stage":3}'))), isNull);
  });

  test('랭킹: 영지 이름·시즌 끝·주차', () {
    for (final e in fx['misc']['stgName'] as List) {
      expect(stgName(e[0] as num), e[1], reason: '${e[0]}');
    }
    expect(seasonEndAt(now), fx['misc']['seasonEnd']);
    expect(((now - seasonZero) / 6048e5).floor() + 1, fx['misc']['curWeek']);
  });

  test('성유물 상자 레벨별 확률 (상한 없음 · 태초, RELIC_BOX.md)', () {
    final c = calcFor('fresh');
    for (final e in fx['misc']['odds'] as List) {
      same(c.odds(e[0] as int), e[1], 'odds Lv.${e[0]}');
    }
  });

  test('카드 동료·전체 동료 목록 순서', () {
    same(GameCalc.cardIds(), fx['misc']['cardIds'], 'CARDIDS');
    same(comps.keys.toList(), fx['misc']['compIds'], 'COMP');
  });

  for (final name in ['fresh', 'mid', 'late', 'old', 'g1', 'g2', 'g3', 'g4', 'tr', 'box']) {
    group('저장 데이터 「$name」', () {
      late Map<String, dynamic> sc;
      setUp(() => sc = (fx['scenarios'] as Map)[name] as Map<String, dynamic>);

      test('프로필 테두리·배지 열림 (pfCheck)', () {
        final c = calcFor(name);
        c.pfCheck();
        same(jsonDecode(jsonEncode({'pfUnl': c.s.raw['pfUnl'], 'bdUnl': c.s.raw['bdUnl'], 'pfNew': c.s.raw['pfNew']})), sc['pf'], 'pf');
      });

      test('은퇴 일기: 특성·지름길·추억 보정·효과 배수', () {
        final c = calcFor(name), r = sc['retire'] as Map<String, dynamic>;
        same({for (final t in memTraits) t.k: c.tl(t.k)}, r['tl'], 'tl');
        same(c.trSpent(), r['spent'], 'trSpent');
        same([for (final b in memBranches) c.trSpent(b.k)], r['spentB'], 'trSpent(b)');
        same(c.memPts(), r['memPts'], 'memPts');
        same(c.trCanAny(), r['canAny'], 'trCanAny');
        same([for (final t in memTraits) c.trOpen(t)], r['open'], 'trOpen');
        same([for (final t in memTraits) c.trNext(t)], r['next'], 'trNext');
        same(c.trResetGem(), r['resetGem'], 'trResetGem');
        same(c.retStart(false), r['start'], 'retStart');
        same(c.retStart(true), r['start1'], 'retStart(1)');
        same(c.retireBase(), r['base'], 'retireBase');
        same(c.retirePts(), r['pts'], 'retirePts');
        same(c.retRun(), r['run'], 'retRun');
        same(c.retCan(), r['can'], 'retCan');
        same([for (final st in [1, 6, 31]) c.retPurse(st)], r['purse'], 'retPurse');
        same([for (final st in [5, 10, 60]) c.bossLimT(st)], r['bossLim'], 'bossLim');
        same([for (final cr in crops) c.cropT(cr)], r['cropT'], 'cropT');
        same(c.crX(), r['crX'], 'crX');
        same(c.offCapH(), r['offCapH'], 'offCapH');
        same(c.trCook(), r['trCook'], 'trCook');
        same(c.trProd(), r['trProd'], 'trProd');
        same(c.trBld(), r['trBld'], 'trBld');
        same(c.trUp(), r['trUp'], 'trUp');
        same([for (final t in memTraits) [t.e(1), t.e(t.max)]], r['eff'], 'MEMT 효과 문구');
        same(memTotal, 282, '전부 찍는 포인트');
      });

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
        same(c.guideIndex(), b['guide'], 'guide');
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
        same({for (final u in upgrades) u.k: [for (var l = 0; l <= 60; l++) c.upgradeCost(u.k, l)]}, e['upg'], 'UPG');
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

      test('마을 확장 공식 (일꾼·생산·주문·축복·마을 레벨)', () {
        final c = calcFor(name), v = sc['village'] as Map<String, dynamic>;
        // 웹과 같은 순서로 부름 (blessLeft 는 날짜가 바뀌면 S.bless 를 새로 씀)
        final m = <String, dynamic>{};
        m['enMax'] = c.enMax();
        m['forgeCut'] = c.forgeCut();
        m['bldSum'] = c.bldSum();
        m['vLv'] = c.vLv();
        m['vlRw'] = c.vlRw();
        m['work'] = {for (final b in buildings) b.k: {'slots': c.wkSlots(b.k), 'ids': c.wkIds(b.k), 'bonus': c.workBonus(b.k), 'prodMul': c.prodMul(b.k)}};
        m['rest'] = c.restIds();
        m['idle'] = c.idleIds();
        m['working'] = c.working();
        m['wkOpen'] = c.wkOpen();
        m['wkOne'] = {for (final id in GameCalc.cardIds()) id: [for (final b in buildings) c.wkOne(b.k, id)]};
        m['cookMs'] = c.cookMs();
        m['vHp'] = c.vHp();
        m['vBrave'] = c.vBrave();
        m['vIdle'] = c.vIdle();
        m['idle1h'] = c.idleGold(3600);
        m['ordN'] = ordN(orNum(c.s.bld['market'], 0));
        m['ordMats'] = c.ordMats();
        m['per2'] = [for (final k in c.ordMats()) c.per2(k)];
        m['ordGold'] = [
          for (final o in c.orders) asMap(o) != null && truthy(asMap(o)!['need']) ? c.ordGold(asMap(o)!) : null
        ];
        m['ordCan'] = [for (final o in c.orders) c.ordCan(o)];
        m['ordReady'] = c.ordReady();
        m['ordKeep'] = c.ordKeep();
        m['blessK'] = c.blessK();
        m['blessMs'] = c.blessMs();
        m['blessLeft'] = c.blessLeft();
        m['blessSec'] = [for (final l in [0, 5, 10]) blessSec(l)];
        m['bless'] = jsonDecode(jsonEncode(c.s.raw['bless']));
        same(m, v, 'village');
      });

      test('대륙 지도 규칙 (안개·이번 회차·탐험·어둠 지울 원)', () {
        final c = calcFor(name), h = c.mapHoles();
        same({
          'seen': [for (var st = 1; st <= 60; st++) c.mapSeen(st)],
          'taken': [for (var st = 1; st <= 60; st++) c.mapTaken(st)],
          'entered': [for (var r = 0; r < 6; r++) c.mapEntered(r)],
          'cleared': [for (var r = 0; r < 6; r++) c.mapRegCleared(r)],
          'all': c.mapAllClear(),
          'explore': c.mapExplore(),
          'cur': c.mapCur(),
          'holes': h == null ? null : [for (final x in h) [x.$1, x.$2, x.$3]],
        }, sc['worldmap'], 'worldmap');
      });

      test('유니크 카엘 촌장 (새벽 종소리·카엘 자리·별 올리기)', () {
        final c = calcFor(name);
        same({
          'vp': c.vpChief(),
          'on': c.chiefOn(),
          'shop': c.chiefShop(),
          'can': c.chiefCan(),
          'pct': [for (var st = 1; st <= 5; st++) GameCalc.chPct(st)],
          'prod': [for (final b in const ['mine', 'dock', 'apiary', 'ranch', 'farm']) c.prodMul(b)],
          'slot': c.slotMember('kael'),
          'mem': c.members(),
          'pow': c.power(),
        }, sc['chief'], 'chief');
      });

      test('마을 난수 (주문·축복 고르기·길 위 동료·다른 주문)', () {
        final c = calcFor(name), r = sc['vrand'] as Map<String, dynamic>, rng = Mulberry32(5151);
        final a = GameActions(c, rng: rng);
        c.s.raw['orders'] = <dynamic>[];
        c.ordTick(rng);
        final o = jsonDecode(jsonEncode(c.orders));
        c.s.raw['bless'] = <String, dynamic>{'d': '', 'used': 0, 'ad': 0, 'k': '', 'until': 0, 'opts': <dynamic>[]};
        final opts = c.blessOpts(rng);
        c.s.raw['walkers'] = <String, dynamic>{'d': '', 'ids': <dynamic>[]};
        final wk = c.walkersToday(rng);
        final sk = <dynamic>[];
        for (var i = 0; i < c.orders.length; i++) {
          final x = asMap(c.orders[i]);
          if (x != null && truthy(x['need'])) {
            a.ordSkip(i);
            a.ordSkip(i);
            sk.add(jsonDecode(jsonEncode(c.orders[i])));
          }
        }
        same({'orders': o, 'opts': opts, 'walkers': wk, 'skip': sk, 'day': jsonDecode(jsonEncode(c.s.raw['ordDay']))}, r, 'vrand');
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
        same([
          for (var i = 0; i < 30; i++) c.gainCard(rng, 1),
          c.gainCard(rng, 30, 'battle'),
          for (var i = 0; i < 20; i++) c.gainCard(rng, 2, 'battle'),
        ], r['cards'], 'gainCard');
        final ch = c.gainCards(rng, 30, 'shop', 5);
        same(ch == null ? null : {'got': [for (final (id, n) in ch.got) [id, n]], 'gold': ch.gold}, r['chunks'], 'gainCards');
        same(jsonDecode(jsonEncode(c.s.raw['cards'])), r['cardsAfter'], 'cards');
        same(c.s.gold, r['goldAfter'], 'gold');
      });

      test('은퇴', () {
        // 웹 retire(p): 은퇴 + 은퇴 횟수 보상(retRwCheck → 받은 게 있으면 pfCheck)
        final c = calcFor(name)..retire(5);
        if (c.retRwCheck() != null) c.pfCheck();
        GameActions(c).chiefCheck(); // 은퇴 10번이면 카엘 촌장 합류 (웹 retire 끝의 chiefCheck)
        same(jsonDecode(jsonEncode(c.s.raw)), sc['retired'], 'retired S');
      });

      test('날짜가 바뀌면 오늘의 할 일 새로 시작', () {
        final c = calcFor(name, at: now + 24 * 3600 * 1000);
        same(jsonDecode(jsonEncode(c.daily())), sc['dailyNext'], 'daily');
      });
    });
  }
}
