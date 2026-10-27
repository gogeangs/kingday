// 태초 등급(6) 장비가 장비 칸·「성유물을 얻었어요」 창에서 회색 네모(화면 오류)가 되지 않는지
// (2026-10-27 대표님 제보: 테두리 이름 목록에 태초가 빠져 있었음)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/main.dart';
import 'package:kingday/ui/game_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _rel(String slot, int g) => {'slot': slot, 'g': g, 'lv': 33, 'atk': 900, 'hp': 9000, 'price': 9748};

void main() {
  test('테두리 이름: 모든 등급(태초 포함)', () {
    expect(gradeFrame(6), 'primal');
    expect(gradeFrame(99), 'primal');
    expect(gradeFrame(null), 'normal');
  });

  for (final w in [320.0, 390.0]) {
    testWidgets('태초 장비 · 폭 ${w.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = Size(w * 3, 780 * 3);
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'acorn-idle-v1': jsonEncode({
          'gold': 50000, 'stage': 40, 'best': 40, 'gem': 500, 'started': true, 'pfSeen': 1, 'boxLv': 33, 'retires': 1,
          'done': {'marta': true, 'margo': true, 'haral': true, 'pete': true, 'tutSkill': true, 'primalIntro': 1},
          'eq': {
            'weapon': _rel('weapon', 5), 'helm': _rel('helm', 6), 'armor': _rel('armor', 6),
            'gloves': _rel('gloves', 6), 'boots': _rel('boots', 4), 'ring': _rel('ring', 6),
          },
          'daily': {'d': '${now.year}-${now.month}-${now.day}', 'kill': 0, 'box': 0, 'harv': 0, 'claim': {}, 'ad': {}},
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

      await frames(1);
      await tester.tap(find.text('게임 시작'));
      await frames();
      for (var i = 0; i < 10; i++) {
        final nav = g.navKey.currentState!;
        if (nav.canPop()) nav.pop();
        await frames(2);
      }

      // 장비 탭: 태초 칸도 정상 (화면 오류 없음)
      g.setTab(GameTab.eq);
      await frames(3);
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);

      // 「성유물을 얻었어요」 창: 새 장비 태초 · 착용 중 태초
      final ctx = g.navKey.currentContext!;
      g.showItemSheet(ctx, Relic.fromJson(_rel('armor', 6)), Relic.fromJson(_rel('armor', 6)));
      await frames();
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.text('성유물을 얻었어요'), findsOneWidget);
      expect(find.byType(RelicCard), findsNWidgets(2));

      await tester.pumpWidget(const SizedBox());
      g.dispose();
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
