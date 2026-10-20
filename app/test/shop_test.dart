// 피트의 상점 화면: 할 일 보상·무료 선물(광고)·골드 바꾸기·카드 묶음·첫 거래 특가·정기 배송·이삭 꾸러미
// 폰 폭 320·390 에서 넘침 없이 눌러지고, 웹과 같은 결과(조작 비교는 actions_parity_test)가 나오는지.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final w in [320.0, 390.0]) {
    testWidgets('피트의 상점 · 폭 ${w.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = Size(w * 3, 760 * 3);
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'acorn-idle-v1': jsonEncode({
          'gold': 50000, 'stage': 23, 'best': 23, 'gem': 500, 'started': true, 'pfSeen': 1,
          'done': {'marta': true, 'margo': true, 'haral': true, 'pete': true, 'tutSkill': true},
          'joined': {'margo': true, 'haral': true},
          'daily': {'d': '${now.year}-${now.month}-${now.day}', 'kill': 150, 'box': 10, 'harv': 3, 'claim': {}, 'ad': {}},
          'last': now.millisecondsSinceEpoch, 'v': 3,
        }),
      });
      final store = await SaveStore.open();
      final g = GameController(store: store, state: store.load(DateTime.now().millisecondsSinceEpoch));
      await tester.pumpWidget(KingdayApp(g: g));

      Future<void> frames([int n = 6]) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> press(String label) async {
        expect(find.text(label), findsWidgets, reason: '「$label」 이 있어야 함');
        await tester.ensureVisible(find.text(label).first);
        await frames(1);
        await tester.tap(find.text(label).first);
        await frames();
      }

      await frames(1);
      await press('게임 시작');
      // 밀린 이야기 창 닫기
      for (var i = 0; i < 10; i++) {
        final nav = g.navKey.currentState!;
        if (nav.canPop()) nav.pop();
        await frames(2);
      }
      expect(g.gemDot, isTrue, reason: '받을 할 일 보상이 있으면 이삭 옆 빨간 점');

      // 상단 이삭을 누르면 상점 (크게 보기로 열어 둠)
      g.state.raw['pgFull'] = true;
      g.setTab(GameTab.sh);
      await frames(3);
      expect(find.text('피트의 상점'), findsWidgets);

      // 할 일: 마물 100마리 · 상자 10번 받기, 작물은 아직
      final gem0 = g.state.gem;
      await press('+10 받기');
      await press('+10 받기');
      expect(g.state.gem, gem0 + 20);
      expect(find.text('3 / 10'), findsOneWidget);
      expect(find.text('+20'), findsOneWidget, reason: '모두 끝내기는 아직');

      // 바로 가기 → 골드 바꾸기
      await press('골드');
      final gold0 = g.state.gold;
      await press('골드 주머니');
      expect(g.state.gold, greaterThan(gold0));
      expect(g.state.gem, gem0 + 20 - 30);

      // 카드 3장 → 카드 공개 창
      await press('카드 3장');
      await frames(4);
      expect(find.text('카드를 받았어요!'), findsOneWidget);
      await press('닫기');

      // 첫 거래 특가 → 이야기 → 전설 성유물 비교 창 → 장착
      await press('₩1,200');
      await frames(3);
      expect(find.text('피트의 진품 보증'), findsOneWidget);
      await press('성유물 확인하기');
      await frames(3);
      expect(find.text('성유물을 얻었어요'), findsOneWidget);
      await press('장착');
      expect(find.text('한 번만'), findsNothing, reason: '첫 거래 특가는 한 번만');

      // 정기 배송: 시작하면 오늘 배송까지 받음
      await press('₩5,500');
      expect(find.text('받음'), findsWidgets);
      expect(g.calc.subOn(), isTrue);

      // 이삭 꾸러미 첫 구매 2배
      final gem1 = g.state.gem;
      await press('₩1,200');
      expect(g.state.gem, gem1 + 120);

      // 무료 선물: 이삭 +5 (3초 광고)
      final gem2 = g.state.gem;
      await tester.ensureVisible(find.text('황금 이삭 +5'));
      await frames(1);
      await tester.tap(find.descendant(of: find.ancestor(of: find.text('황금 이삭 +5'), matching: find.byType(Row)).first, matching: find.text('▶ 받기')));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(g.state.gem, gem2 + 5);
      expect(find.text('오늘 2 / 3회 남음'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      g.dispose();
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
