import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/save_store.dart';
import 'core/state.dart';
import 'screens/battle_screen.dart';

/// 「왕이 되는 그날까지」 네이티브 앱 시작점.
///
/// 지금은 2단계: 웹과 같은 자동 전투 화면. 상단 바·탭·메뉴는 3단계부터 붙인다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = await SaveStore.open();
  final state = store.load(DateTime.now().millisecondsSinceEpoch);
  runApp(ProviderScope(child: KingdayApp(store: store, state: state)));
}

class KingdayApp extends StatelessWidget {
  const KingdayApp({super.key, required this.store, required this.state});
  final SaveStore store;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '왕이 되는 그날까지',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: KdColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: KdColors.gold, brightness: Brightness.dark),
      ),
      home: BattleScreen(store: store, state: state),
    );
  }
}
