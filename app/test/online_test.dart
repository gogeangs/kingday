// 8단계: 서버(Supabase) 기능을 가짜 서버로 확인.
// 진짜 서버에 접속하지 않고, 웹이 보내던 것과 같은 요청을 보내는지·받은 답을 화면에 잘 보여 주는지 본다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kingday/core/server.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/main.dart';
import 'package:kingday/screens/social_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 가짜 Supabase: 웹이 쓰는 주소·함수만 흉내 냄
class FakeSb {
  final calls = <(String, Map<String, dynamic>)>[];
  String nick = '영주12345';
  bool temp = true;
  List<Map<String, dynamic>> mails = [
    {
      'id': 1,
      'kind': 'season',
      'title': '1시즌 랭킹 보상 · 2위',
      'body': '대단해요, 영주님!',
      'reward': {'gem': 300, 'badge': 'top10'},
      'expires_at': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
    },
    {
      'id': 2,
      'kind': 'notice',
      'title': '환영합니다',
      'body': '첫 접속 선물',
      'reward': {'gem': 50, 'cards': 30, 'frame': 'season'},
      'expires_at': DateTime.now().add(const Duration(hours: 5)).toIso8601String(),
    },
  ];

  List<Map<String, dynamic>> rows() => [
        for (var i = 1; i <= 6; i++)
          {
            'rank': i,
            'nick': i == 4 ? nick : '아주아주긴닉네임$i',
            'title': '공작',
            'frame': i == 1 ? 'season' : 'gold',
            'badge': i == 2 ? 'champ' : null,
            'stage': 60 - i * 3,
            'me': i == 4,
            'total': 120,
            'season': 1,
            'season_end': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          },
      ];

  http.Response _j(Object? v) => http.Response.bytes(utf8.encode(jsonEncode(v)), 200, headers: {'content-type': 'application/json'});

  final errors = <String>[];

  Future<http.Response> handle(http.Request r) async {
    try {
      return await _handle(r);
    } catch (e) {
      errors.add('$e');
      rethrow;
    }
  }

  Future<http.Response> _handle(http.Request r) async {
    if (r.headers['apikey'] != sbKey) throw StateError('apikey 없음');
    final p = r.url.path;
    if (p == '/auth/v1/signup') {
      return _j({'access_token': 'a1', 'refresh_token': 'r1', 'expires_in': 3600, 'user': {'id': 'u1'}});
    }
    if (p == '/auth/v1/user') return _j({'is_anonymous': true});
    if (r.headers['authorization'] != 'Bearer a1') throw StateError('토큰 없음: ${r.headers}');
    final fn = p.replaceFirst('/rest/v1/rpc/', '');
    final a = (jsonDecode(r.body) as Map).cast<String, dynamic>();
    calls.add((fn, a));
    switch (fn) {
      case 'kd_ensure_profile':
        return _j({'nick': nick, 'temp': temp});
      case 'kd_set_nick':
        if (a['p_nick'] == '누가씀') return _j('taken');
        nick = a['p_nick'];
        temp = false;
        return _j('ok');
      case 'kd_submit' || 'kd_gob_submit' || 'kd_save_put':
        return _j('ok');
      case 'kd_mail_list':
        return _j(mails);
      case 'kd_mail_claim':
        final got = a['p_id'] == null ? mails : mails.where((m) => m['id'] == a['p_id']).toList();
        mails = mails.where((m) => !got.contains(m)).toList();
        return _j(got);
      case 'kd_ranking':
        return _j(a['p_season'] == 0 ? rows().take(2).toList() : rows());
      case 'kd_gob_ranking':
        return _j([]);
    }
    return http.Response('no', 404);
  }
}

void main() {
  for (final w in [320.0, 390.0]) {
    testWidgets('서버: 시즌 결과 → 우편함 → 닉네임 → 랭킹 → 프로필 · 폭 ${w.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = Size(w * 3, 760 * 3);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'acorn-idle-v1': jsonEncode({
          'gold': 50000, 'stage': 23, 'best': 23, 'gem': 10, 'started': true, 'pfSeen': 1,
          'done': {'marta': true, 'margo': true, 'haral': true},
          'joined': {'margo': true, 'haral': true},
          // 오늘 출석은 이미 함 (출석부가 자동으로 뜨지 않게)
          'att': {'intro': 1, 'last': '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}'},
          'last': DateTime.now().millisecondsSinceEpoch, 'v': 3,
        }),
      });
      final fake = FakeSb();
      final store = await SaveStore.open();
      final server = Server(store.prefs, client: MockClient(fake.handle));
      final g = GameController(store: store, state: store.load(DateTime.now().millisecondsSinceEpoch), server: server);
      await tester.pumpWidget(KingdayApp(g: g));
      addTearDown(() => expect(fake.errors, isEmpty));

      Future<void> frames([int n = 6]) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> press(String label) async {
        expect(find.text(label), findsOneWidget, reason: '「$label」 버튼이 있어야 함');
        await tester.ensureVisible(find.text(label));
        await frames(1);
        await tester.tap(find.text(label));
        await frames();
      }

      await frames(1);
      await press('게임 시작');
      // 1.5초 뒤 계정 준비 → 임시 닉네임 → 우편 확인 → 시즌 결과 창
      await frames(25);
      expect(g.online.nick, '영주12345', reason: 'calls=${fake.calls.map((c) => c.$1)} errors=${fake.errors} last=${g.online.lastError}');
      expect(g.online.nickTemp, isTrue);
      expect(fake.calls.map((c) => c.$1), containsAll(['kd_ensure_profile', 'kd_mail_list']));
      final ens = fake.calls.firstWhere((c) => c.$1 == 'kd_ensure_profile').$2;
      expect(ens.keys, containsAll(['p_frame', 'p_badge', 'p_title']));
      expect(find.text('1시즌 2위!'), findsOneWidget);
      expect(g.state.raw['resSeen'], {'s': 1});

      // 우편함 열기 → 두 통 → 모두 받기
      await press('우편함 열기');
      expect(find.text('환영합니다'), findsOneWidget);
      expect(find.text('시즌 10강 배지'), findsOneWidget);
      final gem0 = g.state.gem;
      await press('모두 받기');
      await frames(4);
      expect(g.state.gem, gem0 + 350);
      expect((g.state.raw['bdUnl'] as Map)['top10'], 1);
      expect((g.state.raw['pfUnl'] as Map)['season'], 1);
      expect(find.text('도착한 우편이 없어요.'), findsOneWidget);
      await press('닫기');
      // 동료 카드 30장 → 카드 공개 창
      await frames(4);
      expect(find.text('카드를 받았어요!'), findsOneWidget);
      await press('닫기');

      // 닉네임은 프로필에서 정함 (랭킹 창엔 닉네임 버튼·물어보는 창 없음)
      openNick(g, after: () => openRanking(g, 'season'));
      await frames();
      await tester.enterText(find.byType(TextField), '누가씀');
      await press('정하기');
      await frames(2);
      expect(find.text('이미 누가 쓰고 있어요'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '은퇴농부');
      await press('정하기');
      await frames(4);
      expect(g.online.nick, '은퇴농부');
      expect(g.online.nickTemp, isFalse);
      final setNick = fake.calls.lastWhere((c) => c.$1 == 'kd_set_nick').$2;
      expect(setNick['p_nick'], '은퇴농부');
      final sub = fake.calls.lastWhere((c) => c.$1 == 'kd_submit').$2;
      expect(sub['p_stage'], 23);
      expect(sub['p_power'], isA<int>());
      // 닉네임을 정하면 바로 랭킹 창
      expect(find.text('은퇴농부'), findsWidgets);
      expect(find.text('상위 4%'), findsOneWidget);
      await press('명예의 전당');
      await frames(3);
      expect(find.textContaining('지금까지 도달한 최고 기록'), findsOneWidget);
      await press('고블린');
      await frames(3);
      expect(find.textContaining('황금 고블린을 잡은 영주가 아직 없어요'), findsOneWidget);
      await press('닫기');

      // 프로필: 우편으로 받은 테두리 끼우기
      openProfile(g);
      await frames();
      expect(find.text('시즌 왕관'), findsOneWidget);
      await tester.ensureVisible(find.text('시즌 왕관'));
      await frames(1);
      await tester.tap(find.text('시즌 왕관'));
      await frames(2);
      expect(g.state.raw['pf'], 'season');
      await press('닫기');

      // 클라우드 저장 (게스트도 저장해 둠)
      expect(await g.online.cloudPut(true), isTrue);
      final put = fake.calls.lastWhere((c) => c.$1 == 'kd_save_put').$2;
      expect((put['p_data'] as Map)['stage'], 23);
      expect(put['p_gem'], isA<int>());

      await tester.pumpWidget(const SizedBox());
      g.dispose();
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('서버가 꺼져 있어도(인터넷 없음) 게임은 그대로', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await SaveStore.open();
    final server = Server(store.prefs, client: MockClient((_) async => throw http.ClientException('offline')));
    final g = GameController(store: store, state: store.load(DateTime.now().millisecondsSinceEpoch), server: server);
    await tester.pumpWidget(KingdayApp(g: g));
    await tester.pump(const Duration(seconds: 3));
    expect(g.online.nick, isNull);
    openMail(g);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('인터넷에 연결되면 우편을 받을 수 있어요.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    g.dispose();
    await tester.pump(const Duration(seconds: 3));
  });
}
