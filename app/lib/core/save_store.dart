/// 기기 저장 — 웹 localStorage 'acorn-idle-v1' 과 같은 키·같은 JSON.
///
/// 2단계에서는 진행이 꺼지지 않게 최소한만 한다(불러오기·주기 저장).
/// 방치 보상·웹 기록 가져오기·클라우드 저장은 7·8단계에서 붙인다.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'calc.dart';
import 'data.dart';
import 'state.dart';

class SaveStore {
  SaveStore(this._prefs);
  final SharedPreferences _prefs;

  static Future<SaveStore> open() async => SaveStore(await SharedPreferences.getInstance());

  /// 웹 load(): 저장이 없거나 깨졌으면 새 게임 (웹 start(): hydrate({gold:60}))
  GameState load(int now) {
    final txt = _prefs.getString(wSaveKey);
    if (txt != null) {
      try {
        final s = GameState.fromJson(txt, now, GameCalc.rankIdxOf);
        if (s.raw['gold'] is num) return s;
      } catch (_) {/* 깨진 저장은 버리고 새로 */}
    }
    return GameState.newGame(now, GameCalc.rankIdxOf);
  }

  /// 웹 save(): 마지막 접속 시각을 적고 통째로 저장
  Future<void> save(GameState s, int now) async {
    s.last = now;
    await _prefs.setString(wSaveKey, s.toJson());
  }
}
