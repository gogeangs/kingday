// 상단 바 숫자 효과 (웹 numFlash): 골드가 크게 오르면 「+N」이 떠올랐다 사라지고, 조금 오를 때는 조용함
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/fmt.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('골드 숫자 효과', (tester) async {
    SharedPreferences.setMockInitialValues({
      'acorn-idle-v1': jsonEncode({'gold': 10000, 'stage': 5, 'best': 5, 'started': true, 'last': DateTime.now().millisecondsSinceEpoch}),
    });
    final store = await SaveStore.open();
    final g = GameController(store: store, state: store.load(DateTime.now().millisecondsSinceEpoch));
    await tester.pumpWidget(KingdayApp(g: g));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('게임 시작'));
    await tester.pump(const Duration(milliseconds: 100));

    // 조금(10% 미만) 오르면 떠오르는 글자 없음
    g.state.gold = g.state.gold + 30;
    g.refresh();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('+30'), findsNothing);

    // 크게 오르면 「+N」
    final d = 250000;
    g.state.gold = g.state.gold + d;
    g.refresh();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('+${fmt(d)}'), findsOneWidget);
    // 1.1초 뒤 사라짐
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('+${fmt(d)}'), findsNothing);

    // 크게 줄면 「-N」
    g.state.gold = 1000;
    g.refresh();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('-'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    g.dispose();
    await tester.pump(const Duration(seconds: 3));
  });
}
