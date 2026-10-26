// 문의하기 (supabase/stage8_inquiry.sql): 설정 → 문의 창 → 보내기 → 내 문의 → 우편함 답변
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kingday/core/app_info.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/core/server.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/main.dart';
import 'package:kingday/screens/settings_sheet.dart';
import 'package:kingday/screens/social_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 서명 없는 가짜 로그인 토큰 (가운데 칸에 계정 번호 sub)
String fakeJwt(String sub) => 'x.${base64Url.encode(utf8.encode(jsonEncode({'sub': sub}))).replaceAll('=', '')}.y';

class FakeInqSb {
  final calls = <(String, Map<String, dynamic>)>[];
  final uploads = <(String, String?, int)>[];
  final errors = <String>[];
  final tok = fakeJwt('11111111-1111-1111-1111-111111111111');

  http.Response _j(Object? v) => http.Response.bytes(utf8.encode(jsonEncode(v)), 200, headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request r) async {
    try {
      return _handle(r);
    } catch (e) {
      errors.add('$e');
      rethrow;
    }
  }

  http.Response _handle(http.Request r) {
    if (r.headers['apikey'] != sbKey) throw StateError('apikey 없음');
    final p = r.url.path;
    if (p == '/auth/v1/signup') {
      return _j({'access_token': tok, 'refresh_token': 'r1', 'expires_in': 3600, 'user': {'id': 'u-old'}});
    }
    if (p == '/auth/v1/user') return _j({'is_anonymous': true});
    if (r.headers['authorization'] != 'Bearer $tok') throw StateError('토큰 없음');
    if (p.startsWith('/storage/v1/object/inquiry/')) {
      uploads.add((p.replaceFirst('/storage/v1/object/inquiry/', ''), r.headers['content-type'], r.bodyBytes.length));
      return _j({'Key': 'ok'});
    }
    final fn = p.replaceFirst('/rest/v1/rpc/', '');
    final a = (jsonDecode(r.body) as Map).cast<String, dynamic>();
    calls.add((fn, a));
    switch (fn) {
      case 'kd_ensure_profile':
        return _j({'nick': '은퇴농부', 'temp': false});
      case 'kd_mail_list':
        return _j([
          {
            'id': 7,
            'kind': 'reply',
            'title': '문의 답변 · 버그',
            'body': '고쳐서 다음 버전에 넣을게요.',
            'reward': <String, dynamic>{},
            'expires_at': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
          },
        ]);
      case 'kd_inq_send':
        return _j('ok');
      case 'kd_inq_mine':
        return _j([
          {
            'id': 2,
            'kind': 'pay',
            'body': '이삭 330개를 샀는데 안 들어왔어요',
            'has_photo': false,
            'status': 'answered',
            'answer': '우편으로 이삭을 보내 드렸어요!',
            'created_at': '2026-10-25T03:00:00Z',
            'answered_at': '2026-10-25T05:10:00Z',
          },
        ]);
      case 'kd_submit' || 'kd_gob_submit' || 'kd_save_put':
        return _j('ok');
    }
    return http.Response('no', 404);
  }
}

void main() {
  test('앱 버전 상수가 pubspec.yaml 과 같음', () {
    final m = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(appVersion, m!.group(1));
  });

  test('로그인 토큰에서 계정 번호 읽기', () {
    expect(Server.jwtSub(fakeJwt('abc-123')), 'abc-123');
    expect(Server.jwtSub('엉터리'), isNull);
  });

  testWidgets('문의하기: 설정 → 보내기 → 내 문의 → 우편함 답변', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 760 * 3);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'acorn-idle-v1': jsonEncode({
        'gold': 500, 'stage': 5, 'best': 5, 'gem': 10, 'started': true, 'pfSeen': 1, 'nick': '은퇴농부',
        'att': {'intro': 1, 'last': '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}'},
        'last': DateTime.now().millisecondsSinceEpoch, 'v': 3,
      }),
    });
    final fake = FakeInqSb();
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
    await frames(25);

    // 설정 → 문의하기
    openSettings(g);
    await frames();
    await press('문의하기');
    expect(find.text('종류'), findsOneWidget);
    await press('결제');

    // 너무 짧으면 보내지 않음
    await tester.enterText(find.byType(TextField), '짧음');
    await press('보내기');
    expect(find.text('내용을 5자 이상 적어 주세요'), findsOneWidget);
    expect(fake.calls.where((c) => c.$1 == 'kd_inq_send'), isEmpty);

    // 돌아갔다 와도 쓰던 글이 남음
    await tester.enterText(find.byType(TextField), '오늘 황금 이삭 330개를 샀는데 들어오지 않았어요');
    await press('돌아가기');
    expect(find.text('카엘의 수첩'), findsOneWidget);
    await press('문의하기');
    expect(find.text('오늘 황금 이삭 330개를 샀는데 들어오지 않았어요'), findsOneWidget);

    await press('보내기');
    await frames(4);
    final sent = fake.calls.lastWhere((c) => c.$1 == 'kd_inq_send').$2;
    expect(sent['p_kind'], 'pay');
    expect(sent['p_body'], '오늘 황금 이삭 330개를 샀는데 들어오지 않았어요');
    expect(sent['p_photo'], isNull);
    expect(sent['p_ver'], appVersion);
    expect((sent['p_platform'] as String).isNotEmpty, isTrue);
    expect(find.text('문의를 보냈어요 ✉️'), findsOneWidget);

    // 내 문의: 답변 보임
    await press('내 문의 보기');
    await frames(3);
    expect(find.text('답변 완료'), findsOneWidget);
    expect(find.text('우편으로 이삭을 보내 드렸어요!'), findsOneWidget);
    // 「새 문의」 → 글은 비어 있음
    await press('새 문의');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    await press('돌아가기');
    await press('닫기');

    // 우편함: 보상 없는 답변은 「확인」
    openMail(g);
    await frames(4);
    expect(find.text('💬 문의 답변 · 버그'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
    await press('닫기');

    // 사진: 계정 번호 폴더에 올리고, 그 경로로 문의
    final png = [0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4];
    final (r, fail) = await g.online.inqSend(kind: 'bug', body: '사진 붙인 문의예요', photo: png, ver: appVersion, device: 'test', platform: 'android');
    expect((r, fail), ('ok', false));
    expect(fake.uploads, hasLength(1));
    final up = fake.uploads.single;
    expect(up.$1, matches(RegExp(r'^11111111-1111-1111-1111-111111111111/[a-z0-9]{6,40}\.png$')));
    expect(up.$2, 'image/png');
    expect(up.$3, png.length);
    expect(fake.calls.lastWhere((c) => c.$1 == 'kd_inq_send').$2['p_photo'], up.$1);

    await tester.pumpWidget(const SizedBox());
    g.dispose();
    await tester.pump(const Duration(seconds: 3));
  });
}
