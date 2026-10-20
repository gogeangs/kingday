import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/save_store.dart';
import 'game/controller.dart';
import 'screens/shell.dart';
import 'ui/theme.dart';

/// 「왕이 되는 그날까지」 네이티브 앱 시작점.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = await SaveStore.open();
  final g = GameController(store: store, state: store.load(DateTime.now().millisecondsSinceEpoch));
  runApp(ProviderScope(overrides: [gameProvider.overrideWithValue(g)], child: KingdayApp(g: g)));
}

class KingdayApp extends StatefulWidget {
  const KingdayApp({super.key, required this.g});
  final GameController g;

  @override
  State<KingdayApp> createState() => _KingdayAppState();
}

class _KingdayAppState extends State<KingdayApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 웹 visibilitychange: 앱을 벗어나면 바로 저장
  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.paused || st == AppLifecycleState.inactive) widget.g.save();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '왕이 되는 그날까지',
        debugShowCheckedModeBanner: false,
        navigatorKey: widget.g.navKey,
        theme: kdTheme(),
        home: const GameShell(),
      );
}
