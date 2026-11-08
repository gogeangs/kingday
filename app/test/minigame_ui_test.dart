// 미니게임 「선물 배달」 화면 (docs/content/EVENT_SNOW.md 3-9~3-11)과 우편 외형·이벤트 재화 (8-1).
// 화면: 연습판을 판 번호 고정으로 열어 3초 세기 → 몇 번 누르기 → 30초 끝 → 결과 판(「…점」)이 나오는지.
// 우편: {skin:'santa', skin_year:2026, evc:{snow2026:300}} 를 받으면 외형과 눈송이 300.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/event.dart';
import 'package:kingday/core/fmt.dart';
import 'package:kingday/core/js.dart';
import 'package:kingday/core/minigame.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/screens/minigame_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

int kst(int y, int m, int d, [int h = 12]) => DateTime.utc(y, m, d, h - 9).millisecondsSinceEpoch;

/// 서버·저장 없이 화면만 돌려 보는 가짜 게임 쪽
class _FakeHost implements MgHost {
  final toasts = <String>[];
  final ends = <int>[];
  int prepared = 0;
  bool ranked = false, doneTap = false;

  @override
  final ValueNotifier<String?> toastMsg = ValueNotifier<String?>(null);

  @override
  void toast(String m) {
    toasts.add(m);
    toastMsg.value = m;
  }

  @override
  void haptic(List<int> p) {}

  @override
  Future<(MgPlan?, bool)> prepare(bool practice, bool Function() gone) async {
    prepared++;
    return (MgPlan(seed: 12345, practice: practice, hint: true), false);
  }

  @override
  MgEnd finish(MgPlan plan, int score) {
    ends.add(score);
    return MgEnd(title: plan.practice ? '연습판' : '선물 배달', score: score, best: false, practice: plan.practice, left: 0);
  }

  @override
  void rank() => ranked = true;

  @override
  void done() => doneTap = true;
}

void main() {
  testWidgets('선물 배달 화면: 연습판 3초 세기 → 누르기 → 끝 → 결과 판', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 780 * 3);
    addTearDown(tester.view.reset);
    final host = _FakeHost();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => MinigameScreen(host: host, practice: true, seed: 777))),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(host.prepared, 1);

    // 3초 세기 (아직 누름이 먹지 않음)
    for (var i = 0; i < 10; i++) {
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('mgCanvas'))));
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // 진행: 0.5초마다 누르기 (30초 + 선물이 떨어질 때까지)
    for (var i = 0; i < 340 && find.byKey(const ValueKey('mgScore')).evaluate().isEmpty; i++) {
      if (i % 5 == 0) await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('mgCanvas'))));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(host.ends, hasLength(1), reason: '판이 한 번 끝남');
    expect(find.textContaining('점'), findsWidgets);
    expect(find.text('${fmt(host.ends.single)}점'), findsOneWidget);
    expect(find.text('연습 다시'), findsOneWidget);

    // 연습 다시 → 다시 준비
    await tester.tap(find.text('연습 다시'));
    await tester.pump();
    expect(host.prepared, 2);

    // ✕: 연습판은 바로 닫힘
    await tester.tap(find.byKey(const ValueKey('mgX')));
    await tester.pumpAndSettle();
    expect(find.byType(MinigameScreen), findsNothing);
  });

  testWidgets('같은 판 번호·같은 누름이면 같은 점수 (화면 없이)', (tester) async {
    int run() {
      final g = MgGame(777);
      for (var i = 0; i < 60 * 32 && !g.over; i++) {
        if (i % 30 == 0) g.tap();
        g.step();
      }
      return g.score;
    }

    expect(run(), run());
  });

  testWidgets('우편: 외형 「산타 카엘」 + 눈송이 300 (이벤트 기간 중)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'acorn-idle-v1': jsonEncode({'gold': 1e6, 'stage': 30, 'best': 30, 'started': true, 'last': DateTime.now().millisecondsSinceEpoch}),
    });
    // 서버 시각을 이벤트 기간(12/15)으로 (기기 시계는 그대로)
    EvClock.skew = kst(2026, 12, 15) - DateTime.now().millisecondsSinceEpoch;
    EvClock.rows = null;
    EvClock.demo = null;
    addTearDown(() => EvClock.skew = 0);
    final store = await SaveStore.open();
    final g = GameController(store: store, state: store.load(DateTime.now().millisecondsSinceEpoch));
    expect(g.calc.evPhase(evts['snow2026']!), 'on');
    final sf0 = asNum(g.calc.evS('snow2026')['sf']);

    g.online.mailApply([
      {
        'id': 9,
        'reward': {
          'skin': 'santa',
          'skin_year': 2026,
          'evc': {'snow2026': 300},
        },
      },
    ]);
    expect(g.calc.skinHas('santa'), isTrue);
    expect((g.state.raw['skins'] as Map)['santa'], [2026]);
    expect(g.state.raw['skin'], 'santa', reason: '처음 받은 외형은 바로 입음');
    expect(g.calc.skinFace('kael'), 'kael_santa');
    expect(asNum(g.calc.evS('snow2026')['sf']) - sf0, 300);

    // 표에 없는 이벤트·외형은 무시, 큰 수는 100000까지
    g.online.mailApply([
      {
        'reward': {
          'skin': 'nope',
          'evc': {'old2020': 50, 'snow2026': 1e9},
        },
      },
    ]);
    expect(asNum(g.calc.evS('snow2026')['sf']) - sf0, 100300);

    g.dispose();
    await tester.pump(const Duration(seconds: 3));
  });
}
