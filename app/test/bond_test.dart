// 원정대의 정 (docs/content/BOND.md 8장): 원정대 탭 하트 줄·원정대 일기 6칸·동료 창 호감도 줄이
// 폰 폭 320·360·390·430 에서 넘치지 않고, 일기에서 새 장면을 누르면 이삭 20(한 번만) · ♥ 오를 때 안내가 나오는지.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/bond.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/main.dart';
import 'package:kingday/screens/bond_ui.dart';
import 'package:kingday/screens/pt_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final w in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('원정대의 정 · 폭 ${w.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = Size(w * 3, 780 * 3);
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'acorn-idle-v1': jsonEncode({
          'gold': 50000, 'stage': 23, 'best': 23, 'gem': 500, 'started': true, 'pfSeen': 1,
          'done': {'marta': true, 'margo': true, 'haral': true, 'pete': true, 'tutSkill': true},
          'joined': {'margo': true, 'haral': true, 'riel': true, 'bron': true},
          'rec': {'brida': 1, 'nella': 2, 'deokbae': 1},
          'party': {'miner': 'brida', 'fisher': 'nella', 'keeper': 'riel', 'cook': 'margo'},
          'daily': {'d': '${now.year}-${now.month}-${now.day}', 'kill': 0, 'box': 0, 'harv': 0, 'claim': {}, 'ad': {}},
          // 브리다 ♥5(단짝) · 브론 ♥3 → 「할머니의 망치」 열림, 덕배·마고 ♥3 → 「스승의 국물」은 이미 봄
          'aff': {'brida': 4100, 'bron': 950, 'nella': 905, 'riel': 59.9, 'margo': 950, 'deokbae': 920},
          'bond': {'seen': {'2': 1}, 'intro': 1, 'five': {'brida': 1}},
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

      Future<void> closeAll() async {
        for (var i = 0; i < 10; i++) {
          final nav = g.navKey.currentState!;
          if (nav.canPop()) nav.pop();
          await frames(2);
        }
      }

      await frames(1);
      await tester.tap(find.text('게임 시작'));
      await frames();
      // 시작하면 열렸는데 못 본 「할머니의 망치」가 줄을 섬 → 장면 창은 닫고 일기에서 다시 엶
      await closeAll();

      // 원정대 탭: 원정대 일기 버튼(1/6 또는 2/6) · 고른 동료 하트 줄
      g.state.raw['pgFull'] = true;
      g.setTab(GameTab.pt);
      await frames(3);
      expect(find.byKey(const ValueKey('bdDiary')), findsOneWidget);
      expect(find.byType(AffHearts), findsWidgets);

      // 원정대 일기 6칸
      final gem0 = g.state.gem, seen0 = g.calc.bondSeenN();
      await tester.ensureVisible(find.byKey(const ValueKey('bdDiary')));
      await frames(1);
      await tester.tap(find.byKey(const ValueKey('bdDiary')));
      await frames();
      expect(find.text('원정대 일기'), findsWidgets);
      for (var k = 1; k <= 6; k++) {
        expect(find.byKey(ValueKey('bd-$k')), findsOneWidget);
      }
      final first = !g.calc.bondSeen.containsKey('4');
      await tester.ensureVisible(find.byKey(const ValueKey('bd-4')));
      await frames(1);
      await tester.tap(find.byKey(const ValueKey('bd-4')));
      await frames();
      expect(find.text('할머니의 망치'), findsWidgets);
      expect(g.state.gem, gem0 + (first ? 20 : 0), reason: '처음 볼 때만 이삭 20');
      expect(g.calc.bondSeenN(), seen0 + (first ? 1 : 0));
      await closeAll();

      // 다시 보기는 이삭 없음
      final gem1 = g.state.gem;
      g.act((a) => a.bondPlay(4));
      await frames();
      expect(g.state.gem, gem1);
      await closeAll();

      // 동료 창: 호감도 줄 + 「?」 설명
      compSheet(g, 'nella');
      await frames();
      expect(find.byKey(const ValueKey('affLine')), findsOneWidget);
      expect(find.text('공격·체력 +6%'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('affQ')));
      await frames(1);
      await tester.tap(find.byKey(const ValueKey('affQ')));
      await frames(2);
      expect(find.textContaining('하루 1번 +10점'), findsOneWidget);
      await closeAll();

      // ♥ 오를 때 토스트: 리엘 59.9 → 60 (♥1)
      g.act((a) => a.affAdd('riel', .2));
      await frames(2);
      expect(g.calc.affLv('riel'), 1);
      expect(g.calc.affMul('riel'), 1.02);

      // 길 위 대화: 하루 1번 +10
      final p0 = g.calc.affPt('bron');
      expect(g.act((a) => a.affTalk('bron')), isTrue);
      expect(g.act((a) => a.affTalk('bron')), isFalse);
      expect(g.calc.affPt('bron'), p0 + 10);
      expect(g.act((a) => a.affTalk('kael')), isFalse, reason: '카엘은 호감도 없음');
      await closeAll();

      await tester.pumpWidget(const SizedBox());
      g.dispose();
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
