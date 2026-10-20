import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stage0/preview_game.dart';

/// 「왕이 되는 그날까지」 네이티브 앱 시작점.
///
/// 0단계: 개발 환경 확인용 빈 앱. 전투 캔버스(Flame)와 일반 화면(Flutter 위젯)이
/// 함께 돌아가는지만 확인한다. 실제 게임 화면은 1단계부터 이식한다.
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
                    Image.asset('assets/game/ui/logo.png', width: 260),
                    const SizedBox(height: 16),
                    const Text(
                      '네이티브 앱 개발 중 · 0단계',
                      style: TextStyle(
                        color: KdColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '전투 화면(Flame)과 메뉴 화면(Flutter)이\n함께 움직이는지 확인하는 시험판입니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KdColors.text, height: 1.5),
                    ),
                    const Spacer(),
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
