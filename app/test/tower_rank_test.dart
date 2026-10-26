// 시련의 탑 랭킹 (supabase/stage9_tower.sql): 최고 층 보내기 → 랭킹 창 「탑」 탭
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/core/server.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/main.dart';
import 'package:kingday/screens/social_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final w in [320.0, 390.0]) {
    testWidgets('탑 랭킹: 최고 층 보내기 · 탭 · 폭 ${w.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = Size(w * 3, 760 * 3);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'acorn-idle-v1': jsonEncode({
          'gold': 500, 'stage': 5, 'best': 5, 'gem': 10, 'started': true, 'pfSeen': 1, 'nick': '영주123',
          'tower': {'top': 61, 'day': '', 'pk': 0},
          'att': {'intro': 1, 'last': '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}'},
          'last': DateTime.now().millisecondsSinceEpoch, 'v': 3,
        }),
      });
      final calls = <(String, Map<String, dynamic>)>[];
      http.Response j(Object? v) => http.Response.bytes(utf8.encode(jsonEncode(v)), 200, headers: {'content-type': 'application/json'});
      final client = MockClient((r) async {
        final p = r.url.path;
        if (p == '/auth/v1/signup') return j({'access_token': 'a1', 'refresh_token': 'r1', 'expires_in': 3600, 'user': {'id': 'u1'}});
        if (p == '/auth/v1/user') return j({'is_anonymous': true});
        final fn = p.replaceFirst('/rest/v1/rpc/', '');
        calls.add((fn, (jsonDecode(r.body) as Map).cast<String, dynamic>()));
        return switch (fn) {
          'kd_ensure_profile' => j({'nick': '영주123', 'temp': false}),
          'kd_mail_list' || 'kd_ranking' || 'kd_gob_ranking' => j([]),
          'kd_tower_ranking' => j([
              for (var i = 1; i <= 5; i++)
                {
                  'rank': i, 'nick': i == 4 ? '영주123' : '탑영주$i', 'top': [132, 88, 88, 61, 40][i - 1], 'frame': 'gold', 'badge': null,
                  'title': '공작', 'me': i == 4, 'total': 37, 'week': 2, 'week_end': '2026-11-02T00:00:00+09:00', 'face': 'margo',
                },
            ]),
          _ => j('ok'),
        };
      });
      final store = await SaveStore.open();
      final g = GameController(store: store, state: store.load(DateTime.now().millisecondsSinceEpoch), server: Server(store.prefs, client: client));
      await tester.pumpWidget(KingdayApp(g: g));

      Future<void> frames([int n = 6]) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await frames(1);
      await tester.tap(find.text('게임 시작'));
      await frames(25);

      openRanking(g, 'tower');
      await frames(6);
      expect(find.text('탑 랭킹'), findsOneWidget);
      expect(calls.where((c) => c.$1 == 'kd_tower_submit').first.$2, {'p_top': 61});
      expect(find.text('132층'), findsOneWidget);
      expect(find.textContaining('내 최고 61층'), findsOneWidget);
      // 같은 주·같은 층이면 다시 보내지 않음
      final n = calls.where((c) => c.$1 == 'kd_tower_submit').length;
      await g.online.towerSubmit();
      expect(calls.where((c) => c.$1 == 'kd_tower_submit').length, n);
      // 층이 오르면 다시 보냄
      (g.state.raw['tower'] as Map)['top'] = 62;
      await g.online.towerSubmit();
      expect(calls.last, ('kd_tower_submit', {'p_top': 62}));

      await tester.pumpWidget(const SizedBox());
      g.dispose();
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
