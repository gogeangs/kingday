import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/calc.dart';
import 'core/data.dart';
import 'core/fmt.dart';
import 'core/state.dart';
import 'stage0/preview_game.dart';

/// 「왕이 되는 그날까지」 네이티브 앱 시작점.
///
/// 지금은 시험 화면: 전투 캔버스(Flame)·일반 화면(Flutter)이 함께 돌아가는지(0단계),
/// 웹과 같은 공식이 들어왔는지(1단계) 확인한다. 실제 게임 화면은 2단계부터 옮긴다.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: KingdayApp()));
}

/// 웹 버전 색 (index.html CSS 변수와 같은 값)
class KdColors {
  static const bg = Color(0xFF141A29); // --bg
  static const panel = Color(0xFF1F2740); // --panel
  static const gold = Color(0xFFFFC94A); // --gold
  static const text = Color(0xFFEEF1F8); // --fg
}

class KingdayApp extends StatelessWidget {
  const KingdayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '왕이 되는 그날까지',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: KdColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: KdColors.gold,
          brightness: Brightness.dark,
        ),
      ),
      home: const Stage0Screen(),
    );
  }
}

class Stage0Screen extends StatefulWidget {
  const Stage0Screen({super.key});

  @override
  State<Stage0Screen> createState() => _Stage0ScreenState();
}

class _Stage0ScreenState extends State<Stage0Screen> {
  late final PreviewGame _game = PreviewGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 위: Flame 전투 캔버스 자리 (웹 버전처럼 화면 위쪽)
            AspectRatio(
              aspectRatio: 390 / 300,
              child: GameWidget(game: _game),
            ),
            // 아래: 일반 Flutter 화면 (메뉴·창 자리)
            Expanded(
              child: Container(
                width: double.infinity,
                color: KdColors.panel,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                    Image.asset('assets/game/ui/logo.png', width: 200),
                    const SizedBox(height: 16),
                    const Text(
                      '네이티브 앱 개발 중 · 1단계',
                      style: TextStyle(
                        color: KdColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '웹과 같은 공식으로 계산한 값입니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KdColors.text, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    const _FormulaCheck(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _game.togglePause();
                        setState(() {});
                      },
                      child: Text(_game.paused ? '다시 걷기' : '멈추기'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1단계 확인용: 새 게임 기준으로 웹과 같은 공식 결과를 몇 줄 보여 준다.
class _FormulaCheck extends StatelessWidget {
  const _FormulaCheck();

  @override
  Widget build(BuildContext context) {
    final c = GameCalc(GameState.newGame(DateTime.now().millisecondsSinceEpoch, GameCalc.rankIdxOf));
    final rows = <(String, String)>[
      ('새 게임 원정대 전투력', fmt(c.power())),
      ('${GameCalc.terrName(10)} 군단장 체력', fmt(GameCalc.monHp(10, true))),
      ('${GameCalc.terrName(50)} 군단장 체력', fmt(GameCalc.monHp(50, true))),
      ('성유물 상자 가격 (1영지)', fmt(c.boxCost())),
      ('여관 Lv.10 공사비', fmt(GameCalc.bldCost(buildingDef('inn'), 9))),
    ];
    return Column(
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(k, style: const TextStyle(color: KdColors.text, fontSize: 13))),
                Text(v, style: const TextStyle(color: KdColors.gold, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}
