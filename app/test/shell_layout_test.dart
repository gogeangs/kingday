// 화면 틀이 폰 크기 4종(320·360·390·430 폭)에서 넘치거나 깨지지 않는지 확인.
// (웹 버전을 Playwright 로 확인하던 크기와 같음) Flutter 는 글자·상자가 넘치면 테스트를 실패시킨다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/challenge.dart';
import 'package:kingday/core/retire.dart';
import 'package:kingday/core/save_code.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/main.dart';
import 'package:kingday/screens/challenge_sheet.dart';
import 'package:kingday/screens/mp_page.dart';
import 'package:kingday/screens/pt_page.dart';
import 'package:kingday/screens/settings_sheet.dart';
import 'package:kingday/screens/vl_page.dart';
import 'package:kingday/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 오늘 출석을 이미 한 것으로 (출석부가 자동으로 뜨지 않게)
String _today() {
  final t = DateTime.now();
  return '${t.year}-${t.month}-${t.day}';
}

/// 후반 저장 (긴 칭호·큰 숫자·5명 원정대)
Map<String, Object> _lateSave() => {
      'acorn-idle-v1': '{"gold":9.87e14,"stage":51,"best":51,"gem":123456,"started":true,"chOpen":1,"tower":{"top":14,"day":""},'
          '"joined":{"margo":true,"haral":true,"riel":true,"bron":true},'
          '"done":{"marta":true,"margo":true,"haral":true,"riel":true,"bron":true,"tutSkill":true,"toby":true,"toby2":true,"capRoad":true,"cap56":true,"cap57":true},'
          '"lv":{"bron":60,"haral":61,"riel":58,"margo":55},"bld":{"inn":10,"farm":6,"diner":10,"dock":10,"apiary":9,"mine":10,"forge":3,"market":4,"ranch":2,"chapel":5},'
          '"work":{"dock":["bron"]},"orders":[{"who":"pete","need":{"fish":40,"egg":10},"gold":0,"extra":{"k":"gem","n":4},"at":0},{"at":9999999999999},{"who":"nella","need":{"honey":30},"gold":0,"extra":{"k":"card","n":2},"at":0}],'
          '"bless":{"d":"","used":0,"ad":0,"k":"gold","until":9999999999999,"opts":[]},"vlv":2,'
          '"rec":{"brida":3},"party":{"miner":"brida"},"seeds":{"wheat":5,"carrot":2,"pumpkin":1},"items":{"wheat":40,"carrot":9,"pumpkin":4,"fish":120,"honey":80,"ore":999},"plots":[{"k":"wheat","at":0},{"k":"carrot","at":9999999999999},null],"plotTag":[null,"carrot"],"build":{"k":"dock","end":9999999999999,"dur":3600},"bq":["apiary"],"gemPlots":2,"buffs":{"atk":9999999999999,"gold":9999999999999},"att":{"intro":1,"last":"${_today()}"},"v":3}',
    };

void main() {
  for (final save in ['new', 'late']) {
    for (final w in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('화면 틀 · ${save == 'new' ? '새 게임' : '후반'} · 폭 ${w.toInt()}', (tester) async {
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = Size(w * 3, 760 * 3);
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues(save == 'new' ? {} : _lateSave());
        final store = await SaveStore.open();
        final g = GameController(store: store, state: store.load(DateTime.now().millisecondsSinceEpoch));

        await tester.pumpWidget(KingdayApp(g: g));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('게임 시작'), findsOneWidget);

        await tester.tap(find.text('게임 시작'));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('게임 시작'), findsNothing);

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

        // 새 게임: 프롤로그 → 첫 지역 소개
        if (save == 'new') {
          await frames();
          expect(find.text('밭에 박힌 쇠막대'), findsOneWidget);
          await press('일단 마을부터 지키자');
          await press('진격한다');
          expect(find.text('할 일'), findsOneWidget);
        }

        // 탭 화면 모두 열어 보기 (반쯤 열림 → 크게 보기)
        for (final full in [false, true]) {
          if (g.pgFull != full) g.togglePgFull();
          for (final t in GameTab.values) {
            g.setTab(t);
            await tester.pump(const Duration(milliseconds: 50));
            expect(find.text(t.title), findsWidgets);
          }
        }
        g.setTab(null);
        await tester.pump(const Duration(milliseconds: 50));

        // 이야기 창 (대사 줄·금테 창·버튼) — 앞에 열린 창이 있으면 실패 때 무엇인지 보여 줌
        printOnFailure('앞에 열린 창: ${tester.widgetList<Text>(find.descendant(of: find.byType(KdSheetFrame), matching: find.byType(Text))).map((t) => t.data).take(6).toList()} · 단계 ${g.state.stage}');
        // 이 저장에서 아직 안 본 옛 이야기·칭호 창이 있으면 먼저 모두 닫음 (전투가 빠르면 시험 중에 뜸)
        for (var i = 0; i < 12; i++) {
          final nav = g.navKey.currentState!;
          if (!nav.canPop()) break;
          nav.pop();
          await tester.pump(const Duration(milliseconds: 100));
        }
        g.scene('동료 합류', '요리사 마고', [
          '풍차 언덕 식당 주방에서, 국자 하나로 마물을 막아 내던 아주머니가 있었다.',
          'm:마고@laugh|배고픈 원정대는 못 이겨. 상처엔 수프가 최고야.',
          'k:…네. 사실 그게 제일 하고 싶은 일이에요.',
          'q@proud:훌륭한 안목을 가진 아이로군.',
          'sys:마고가 합류했어요.',
        ], '함께 간다', illust: 'join', altLabel: '나중에');
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('함께 간다'), findsOneWidget);
        // 좁은 폰에서는 창이 길어 버튼이 아래에 있으므로 내려서 누름
        await tester.ensureVisible(find.text('함께 간다'));
        await tester.pump(const Duration(milliseconds: 100));
        var went = false;
        g.scene('확인', '눌러지는지', ['sys:두 번째 창'], '확인했어', onGo: () => went = true);
        await tester.tap(find.text('함께 간다'), warnIfMissed: true);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('함께 간다'), findsNothing, reason: 'modalOpen=${g.modalOpen}');
        // 대기열: 첫 창을 닫으면 다음 창이 뜸
        expect(find.text('확인했어'), findsOneWidget);
        await tester.ensureVisible(find.text('확인했어'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('확인했어'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(went, isTrue);

        Future<void> closeTop() async {
          g.navKey.currentState!.pop();
          await frames();
        }

        // 4단계 화면: 장비·원정대(하위 탭 3개)·단련
        g.state.raw['pgFull'] = false;
        for (final t in [GameTab.eq, GameTab.up]) {
          g.setTab(t);
          await frames(2);
        }
        for (final sub in ['form', 'list', 'card']) {
          g.state.raw['ptTab'] = sub;
          g.setTab(null);
          g.setTab(GameTab.pt);
          await frames(2);
        }
        g.setTab(null);
        await frames(2);

        // 5단계: 마을(건물 6곳·밭·식당)·지도
        g.setTab(GameTab.vl);
        for (final k in ['farm', 'inn', 'diner', 'dock', 'apiary', 'mine', 'forge', 'market', 'ranch', 'chapel']) {
          g.vlSelect(k);
          await frames(2);
          // 건물 창 탭(기능·정보·일꾼)과 크게 보기
          for (final t in g.vbTabs(k)) {
            g.vbTabSet(k, t);
            await frames(1);
          }
        }
        g.vbFull = true;
        g.vlSelect('market', tab: 'order');
        await frames(2);
        g.vbFull = false;
        g.vbClose();
        await frames(1);
        // 일꾼 관리 창 · 마을 레벨 창
        showWorkSheet(g);
        await frames(2);
        await closeTop();
        showVlSheet(g);
        await frames(2);
        await closeTop();
        if (g.calc.plotCount() > 0) {
          g.vlSelect('farm');
          g.state.seeds['wheat'] = 3;
          g.plotEdit = true;
          await frames(2);
          g.plotEdit = false;
          g.acts.ensurePlots();
          g.state.plots[0] = null;
          await frames(2);
        }
        g.setTab(GameTab.mp);
        await frames(2);
        expect(find.textContaining('대륙 탐험'), findsOneWidget);
        // 지역 확대 → 아래 반 창(영지 10곳) → 전체 지도
        mapZoomTo(g, 0, 360);
        await frames(2);
        expect(find.textContaining('되찾은 영지'), findsOneWidget);
        expect(find.text('1-1'), findsOneWidget);
        mapZoomOut(g);
        await frames(2);
        expect(find.textContaining('되찾은 영지'), findsNothing);
        g.setTab(null);

        // 유니크 카엘 촌장: 첫 은퇴 뒤 상점 상품 → 맞이하기 장면 → 카엘 자리 → 정보 창 · 카엘 자리 창
        final ret0 = g.state.raw['retires'];
        g.state.raw['retires'] = 1;
        g.setTab(GameTab.sh);
        await frames(2);
        expect(find.text('카엘 촌장 맞이하기'), findsOneWidget);
        g.act((a) => a.buyChief());
        await frames();
        expect(find.text('은퇴하면 더 바빠진다'), findsOneWidget);
        await tester.ensureVisible(find.text('카엘 자리에 출전'));
        await frames(1);
        await tester.tap(find.text('카엘 자리에 출전'));
        await frames();
        expect(g.calc.slotMember('kael'), 'kael_chief');
        g.state.raw['ucard'] = 30;
        g.setTab(GameTab.pt);
        g.state.raw['ptTab'] = 'card';
        g.refresh();
        await frames(2);
        expect(find.textContaining('유니크 카드 30 / 20'), findsOneWidget);
        chiefSheet(g);
        await frames();
        expect(find.text('다 함께 울력'), findsOneWidget);
        await closeTop();
        kaelSeatSheet(g);
        await frames();
        expect(find.text('누가 출전할까요?'), findsOneWidget);
        await closeTop();
        g.state.raw['ptTab'] = 'form';
        g.state.raw['retires'] = ret0; // 아래 은퇴 시험이 보는 이야기 창이 그대로 나오게
        g.setTab(null);
        await frames(2);

        // 상자 열기 → 비교 창 → 장착
        g.state.gold = 1e12;
        g.state.done['pete'] = true;
        g.openBox();
        await frames();
        expect(find.text('성유물을 얻었어요'), findsOneWidget);
        await tester.ensureVisible(find.text('장착'));
        await frames(1);
        await tester.tap(find.text('장착'));
        await frames();
        expect(find.text('성유물을 얻었어요'), findsNothing);

        // 10연속 결과 창
        g.state.gem = 1000;
        g.act((a) => a.open10());
        await frames();
        expect(find.text('피트의 특별 배달'), findsOneWidget);
        await closeTop();

        // 동료 정보 창·자리 고르기 창·장비 칸 창
        for (final id in ['margo', 'brida']) {
          if (!g.calc.owned(id)) continue;
          compSheet(g, id);
          await frames();
          expect(find.text('레벨업'), findsWidgets);
          await closeTop();
        }
        if (g.calc.jobMembers('miner').length > 1) {
          seatSheet(g, 'miner');
          await frames();
          expect(find.text('누구를 출전시킬까요?'), findsOneWidget);
          await closeTop();
        }

        // 도전 (후반 저장만): 창 → 탑 15층(쌍둥이) 전투 화면 → 나가기 / 던전 전투 화면 → 나가기(★0 환불 창)
        if (save == 'late') {
        openChallenge(g);
        await frames();
        expect(find.text('시련의 탑'), findsWidgets);
        expect(find.text('요일 던전'), findsOneWidget);
        await closeTop();
        g.towerStart(15);
        await frames(3);
        expect(find.text('나가기'), findsOneWidget);
        expect(find.text('시련의 탑 15층'), findsOneWidget);
        g.chExitTap();
        await frames();
        expect(g.sim.ch, isNull);
        g.dunEnter(g.calc.dunOpenK().first);
        await frames();
        if (find.text('입장하기').evaluate().isNotEmpty) await press('입장하기');
        await frames(2);
        expect(g.sim.ch?.mode, 'dun');
        final kills = g.sim.ch?.kills;
        g.chExitTap();
        await frames();
        // 앞서 대기열에 있던 창(칭호 상승 등)이 먼저 뜨면 닫고 결과 창까지 감
        for (var i = 0; i < 5 && find.text('한 마리도 못 잡았어요').evaluate().isEmpty; i++) {
          final nav = g.navKey.currentState!;
          if (!nav.canPop()) break;
          nav.pop();
          await frames();
        }
        final open = tester.widgetList<Text>(find.descendant(of: find.byType(KdSheetFrame), matching: find.byType(Text))).map((t) => t.data).take(8).toList();
        expect(g.sim.ch, isNull);
        expect(g.calc.dunLeft(), 2, reason: '★0 이면 입장권 환불 (처치 $kills)');
        expect(find.text('한 마리도 못 잡았어요'), findsOneWidget, reason: '처치 $kills · modalOpen ${g.modalOpen} · 열린 창 $open');
        await press('확인');
        }

        // 은퇴 일기 (docs/content/RETIRE.md): 처음 대사 → 특성 찍기 → 갈래·탭 바꾸기 → 초기화 확인
        g.state.memory = 40;
        g.setTab(GameTab.up);
        await frames(2);
        expect(find.byKey(const ValueKey('diaryBtn')), findsOneWidget);
        g.openDiary();
        await frames();
        expect(find.text('카엘의 은퇴 일기'), findsOneWidget);
        await press('일기 펼치기');
        await frames();
        // 고른 탭·갈래는 창을 닫아도 남음(웹 diaryTab·diaryBr) → 앞 시험에서 고른 것이 남아 있을 수 있어 처음으로 돌림
        await tester.tap(find.byKey(const ValueKey('dyTab-tr')));
        await frames(2);
        await tester.tap(find.byKey(const ValueKey('dyBr-sword')));
        await frames(2);
        expect(find.text('날 선 괭이'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('dyTr-sharp')));
        await frames(2);
        expect(g.calc.tl('sharp'), 1);
        await tester.tap(find.byKey(const ValueKey('dyBr-travel')));
        await frames(2);
        expect(find.text('지름길'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('dyBr-farm')));
        await frames(2);
        expect(find.text('풍년의 기억'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('dyReset')));
        await frames(1);
        await tester.tap(find.byKey(const ValueKey('dyReset')));
        await frames(2);
        expect(find.text('특성 초기화'), findsOneWidget);
        await press('초기화');
        expect(g.calc.tl('sharp'), 0);
        expect(g.calc.trResetGem(), 100, reason: '첫 초기화는 무료, 다음부터 이삭 100');
        await tester.tap(find.byKey(const ValueKey('dyTab-log')));
        await frames(2);
        expect(find.text('은퇴 횟수'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('dyTab-rw')));
        await frames(2);
        expect(find.textContaining('은퇴 20회'), findsOneWidget);
        await press('닫기');

        // 6단계: 은퇴 (단련 탭 상자 → 은퇴하기 → 확인 → 몇 년 뒤 → 첫 지역)
        g.state.stage = 25;
        g.state.best = 25;
        g.setTab(GameTab.up);
        await frames(2);
        g.askRetire();
        await frames();
        await press('은퇴 준비하기');
        expect(find.text('정말 은퇴할까요?'), findsOneWidget);
        await press('은퇴 확정');
        expect(find.text('…다시 끌려 나오다'), findsOneWidget);
        await press('괭이 대신 검을 든다');
        await press('진격한다');
        expect(g.state.stage, 1);
        expect(g.state.retires, greaterThan(0));

        // 알림
        g.toast('세 줄이 넘을 수도 있는 아주 긴 알림 문장이 잘 줄바꿈되는지 확인해요. 황금 고블린 처치! 골드 +1.23M · 이삭 +9');
        await tester.pump(const Duration(milliseconds: 100));

        await tester.pumpWidget(const SizedBox());
        g.dispose();
        await tester.pump(const Duration(seconds: 3));
      });
    }
  }

  // 7단계: 방치 보상 창 → 설정(카엘의 수첩) → 저장 코드로 불러오기 → 게임 초기화
  for (final w in [320.0, 390.0]) {
    testWidgets('방치 보상·설정·저장 코드 · 폭 ${w.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = Size(w * 3, 760 * 3);
      addTearDown(tester.view.reset);
      final away = DateTime.now().millisecondsSinceEpoch - 3 * 3600 * 1000;
      SharedPreferences.setMockInitialValues({
        'acorn-idle-v1': '{"gold":5000,"stage":12,"best":12,"gem":40,"started":true,"done":{"marta":true},"bld":{"inn":2,"farm":1},"att":{"intro":1,"last":"${_today()}"},"last":$away,"v":3}',
      });
      final store = await SaveStore.open();
      final g = GameController(store: store, state: store.load(DateTime.now().millisecondsSinceEpoch));
      expect(g.state.gold, greaterThan(5000), reason: '꺼 둔 3시간 동안의 세금이 바로 더해짐');

      await tester.pumpWidget(KingdayApp(g: g));
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
      expect(find.text('영지에서 세금이 걷혔어요'), findsOneWidget);
      expect(find.text('3시간 0분 동안'), findsOneWidget);
      await press('받기');
      expect(find.text('영지에서 세금이 걷혔어요'), findsNothing);

      // 설정 창
      openSettings(g);
      await frames();
      expect(find.text('카엘의 수첩'), findsOneWidget);
      await press('진동 끄기');
      expect(g.state.raw['vib'], false);
      await press('코드 만들기·복사');
      final code = tester.widget<TextField>(find.byType(TextField)).controller!.text;
      expect(importSaveCode(code)!['stage'], 12);

      // 다른 기록(영지 30)을 코드로 불러오기 → 앱이 그 기록으로 다시 시작
      final other = Map<String, dynamic>.from(importSaveCode(code)!)
        ..['stage'] = 30
        ..['best'] = 30
        ..['last'] = DateTime.now().millisecondsSinceEpoch;
      await tester.enterText(find.byType(TextField), base64Encode(utf8.encode(jsonEncode(other))));
      await press('불러오기');
      final g2 = tester.state<KingdayAppState>(find.byType(KingdayApp)).g;
      expect(identical(g2, g), isFalse);
      expect(g2.state.stage, 30);
      await press('게임 시작');

      // 엉터리 코드는 거절
      openSettings(g2);
      await frames();
      await tester.enterText(find.byType(TextField), '엉터리 코드');
      await press('불러오기');
      expect(find.text('저장 코드가 올바르지 않아요'), findsOneWidget);

      // 게임 초기화 (두 번 확인)
      await press('게임 초기화');
      expect(find.text('모두 지우기'), findsOneWidget);
      await press('모두 지우기');
      final g3 = tester.state<KingdayAppState>(find.byType(KingdayApp)).g;
      expect(g3.state.stage, 1);
      expect(g3.state.gold, 60);
      await press('게임 시작');
      await frames();
      expect(find.text('밭에 박힌 쇠막대'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      g3.dispose();
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
