// 마을 「피트의 가게」: 원정 일지 배너·할 일 보상·골드 바꾸기·카드 묶음 (2026-11-16 결제·광고 없음, 상점 탭을 마을로)
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
    testWidgets('피트의 가게 · 폭 ${w.toInt()}', (tester) async {
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

      // 오른쪽 세로 버튼 줄에 상점 버튼은 없음 · 마을 탭 「피트의 가게」 버튼으로 열기 (크게 보기로 열어 둠)
      expect(find.text('상점'), findsNothing);
      g.state.raw['pgFull'] = true;
      g.setTab(GameTab.vl);
      await frames(3);
      await tester.ensureVisible(find.byKey(const ValueKey('vShop')));
      await frames(1);
      await tester.tap(find.byKey(const ValueKey('vShop')));
      await frames(3);
      expect(g.tab, GameTab.sh);
      expect(find.text('피트의 가게'), findsWidgets);
      expect(find.text('원정 일지'), findsWidgets, reason: '원정 일지 배너가 맨 위');

      // 할 일: 마물 100마리 · 상자 10번 받기, 작물은 아직
      final gem0 = g.state.gem;
      await press('+10 받기');
      await press('+10 받기');
      expect(g.state.gem, gem0 + 20);
      expect(find.text('3 / 10'), findsOneWidget);
      expect(find.text('+20'), findsOneWidget, reason: '모두 끝내기는 아직');

      // 바로 가기 → 골드 바꾸기
      await press('🌾 이삭으로');
      final gold0 = g.state.gold;
      await press('골드 주머니');
      expect(g.state.gold, greaterThan(gold0));
      expect(g.state.gem, gem0 + 20 - 30);

      // 카드 3장 → 카드 공개 창
      await press('카드 3장');
      await frames(4);
      expect(find.text('카드를 받았어요!'), findsOneWidget);
      // 상점에서 산 카드: 「또 뽑기」(가격 보임) → 같은 묶음을 한 번 더
      final gemA = g.state.gem;
      await press('또 뽑기');
      await frames(4);
      expect(g.state.gem, gemA - 30);
      expect(find.text('카드를 받았어요!'), findsOneWidget);
      g.navKey.currentState!.pop();
      await frames(4);

      // 결제 상품은 없음 (2026-11-16 유료화 제거)
      expect(find.textContaining('₩'), findsNothing);
      expect(find.text('💳 충전·패키지'), findsNothing);

      // 광고는 없음 (2026-11-16 완전 무료)
      expect(find.textContaining('광고'), findsNothing);
      expect(find.text('▶ 받기'), findsNothing);
      // 옛 저장의 광고 횟수 칸은 조용히 지워짐
      expect((g.state.raw['daily'] as Map).containsKey('ad'), isFalse);

      await tester.pumpWidget(const SizedBox());
      g.dispose();
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
