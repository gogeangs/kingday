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
import 'package:kingday/core/event.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/core/server.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/main.dart';
import 'package:kingday/screens/challenge_sheet.dart';
import 'package:kingday/screens/event_sheet.dart';
import 'package:kingday/screens/pt_page.dart';
import 'package:kingday/screens/settings_sheet.dart';
import 'package:kingday/screens/social_sheets.dart';
import 'package:kingday/ui/widgets.dart';
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

/// 2부: 1부를 끝내고 61 「왕궁 뜰」에 있던 예전 저장 (2부 시작 장면 → 큰 제목 → 엘프 왕국 이야기)
Map<String, Object> _p2() {
  final m = jsonDecode(_late()['acorn-idle-v1'] as String) as Map<String, dynamic>;
  final now = DateTime.now();
  final add = <String, dynamic>{
    'stage': 61, 'wave': 3, 'best': 61, 'capClears': 1, 'ending1': 1, 'gold': 9.87e22,
    'up': <String, dynamic>{'atk': 900, 'hp': 900, 'spd': 30, 'crit': 40},
    'att': <String, dynamic>{'intro': 1, 'w': 1, 'ym': '', 'm': 0, 'last': '${now.year}-${now.month}-${now.day}'},
    'mapIntro': 1, 'fogSeen': 61, 'regSeen': <String, dynamic>{'0': 1, '1': 1, '2': 1, '3': 1, '4': 1, '5': 1}, 'rankSeen': 7, 'gemRank': 7,
  };
  add.forEach((k, v) => m[k] = v);
  final done = m['done'] as Map;
  for (final k in const ['capRoad', 'cap56', 'cap57']) {
    done[k] = true;
  }
  return {'acorn-idle-v1': jsonEncode(m)};
}

/// 눈꽃제: 영지 30 (EvClock.demo = 'xmas' 로 이벤트·크리스마스 주간을 켬)
Map<String, Object> _snow() {
  final m = jsonDecode(_late()['acorn-idle-v1'] as String) as Map<String, dynamic>;
  final t = DateTime.now();
  m.addAll({
    'stage': 30, 'wave': 3, 'best': 30, 'gold': 9.87e12, 'chOpen': 1,
    'att': {'intro': 1, 'w': 1, 'ym': '', 'm': 0, 'last': '${t.year}-${t.month}-${t.day}'},
  });
  (m['cards'] as Map)['sobok'] = 20;
  return {'acorn-idle-v1': jsonEncode(m)};
}

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

  for (final save in ['new', 'late', 'p2', 'snow']) {
    testWidgets('화면 캡처 · $save', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(_w * 2, _h * 2);
      addTearDown(tester.view.reset);
      // 눈꽃제: 기간·크리스마스 주간을 켠 채로 시작 (시계는 못 바꾸므로 미리보기 스위치)
      EvClock.demo = save == 'snow' ? 'xmas' : null;
      addTearDown(() => EvClock.demo = null);
      SharedPreferences.setMockInitialValues(save == 'new' ? {} : save == 'p2' ? _p2() : save == 'snow' ? _snow() : _late());
      final store = await SaveStore.open();
      final g = GameController(
        store: store,
        state: store.load(DateTime.now().millisecondsSinceEpoch),
        server: save == 'late' ? Server(store.prefs, client: MockClient(_fake)) : null,
      );
      if (save == 'snow') g.calc.evS(evMain)['sf'] = 1200;
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
      if (save == 'p2' || save == 'snow') {
        // 2부 시작 장면 → 큰 제목 → 엘프 왕국 이야기 (방치 보상·출석 창이 사이에 끼면 그것도 찍음)
        for (var i = 0; i < 6; i++) {
          await frames(6);
          if (!g.navKey.currentState!.canPop()) break;
          await shot(save == 'p2' ? 'p2_pop$i' : 'pop$i');
          await close();
        }
      } else if (save == 'new') {
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
        if (find.text('출석하기').evaluate().isNotEmpty) {
          await tester.tap(find.text('출석하기'));
          await frames(8);
          await shot('attend_claimed');
        }
        if (find.text('한달').evaluate().isNotEmpty) {
          await tester.tap(find.text('한달'));
          await frames(4);
          await shot('attend_month');
        }
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
      if (save == 'snow') {
        // 눈꽃제: 이벤트 창 탭마다 · 출석 받기 · 산타 피트 선물 · 도전 창 칸 · 마을 트리 · 눈사람 대장 전투·결과 · 폭 320~430
        for (final t in ['att', 'boss', 'shop', 'mg']) {
          openEventSheet(g, evMain, t);
          await frames();
          await shot('ev_$t');
          if (t == 'att') {
            await tester.tap(find.byKey(const ValueKey('evAtt')));
            await frames();
            await shot('ev_att_claimed');
          }
          await close();
        }
        ((g.calc.evS(evMain)['xm'] as Map)['gift'] as Map).clear();
        g.evGiftQueue(evMain);
        await frames();
        await shot('xmas_gift');
        await close();
        openChallenge(g);
        await frames();
        await shot('challenge_ev');
        await close();
        g.setTab(GameTab.vl);
        await frames(6);
        await shot('vl_tree');
        g.setTab(null);
        await frames(2);
        final r = g.acts.evBossBegin(evMain);
        g.sim.evBossStart(evMain, r.stg, r.santa, r.ref);
        await frames(30);
        await shot('snow_boss');
        g.sim.chExit();
        await frames(2);
        final rows = g.acts.evGive(evMain, [{'k': 'gem', 'n': 30}]);
        g.queue((ctx) => showKdSheet<void>(ctx, builder: (c) => evBossResultBody(g, c, id: evMain, won: true, stg: 5, santa: true, sf: 60, rows: rows)));
        await frames();
        await shot('snow_boss_result');
        await close();
        for (final w in [320.0, 360.0, 390.0, 430.0]) {
          tester.view.physicalSize = Size(w * 2, _h * 2);
          await frames(2);
          for (final t in ['att', 'shop']) {
            openEventSheet(g, evMain, t);
            await frames();
            await shot('ev_${t}_w${w.round()}');
            await close();
          }
        }
        tester.view.physicalSize = const Size(_w * 2, _h * 2);
        await tester.pumpWidget(const SizedBox());
        g.dispose();
        EvClock.demo = null;
        await tester.pump(const Duration(seconds: 3));
        return;
      }
      if (save == 'p2') {
        // 사막 제국 75 · 엘프 동맹 · 솔렌·사프란 합류 → 전투 · 지도(바다 건너) · 프로필 동맹 칸 · 동맹 창
        g.state.stage = 75;
        g.state.best = 75;
        g.state.wave = 2;
        g.state.raw['ally'] = {'elf': 1, 'desert': 0, 'north': 0};
        g.state.raw['p2Intro'] = 1;
        g.sim.runStoryEvents();
        for (var i = 0; i < 25; i++) {
          final nav = g.navKey.currentState!;
          if (nav.canPop()) nav.pop();
          await frames(3);
        }
        g.state.raw['party'] = {'keeper': 'solen', 'cook': 'saffron'};
        await frames(40);
        await shot('p2_battle75');
        g.state.raw['pgFull'] = true;
        g.setTab(GameTab.mp);
        await frames(6);
        await shot('p2_map_sea');
        g.setTab(null);
        await frames(2);
        g.state.raw['pgFull'] = false;
        g.state.wave = 10;
        g.state.stage = 80;
        await frames(30);
        await shot('p2_boss80');
      }

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
