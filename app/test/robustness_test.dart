// QA: 예외 상황 — 깨진 저장, 이상한 값, 아주 큰 숫자, 시계가 거꾸로 감, 아주 오래 꺼 둠, 이상한 저장 코드.
// 어떤 경우에도 앱이 멈추지(예외) 않고, 골드·아이템이 음수나 NaN 이 되지 않아야 한다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/js.dart';
import 'package:kingday/core/save_code.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/core/state.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 숫자가 모두 정상인지 (NaN·무한·음수 골드 없음)
void sane(GameState s, String where) {
  // 처음부터 음수였던 저장은 음수 검사를 건너뜀
  final neg = where.contains('음수');
  void walk(Object? v, String p) {
    if (v is double) {
      expect(v.isNaN, isFalse, reason: '$where: $p 가 NaN');
      expect(v.isInfinite, isFalse, reason: '$where: $p 가 무한');
    } else if (v is Map) {
      v.forEach((k, x) => walk(x, '$p.$k'));
    } else if (v is List) {
      for (var i = 0; i < v.length; i++) {
        walk(v[i], '$p[$i]');
      }
    }
  }

  walk(s.raw, 'S');
  // 다시 저장해도 JSON 으로 바뀌어야 함
  expect(() => jsonEncode(s.raw), returnsNormally, reason: '$where: JSON 저장 불가');
  if (neg) return;
  expect(s.gold, greaterThanOrEqualTo(0), reason: '$where: 골드 음수');
  expect(s.gem, greaterThanOrEqualTo(0), reason: '$where: 이삭 음수');
  for (final e in s.items.entries) {
    expect(asNum(e.value), greaterThanOrEqualTo(0), reason: '$where: 아이템 ${e.key} 음수');
  }
}

final _now = DateTime.now().millisecondsSinceEpoch;

/// 깨지거나 이상한 저장들
final Map<String, String?> _badSaves = {
  '빈 문자열': '',
  '글자 쓰레기': '안녕하세요{{{',
  'null': 'null',
  '배열': '[1,2,3]',
  '빈 객체': '{}',
  '골드가 글자': '{"gold":"많이","stage":3}',
  '타입 뒤섞임': '{"gold":100,"stage":"7","best":null,"eq":3,"plots":"x","party":[],"joined":5,"lv":"a","up":[],"bld":{"farm":"2"},"items":{"ore":"5"},"seeds":null,"cards":{"daisy":"many"},"done":[],"started":true}',
  '음수와 이상한 숫자': '{"gold":-500,"gem":-3,"stage":-2,"best":0,"boxLv":0,"wave":99,"memory":-1,"retires":-1,"started":true}',
  '아주 큰 숫자': '{"gold":1.7e308,"gem":1e300,"stage":51,"best":51,"boxLv":10,"up":{"atk":900,"hp":900,"spd":40,"crit":55},"started":true}',
  '미래 시각(시계 되돌림)': '{"gold":1000,"stage":12,"best":12,"started":true,"last":${_now + 10 * 86400000},"prod":{"dock":${_now + 86400000}},"bld":{"dock":3,"farm":2},"plots":[{"k":"wheat","at":${_now + 86400000}}],"buffs":{"atk":${_now + 9e9}}}',
  // 웹 QA(2026-10-23): 웹은 이런 저장에서 멈추거나 새 게임으로 덮어썼음 → 웹·앱 hydrate 가 깨진 칸만 기본값으로
  '칸이 비어 있음(null)': '{"gold":null,"stage":23,"best":25,"bld":null,"up":null,"eq":null,"joined":null,"done":null,"lv":null,"items":null,"buffs":null,"prod":null,"seeds":null,"started":true}',
  '아주 오래 꺼 둠(1970년)': '{"gold":1000,"stage":12,"best":12,"started":true,"last":0,"prod":{"dock":0,"mine":0},"bld":{"dock":3,"mine":2,"farm":2},"plots":[{"k":"wheat","at":0}]}',
};

void main() {
  group('저장 불러오기가 절대 멈추지 않음', () {
    for (final e in _badSaves.entries) {
      test(e.key, () async {
        SharedPreferences.setMockInitialValues({if (e.value != null) 'acorn-idle-v1': e.value!});
        final store = await SaveStore.open();
        final s = store.load(_now);
        final c = GameCalc(s);
        // 공식들을 한 번씩 불러 봄
        c.power();
        c.produce();
        c.offlineReward();
        c.guideNow();
        c.retireTarget();
        c.boxCost();
        expect(c.offlineReward().gold, greaterThanOrEqualTo(0), reason: '방치 보상이 음수');
        sane(s, e.key);
      });
    }
  });

  test('깨진 칸이 있어도 나머지 기록은 살림 · 못 읽은 저장은 백업', () async {
    SharedPreferences.setMockInitialValues({'acorn-idle-v1': _badSaves['칸이 비어 있음(null)']!});
    var store = await SaveStore.open();
    var s = store.load(_now);
    expect(s.stage, 23);
    expect(s.best, 25);
    expect(s.gold, 0);
    expect(asMap(s.raw['bld'])!['inn'], 0);
    expect(store.prefs.getString('acorn-idle-v1-bak'), isNull);
    SharedPreferences.setMockInitialValues({'acorn-idle-v1': '안녕하세요{{{'});
    store = await SaveStore.open();
    s = store.load(_now);
    expect(s.stage, 1);
    expect(store.prefs.getString('acorn-idle-v1-bak'), '안녕하세요{{{');
  });

  group('화면이 깨진 저장에서도 열림', () {
    for (final e in _badSaves.entries) {
      testWidgets(e.key, (tester) async {
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = const Size(360 * 3, 740 * 3);
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({if (e.value != null) 'acorn-idle-v1': e.value!});
        final store = await SaveStore.open();
        final g = GameController(store: store, state: store.load(DateTime.now().millisecondsSinceEpoch));
        await tester.pumpWidget(KingdayApp(g: g));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('게임 시작'));
        // 전투 10초 + 뜨는 창은 모두 닫기
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (i % 10 == 0) {
            final nav = g.navKey.currentState;
            if (nav != null && nav.canPop()) nav.pop();
          }
        }
        for (final t in GameTab.values) {
          g.setTab(t);
          await tester.pump(const Duration(milliseconds: 100));
        }
        g.setTab(null);
        await tester.pump(const Duration(milliseconds: 100));
        sane(g.state, e.key);
        await tester.pumpWidget(const SizedBox());
        g.dispose();
        await tester.pump(const Duration(seconds: 3));
      });
    }
  });

  testWidgets('화면을 켠 채 10분 자동 플레이 (창·탭·자동 열기)', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'acorn-idle-v1': jsonEncode({'gold': 3000, 'stage': 1, 'best': 1, 'started': true, 'autoOpen': true, 'autoSell': true, 'done': {'pete': true}, 'last': _now}),
    });
    final store = await SaveStore.open();
    final g = GameController(store: store, state: store.load(DateTime.now().millisecondsSinceEpoch));
    await tester.pumpWidget(KingdayApp(g: g));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('게임 시작'));
    // 시험 환경에서는 전투 화면(Flame)의 그림 불러오기가 끝나지 않으므로, 전투 한 걸음을 직접 돌림
    // (실제 폰에서는 Flame 이 매 프레임 부르는 것과 같은 함수)
    final tabs = [null, GameTab.eq, GameTab.pt, GameTab.up, GameTab.vl, GameTab.mp, null];
    for (var i = 0; i < 6000; i++) {
      if (!g.game.isLoaded) g.game.update(.1);
      await tester.pump(const Duration(milliseconds: 100));
      if (i % 30 == 0) {
        // 뜬 창은 닫고(고르던 장비는 버림), 단련도 조금씩
        final nav = g.navKey.currentState;
        if (nav != null && nav.canPop()) nav.pop();
        g.acts.pending = null;
        final best = g.acts.bestUpgrade();
        if (best != null) g.act((a) => a.upFire(best));
      }
      if (i % 600 == 0) g.setTab(tabs[(i ~/ 600) % tabs.length]);
    }
    expect(g.state.stage, greaterThan(3), reason: '10분 동안 영지를 몇 곳은 되찾아야 함');
    sane(g.state, '10분 자동 플레이');
    await tester.pumpWidget(const SizedBox());
    g.dispose();
    await tester.pump(const Duration(seconds: 3));
  }, timeout: const Timeout(Duration(minutes: 6)));

  test('시계가 거꾸로 가도 방치 보상·생산이 음수가 아님', () {
    final s = GameState.hydrate(jsonDecode(_badSaves['미래 시각(시계 되돌림)']!) as Map<String, dynamic>, _now, GameCalc.rankIdxOf);
    final c = GameCalc(s);
    final items0 = Map<String, dynamic>.from(s.items);
    c.produce();
    expect(c.offlineReward().gold, 0);
    for (final k in items0.keys) {
      expect(asNum(s.items[k]), greaterThanOrEqualTo(asNum(items0[k])), reason: '$k 가 줄어듦');
    }
    sane(s, '시계 되돌림');
  });

  test('아주 오래 꺼 두면 방치 보상은 최대 시간까지만', () {
    final s = GameState.hydrate(jsonDecode(_badSaves['아주 오래 꺼 둠(1970년)']!) as Map<String, dynamic>, _now, GameCalc.rankIdxOf);
    final c = GameCalc(s);
    final r = c.offlineReward();
    expect(r.sec, r.cap);
    expect(r.gold, greaterThan(0));
    c.produce();
    sane(s, '오래 꺼 둠');
  });

  test('저장 코드: 이모지·긴 기록도 그대로 오가고, 잘린 코드는 거절', () {
    final s = GameState.newGame(_now, GameCalc.rankIdxOf);
    s.raw['nick'] = '영주😀_왕';
    s.raw['big'] = List.generate(3000, (i) => {'i': i, 't': '가나다라마바사'});
    final code = exportSaveCode(s);
    final back = importSaveCode(code)!;
    expect(back['nick'], '영주😀_왕');
    expect((back['big'] as List).length, 3000);
    expect(importSaveCode(code.substring(0, code.length ~/ 2)), isNull);
    expect(importSaveCode('   '), isNull);
    expect(importSaveCode(base64Encode(utf8.encode('[1,2]'))), isNull);
  });
}
