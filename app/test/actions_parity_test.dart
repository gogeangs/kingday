// 누르면 일어나는 일(상자·10연속·단련·레벨업·별·편성·대장간)이 웹과 같은지 확인.
// 정답 값: node tools/parity/make_action_fixtures.js (웹 코드를 같은 난수로 실행)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/actions.dart';
import 'package:kingday/core/attendance.dart';
import 'package:kingday/core/bond.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/data.dart';
import 'package:kingday/core/profile_data.dart';
import 'package:kingday/core/rng.dart';
import 'package:kingday/core/state.dart';
import 'package:kingday/core/village.dart';

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
      var clock = now;
      final c = GameCalc(s, clock: () => clock);
      final a = GameActions(c, rng: Mulberry32(9090));
      for (final st in (cs['steps'] as List).cast<Map<String, dynamic>>()) {
        final o = (st['op'] as String).split(':');
        switch (o[0]) {
          case 'box':
            a.openBox(o.length > 1 && o[1] == 'auto');
          case 'equip':
            if (a.pending != null) a.equip(a.pending!);
          case 'sell':
            if (a.pending != null) a.sell(a.pending!);
          // ── 피트의 상점 ──
          case 'daily':
            c.daily()[o[1]] = num.parse(o[2]);
          case 'mis':
            a.claimMission(o[1]);
          case 'gx':
            a.buyGoldX(o[1]);
          case 'cp':
            a.buyCardPack(int.parse(o[1]));
          case 'pack':
            a.buyPack(o[1]);
          case 'starter':
            a.buyStarter();
          case 'sub':
            a.buySub();
          case 'subclaim':
            a.claimSub();
          case 'chief':
            a.buyChief();
          case 'chiefchk':
            a.chiefCheck();
          case 'chiefup':
            a.chiefUp();
          case 'kseat':
            a.setKaelSeat(o[1]);
          case 'ucard':
            s.raw['ucard'] = num.parse(o[1]);
          case 'retires':
            s.raw['retires'] = num.parse(o[1]);
          case 'adbox':
            a.adBoxGive();
          case 'adgem':
            s.gem = s.gem + 5;
          case 'adcard':
            a.adCardGive();
          case 'att':
            a.attDo(o[1]);
          case 'attad':
            a.attAdDo(o[1]);
          case 'attm':
            a.attA()['ym'] = o[1];
            a.attA()['m'] = int.parse(o[2]);
          // 판마다 따로 받기 · 전설 만능 카드 (CONTENT_ATTENDANCE_2.md)
          case 'attb':
            a.attDo(o[1], o[2]);
          case 'attadb':
            a.attAdDo(o[1], o[2]);
          case 'attlegacy':
            s.raw['att'] = {'last': o[1], 'w': int.parse(o[2]), 'ym': '2026-10', 'm': int.parse(o[3]), 'ad': o[1], 'got': [{'k': 'gem', 'n': 10}], 'intro': 1, 'tab': 'w'};
          case 'lcard':
            s.raw['lcard'] = int.parse(o[1]);
          case 'lcuse':
            a.lcardUse(o[1]);
          case 'tk':
            a.attA();
            (s.raw['tickets'] as Map)[o[1]] = int.parse(o[2]);
          // ── 상점·패스 (docs/content/SHOP.md) ──
          case 'started':
            s.raw['started'] = true;
          case 'padd':
            a.passAdd(o[1]);
          case 'pkill':
            for (var i = 0; i < int.parse(o[1]); i++) {
              a.passKill();
            }
          case 'ppt':
            a.passS()['pt'] = int.parse(o[1]);
          case 'pclaim':
            if (o.length > 1) {
              a.passClaim(o[1], int.parse(o[2]));
            } else {
              a.passClaim();
            }
          case 'pbuy':
            a.buyPass();
          case 'popen':
            a.passOpen(int.parse(o[1]));
          case 'pmail':
            a.passMailClaim(o.length > 1 ? o[1] : null);
          case 'pwarn':
            a.passWarn();
          case 'best':
            s.best = int.parse(o[1]);
          case 'grow':
            a.buyGrow();
          case 'growgive':
            a.growGive();
          case 'growchk':
            a.growCheck();
          // ── 유니크 뚝딱이 ──
          case 'tbuy':
            a.buyTtuk();
          case 'uqup':
            a.uqUp(o[1]);
          // ── 유니크 루시안 ──
          case 'lbuy':
            a.buyLucian();
          // ── 원정대의 정 ──
          case 'aff':
            (s.raw['aff'] as Map)[o[1]] = num.parse(o[2]);
          case 'afftick':
            a.affTick(num.parse(o[1]));
          case 'afftalk':
            a.affTalk(o[1]);
          case 'bondplay':
            a.bondPlay(int.parse(o[1]));
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
          // ── 마을 ──
          case 'ensure':
            a.ensurePlots();
          case 'plant':
            a.plant(int.parse(o[1]), o[2]);
          case 'plantc':
            a.plantChosen(int.parse(o[1]), o[2], tag: true);
          case 'choose':
            a.chooseSeedTagged(int.parse(o[1]));
          case 'harv':
            a.harvest(int.parse(o[1]));
          case 'tap':
            a.tapPlot(int.parse(o[1]));
          case 'harvall':
            a.harvestAll();
          case 'plantall':
            a.plantAll();
          case 'tag':
            a.cycleTag(int.parse(o[1]));
          case 'gemplot':
            final n = s.gemPlots.toInt();
            if (n < gemPlotCost.length) a.buyGemPlot(n, gemPlotCost[n]);
          case 'grownow':
            a.growNow();
          case 'cook':
            a.cook(o[1]);
          case 'sellall':
            a.sellAll();
          case 'build':
            a.orderBuild(o[1]);
          case 'cancel':
            a.cancelQueued(o[1]);
          case 'bgem':
            a.buildByGem(o[1]);
          case 'bfin':
            a.finishByGem();
          case 'time':
            clock += int.parse(o[1]);
            c.produce();
          case 'seeds':
            s.seeds[o[1]] = num.parse(o[2]);
          case 'items':
            s.items[o[1]] = num.parse(o[2]);
          // ── 마을 확장 ──
          case 'bld':
            s.bld[o[1]] = int.parse(o[2]);
          case 'otick':
            c.ordTick(a.rng);
          case 'odeliver':
            a.ordDeliver(int.parse(o[1]));
          case 'oskip':
            a.ordSkip(int.parse(o[1]));
          case 'keep':
            s.raw['keepOrder'] = int.parse(o[1]);
          case 'blessfirst':
            final opts = c.blessOpts(a.rng);
            if (opts.isNotEmpty) a.blessPick(opts.first);
          case 'blessad':
            a.blessAdGrant();
          case 'wkput':
            a.wkPut(o[1], int.parse(o[2]), o[3]);
          case 'wkout':
            c.work[o[1]] = c.wkIds(o[1]).where((x) => x != o[2]).toList();
          case 'wkauto':
            a.wkAuto(o[1] == '1');
          case 'wkclear':
            s.raw['work'] = <String, dynamic>{};
          case 'vlclaim':
            // 웹 vlClaim: 보상 → pfCheck → save()(마지막 접속 시각)
            if (a.vlClaim().isNotEmpty) {
              c.pfCheck();
              s.last = c.now;
            }
          case 'harvre':
            a.harvestReplant();
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
