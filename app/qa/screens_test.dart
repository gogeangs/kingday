// ignore_for_file: invalid_use_of_visible_for_testing_member
// QA 화면 캡처: 실제 글꼴·그림으로 주요 화면을 PNG 로 찍는다 (웹 화면과 나란히 비교용).
//   flutter test --update-goldens qa/screens_test.dart   → qa/shots/*.png
// 평소 시험(flutter test)에는 들어가지 않는다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/core/server.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/main.dart';
import 'package:kingday/screens/pt_page.dart';
import 'package:kingday/screens/settings_sheet.dart';
import 'package:kingday/screens/social_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _w = 390.0, _h = 844.0;

Map<String, Object> _late() => {
      'acorn-idle-v1': jsonEncode({
        'gold': 9.87e14, 'stage': 51, 'best': 51, 'gem': 1234, 'started': true, 'pfSeen': 1, 'pf': 'gold', 'badge': 'chest',
        'joined': {'margo': true, 'haral': true, 'riel': true, 'bron': true},
        'done': {'marta': true, 'margo': true, 'haral': true, 'riel': true, 'bron': true, 'tutSkill': true, 'pete': true},
        'lv': {'bron': 60, 'haral': 61, 'riel': 58, 'margo': 55}, 'bld': {'inn': 10, 'farm': 6, 'diner': 10, 'dock': 10, 'apiary': 9, 'mine': 10},
        'rec': {'brida': 3, 'luka': 2}, 'cards': {'luka': 12, 'daisy': 30}, 'party': {'miner': 'brida'},
        'up': {'atk': 300, 'hp': 280, 'spd': 30, 'crit': 40}, 'boxLv': 8, 'retires': 2, 'memory': 14,
        'seeds': {'wheat': 5, 'carrot': 2, 'pumpkin': 1}, 'items': {'wheat': 40, 'carrot': 9, 'pumpkin': 4, 'fish': 120, 'honey': 80, 'ore': 999},
        'plots': [{'k': 'wheat', 'at': 0}, {'k': 'carrot', 'at': 9999999999999}, null], 'gemPlots': 2,
        'bdUnl': {'chest': 1, 'rebuild': 1, 'att_202611': 1}, 'att': {'intro': 1, 'w': 2, 'ym': '', 'm': 0}, 'tickets': {'box': 2, 'box10': 1}, 'pfUnl': {'gold': 1, 'silver': 1, 'straw': 1},
        'last': DateTime.now().millisecondsSinceEpoch - 5 * 3600 * 1000, 'v': 3,
      }),
    };

http.Response _j(Object? v) => http.Response.bytes(utf8.encode(jsonEncode(v)), 200, headers: {'content-type': 'application/json'});

Future<http.Response> _fake(http.Request r) async {
  final p = r.url.path;
  if (p == '/auth/v1/signup') return _j({'access_token': 'a', 'refresh_token': 'r', 'expires_in': 3600, 'user': {'id': 'u'}});
  if (p == '/auth/v1/user') return _j({'is_anonymous': true});
  final fn = p.replaceFirst('/rest/v1/rpc/', '');
  final end = DateTime.now().add(const Duration(days: 2, hours: 5)).toIso8601String();
  return switch (fn) {
    'kd_ensure_profile' => _j({'nick': '은퇴하고픈농부', 'temp': false}),
    'kd_mail_list' => _j([
        {'id': 1, 'kind': 'notice', 'title': '왕국 재건 기념 선물', 'body': '영주님의 귀환을 환영해요', 'reward': {'gem': 50, 'cards': 30}, 'expires_at': end},
        {'id': 2, 'kind': 'season', 'title': '1시즌 참여 보상', 'body': '', 'reward': {'gem': 20, 'frame': 'season'}, 'expires_at': end},
      ]),
    'kd_ranking' => _j([
        for (var i = 1; i <= 8; i++)
          {'rank': i, 'nick': ['왕좌의주인', '감자귀족', '밭갈이장인', '은퇴하고픈농부', '마왕잡는농부', '도토리', '용사지망생', '영주12345'][i - 1], 'title': '공작',
           'frame': ['season', 'royal', 'gold', 'gold', 'silver', 'straw', 'wood', 'wood'][i - 1], 'badge': i == 1 ? 'champ' : i < 4 ? 'top10' : null,
           'stage': 60 - i * 2, 'me': i == 4, 'total': 87, 'season': 1, 'season_end': end},
      ]),
    _ => _j('ok'),
  };
}

Future<void> _fonts() async {
  for (final (fam, files) in const [
    ('Hahmlet', ['hahmlet-500', 'hahmlet-700']),
    ('PlexKR', ['plexkr-400', 'plexkr-600']),
  ]) {
    final l = FontLoader(fam);
    for (final f in files) {
      l.addFont(rootBundle.load('assets/game/fonts/$f.ttf'));
    }
    await l.load();
  }
}

void main() {
  setUpAll(_fonts);

  for (final save in ['new', 'late']) {
    testWidgets('화면 캡처 · $save', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(_w * 2, _h * 2);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(save == 'new' ? {} : _late());
      final store = await SaveStore.open();
      final g = GameController(
        store: store,
        state: store.load(DateTime.now().millisecondsSinceEpoch),
        server: save == 'late' ? Server(store.prefs, client: MockClient(_fake)) : null,
      );
      await tester.pumpWidget(RepaintBoundary(child: KingdayApp(g: g)));

      Future<void> frames([int n = 6]) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // 그림을 실제로 다 불러올 때까지 잠깐 진짜 시간으로 기다림
      Future<void> settle() async {
        for (var k = 0; k < 3; k++) {
          await tester.runAsync(() async {
            for (final e in find.byType(Image).evaluate()) {
              final im = e.widget as Image;
              try {
                await precacheImage(im.image, e);
              } catch (_) {}
            }
            await Future<void>.delayed(const Duration(milliseconds: 300));
          });
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      var n = 0;
      Future<void> shot(String name) async {
        await settle();
        n++;
        await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('shots/${save}_${n.toString().padLeft(2, '0')}_$name.png'));
      }

      Future<void> close() async {
        final nav = g.navKey.currentState!;
        if (nav.canPop()) nav.pop();
        await frames();
      }

      await frames(2);
      await shot('title');
      await tester.tap(find.text('게임 시작'));
      await frames(8);
      if (save == 'new') {
        await shot('prologue');
        await close();
        await frames(4);
        await shot('region_intro');
        await close();
      } else {
        await shot('offline_reward');
        await close();
        // 출석체크: 방치 보상 다음에 자동으로 뜸 → 출석하기 → 한달 판
        await frames(6);
        await shot('attend');
        await tester.tap(find.text('출석하기'));
        await frames(8);
        await shot('attend_claimed');
        await tester.tap(find.text('한달'));
        await frames(4);
        await shot('attend_month');
        await close();
      }
      // 밀린 이야기 창들을 모두 닫음
      for (var i = 0; i < 25; i++) {
        final nav = g.navKey.currentState!;
        if (nav.canPop()) nav.pop();
        await frames(3);
      }
      await frames(30);
      await shot('battle');

      g.state.raw['pgFull'] = false;
      for (final t in [GameTab.eq, GameTab.up, GameTab.vl, GameTab.mp, GameTab.sh]) {
        g.setTab(t);
        await frames(3);
        await shot('tab_${t.name}');
      }
      for (final sub in ['form', 'list', 'card']) {
        g.state.raw['ptTab'] = sub;
        g.setTab(null);
        g.setTab(GameTab.pt);
        await frames(3);
        await shot('tab_pt_$sub');
      }
      g.state.raw['pgFull'] = true;
      g.setTab(null);
      g.setTab(GameTab.vl);
      await frames(3);
      await shot('tab_vl_full');
      // 마을 건물 창 (아래 반 창)
      g.state.raw['pgFull'] = false;
      for (final (k, t) in [('forge', 'forge'), ('market', 'order'), ('chapel', 'bless'), ('dock', 'work')]) {
        g.vlSelect(k, tab: t);
        await frames(3);
        await shot('vl_${k}_$t');
      }
      g.vbClose();
      g.setTab(null);
      await frames(2);

      g.state.gold = 1e15;
      g.state.done['pete'] = true;
      g.openBox();
      await frames();
      await shot('item_compare');
      await close();

      if (g.calc.owned('margo')) {
        compSheet(g, 'margo');
        await frames();
        await shot('comp_margo');
        await close();
      }

      openProfile(g);
      await frames();
      await shot('profile');
      await close();
      openSettings(g);
      await frames(10);
      await shot('settings');
      await close();

      if (save == 'late') {
        openRanking(g, 'season');
        await frames(10);
        await shot('ranking');
        await close();
        openMail(g);
        await frames(10);
        await shot('mail');
        await close();
        g.state.stage = 25;
        g.askRetire();
        await frames();
        await shot('retire');
        await close();
      }

      await tester.pumpWidget(const SizedBox());
      g.dispose();
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
