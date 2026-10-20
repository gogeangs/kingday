// 화면 틀이 폰 크기 4종(320·360·390·430 폭)에서 넘치거나 깨지지 않는지 확인.
// (웹 버전을 Playwright 로 확인하던 크기와 같음) Flutter 는 글자·상자가 넘치면 테스트를 실패시킨다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/core/save_store.dart';
import 'package:kingday/game/controller.dart';
import 'package:kingday/main.dart';
import 'package:kingday/screens/pt_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 후반 저장 (긴 칭호·큰 숫자·5명 원정대)
Map<String, Object> _lateSave() => {
      'acorn-idle-v1': '{"gold":9.87e14,"stage":51,"best":51,"gem":123456,"started":true,'
          '"joined":{"margo":true,"haral":true,"riel":true,"bron":true},'
          '"done":{"marta":true,"margo":true,"haral":true,"riel":true,"bron":true,"tutSkill":true},'
          '"lv":{"bron":60,"haral":61,"riel":58,"margo":55},"bld":{"inn":10,"farm":6,"diner":10,"dock":10,"apiary":9,"mine":10},'
          '"rec":{"brida":3},"party":{"miner":"brida"},"seeds":{"wheat":5,"carrot":2,"pumpkin":1},"items":{"wheat":40,"carrot":9,"pumpkin":4,"fish":120,"honey":80,"ore":999},"plots":[{"k":"wheat","at":0},{"k":"carrot","at":9999999999999},null],"plotTag":[null,"carrot"],"build":{"k":"dock","end":9999999999999,"dur":3600},"bq":["apiary"],"gemPlots":2,"buffs":{"atk":9999999999999,"gold":9999999999999},"v":3}',
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

        await tester.pumpWidget(ProviderScope(overrides: [gameProvider.overrideWithValue(g)], child: KingdayApp(g: g)));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('게임 시작'), findsOneWidget);

        await tester.tap(find.text('게임 시작'));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('게임 시작'), findsNothing);

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

        // 이야기 창 (대사 줄·금테 창·버튼)
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

        Future<void> frames([int n = 6]) async {
          for (var i = 0; i < n; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

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
        for (final k in ['farm', 'inn', 'diner', 'dock', 'apiary', 'mine']) {
          g.vlSelect(k);
          await frames(2);
        }
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

        // 알림
        g.toast('세 줄이 넘을 수도 있는 아주 긴 알림 문장이 잘 줄바꿈되는지 확인해요. 황금 고블린 처치! 골드 +1.23M · 이삭 +9');
        await tester.pump(const Duration(milliseconds: 100));

        await tester.pumpWidget(const SizedBox());
        g.dispose();
        await tester.pump(const Duration(seconds: 3));
      });
    }
  }
}
