import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/save_store.dart';
import 'core/server.dart';
import 'core/state.dart';
import 'game/ads.dart';
import 'game/controller.dart';
import 'game/feel.dart';
import 'screens/shell.dart';
import 'ui/theme.dart';

/// 「왕이 되는 그날까지」 네이티브 앱 시작점.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 실제 폰: 효과음·진동 켬 (시험에서는 꺼져 있음)
  Feel.live = true;
  // 보상형 광고 (시험용 광고 ID)
  Ads.live = true;
  unawaited(Ads.init());
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = await SaveStore.open();
  final g = GameController(store: store, state: store.load(DateTime.now().millisecondsSinceEpoch), server: Server(store.prefs));
  runApp(KingdayApp(g: g));
}

/// 앱 뿌리. 저장 코드 불러오기·초기화 때 진행 담당을 새로 만들어 통째로 바꿔 끼움
/// (웹은 location.reload() 로 페이지를 다시 읽는 자리)
class KingdayApp extends StatefulWidget {
  const KingdayApp({super.key, required this.g});
  final GameController g;

  @override
  State<KingdayApp> createState() => KingdayAppState();
}

class KingdayAppState extends State<KingdayApp> with WidgetsBindingObserver {
  late GameController g;

  @override
  void initState() {
    super.initState();
    g = widget.g..onRestart = _restart;
    WidgetsBinding.instance.addObserver(this);
  }

  void _restart(GameState next) {
    final old = g;
    old.noSave = true;
    setState(() => g = GameController(store: old.store, state: next, server: old.online.sv)..onRestart = _restart);
    // 옛 화면이 다 사라진 다음에 정리
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 웹 visibilitychange: 앱을 벗어나면 바로 저장, 돌아오면 그동안의 방치 보상
  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    switch (st) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        g.onPause();
      case AppLifecycleState.inactive:
        g.save();
      case AppLifecycleState.resumed:
        g.onResume();
    }
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
        key: ObjectKey(g),
        overrides: [gameProvider.overrideWithValue(g)],
        child: MaterialApp(
          title: '왕이 되는 그날까지',
          debugShowCheckedModeBanner: false,
          navigatorKey: g.navKey,
          theme: kdTheme(),
          home: const GameShell(),
        ),
      );
}
